;==============================================================================
;  Osd.ahk -- la pastille d'intensite.
;
;  Un bandeau sombre a coins arrondis, en bas au centre, avec le logo, une
;  barre et la valeur. Volontairement discrete : elle apparait a chaque appui
;  et doit se laisser oublier. Elle ne prend jamais le focus et s'efface seule.
;
;  La mise a l'echelle d'affichage reste active, sinon la pastille serait
;  minuscule sur un ecran a 150 %. En revanche Gui.Show met la TAILLE a
;  l'echelle mais pas la POSITION : on mesure donc la fenetre une fois, puis on
;  la place en pixels reels.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Blob.ahk
#Include %A_LineFile%\..\Theme.ahk
#Include %A_LineFile%\..\Ecrans.ahk
#Include %A_LineFile%\..\Ui.ahk
#Include %A_LineFile%\..\Police.ahk
#Include %A_LineFile%\..\Unite.ahk
#Include %A_LineFile%\..\Config.ahk

class Osd {

    static LARGEUR := 228           ; en points, avant mise a l'echelle
    static HAUTEUR := 46
    static MARGE_BAS := 56          ; au-dessus de la barre des taches
    static DUREE := 1200

    static gui := 0
    static pic := 0
    static barre := 0
    static valeur := 0
    static mot := 0                 ; un libelle long, a la place de la barre
    static minuteur := 0
    static px := 0
    static py := 0

    static _Construire() {
        if (Osd.gui)
            return

        g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000", "Ocre")
        g.BackColor := Theme.FOND
        g.MarginX := 0, g.MarginY := 0
        Osd.pic := g.Add("Picture", "x14 y12 w22 h22")
        Osd.barre := g.Add("Progress", "x46 y21 w110 h5 Background" . Theme.TRAIT
                                     . " c" . Theme.ACCENT, 0)

        ;  Le libelle est dessine en GDI+ (Dessin), comme tout le texte du
        ;  panneau et des reglages, et non par un controle Text : celui-ci
        ;  passe par ClearType, dont les franges colorees sur fond sombre
        ;  detonnaient a cote du reste.
        ;
        ;  Deux libelles fixes plutot qu'un seul qu'on deplace : un controle
        ;  deplace laisse derriere lui des bouts de l'ancien texte. L'etroit,
        ;  a droite, tient "100 %", "4380 K", "coupe", MAX ; le large prend la
        ;  place de la barre pour les mots qui n'y tiennent pas -- DARKROOM,
        ;  COLOUR.
        Osd.valeur := g.Add("Picture", "x160 y12 w56 h22")
        Osd.mot := g.Add("Picture", "x46 y12 w170 h22 Hidden")
        ;  Un clic sur la pastille : voir Proposer.
        for ctrl in [Osd.pic, Osd.valeur, Osd.mot]
            ctrl.OnEvent("Click", (*) => Osd._Clic())

        Osd.gui := g
        g.Show("Hide NoActivate w" . Osd.LARGEUR . " h" . Osd.HAUTEUR)
        Theme.Fenetre(g.Hwnd, true)

        ; taille reelle apres mise a l'echelle : sans DetectHiddenWindows,
        ; WinGetPos echoue sur une fenetre cachee et renvoie zero
        ancien := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        WinGetPos(, , &w, &h, "ahk_id " . g.Hwnd)
        DetectHiddenWindows(ancien)
        Osd.px := w, Osd.py := h
    }

    ;--------------------------------------------------------------------------
    ;  texte remplace la valeur affichee, par exemple "coupe".
    ;
    ;  barre et teinte servent a la luminosite : la tache garde la couleur du
    ;  filtre -- c'est elle qui identifie l'application -- mais la barre passe
    ;  au gris. Ce changement de couleur suffit a dire qu'on ne regle pas la
    ;  meme chose, sans avoir a caser un libelle dans une pastille dont
    ;  l'interet est justement de tenir en un coup d'oeil.
    ;--------------------------------------------------------------------------
    ;  ecran designe ou l'afficher. Sur deux ecrans, la poser toujours sur le
    ;  principal revenait a ne pas repondre : quelqu'un qui travaille sur le
    ;  second appuie sur son raccourci et ne voit rien, alors que la pastille
    ;  est apparue derriere lui.
    ;  duree remplace la duree d'affichage, en millisecondes : les pastilles
    ;  d'accueil du premier lancement restent le temps d'etre lues.
    static Montrer(p, texte := "", barre := -1, teinte := "", ecran := 0, duree := 0) {
        ;  Coupee dans le panneau, la pastille ne vient plus a chaque geste.
        ;  Celles qui ont leur propre duree -- l'accueil du premier lancement
        ;  -- passent quand meme : elles ne repondent pas a un geste, elles
        ;  disent ou est la porte.
        if (duree <= 0 && !Osd.Permise())
            return
        ;  Une pastille ordinaire qui remplace une proposition en efface
        ;  l'action : sinon un clic sur "MAX" acceptait encore l'habitude
        ;  proposee juste avant. Proposer repose la sienne apres cet appel.
        Osd.action := 0
        Osd._Construire()

        if (barre < 0)
            barre := p

        Blob.Poser(Osd.pic, p, 22)
        Osd.barre.Opt("c" . (teinte != "" ? teinte : Blob.Hex(p)))
        Osd.barre.Value := Max(0, Min(100, barre))

        ;  "100 %", "4380 K", "coupe", MAX : six caracteres tiennent a droite
        ;  de la barre. Au-dela, le mot prend la place de la barre.
        s := texte ? texte : Unite.Texte(p)
        long := StrLen(s) > 6
        Osd._Ecrire(long ? Osd.mot : Osd.valeur, long ? 170 : 56, s)
        Osd.barre.Visible := !long
        Osd.valeur.Visible := !long
        Osd.mot.Visible := long

        x := (A_ScreenWidth - Osd.px) // 2
        y := A_ScreenHeight - Osd.py - Osd.MARGE_BAS
        try {
            if (!ecran)
                ecran := Ecrans.Actif()
            x := ecran.tx + (ecran.tw - Osd.px) // 2
            y := ecran.ty + ecran.th - Osd.py - Osd.MARGE_BAS
        }

        Osd.gui.Show("NoActivate x" . x . " y" . y
                   . " w" . Osd.LARGEUR . " h" . Osd.HAUTEUR)

        ; rester au-dessus sans jamais voler le focus
        DllCall("SetWindowPos", "ptr", Osd.gui.Hwnd, "ptr", -1
              , "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0013)

        if (Osd.minuteur)
            SetTimer(Osd.minuteur, 0)
        Osd.minuteur := () => Osd.Cacher()
        SetTimer(Osd.minuteur, -(duree > 0 ? duree : Osd.DUREE))
    }

    ;  "pastille" dans ocre.ini : 1 par defaut. La ligne du panneau la bascule.
    static Permise() {
        return Config.Lire("pastille") != "0"
    }

    static Basculer() {
        Config.Ecrire("pastille", Osd.Permise() ? 0 : 1)
        if (!Osd.Permise())
            Osd.Cacher()
    }

    ;  Inter Medium, embarquee (voir Police.ahk). Si elle manque, Famille()
    ;  vaut 0 et Dessin.Texte retombe sur Segoe UI.
    static _Ecrire(ctrl, w, s) {
        d := Dessin.Creer(ctrl, w, 22)
        Dessin.Fond(d, Ui.Coul(Theme.FOND))
        fam := Police.Famille()
        Dessin.Texte(d, s, 0, 0, w, 22, 13, false, Ui.Coul(Theme.TEXTE), 2
                   , fam ? fam : "Segoe UI")
        Dessin.Poser(d, ctrl)
    }

    static Cacher() {
        Osd.action := 0
        if (Osd.gui)
            Osd.gui.Hide()
    }

    ;--------------------------------------------------------------------------
    ;  Une pastille qu'on peut cliquer : "80 comme hier ?". Elle reste huit
    ;  secondes ; un clic n'importe ou dessus appelle action et la ferme.
    ;  La fenetre ne prend jamais le focus (NoActivate), mais un clic sur
    ;  ses controles lui arrive quand meme.
    ;--------------------------------------------------------------------------
    static action := 0
    static PROPOSITION := 8000

    static Proposer(p, texte, action, ecran := 0) {
        Osd.Montrer(p, texte, -1, "", ecran, Osd.PROPOSITION)
        Osd.action := action
    }

    static _Clic(*) {
        a := Osd.action
        Osd.Cacher()
        if (a)
            try a()
    }
}
