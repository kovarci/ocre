;==============================================================================
;  Panneau.ahk -- le panneau du clic droit, en remplacement du menu systeme.
;
;  Un menu Windows est dessine par le systeme : hauteur de ligne, police,
;  marges et coins ne sont pas negociables, et le resultat detonne a cote d'une
;  fenetre entierement peinte. On affiche donc une petite fenetre a nous, ce
;  qui permet en prime d'y mettre le curseur d'intensite : regler le filtre ne
;  demande plus d'ouvrir les reglages.
;
;  Elle se ferme des qu'elle perd le focus, comme un menu. AutoHotkey n'expose
;  pas d'evenement de desactivation : un minuteur surveille la fenetre active.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Blob.ahk
#Include %A_LineFile%\..\Theme.ahk
#Include %A_LineFile%\..\I18n.ahk
#Include %A_LineFile%\..\Widgets.ahk
#Include %A_LineFile%\..\Gamma.ahk
#Include %A_LineFile%\..\Unite.ahk
#Include %A_LineFile%\..\Horaire.ahk
#Include %A_LineFile%\..\Ecrans.ahk
#Include %A_LineFile%\..\Osd.ahk

class Panneau {

    static L := 226
    static gui := 0
    static ctrls := 0
    static veille := 0
    static actions := 0
    static px := 0
    static py := 0
    static logo := 0          ; meme rendez-vous differe que dans les reglages
    static teinte := 0
    static ticLogo := 0

    ;--------------------------------------------------------------------------
    ;  actions : Map avec les cles intensite, luminosite, plus, moins, couper,
    ;  chambre, lireChambre, lire, lireLum, prereglage, reprendre, unite,
    ;  reglages, quitter.
    ;--------------------------------------------------------------------------
    static Montrer(intensite, luminosite, actions) {
        Panneau.Fermer()
        Panneau.actions := actions

        c := Map()
        ;  WS_CLIPCHILDREN et WS_EX_COMPOSITED : le panneau porte deux curseurs,
        ;  et sans ces deux drapeaux ils clignotent des qu'on les fait glisser.
        g := Gui("-Caption +AlwaysOnTop +ToolWindow +0x02000000 +E0x02000000", "Ocre")
        g.BackColor := Theme.FOND
        g.MarginX := 0, g.MarginY := 0

        ;--- en-tete ----------------------------------------------------------
        c["logo"] := g.Add("Picture", "x16 y14 w24 h24")
        Blob.Poser(c["logo"], intensite, 24)
        Panneau.logo := c["logo"]

        g.SetFont("s10 w600 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x50 y17 w100 h20", "Ocre")
        ;  La valeur, en haut a droite, se clique : c'est LA qu'on passe des
        ;  pour cent aux Kelvin et retour (voir Unite.ahk). Nulle part
        ;  ailleurs -- un gout qu'on choisit une fois n'a pas besoin d'une
        ;  case dans les reglages, et la valeur est ce qui change, donc ce
        ;  qu'on clique.
        g.SetFont("s10 w600 c" . Theme.TEXTE_BAS, "Segoe UI")
        c["pct"] := g.Add("Text", "x126 y17 w84 h20 Right", Panneau._Valeur(intensite))
        c["pct"].OnEvent("Click", (*) => Panneau._Unite(c))

        ;--- curseur d'intensite ----------------------------------------------
        c["curseur"] := Curseur.Creer(g, 8, 44, 210, 24, intensite
                                    , (v) => Panneau._Glisser(c, v))

        ;--- curseur de luminosite --------------------------------------------
        ;  L'assombrissement se cherche comme l'intensite : deux jauges cote a
        ;  cote valent mieux qu'un menu ou l'on entrerait un nombre.
        g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x16 y74 w110 h16", I18n.S("lum_court"))
        c["pctLum"] := g.Add("Text", "x116 y74 w94 h16 Right", luminosite . " %")

        c["curseurLum"] := Curseur.Creer(g, 8, 92, 210, 24, luminosite
                                       , (v) => Panneau._GlisserLum(c, v)
                                       , 0, 100, Theme.TEXTE_BAS)

        ;--- prereglages ------------------------------------------------------
        ;  Trois etats qu'on rejoint d'un clic, plutot que de chercher deux
        ;  curseurs a chaque fois. Ils sont ici et pas dans les reglages :
        ;  c'est un geste courant, et les reglages sont ce qu'on ouvre une fois
        ;  par mois.
        ;
        ;  Une rangee de trois boutons plutot que trois rangees pleines : le
        ;  panneau doit tenir au-dessus de la zone de notification, et trois
        ;  rangees lui coutaient quatre-vingt-dix points de hauteur pour trois
        ;  mots.
        c["pre1"] := Bouton.Creer(g, 8, 124, 68, 28, I18n.S("pre_lecture"), false
                                , () => Panneau._Pre(c, "pre_lecture"))
        c["pre2"] := Bouton.Creer(g, 79, 124, 68, 28, I18n.S("pre_film"), false
                                , () => Panneau._Pre(c, "pre_film"))
        c["pre3"] := Bouton.Creer(g, 150, 124, 68, 28, I18n.S("pre_nuit"), false
                                , () => Panneau._Pre(c, "pre_nuit"))

        ;--- commandes --------------------------------------------------------
        y := 166
        c["plus"] := Rangee.Creer(g, 8, y, 210, 30, I18n.S("plus_chaud"), false
                                , () => Panneau._Agir(c, "plus"))
        c["moins"] := Rangee.Creer(g, 8, y + 30, 210, 30, I18n.S("moins_chaud"), false
                                 , () => Panneau._Agir(c, "moins"))
        c["couper"] := Rangee.Creer(g, 8, y + 60, 210, 30, I18n.S("couper"), false
                                  , () => Panneau._Agir(c, "couper"))

        ;  La chambre noire n'existe qu'ici : ni raccourci, ni case dans les
        ;  reglages, ni cle dans ocre.ini. C'est un mode qu'on essaie, pas un
        ;  reglage qu'on garde (voir Filtre.chambre). La ligne ferme le
        ;  panneau, comme les reglages : on vient de changer l'ecran entier,
        ;  on veut le voir.
        c["chambre"] := Rangee.Creer(g, 8, y + 90, 210, 30, Panneau._TexteChambre(), false
                                   , () => Panneau._Sortir("chambre"))

        ;  La pastille se coupe ici, et seulement ici : comme l'unite, c'est
        ;  un gout qu'on choisit une fois. La ligne reste ouverte et change
        ;  de coche -- on voit ce qu'on vient de faire, sans pastille pour
        ;  le dire.
        c["pastille"] := Rangee.Creer(g, 8, y + 120, 210, 30, Panneau._TextePastille(), false
                                    , () => Panneau._Pastille(c))
        y += 150

        ;  Le planificateur suspendu par un reglage a la main le dit ici, et
        ;  offre de reprendre sans attendre le basculement. La ligne n'existe
        ;  que dans ce cas : un panneau qui doit tenir au-dessus de la barre
        ;  des taches ne porte pas de ligne morte.
        if (Horaire.Suspendu()) {
            g.SetFont("s7 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
            g.Add("Text", "x22 y" . (y + 2) . " w190 h14"
                , I18n.S("horaire_suspendu") . Horaire.FinSuspension())
            c["reprendre"] := Rangee.Creer(g, 8, y + 16, 210, 30
                                         , I18n.S("reprendre_horaire"), false
                                         , () => Panneau._Sortir("reprendre"))
            y += 48
        }

        g.Add("Text", "x22 y" . (y + 8) . " w182 h1 Background" . Theme.TRAIT)

        c["reglages"] := Rangee.Creer(g, 8, y + 16, 210, 30, I18n.S("reglages"), true
                                    , () => Panneau._Sortir("reglages"))
        c["quitter"] := Rangee.Creer(g, 8, y + 46, 210, 30, I18n.S("quitter"), false
                                   , () => Panneau._Sortir("quitter"))

        hauteur := y + 86
        Panneau.ctrls := c
        Panneau.gui := g

        ;  Echap ferme, comme un menu ; les fleches reglent le curseur vise
        ;  -- l'intensite tant qu'on n'a pas clique l'autre, Tab pour passer
        ;  de l'un a l'autre.
        Clavier.Lier(g.Hwnd, Map("Escape", (*) => Panneau.Fermer()))
        Curseur.Clavier(g, () => Max(1, Config.LireNombre("pas")))

        ;--- placement au-dessus de la zone de notification --------------------
        g.Show("Hide w" . Panneau.L . " h" . hauteur)
        ancien := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        WinGetPos(, , &w, &h, "ahk_id " . g.Hwnd)
        DetectHiddenWindows(ancien)
        Panneau.px := w, Panneau.py := h

        ;  Borne a la zone de travail de l'ecran SOUS la souris : la barre des
        ;  taches, et son icone, ne sont pas toujours sur l'ecran principal.
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        x := mx - w // 2
        y2 := my - h - 8
        try {
            e := Ecrans.Sous(mx, my)
            x := Max(e.tx + 4, Min(x, e.tx + e.tw - w - 4))
            y2 := Max(e.ty + 4, Min(y2, e.ty + e.th - h - 4))
        }

        ;  Coins arrondis et theme sombre poses avant l'affichage : apres, le
        ;  premier rendu se fait avec les coins et le cadre du systeme.
        Theme.Fenetre(g.Hwnd, true)
        g.Show("x" . x . " y" . y2 . " w" . Panneau.L . " h" . hauteur)
        try WinActivate("ahk_id " . g.Hwnd)
        Ui.Suivre()

        ; un menu se referme quand on clique ailleurs ; AutoHotkey n'ayant pas
        ; d'evenement de desactivation, on surveille la fenetre active
        Panneau.veille := () => Panneau._Veiller()
        SetTimer(Panneau.veille, 160)
    }

    static _Veiller() {
        if (!Panneau.gui)
            return
        try {
            if (!WinActive("ahk_id " . Panneau.gui.Hwnd)) {
                Panneau.Fermer()
                return
            }
        }
        Panneau._Souffler()
    }

    ;  La valeur en haut se clique pour changer d'unite, et rien ne le dit :
    ;  une infobulle au survol le souffle. Le meme minuteur que la veille,
    ;  toutes les 160 ms, suffit a un survol.
    static infobulle := false

    static _Souffler() {
        try {
            MouseGetPos(, , &fen, &ctrl, 2)
            dessus := (fen = Panneau.gui.Hwnd && Panneau.ctrls
                    && ctrl = Panneau.ctrls["pct"].Hwnd)
            if (dessus && !Panneau.infobulle)
                ToolTip(I18n.S("aide_unite"))
            else if (!dessus && Panneau.infobulle)
                ToolTip()
            Panneau.infobulle := dessus
        }
    }

    ;  Poser une icone sur un Picture l'efface puis le redessine : a soixante
    ;  fois par seconde, il scintille. La teinte du logo bouge lentement, un
    ;  rendez-vous toutes les 60 ms suffit largement.
    static _Teinter(v) {
        Panneau.teinte := v
        if (!Panneau.ticLogo)
            Panneau.ticLogo := () => Panneau._PoserLogo()
        SetTimer(Panneau.ticLogo, -60)
    }

    static _PoserLogo() {
        if (Panneau.logo)
            Blob.Poser(Panneau.logo, Panneau.teinte, 24)
    }

    ;  "off" a zero, sinon la valeur dans l'unite choisie.
    static _Valeur(v) {
        return v = 0 ? I18n.S("coupe") : Unite.Texte(v)
    }

    ;  Bascule l'unite et reecrit la valeur ; le reste de l'application la
    ;  reprendra a son prochain affichage.
    static _Unite(c) {
        Unite.Basculer()
        Panneau._Relire(c)
        if (Panneau.actions.Has("unite"))
            (Panneau.actions["unite"])()
    }

    static _Glisser(c, v) {
        c["pct"].Text := Panneau._Valeur(v)
        Panneau._Teinter(v)
        if (Panneau.actions.Has("intensite"))
            (Panneau.actions["intensite"])(v)
    }

    static _GlisserLum(c, v) {
        c["pctLum"].Text := v . " %"
        if (Panneau.actions.Has("luminosite"))
            (Panneau.actions["luminosite"])(v)
    }

    ;  Les trois commandes de reglage laissent le panneau ouvert : on enchaine
    ;  volontiers plusieurs paliers.
    static _Agir(c, cle) {
        if (Panneau.actions.Has(cle))
            (Panneau.actions[cle])()
        Panneau._Relire(c)
    }

    ;  Un prereglage bouge les deux valeurs : le panneau relit donc aussi le
    ;  curseur de luminosite, que les trois commandes de reglage laissent
    ;  tranquille.
    static _Pre(c, cle) {
        if (Panneau.actions.Has("prereglage"))
            (Panneau.actions["prereglage"])(cle)
        Panneau._Relire(c)

        if (Panneau.actions.Has("lireLum")) {
            l := (Panneau.actions["lireLum"])()
            Curseur.Definir(c["curseurLum"], l)
            c["pctLum"].Text := l . " %"
        }
    }

    static _Relire(c) {
        if (!Panneau.actions.Has("lire"))
            return
        v := (Panneau.actions["lire"])()
        Curseur.Definir(c["curseur"], v)
        c["pct"].Text := Panneau._Valeur(v)
        Blob.Poser(c["logo"], v, 24)
    }

    ;  Une coche en tete quand le mode est actif : la ligne dit alors ce
    ;  qu'un second clic defait.
    static _TexteChambre() {
        actif := Panneau.actions.Has("lireChambre") && (Panneau.actions["lireChambre"])()
        return (actif ? Chr(0x2713) . "  " : "") . I18n.S("chambre")
    }

    static _TextePastille() {
        return (Osd.Permise() ? Chr(0x2713) . "  " : "") . I18n.S("pastille")
    }

    static _Pastille(c) {
        Osd.Basculer()
        Rangee.Definir(c["pastille"], Panneau._TextePastille())
    }

    static _Sortir(cle) {
        act := Panneau.actions.Has(cle) ? Panneau.actions[cle] : 0
        Panneau.Fermer()
        if (act)
            act()
    }

    static Fermer() {
        if (Panneau.ticLogo) {
            SetTimer(Panneau.ticLogo, 0)
            Panneau.ticLogo := 0
        }
        Panneau.logo := 0
        if (Panneau.infobulle) {
            ToolTip()
            Panneau.infobulle := false
        }
        if (Panneau.veille) {
            SetTimer(Panneau.veille, 0)
            Panneau.veille := 0
        }
        if (Panneau.gui) {
            Clavier.Delier(Panneau.gui.Hwnd)
            Ui.Oublier(Panneau.gui.Hwnd)
            Panneau.gui.Destroy()
            Panneau.gui := 0
            Panneau.ctrls := 0
        }
    }

    static Ouvert() {
        return Panneau.gui ? true : false
    }
}
