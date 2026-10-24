;==============================================================================
;  Adaptatif.ahk -- la luminosite qui suit ce que l'ecran montre.
;
;  C'est l'idee de Gammy : une page blanche a 100 % de retroeclairage
;  eblouit, un film sombre a 40 % ne se voit plus. Plutot que de regler la
;  luminosite a la main a chaque changement de fenetre, on regarde ce que
;  l'ecran affiche -- sa luminance moyenne -- et l'on descend la luminosite
;  d'Ocre quand le contenu est clair, on la remonte quand il est sombre,
;  entre deux bornes que l'utilisateur choisit.
;
;  La mesure vient de la duplication de bureau DXGI (voir Capture.ahk) :
;  la carte graphique fait la moyenne de tout l'ecran par sa chaine de
;  mipmaps, et le processeur ne relit que soixante points de large. Moins
;  d'un dixieme de milliseconde, et rien du tout quand l'ecran n'a pas
;  change. Si la duplication manque -- une session distante, une machine
;  sans Direct3D --, on retombe sur une copie GDI, plus chere (quatre a
;  sept millisecondes), et l'on ne la fait plus qu'une fois sur trois. La
;  rampe et le retroeclairage ne sont dans aucune des deux : on mesure le
;  contenu, pas ce qu'on en fait, et rien ne boucle.
;
;  Le rythme depasse celui de Gammy : sept mesures par seconde, et la
;  cible recalculee a chacune. Entre la mesure et l'ecran, deux
;  amortisseurs, pour qu'une
;  fenetre qui passe devant une autre ne fasse pas clignoter l'ecran : une
;  moyenne glissante courte (les six dixiemes de la mesure neuve : une page
;  qui change est suivie en trois mesures, une demi-seconde), et un pas
;  minimal de deux points. Le mouvement lui-meme est un fondu, relance
;  depuis la valeur du moment a chaque nouvelle cible : quand le contenu
;  bouge encore, la luminosite le suit sans jamais sauter. Un ecran tout
;  noir -- un jeu en plein ecran exclusif que la copie ne voit pas -- ne
;  dit rien, et l'on garde la valeur d'avant.
;
;  Trois cles d'ocre.ini sans commande dans les reglages, pour qui veut
;  regler la nervosite : adapt_periode (ms entre deux mesures), adapt_fondu
;  (ms du mouvement), adapt_lissage (part de la mesure neuve, 0 a 1).
;
;  Coupe par defaut, comme tout ce qui bouge tout seul.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\Ecrans.ahk
#Include %A_LineFile%\..\Filtre.ahk
#Include %A_LineFile%\..\Capture.ahk

class Adaptatif {

    static PERIODE := 150          ; ms entre deux mesures, par defaut
    static GDI_UNE_SUR := 3        ; sans duplication DXGI, une mesure GDI sur trois
    static FONDU := 600            ; ms du mouvement vers la nouvelle valeur, par defaut
    static LISSAGE := 0.6          ; part de la mesure neuve dans la moyenne glissante
    static GRILLE_L := 64          ; la copie reduite de l'ecran
    static GRILLE_H := 40
    static SEUIL := 2              ; en dessous, on ne bouge pas (points de luminosite)

    static actif := false
    static mini := 30
    static maxi := 100
    static cadence := 150        ; les trois valeurs en service, lues d'ocre.ini
    static mouvement := 600
    static part := 0.6
    static tours := 0            ; compte les tours, pour espacer les mesures GDI
    static tic := 0
    static etat := Map()           ; id d'ecran (ou "*") -> { luma, derniere }
    static poser := 0              ; (pourcent, ecran, duree) => ... pose la luminosite
    static permis := 0             ; () => bool : peut-on bouger en ce moment ?
    static retrait := 0            ; () => points a retirer (la batterie)
    static decalage := 0           ; () => points a ajouter : l'ecart appris (Habitudes)
    static brute := -1             ; la derniere cible avant ecart, pour les habitudes

    static Init(poser, permis := 0, retrait := 0) {
        Adaptatif.poser := poser
        Adaptatif.permis := permis
        Adaptatif.retrait := retrait
        Adaptatif.signature := ""             ; tout repart de zero
        Adaptatif.Relire()
    }

    ;  Rien n'est refait si les reglages du suivi n'ont pas change : chaque
    ;  bascule des reglages passe par ici, et refaire la duplication du
    ;  bureau pour rien coute une bonne fraction de seconde.
    static signature := ""

    static Relire() {
        actif := (Config.Lire("adaptatif") = "1")
        mini := Max(0, Min(100, Config.LireNombre("adapt_mini")))
        maxi := Max(mini, Min(100, Config.LireNombre("adapt_maxi")))
        p := Config.LireNombre("adapt_periode"), f := Config.LireNombre("adapt_fondu")
        l := Config.Lire("adapt_lissage")
        cadence := p >= 50 ? p : Adaptatif.PERIODE
        mouvement := f >= 0 && Config.Lire("adapt_fondu") != "" ? f : Adaptatif.FONDU
        part := IsNumber(l) && l > 0 && l <= 1 ? l + 0.0 : Adaptatif.LISSAGE
        signature := actif . "|" . mini . "|" . maxi . "|" . cadence . "|" . mouvement . "|" . part
        if (signature = Adaptatif.signature && (Adaptatif.tic || !actif))
            return
        Adaptatif.signature := signature
        Adaptatif.Arreter()
        Adaptatif.actif := actif
        Adaptatif.mini := mini, Adaptatif.maxi := maxi
        Adaptatif.cadence := cadence, Adaptatif.mouvement := mouvement, Adaptatif.part := part
        if (!Adaptatif.actif)
            return
        Adaptatif.tic := () => Adaptatif._Battre()
        SetTimer(Adaptatif.tic, Adaptatif.cadence)
    }

    static Arreter() {
        if (Adaptatif.tic)
            SetTimer(Adaptatif.tic, 0)
        Adaptatif.tic := 0
        Adaptatif.etat := Map()
        Adaptatif.brute := -1
        Capture.Oublier()
    }

    ;  Un tour : un ecran par reglage -- tous quand ils sont separes, sinon
    ;  celui qu'on regarde, dont le contenu vaut pour l'ensemble.
    static _Battre() {
        if (Adaptatif.permis && !(Adaptatif.permis)())
            return
        Adaptatif.tours += 1
        if (Filtre.separes) {
            for e in Ecrans.Lister()
                Adaptatif._Suivre(e, e.id)
        } else {
            Adaptatif._Suivre(Ecrans.Actif(), "*")
        }
    }

    static _Suivre(e, id) {
        luma := Capture.Luma(e)
        if (luma = -3) {
            ;  Pas de duplication ici : GDI, moins souvent.
            if (Mod(Adaptatif.tours, Adaptatif.GDI_UNE_SUR))
                return
            luma := Adaptatif.Mesurer(e)
        }
        if (luma < 0)
            return                                   ; rien vu, ou rien de neuf : on garde
        if (!Adaptatif.etat.Has(id))
            Adaptatif.etat[id] := { luma: luma, derniere: -1 }
        s := Adaptatif.etat[id]
        s.luma := s.luma + Adaptatif.part * (luma - s.luma)

        cible := Adaptatif.Cible(s.luma)
        if (Adaptatif.retrait)
            cible := Max(0, cible - (Adaptatif.retrait)())
        Adaptatif.brute := cible
        if (Adaptatif.decalage)
            try cible := Max(0, Min(100, cible + Round((Adaptatif.decalage)())))
        if (s.derniere >= 0 && Abs(cible - s.derniere) < Adaptatif.SEUIL)
            return
        s.derniere := cible
        if (Adaptatif.poser)
            try (Adaptatif.poser)(cible, id = "*" ? 0 : e, Adaptatif.mouvement)
    }

    ;  De la luminance (0 sombre, 1 clair) a la luminosite : lineaire entre
    ;  les bornes, la clarte vers le bas.
    static Cible(luma) {
        return Round(Adaptatif.maxi - (Adaptatif.maxi - Adaptatif.mini) * Max(0.0, Min(1.0, luma)))
    }

    ;--------------------------------------------------------------------------
    ;  La luminance moyenne d'un ecran par GDI, de 0 a 1, ou -1 si la copie
    ;  n'a rien donne (tout noir : un plein ecran exclusif, un ecran eteint).
    ;  C'est le repli quand la duplication DXGI manque.
    ;
    ;  Un StretchBlt de l'ecran vers une DIB de 64 x 40, sans moyenne (le
    ;  mode HALFTONE coute quatre fois plus pour la meme reponse a deux
    ;  centiemes pres), puis Rec. 601 sur chaque point : c'est une moyenne,
    ;  pas une mesure d'etalonnage.
    ;--------------------------------------------------------------------------
    static Mesurer(e := 0) {
        x := 0, y := 0, w := A_ScreenWidth, h := A_ScreenHeight
        try {
            if (e)
                x := e.tx, y := e.ty, w := e.tw, h := e.th
        }
        gl := Adaptatif.GRILLE_L, gh := Adaptatif.GRILLE_H
        somme := 0, n := gl * gh
        hdcS := DllCall("GetDC", "ptr", 0, "ptr")
        hdcM := DllCall("CreateCompatibleDC", "ptr", hdcS, "ptr")
        try {
            ;  BITMAPINFOHEADER : hauteur negative, lignes du haut vers le bas
            bi := Buffer(40, 0)
            NumPut("UInt", 40, bi, 0), NumPut("Int", gl, bi, 4), NumPut("Int", -gh, bi, 8)
            NumPut("UShort", 1, bi, 12), NumPut("UShort", 32, bi, 14)
            hbm := DllCall("CreateDIBSection", "ptr", hdcM, "ptr", bi, "uint", 0
                         , "ptr*", &bits := 0, "ptr", 0, "uint", 0, "ptr")
            old := DllCall("SelectObject", "ptr", hdcM, "ptr", hbm, "ptr")
            DllCall("SetStretchBltMode", "ptr", hdcM, "int", 3)      ; COLORONCOLOR
            ok := DllCall("StretchBlt", "ptr", hdcM, "int", 0, "int", 0, "int", gl, "int", gh
                        , "ptr", hdcS, "int", x, "int", y, "int", w, "int", h
                        , "uint", 0x00CC0020)                       ; SRCCOPY
            if (ok) {
                Loop n {
                    p := NumGet(bits, (A_Index - 1) * 4, "UInt")
                    somme += 299 * ((p >> 16) & 0xFF) + 587 * ((p >> 8) & 0xFF) + 114 * (p & 0xFF)
                }
            }
            DllCall("SelectObject", "ptr", hdcM, "ptr", old)
            DllCall("DeleteObject", "ptr", hbm)
        }
        DllCall("DeleteDC", "ptr", hdcM)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hdcS)
        if (somme = 0)
            return -1
        return somme / (n * 255000.0)
    }
}
