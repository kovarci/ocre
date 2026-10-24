;==============================================================================
;  Widgets.ahk -- les commandes de l'interface, toutes dessinees.
;
;  Bouton, bascule, curseur, compteur et drapeau. Chacun est une Picture dont
;  le contenu est peint en GDI+ (voir Ui.ahk) : c'est ce qui permet de tenir
;  une palette coherente, la ou les widgets Windows imposent leur bleu systeme.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Ui.ahk
#Include %A_LineFile%\..\Theme.ahk
#Include %A_LineFile%\..\I18n.ahk

;------------------------------------------------------------------ bouton ----
class Bouton {

    static Creer(g, x, y, w, h, texte, primaire, action) {
        ctrl := g.Add("Picture", "x" . x . " y" . y . " w" . w . " h" . h)
        o := { ctrl: ctrl, w: w, h: h, texte: texte, primaire: primaire }

        peindre := (z) => Bouton._Peindre(o, z)
        z := Ui.Ajouter(ctrl, peindre)
        o.zone := z

        ctrl.OnEvent("Click", (*) => action())
        return o
    }

    static _Peindre(o, z) {
        d := Dessin.Creer(o.ctrl, o.w, o.h)
        Dessin.Fond(d, Ui.Coul(Theme.FOND))

        if (o.primaire) {
            fond := z.survol ? Theme.ACCENT_VIF : Theme.ACCENT
            Dessin.Rect(d, 0, 0, o.w, o.h, 6, Ui.Coul(fond))
            Dessin.Texte(d, o.texte, 0, 0, o.w, o.h, 12, true
                       , Ui.Coul(Theme.SUR_ACCENT), 1)
        } else {
            Dessin.Rect(d, 0, 0, o.w, o.h, 6
                      , Ui.Coul(z.survol ? Theme.SURFACE_VIF : Theme.SURFACE))
            Dessin.Rect(d, 0.5, 0.5, o.w - 1, o.h - 1, 6, Ui.Coul(Theme.TRAIT), 1)
            Dessin.Texte(d, o.texte, 0, 0, o.w, o.h, 12, false
                       , Ui.Coul(Theme.TEXTE), 1)
        }
        Dessin.Poser(d, o.ctrl)
    }

    static Redessiner(o) {
        Bouton._Peindre(o, o.zone)
    }
}

;------------------------------------------------------------------ champ ----
;  Zone de saisie d'un raccourci. Un Text encadre ferait l'affaire, mais son
;  cadre est peint par Windows en relief clair : on le dessine donc aussi.
class Champ {

    static Creer(g, x, y, w, h, texte, action) {
        ctrl := g.Add("Picture", "x" . x . " y" . y . " w" . w . " h" . h)
        o := { ctrl: ctrl, w: w, h: h, texte: texte, saisie: false }

        z := Ui.Ajouter(ctrl, (zz) => Champ._Peindre(o, zz))
        o.zone := z

        ctrl.OnEvent("Click", (*) => action())
        return o
    }

    static Definir(o, texte, saisie := false) {
        o.texte := texte
        o.saisie := saisie
        Champ._Peindre(o, o.zone)
    }

    static _Peindre(o, z) {
        d := Dessin.Creer(o.ctrl, o.w, o.h)
        Dessin.Fond(d, Ui.Coul(Theme.FOND))

        Dessin.Rect(d, 0, 0, o.w, o.h, 5, Ui.Coul(Theme.SURFACE))
        bord := o.saisie ? Theme.ACCENT : (z.survol ? Theme.TRAIT_VIF : Theme.TRAIT)
        Dessin.Rect(d, 0.5, 0.5, o.w - 1, o.h - 1, 5, Ui.Coul(bord), 1)

        Dessin.Texte(d, o.texte, 4, 0, o.w - 8, o.h, 11, false
                   , Ui.Coul(o.saisie ? Theme.ACCENT : Theme.TEXTE), 1)
        Dessin.Poser(d, o.ctrl)
    }
}

;--------------------------------------------------------------- bascule ------
class Bascule {

    static L := 38
    static H := 20

    static Creer(g, x, y, actif, action) {
        ctrl := g.Add("Picture", "x" . x . " y" . y
                              . " w" . Bascule.L . " h" . Bascule.H)
        o := { ctrl: ctrl, actif: actif ? true : false, action: action }

        z := Ui.Ajouter(ctrl, (zz) => Bascule._Peindre(o, zz))
        o.zone := z

        ctrl.OnEvent("Click", (*) => Bascule._Basculer(o))
        return o
    }

    static _Basculer(o) {
        o.actif := !o.actif
        Bascule._Peindre(o, o.zone)
        if (o.action)
            (o.action)(o.actif)
    }

    static Definir(o, actif) {
        o.actif := actif ? true : false
        Bascule._Peindre(o, o.zone)
    }

    static _Peindre(o, z) {
        d := Dessin.Creer(o.ctrl, Bascule.L, Bascule.H)
        Dessin.Fond(d, Ui.Coul(Theme.FOND))

        piste := o.actif ? (z.survol ? Theme.ACCENT_VIF : Theme.ACCENT)
                         : (z.survol ? Theme.TRAIT_VIF : Theme.TRAIT)
        Dessin.Rect(d, 0, 1, Bascule.L, Bascule.H - 2, (Bascule.H - 2) / 2
                  , Ui.Coul(piste))

        dia := Bascule.H - 8
        cx := o.actif ? (Bascule.L - dia - 4) : 4
        Dessin.Cercle(d, cx, 4, dia
                    , Ui.Coul(o.actif ? Theme.SUR_ACCENT : Theme.TEXTE_BAS))

        Dessin.Poser(d, o.ctrl)
    }
}

;--------------------------------------------------------------- curseur ------
class Curseur {

    ;  Le clavier. Une Picture ne recoit pas de touches ; les fleches passent
    ;  donc par des raccourcis conditionnes a la fenetre (voir Clavier), et il
    ;  faut savoir a quel curseur les adresser : le dernier clique, ou le
    ;  premier cree tant qu'aucun ne l'a ete. Tab passe au suivant.
    ;
    ;  L'anneau qui marque le curseur vise n'apparait qu'a la premiere touche,
    ;  comme le fait Windows : a la souris, personne n'a besoin de savoir
    ;  lequel des deux repondrait aux fleches.
    static parGui := Map()     ; hwnd -> [curseurs, dans l'ordre de creation]
    static focal := Map()      ; hwnd -> le curseur vise
    static visible := Map()    ; hwnd -> l'anneau se montre-t-il

    ;  mini et maxi bornent la course : l'intensite va de 0 a 100, la
    ;  luminosite couvre la meme course. teinte fige la couleur
    ;  de la partie remplie -- sans elle, elle suit l'intensite du filtre, ce
    ;  qui n'aurait pas de sens pour la luminosite.
    static Creer(g, x, y, w, h, valeur, action, mini := 0, maxi := 100, teinte := 0) {
        ctrl := g.Add("Picture", "x" . x . " y" . y . " w" . w . " h" . h)
        o := { ctrl: ctrl, w: w, h: h, valeur: valeur, action: action
             , mini: mini, maxi: maxi, teinte: teinte, gui: g.Hwnd }

        if (!Curseur.parGui.Has(g.Hwnd))
            Curseur.parGui[g.Hwnd] := []
        Curseur.parGui[g.Hwnd].Push(o)
        if (!Curseur.focal.Has(g.Hwnd))
            Curseur.focal[g.Hwnd] := o

        z := Ui.Ajouter(ctrl, (zz) => Curseur._Peindre(o, zz))
        o.zone := z

        ctrl.OnEvent("Click", (*) => Curseur._Saisir(o))
        return o
    }

    ;--------------------------------------------------------------------------
    ;  Relie les fleches a la fenetre : gauche et droite d'un pas, Origine et
    ;  Fin aux bornes, Tab pour changer de curseur. pas est relu a chaque
    ;  appui, comme pour les raccourcis globaux, pour suivre le reglage.
    ;--------------------------------------------------------------------------
    ;  fenetre : la fenetre active a conditionner, si ce n'est pas g --
    ;  un contenu porte par un cadre (voir Cadre.ahk) n'est jamais actif,
    ;  c'est le cadre qui l'est.
    static Clavier(g, pas, fenetre := 0) {
        hw := g.Hwnd
        Clavier.Lier(fenetre ? fenetre : hw, Map(
            "Left",  (*) => Curseur._Decaler(hw, -pas()),
            "Right", (*) => Curseur._Decaler(hw, +pas()),
            "Home",  (*) => Curseur._Borner(hw, -1),
            "End",   (*) => Curseur._Borner(hw, +1),
            "Tab",   (*) => Curseur._Suivant(hw, +1),
            "+Tab",  (*) => Curseur._Suivant(hw, -1)))
    }

    static Oublier(hwnd) {
        for m in [Curseur.parGui, Curseur.focal, Curseur.visible] {
            if (m.Has(hwnd))
                m.Delete(hwnd)
        }
    }

    static _Vise(hwnd) {
        return Curseur.focal.Has(hwnd) ? Curseur.focal[hwnd] : 0
    }

    static _Viser(o, montrer := false) {
        ancien := Curseur._Vise(o.gui)
        Curseur.focal[o.gui] := o
        if (montrer)
            Curseur.visible[o.gui] := true
        if (ancien && ancien != o)
            Curseur._Peindre(ancien, ancien.zone)
        Curseur._Peindre(o, o.zone)
    }

    static _Decaler(hwnd, delta) {
        o := Curseur._Vise(hwnd)
        if (!o)
            return
        Curseur._Viser(o, true)
        Curseur._Poser(o, o.valeur + delta)
    }

    static _Borner(hwnd, sens) {
        o := Curseur._Vise(hwnd)
        if (!o)
            return
        Curseur._Viser(o, true)
        Curseur._Poser(o, sens < 0 ? o.mini : o.maxi)
    }

    static _Suivant(hwnd, sens) {
        if (!Curseur.parGui.Has(hwnd))
            return
        liste := Curseur.parGui[hwnd]
        o := Curseur._Vise(hwnd)
        i := 1
        for k, c in liste {
            if (c = o)
                i := k
        }
        i := Mod(i - 1 + sens + liste.Length, liste.Length) + 1
        Curseur._Viser(liste[i], true)
    }

    ;  Pose une valeur venue du clavier : bornee, peinte, et transmise comme
    ;  si elle venait de la souris.
    static _Poser(o, v) {
        v := Max(o.mini, Min(o.maxi, Round(v)))
        if (v = o.valeur)
            return
        o.valeur := v
        Curseur._Peindre(o, o.zone)
        if (o.action)
            (o.action)(v)
    }

    ;  Un clic pose la valeur, puis on suit la souris tant que le bouton reste
    ;  enfonce : c'est ce qui donne le glisser sans hook souris.
    ;
    ;  Le survol est gele pendant le geste, et le pouce garde sa taille de
    ;  survol : la souris sort forcement du controle quand on glisse vite, et
    ;  le releve de survol faisait alors battre le pouce entre 14 et 16 points.
    static _Saisir(o) {
        Curseur._Viser(o)
        Ui.gele := true
        o.zone.survol := true
        try {
            Curseur._Depuis(o)
            while (GetKeyState("LButton", "P")) {
                Curseur._Depuis(o)
                Sleep(16)
            }
        }
        Ui.gele := false
    }

    static _Depuis(o) {
        marge := 8
        px := Ui.PosLocale(o.ctrl, o.w)
        v := Round(o.mini + (px - marge) / (o.w - 2 * marge) * (o.maxi - o.mini))
        v := Max(o.mini, Min(o.maxi, v))
        if (v != o.valeur) {
            o.valeur := v
            Curseur._Peindre(o, o.zone)
            if (o.action)
                (o.action)(v)
        }
    }

    static Definir(o, v) {
        o.valeur := Max(o.mini, Min(o.maxi, Round(v)))
        Curseur._Peindre(o, o.zone)
    }

    static _Peindre(o, z) {
        d := Dessin.Creer(o.ctrl, o.w, o.h)
        Dessin.Fond(d, Ui.Coul(Theme.FOND))

        marge := 8
        cy := o.h / 2
        piste := o.w - 2 * marge
        etendue := Max(1, o.maxi - o.mini)
        rempli := piste * (o.valeur - o.mini) / etendue

        Dessin.Rect(d, marge, cy - 2, piste, 4, 2, Ui.Coul(Theme.TRAIT))
        if (rempli > 0)
            Dessin.Rect(d, marge, cy - 2, rempli, 4, 2
                      , Ui.Coul(o.teinte ? o.teinte : Blob.Hex(o.valeur)))

        dia := z.survol ? 16 : 14

        ;  L'anneau du curseur vise par le clavier : un cercle un peu plus
        ;  large, sous le pouce, dans la couleur d'accent.
        if (Curseur.visible.Has(o.gui) && Curseur.visible[o.gui]
         && Curseur._Vise(o.gui) = o)
            Dessin.Cercle(d, marge + rempli - dia / 2 - 2, cy - dia / 2 - 2, dia + 4
                        , Ui.Coul(Theme.ACCENT))

        Dessin.Cercle(d, marge + rempli - dia / 2, cy - dia / 2, dia
                    , Ui.Coul(Theme.TEXTE))

        Dessin.Poser(d, o.ctrl)
    }
}

;--------------------------------------------------------------- clavier ------
;  Des touches pour une fenetre entiere.
;
;  Les Picture ne recoivent rien du clavier. Des raccourcis conditionnes a la
;  fenetre active (HotIfWinActive) font l'affaire : ils ne vivent que tant
;  que notre fenetre a le focus, et ne prennent rien a personne d'autre. Ils
;  sont retires avec elle -- la fenetre des reglages se reconstruit a chaque
;  changement de langue, et chaque reconstruction en creerait un jeu de plus.
class Clavier {

    static lies := Map()       ; hwnd -> [touches]

    ;  touches : Map("Left", fn, "Escape", fn, ...)
    static Lier(hwnd, touches) {
        HotIfWinActive("ahk_id " . hwnd)
        for t, fn in touches
            try Hotkey(t, fn, "On")
        HotIf()

        liste := Clavier.lies.Has(hwnd) ? Clavier.lies[hwnd] : []
        for t in touches
            liste.Push(t)
        Clavier.lies[hwnd] := liste
    }

    static Delier(hwnd) {
        Curseur.Oublier(hwnd)
        if (!Clavier.lies.Has(hwnd))
            return
        Clavier._Etat(hwnd, "Off")
        Clavier.lies.Delete(hwnd)
    }

    ;  Le temps d'une capture de raccourci, les touches de la fenetre se
    ;  taisent : sinon une fleche assignee comme raccourci serait avalee par
    ;  le curseur avant d'atteindre le champ.
    static Suspendre(hwnd) {
        Clavier._Etat(hwnd, "Off")
    }

    static Reprendre(hwnd) {
        Clavier._Etat(hwnd, "On")
    }

    static _Etat(hwnd, etat) {
        if (!Clavier.lies.Has(hwnd))
            return
        HotIfWinActive("ahk_id " . hwnd)
        for t in Clavier.lies[hwnd]
            try Hotkey(t, etat)
        HotIf()
    }
}

;---------------------------------------------------------------- alerte ------
;  Un bandeau rouge, pour une seule chose : dire qu'un filtre de Windows se
;  cumule au notre (voir Concurrents.ahk). Il ne repond a rien, ne se survole
;  pas, et n'existe que quand il y a quelque chose a dire.
class Alerte {

    static Creer(g, x, y, w, h, texte) {
        ctrl := g.Add("Picture", "x" . x . " y" . y . " w" . w . " h" . h)
        o := { ctrl: ctrl, w: w, h: h, texte: texte }
        o.zone := Ui.Ajouter(ctrl, (zz) => Alerte._Peindre(o, zz))
        return o
    }

    static _Peindre(o, z) {
        d := Dessin.Creer(o.ctrl, o.w, o.h)
        Dessin.Fond(d, Ui.Coul(Theme.FOND))
        Dessin.Rect(d, 0, 0, o.w, o.h, 6, Ui.Coul(Theme.ALERTE_FOND))

        ;  Un point plein en tete, a la place d'un pictogramme : il se lit
        ;  comme un voyant, et n'exige aucune police de symboles.
        Dessin.Cercle(d, 12, o.h / 2 - 4, 8, Ui.Coul(Theme.ALERTE_TEXTE))
        Dessin.Texte(d, o.texte, 28, 0, o.w - 36, o.h, 11, false
                   , Ui.Coul(Theme.ALERTE_TEXTE), 0)
        Dessin.Poser(d, o.ctrl)
    }
}

;-------------------------------------------------------------- compteur ------
class Compteur {

    ;  pas : increment par clic. Une duree de fondu se compte en quarts
    ;  d'heure, une intensite en paliers de cinq points ; un increment de un
    ;  demanderait vingt clics pour la meme course.
    static Creer(g, x, y, w, h, valeur, mini, maxi, action, pas := 1) {
        ctrl := g.Add("Picture", "x" . x . " y" . y . " w" . w . " h" . h)
        o := { ctrl: ctrl, w: w, h: h, valeur: valeur
             , mini: mini, maxi: maxi, action: action, pas: pas }

        z := Ui.Ajouter(ctrl, (zz) => Compteur._Peindre(o, zz))
        o.zone := z

        ctrl.OnEvent("Click", (*) => Compteur._Clic(o))
        return o
    }

    ;  Les deux boutons occupent une largeur fixe, pas un tiers chacun : a
    ;  84 points de large, le tiers du milieu ne laissait que 28 points pour la
    ;  valeur, et "180" n'y tenait pas.
    static COTE := 20

    static _Clic(o) {
        px := Ui.PosLocale(o.ctrl, o.w)
        cote := Min(Compteur.COTE, o.w / 3)
        sens := (px < cote) ? -1 : (px > o.w - cote) ? 1 : 0
        if (!sens)
            return
        v := Max(o.mini, Min(o.maxi, o.valeur + sens * o.pas))
        if (v = o.valeur)
            return
        o.valeur := v
        Compteur._Peindre(o, o.zone)
        if (o.action)
            (o.action)(v)
    }

    static _Peindre(o, z) {
        d := Dessin.Creer(o.ctrl, o.w, o.h)
        Dessin.Fond(d, Ui.Coul(Theme.FOND))

        Dessin.Rect(d, 0, 0, o.w, o.h, 6, Ui.Coul(Theme.SURFACE))
        Dessin.Rect(d, 0.5, 0.5, o.w - 1, o.h - 1, 6, Ui.Coul(Theme.TRAIT), 1)

        cote := Min(Compteur.COTE, o.w / 3)
        gris := Ui.Coul(Theme.TEXTE_BAS)
        Dessin.Texte(d, "-", 0, 0, cote, o.h, 14, true, gris, 1)
        Dessin.Texte(d, "+", o.w - cote, 0, cote, o.h, 13, true, gris, 1)
        Dessin.Texte(d, o.valeur, cote, 0, o.w - 2 * cote, o.h, 12, true
                   , Ui.Coul(Theme.TEXTE), 1)

        Dessin.Poser(d, o.ctrl)
    }
}

;--------------------------------------------------------------- horloge ------
;  Une heure de la journee, reglee par demi-heures. Un champ de saisie
;  obligerait a valider un format et a gerer les frappes invalides, pour un
;  reglage qui ne demande jamais mieux que la demi-heure.
class Horloge {

    static Creer(g, x, y, w, h, minutes, action, pas := 30) {
        ctrl := g.Add("Picture", "x" . x . " y" . y . " w" . w . " h" . h)
        o := { ctrl: ctrl, w: w, h: h, valeur: minutes, action: action, pas: pas }

        z := Ui.Ajouter(ctrl, (zz) => Horloge._Peindre(o, zz))
        o.zone := z

        ctrl.OnEvent("Click", (*) => Horloge._Clic(o))
        return o
    }

    static _Clic(o) {
        px := Ui.PosLocale(o.ctrl, o.w)
        cote := Min(Compteur.COTE, o.w / 3)
        sens := (px < cote) ? -1 : (px > o.w - cote) ? 1 : 0
        if (!sens)
            return
        ;  L'heure tourne : minuit moins une demi-heure vaut 23:30, pas -30.
        o.valeur := Mod(Mod(o.valeur + sens * o.pas, 1440) + 1440, 1440)
        Horloge._Peindre(o, o.zone)
        if (o.action)
            (o.action)(o.valeur)
    }

    static Texte(minutes) {
        return Format("{:02}:{:02}", minutes // 60, Mod(minutes, 60))
    }

    static _Peindre(o, z) {
        d := Dessin.Creer(o.ctrl, o.w, o.h)
        Dessin.Fond(d, Ui.Coul(Theme.FOND))

        Dessin.Rect(d, 0, 0, o.w, o.h, 6, Ui.Coul(Theme.SURFACE))
        Dessin.Rect(d, 0.5, 0.5, o.w - 1, o.h - 1, 6, Ui.Coul(Theme.TRAIT), 1)

        cote := Min(Compteur.COTE, o.w / 3)
        gris := Ui.Coul(Theme.TEXTE_BAS)
        Dessin.Texte(d, "-", 0, 0, cote, o.h, 14, true, gris, 1)
        Dessin.Texte(d, "+", o.w - cote, 0, cote, o.h, 13, true, gris, 1)
        ;  Affichee dans l'habitude de la langue ; Texte() reste en 24 h pour
        ;  ce qui s'ecrit dans ocre.ini.
        Dessin.Texte(d, I18n.Heure(o.valeur), cote, 0, o.w - 2 * cote, o.h, 12
                   , true, Ui.Coul(Theme.TEXTE), 1)

        Dessin.Poser(d, o.ctrl)
    }
}

;--------------------------------------------------------------- rangee -------
;  Ligne d'un panneau : un libelle qui s'eclaire au survol. Remplace l'entree
;  de menu systeme, dont on ne maitrise ni la hauteur, ni la police, ni les
;  marges.
class Rangee {

    static Creer(g, x, y, w, h, texte, accent, action) {
        ctrl := g.Add("Picture", "x" . x . " y" . y . " w" . w . " h" . h)
        o := { ctrl: ctrl, w: w, h: h, texte: texte, accent: accent }

        z := Ui.Ajouter(ctrl, (zz) => Rangee._Peindre(o, zz))
        o.zone := z

        ctrl.OnEvent("Click", (*) => action())
        return o
    }

    static Definir(o, texte) {
        o.texte := texte
        Rangee._Peindre(o, o.zone)
    }

    static _Peindre(o, z) {
        d := Dessin.Creer(o.ctrl, o.w, o.h)
        Dessin.Fond(d, Ui.Coul(Theme.FOND))

        if (z.survol)
            Dessin.Rect(d, 0, 1, o.w, o.h - 2, 5, Ui.Coul(Theme.SURFACE_VIF))

        Dessin.Texte(d, o.texte, 14, 0, o.w - 24, o.h, 12, false
                   , Ui.Coul(o.accent ? Theme.ACCENT : Theme.TEXTE), 0)
        Dessin.Poser(d, o.ctrl)
    }
}

;--------------------------------------------------------------- drapeau ------
class Drapeau {

    static L := 26
    static H := 17

    static Creer(g, x, y, code, actif, action) {
        ctrl := g.Add("Picture", "x" . x . " y" . y
                              . " w" . Drapeau.L . " h" . Drapeau.H + 6)
        o := { ctrl: ctrl, code: code, actif: actif, action: action }

        z := Ui.Ajouter(ctrl, (zz) => Drapeau._Peindre(o, zz))
        o.zone := z

        ctrl.OnEvent("Click", (*) => (o.action)(o.code))
        return o
    }

    static Definir(o, actif) {
        o.actif := actif
        Drapeau._Peindre(o, o.zone)
    }

    static _Peindre(o, z) {
        H := Drapeau.H
        L := Drapeau.L
        d := Dessin.Creer(o.ctrl, L, H + 6)
        Dessin.Fond(d, Ui.Coul(Theme.FOND))

        ; la langue courante est signalee par un trait sous le drapeau, plus
        ; lisible qu'un cadre sur un gabarit aussi petit
        opacite := (o.actif || z.survol) ? 255 : 110

        Dessin.Limiter(d, 0, 0, L, H, 3)
        if (o.code = "fr") {
            Dessin.Rect(d, 0, 0, L / 3, H, 0, Ui.Coul("0055A4", opacite))
            Dessin.Rect(d, L / 3, 0, L / 3, H, 0, Ui.Coul("F4F4F4", opacite))
            Dessin.Rect(d, 2 * L / 3, 0, L / 3, H, 0, Ui.Coul("EF4135", opacite))
        } else {
            Dessin.Rect(d, 0, 0, L, H, 0, Ui.Coul("012169", opacite))
            Dessin.Ligne(d, 0, 0, L, H, 4, Ui.Coul("F4F4F4", opacite))
            Dessin.Ligne(d, L, 0, 0, H, 4, Ui.Coul("F4F4F4", opacite))
            Dessin.Ligne(d, 0, 0, L, H, 2, Ui.Coul("C8102E", opacite))
            Dessin.Ligne(d, L, 0, 0, H, 2, Ui.Coul("C8102E", opacite))
            Dessin.Rect(d, 0, H / 2 - 3, L, 6, 0, Ui.Coul("F4F4F4", opacite))
            Dessin.Rect(d, L / 2 - 3, 0, 6, H, 0, Ui.Coul("F4F4F4", opacite))
            Dessin.Rect(d, 0, H / 2 - 1.5, L, 3, 0, Ui.Coul("C8102E", opacite))
            Dessin.Rect(d, L / 2 - 1.5, 0, 3, H, 0, Ui.Coul("C8102E", opacite))
        }
        Dessin.Liberer(d)

        if (o.actif)
            Dessin.Rect(d, 3, H + 3, L - 6, 2, 1, Ui.Coul(Theme.ACCENT))

        Dessin.Poser(d, o.ctrl)
    }
}
