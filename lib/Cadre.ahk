;==============================================================================
;  Cadre.ahk -- une fenetre qu'on redimensionne, autour d'un contenu qui ne
;  bouge pas.
;
;  La fenetre des reglages est peinte a coordonnees fixes : chaque controle
;  a sa place au point pres, et c'est ce qui la rend nette. Mais une fenetre
;  qui refuse d'etre tiree par ses bords detonne a cote de tout le reste, et
;  quand elle depasse l'ecran, il n'y a rien a faire.
;
;  D'ou ce cadre : une fenetre ordinaire, redimensionnable, qui porte le
;  contenu comme fenetre enfant (WS_CHILD). Le contenu garde sa largeur et
;  sa hauteur ; le cadre le centre quand il est plus large, et le fait
;  defiler par un ascenseur quand il est moins haut -- comme les reglages de
;  Windows centrent leur colonne, comme un navigateur fait defiler une page.
;  Rien n'est etire : un curseur de 276 points reste un curseur de 276
;  points, quelle que soit la fenetre.
;
;  Les raccourcis de la fenetre (fleches, Echap) se conditionnent sur le
;  cadre, qui est la fenetre active ; les zones peintes restent sur le
;  contenu, qui porte les controles. Tout le reste -- survol, clic, glisser
;  -- lit la position de la souris et ne sait rien du cadre.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Theme.ahk
#Include %A_LineFile%\..\Widgets.ahk
#Include %A_LineFile%\..\Ecrans.ahk
#Include %A_LineFile%\..\Config.ahk

class Cadre {

    static MARGE := 40             ; ce qu'on laisse autour, a la premiere ouverture
    static PAS := 48               ; un cran de molette ou de fleche, en points

    ;  Ouvre un cadre et son contenu, vides. L'appelant construit ses
    ;  controles dans o.contenu, puis appelle Montrer.
    static Creer(titre, largeur, options := "") {
        ;  WS_CLIPCHILDREN et WS_EX_COMPOSITED des deux cotes : voir
        ;  Reglages._Construire pour pourquoi il faut les deux.
        fen := Gui("+Resize -MaximizeBox +0x02000000 +E0x02000000 " . options, titre)
        fen.BackColor := Theme.FOND
        fen.MarginX := 0, fen.MarginY := 0

        ;  WS_CHILD (0x40000000) a la place de WS_POPUP (0x80000000) : une
        ;  vraie fenetre enfant, decoupee par le cadre, sans cadre a elle.
        con := Gui("-Caption -0x80000000 +0x40000000 +Parent" . fen.Hwnd
                 . " +0x02000000 +E0x02000000")
        con.BackColor := Theme.FOND
        con.MarginX := 0, con.MarginY := 0

        o := { fenetre: fen, contenu: con, largeur: largeur, hauteur: 0
             , pos: 0, occupe: false, surTaille: 0, posee: 0 }
        Cadre.cadres[fen.Hwnd] := o

        ;  -1 : reduite dans la barre des taches, rien a disposer.
        fen.OnEvent("Size", (g, etat, w, h) => etat = -1 ? 0 : Cadre._Disposer(o))
        Cadre._Ecouter()
        return o
    }

    static cadres := Map()         ; hwnd du cadre -> o
    static ecoute := false

    ;  Le contenu est construit : on connait sa hauteur. Le cadre s'ouvre a
    ;  la taille demandee -- celle d'avant, ou celle du contenu bornee a
    ;  l'ecran -- et se place par le rappel de l'appelant.
    ;
    ;  taille : { w, h } en points, taille cliente, ou 0.
    ;  placer(fen, w, h) : montre la fenetre a cette taille cliente.
    static Montrer(o, hauteur, taille, placer) {
        o.hauteur := hauteur
        o.contenu.Show("Hide x0 y0 w" . o.largeur . " h" . hauteur)

        ;  L'ascenseur prend sa place dans le client : on l'ajoute a la
        ;  largeur minimale pour que le contenu ne soit jamais rogne.
        asc := Cadre._LargeurAscenseur()
        o.fenetre.Opt("+MinSize" . (o.largeur + asc) . "x240")

        w := o.largeur + asc
        h := hauteur
        if (taille && taille.w >= w && taille.h >= 240) {
            w := taille.w, h := taille.h
        } else {
            ;  Pas plus haut que l'ecran, moins une marge : c'est justement
            ;  le cas ou l'ascenseur sert.
            try {
                e := Ecrans.SousSouris()
                echelle := A_ScreenDPI / 96.0
                h := Min(h, Round(e.th / echelle) - Cadre.MARGE - 40)
            }
        }

        Theme.Fenetre(o.fenetre.Hwnd, false)
        ;  L'ascenseur en sombre : c'est le seul element systeme du cadre.
        try DllCall("uxtheme\SetWindowTheme", "ptr", o.fenetre.Hwnd, "str", "DarkMode_Explorer", "ptr", 0)

        ;  La taille qu'on pose nous-memes : seule une taille DIFFERENTE, donc
        ;  voulue par l'utilisateur, merite d'etre retenue (voir _Disposer).
        o.posee := { w: w, h: h }
        placer(o.fenetre, w, h)
        o.contenu.Show("x0 y0 w" . o.largeur . " h" . hauteur . " NoActivate")
        Cadre._Disposer(o)
    }

    ;  Tout ce qu'une fenetre secondaire demande, en un appel : Fermer et
    ;  Echap vers "fermer", la taille retenue sous "taille_<nom>" dans
    ;  ocre.ini -- en differe, un redimensionnement en envoie des dizaines
    ;  par seconde --, la fenetre a sa place d'avant (une reconstruction) ou
    ;  centree sur l'ecran de la souris. Echap par un raccourci conditionne,
    ;  comme les fleches : l'evenement Escape d'un Gui ne vient pas quand le
    ;  focus est dans l'enfant.
    static Presenter(o, hauteur, nom, fermer, place := 0) {
        o.fenetre.OnEvent("Close", (*) => fermer())
        Clavier.Lier(o.fenetre.Hwnd, Map("Escape", (*) => fermer()))
        Cadre.Montrer(o, hauteur, Cadre.Retenue(nom), (fen, w, h) => Cadre._Placer(fen, w, h, place))
        o.surTaille := (t) => Config.EcrireDiffere("taille_" . nom, t.w . "," . t.h)
        Ui.Suivre()
    }

    static _Placer(fen, w, h, place) {
        if (place)
            fen.Show("x" . place.x . " y" . place.y . " w" . w . " h" . h)
        else
            Ui.Centrer(fen, w, h)
    }

    ;  "520,700" -> { w, h }, ou 0 si rien n'a ete retenu pour cette fenetre.
    static Retenue(nom) {
        parts := StrSplit(Config.Lire("taille_" . nom), ",")
        if (parts.Length = 2 && IsNumber(parts[1]) && IsNumber(parts[2]))
            return { w: Integer(parts[1]), h: Integer(parts[2]) }
        return 0
    }

    ;  La taille cliente courante, en points -- pour la retenir.
    static Taille(o) {
        o.fenetre.GetClientPos(, , &w, &h)
        return { w: w, h: h }
    }

    ;  Delie les raccourcis, oublie les zones, detruit les deux fenetres.
    static Detruire(o) {
        Cadre.cadres.Delete(o.fenetre.Hwnd)
        Clavier.Delier(o.fenetre.Hwnd)
        Curseur.Oublier(o.contenu.Hwnd)
        Ui.Oublier(o.contenu.Hwnd)
        Ui.Oublier(o.fenetre.Hwnd)
        try o.contenu.Destroy()
        try o.fenetre.Destroy()
    }

    ;--------------------------------------------------------------------------
    ;  Place le contenu dans le cadre : centre en largeur, defile en hauteur.
    ;  Montrer ou cacher l'ascenseur change la largeur cliente, ce qui
    ;  redeclenche Size : on se protege de la reentree, et on relit le client
    ;  apres avoir pose l'ascenseur.
    ;--------------------------------------------------------------------------
    static _Disposer(o) {
        if (o.occupe || !o.hauteur)
            return
        o.occupe := true
        try {
            o.fenetre.GetClientPos(, , &cw, &ch)
            defile := (o.hauteur > ch)
            DllCall("ShowScrollBar", "ptr", o.fenetre.Hwnd, "int", 1, "int", defile)
            o.fenetre.GetClientPos(, , &cw, &ch)

            o.pos := defile ? Max(0, Min(o.pos, o.hauteur - ch)) : 0
            if (defile)
                Cadre._Ascenseur(o, ch)

            x := Max(0, (cw - o.largeur) // 2)
            o.contenu.Move(x, -o.pos)

            ;  Retenir la taille seulement si elle n'est plus celle qu'on a
            ;  posee : sinon la premiere ouverture figeait la hauteur du
            ;  contenu de ce jour-la, et une fenetre qui grandit ensuite --
            ;  un bandeau d'alerte, un deuxieme ecran -- s'ouvrait avec un
            ;  ascenseur au lieu de sa hauteur.
            t := Cadre.Taille(o)
            if (o.surTaille && (!o.posee || t.w != o.posee.w || t.h != o.posee.h)) {
                o.posee := t
                try (o.surTaille)(t)
            }
        }
        o.occupe := false
    }

    ;  SCROLLINFO : cbSize, fMask, nMin, nMax, nPage, nPos, nTrackPos.
    static _Ascenseur(o, page) {
        si := Buffer(28, 0)
        NumPut("UInt", 28, si, 0)
        NumPut("UInt", 0x1 | 0x2 | 0x4, si, 4)      ; SIF_RANGE | SIF_PAGE | SIF_POS
        NumPut("Int", 0, si, 8)
        NumPut("Int", o.hauteur - 1, si, 12)
        NumPut("UInt", page, si, 16)
        NumPut("Int", o.pos, si, 20)
        DllCall("SetScrollInfo", "ptr", o.fenetre.Hwnd, "int", 1, "ptr", si, "int", 1)
    }

    static _Defiler(o, delta) {
        o.fenetre.GetClientPos(, , , &ch)
        if (o.hauteur <= ch)
            return
        nouveau := Max(0, Min(o.pos + delta, o.hauteur - ch))
        if (nouveau = o.pos)
            return
        o.pos := nouveau
        Cadre._Disposer(o)
    }

    ;  Un seul abonnement aux messages, pour tous les cadres.
    static _Ecouter() {
        if (Cadre.ecoute)
            return
        Cadre.ecoute := true
        OnMessage(0x0115, ObjBindMethod(Cadre, "_SurAscenseur"))    ; WM_VSCROLL
        OnMessage(0x020A, ObjBindMethod(Cadre, "_SurMolette"))      ; WM_MOUSEWHEEL
    }

    static _SurAscenseur(wParam, lParam, msg, hwnd) {
        if (!Cadre.cadres.Has(hwnd))
            return
        o := Cadre.cadres[hwnd]
        o.fenetre.GetClientPos(, , , &ch)
        switch (wParam & 0xFFFF) {
            case 0: Cadre._Defiler(o, -Cadre.PAS)              ; SB_LINEUP
            case 1: Cadre._Defiler(o, +Cadre.PAS)              ; SB_LINEDOWN
            case 2: Cadre._Defiler(o, -ch)                     ; SB_PAGEUP
            case 3: Cadre._Defiler(o, +ch)                     ; SB_PAGEDOWN
            case 4, 5:                                         ; SB_THUMBPOSITION, SB_THUMBTRACK
                ;  La position de la poignee se relit en entier : les seize
                ;  bits de wParam ne suffisent pas toujours.
                si := Buffer(28, 0)
                NumPut("UInt", 28, si, 0)
                NumPut("UInt", 0x10, si, 4)                    ; SIF_TRACKPOS
                DllCall("GetScrollInfo", "ptr", hwnd, "int", 1, "ptr", si)
                Cadre._Defiler(o, NumGet(si, 24, "Int") - o.pos)
            case 6: Cadre._Defiler(o, -o.hauteur)              ; SB_TOP
            case 7: Cadre._Defiler(o, +o.hauteur)              ; SB_BOTTOM
        }
        return 0
    }

    ;  La molette va au cadre sous la souris, quel que soit le controle qui
    ;  a le focus. Trois crans par coup, comme Windows.
    static _SurMolette(wParam, lParam, msg, hwnd) {
        racine := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")
        if (!Cadre.cadres.Has(racine))
            return
        delta := (wParam >> 16) & 0xFFFF
        if (delta >= 0x8000)
            delta -= 0x10000
        Cadre._Defiler(Cadre.cadres[racine], -Round(delta / 120.0 * Cadre.PAS))
        return 0
    }

    ;  La largeur de l'ascenseur, en points.
    static _LargeurAscenseur() {
        return Round(SysGet(2) * 96.0 / A_ScreenDPI)          ; SM_CXVSCROLL
    }
}
