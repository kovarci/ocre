;==============================================================================
;  Ecrans.ahk -- qui sont les ecrans, et lequel regarde-t-on.
;
;  Gamma.ahk enumerait deja les affichages pour poser la meme rampe sur
;  chacun. Deux besoins nouveaux demandaient de savoir un peu plus :
;
;  - un reglage par ecran. Une dalle de portable et un IPS externe n'ont pas
;    la meme temperature native : a 60 % l'un vire a l'orange quand l'autre
;    reste jaune. Il faut donc pouvoir les regler separement -- et pour cela
;    reconnaitre un ecran d'une session a l'autre.
;
;  - le retroeclairage materiel (voir Retro.ahk), qui se pilote par HMONITOR
;    et non par contexte de peripherique.
;
;  L'identite d'un ecran est son DeviceID de moniteur, du genre
;  MONITOR\ACR0429\{4d36e96e-...}\0001 : il porte le code constructeur et le
;  modele lus dans l'EDID, et le suffixe numerique separe deux exemplaires
;  identiques. Il survit a un redemarrage, ce que ni le HMONITOR ni le nom
;  \\.\DISPLAY1 ne font -- ces deux-la changent au gre des branchements.
;
;  Un ecran sans EDID exploitable -- pilote generique, machine virtuelle --
;  retombe sur son nom d'affichage. C'est moins stable, mais c'est le cas ou
;  il n'y a de toute facon qu'un ecran.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\I18n.ahk

class Ecrans {

    static liste := 0         ; enumeration en cache
    static nb := 0            ; nombre d'ecrans au moment de l'enumeration

    ;--------------------------------------------------------------------------
    ;  La liste des ecrans attaches au bureau.
    ;
    ;  Chaque entree porte :
    ;    id          identifiant stable, pour les reglages persistes
    ;    nom         libelle affichable ("Acer KA240Y", sinon "Ecran 1")
    ;    hdc         contexte de peripherique, pour la rampe gamma
    ;    hmon        HMONITOR, pour le retroeclairage materiel
    ;    principal   vrai pour l'ecran principal
    ;    x, y, w, h  la zone occupee sur le bureau virtuel
    ;
    ;  Les contextes restent ouverts d'un appel a l'autre : les rouvrir a
    ;  chaque cran couterait plus cher que la rampe elle-meme, et la molette en
    ;  demande plusieurs dizaines par seconde. Oublier() les referme quand la
    ;  configuration change.
    ;--------------------------------------------------------------------------
    static Lister() {
        if (Ecrans.liste)
            return Ecrans.liste

        trouves := []

        ;  EnumDisplayMonitors donne les HMONITOR ; GetMonitorInfoW donne pour
        ;  chacun le nom d'affichage, qui est la cle des deux autres API.
        rappel := CallbackCreate(_Recolter, "F", 4)
        DllCall("EnumDisplayMonitors", "ptr", 0, "ptr", 0, "ptr", rappel, "ptr", 0)
        CallbackFree(rappel)

        ;  Pilote exotique, session particuliere : si l'enumeration ne donne
        ;  rien, le contexte du bureau entier vaut mieux que pas de filtre du
        ;  tout. Il ne touchera que l'ecran principal, ce qui est deja mieux
        ;  que rien.
        if (!trouves.Length) {
            hdc := DllCall("GetDC", "ptr", 0, "ptr")
            if (hdc)
                trouves.Push({ id: "bureau", nom: "", hdc: hdc, hmon: 0
                             , propre: false, principal: true
                             , x: 0, y: 0, w: A_ScreenWidth, h: A_ScreenHeight
                             , tx: 0, ty: 0, tw: A_ScreenWidth, th: A_ScreenHeight })
        }

        ;  L'ordre de l'enumeration n'est pas garanti d'une fois sur l'autre.
        ;  Trier sur la position rend la liste des reglages stable : l'ecran de
        ;  gauche reste le premier.
        Ecrans._Trier(trouves)

        ;  Le libelle de repli ne peut etre pose qu'ici : "Ecran 2" n'a de sens
        ;  qu'une fois l'ordre arrete.
        for i, e in trouves {
            if (e.nom = "")
                e.nom := Format(I18n.S("ecran_n"), i)
        }

        Ecrans.liste := trouves
        Ecrans.nb := SysGet(80)          ; SM_CMONITORS
        return trouves

        _Recolter(hmon, hdcInutile, rect, donnees) {
            ;  MONITORINFOEXW : cbSize, rcMonitor(16), rcWork(16), dwFlags,
            ;  puis szDevice sur 32 caracteres larges.
            mi := Buffer(40 + 64, 0)
            NumPut("UInt", 40 + 64, mi, 0)
            if (!DllCall("GetMonitorInfoW", "ptr", hmon, "ptr", mi))
                return true

            nom := StrGet(mi.Ptr + 40, 32, "UTF-16")
            if (nom = "")
                return true

            hdc := DllCall("gdi32\CreateDCW", "wstr", "DISPLAY", "wstr", nom
                         , "ptr", 0, "ptr", 0, "ptr")
            if (!hdc)
                return true

            ident := Ecrans._Identite(nom)

            ;  MONITORINFOEXW : cbSize a 0, rcMonitor de 4 a 20, rcWork de 20
            ;  a 36, dwFlags a 36. La zone de travail exclut la barre des
            ;  taches -- c'est elle qu'il faut pour poser la pastille.
            trouves.Push({ id: ident.id, nom: ident.nom, hdc: hdc, hmon: hmon
                         , propre: true
                         , principal: (NumGet(mi, 36, "UInt") & 1) ? true : false
                         , x: NumGet(mi, 4, "Int"),  y: NumGet(mi, 8, "Int")
                         , w: NumGet(mi, 12, "Int") - NumGet(mi, 4, "Int")
                         , h: NumGet(mi, 16, "Int") - NumGet(mi, 8, "Int")
                         , tx: NumGet(mi, 20, "Int"), ty: NumGet(mi, 24, "Int")
                         , tw: NumGet(mi, 28, "Int") - NumGet(mi, 20, "Int")
                         , th: NumGet(mi, 32, "Int") - NumGet(mi, 24, "Int") })
            return true
        }
    }

    ;--------------------------------------------------------------------------
    ;  Identite et libelle d'un affichage, lus sur son moniteur enfant.
    ;
    ;  EnumDisplayDevices appelee sur "\\.\DISPLAY1" ne rend plus l'adaptateur
    ;  mais l'ecran qui y est branche : DeviceString y est le nom du modele et
    ;  DeviceID la chaine issue de l'EDID.
    ;--------------------------------------------------------------------------
    ;  DISPLAY_DEVICEW, en octets. Les additions calculees ont deja coute une
    ;  sonde : DeviceID commence a 328 et non a 324, ou se trouve StateFlags.
    ;  Lu quatre octets trop tot, l'identifiant valait le caractere de controle
    ;  correspondant a l'etat de l'ecran -- une chaine non vide, invisible a
    ;  l'affichage, et differente d'une machine a l'autre.
    ;
    ;      0    cb              DWORD
    ;      4    DeviceName      32 caracteres larges
    ;     68    DeviceString    128
    ;    324    StateFlags      DWORD
    ;    328    DeviceID        128
    ;    584    DeviceKey       128
    static _Identite(affichage) {
        dd := Buffer(840, 0)
        NumPut("UInt", 840, dd, 0)
        if (!DllCall("EnumDisplayDevicesW", "wstr", affichage, "uint", 0
                   , "ptr", dd, "uint", 0))
            return { id: affichage, nom: "" }

        modele := StrGet(dd.Ptr + 68, 128, "UTF-16")
        ident := StrGet(dd.Ptr + 328, 128, "UTF-16")

        ;  "Generic PnP Monitor" est ce que Windows repond quand il n'a rien
        ;  lu : l'afficher n'apprendrait rien a personne, et le repli numerote
        ;  vaut mieux.
        if (modele = "Generic PnP Monitor"
         || modele = "Moniteur PnP g" . Chr(0xE9) . "n" . Chr(0xE9) . "rique")
            modele := ""

        ;  Un identifiant credible fait au moins quelques caracteres : le repli
        ;  sur le nom d'affichage vaut mieux qu'une cle vide, qui confondrait
        ;  deux ecrans dans les reglages.
        return { id: (StrLen(ident) > 4 ? ident : affichage), nom: modele }
    }

    ;  Tri par position, de gauche a droite puis de haut en bas.
    static _Trier(liste) {
        Loop liste.Length - 1 {
            i := A_Index
            Loop liste.Length - i {
                j := A_Index
                a := liste[j], b := liste[j + 1]
                if (a.x > b.x || (a.x = b.x && a.y > b.y)) {
                    liste[j] := b
                    liste[j + 1] := a
                }
            }
        }
    }

    ;--------------------------------------------------------------------------
    ;  Referme les contextes. Celui d'un ecran debranche ne pose plus rien, et
    ;  un ecran qui arrive n'en a pas encore.
    ;--------------------------------------------------------------------------
    static Oublier() {
        if (!Ecrans.liste)
            return
        for e in Ecrans.liste {
            if (e.propre)
                DllCall("gdi32\DeleteDC", "ptr", e.hdc)
            else
                DllCall("ReleaseDC", "ptr", 0, "ptr", e.hdc)
        }
        Ecrans.liste := 0
    }

    ;  Le nombre d'ecrans a-t-il change depuis l'enumeration ?
    static Verifier() {
        if (Ecrans.liste && SysGet(80) != Ecrans.nb)
            Ecrans.Oublier()
    }

    static Nombre() {
        return Ecrans.Lister().Length
    }

    ;--------------------------------------------------------------------------
    ;  L'ecran ou se trouve un point, en coordonnees du bureau virtuel.
    ;
    ;  Sert a deux choses : poser la pastille la ou l'on travaille, et diriger
    ;  la molette vers l'ecran qu'elle survole. Un point hors de tout ecran --
    ;  cela arrive entre deux dalles de hauteurs differentes -- retombe sur le
    ;  principal plutot que sur rien.
    ;--------------------------------------------------------------------------
    static Sous(x, y) {
        for e in Ecrans.Lister() {
            if (x >= e.x && x < e.x + e.w && y >= e.y && y < e.y + e.h)
                return e
        }
        return Ecrans.Principal()
    }

    static Principal() {
        for e in Ecrans.Lister() {
            if (e.principal)
                return e
        }
        return Ecrans.Lister()[1]
    }

    ;  L'ecran sous la souris.
    static SousSouris() {
        ancien := A_CoordModeMouse
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        CoordMode("Mouse", ancien)
        return Ecrans.Sous(mx, my)
    }

    ;--------------------------------------------------------------------------
    ;  L'ecran de la fenetre active.
    ;
    ;  C'est le bon repere pour un raccourci clavier : on regarde ce sur quoi
    ;  on tape. La souris, elle, peut etre restee ailleurs -- et c'est la
    ;  molette qui la suit.
    ;--------------------------------------------------------------------------
    static Actif() {
        try {
            hwnd := WinGetID("A")
            hmon := DllCall("MonitorFromWindow", "ptr", hwnd, "uint", 2, "ptr")
            for e in Ecrans.Lister() {
                if (e.hmon = hmon)
                    return e
            }
        }
        return Ecrans.Principal()
    }

    ;  L'ecran portant un identifiant donne, ou rien.
    static ParId(id) {
        for e in Ecrans.Lister() {
            if (e.id = id)
                return e
        }
        return 0
    }
}
