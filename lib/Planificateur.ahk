;==============================================================================
;  Planificateur.ahk -- la fenetre du planificateur.
;
;  Ces reglages vivaient dans la fenetre principale. Ils en sont sortis pour
;  une raison mesurable : avec le mode solaire, le lieu et les deux decalages,
;  la fenetre atteignait 1244 pixels sur un ecran de 1200 a 150 % de mise a
;  l'echelle. Elle ne tenait plus.
;
;  C'etait le bon candidat. Un horaire se regle une fois et ne se retouche
;  plus, alors que l'intensite et les raccourcis se reprennent ; et le mode
;  solaire demande de la place -- un lieu, deux decalages -- que la fenetre
;  principale n'avait pas a donner. La bascule "suivre un horaire" reste
;  la-bas, ou elle se voit d'un coup d'oeil.
;
;  Trois modes, choisis d'un clic en tete de fenetre :
;
;    manuel   rien ne bouge tout seul (horaire = 0)
;    soleil   les basculements suivent le coucher et le lever (h_soleil = 1)
;    fixe     deux heures de la journee (h_soleil = 0)
;
;  Ils etaient repartis entre une bascule ici et une la-bas, et il fallait
;  les deux pour comprendre ou l'on en etait. La bascule de la fenetre
;  principale reste, et suit : elle vaut "pas manuel".
;
;  Comme la fenetre du lieu, elle enregistre en validant plutot qu'a la
;  fermeture de la fenetre principale : deux niveaux de "Enregistrer"
;  imbriques poseraient la question de ce qui se passe quand on valide l'un et
;  ferme l'autre. Le mode, lui, s'ecrit des le clic : la fenetre se
;  reconstruit autour, et relirait sinon l'ancien.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Theme.ahk
#Include %A_LineFile%\..\I18n.ahk
#Include %A_LineFile%\..\Widgets.ahk
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\Cadre.ahk
#Include %A_LineFile%\..\Horaire.ahk
#Include %A_LineFile%\..\Lieu.ahk

class Planificateur {

    static L := 464
    static gui := 0
    static c := 0
    static mode := "manuel"
    static surValider := 0
    static place := 0
    static porteur := 0        ; le cadre redimensionnable (voir Cadre.ahk)

    static MODES := ["manuel", "soleil", "fixe"]

    static Ouvrir(surValider := 0) {
        if (Planificateur.gui) {
            try WinActivate("ahk_id " . Planificateur.gui.Hwnd)
            return
        }
        Planificateur.surValider := surValider
        Planificateur.mode := Planificateur.ModeCourant()
        Planificateur._Construire()
    }

    ;  Le mode, lu dans les deux cles qui le portent.
    static ModeCourant() {
        if (Config.Lire("horaire") != "1")
            return "manuel"
        return Config.Lire("h_soleil") = "1" ? "soleil" : "fixe"
    }

    static _Construire() {
        c := Map()
        S := (k) => I18n.S(k)
        mode := Planificateur.mode

        porteur := Cadre.Creer("Ocre", Planificateur.L)
        g := porteur.contenu

        ;--- en-tete ----------------------------------------------------------
        g.SetFont("s12 w600 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y20 w300 h24", S("planificateur_titre"))

        ;--- le mode ----------------------------------------------------------
        ;  Trois boutons, celui du mode en accent : la meme rangee que le
        ;  selecteur d'ecran des reglages.
        ;
        ;  ObjBindMethod et non une lambda : une lambda creee dans une boucle
        ;  capture la VARIABLE, pas sa valeur, et les trois auraient appele
        ;  _Mode avec le dernier mode de la liste. Mesure : cliquer Soleil ne
        ;  faisait rien.
        for i, m in Planificateur.MODES {
            c["mode_" . m] := Bouton.Creer(g, 24 + (i - 1) * 140, 58, 136, 26
                                         , S("mode_" . m), mode = m
                                         , ObjBindMethod(Planificateur, "_Mode", m))
        }

        y := 104
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")

        if (mode = "manuel") {
            ;  Rien a regler : on le dit, et on s'arrete la.
            g.SetFont("s7 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
            g.Add("Text", "x24 y" . y . " w416 h30", S("aide_manuel"))
            y += 40
        } else {
            if (mode = "soleil") {
                ;  Le lieu, sur sa rangee : le soleil ne se calcule pas sans.
                g.Add("Text", "x24 y" . (y + 5) . " w110 h18", S("lieu"))
                c["lieu"] := Bouton.Creer(g, 148, y, 292, 26, Lieu.Resume(), false
                                        , () => Planificateur._Lieu(c))
                y += 40

                ;  Deux decalages sur le coucher et le lever, en minutes.
                g.Add("Text", "x24 y" . (y + 5) . " w120 h18", S("dec_nuit"))
                c["h_dec_nuit"] := Compteur.Creer(g, 140, y, 100, 26
                                                , Config.LireNombre("h_dec_nuit")
                                                , -180, 180, (v) => Planificateur._Ecrire("h_dec_nuit", v), 15)
                g.Add("Text", "x252 y" . (y + 5) . " w100 h18", S("dec_jour"))
                c["h_dec_jour"] := Compteur.Creer(g, 340, y, 100, 26
                                                , Config.LireNombre("h_dec_jour")
                                                , -180, 180, (v) => Planificateur._Ecrire("h_dec_jour", v), 15)
            } else {
                ;  Deux heures de la journee, par demi-heures.
                g.Add("Text", "x24 y" . (y + 5) . " w120 h18", S("nuit_de"))
                c["h_debut"] := Horloge.Creer(g, 140, y, 100, 26
                                            , Horaire.EnMinutes(Config.Lire("h_debut"), 21 * 60)
                                            , (v) => Planificateur._Ecrire("h_debut", Horloge.Texte(v)))
                g.Add("Text", "x252 y" . (y + 5) . " w100 h18", S("jour_de"))
                c["h_fin"] := Horloge.Creer(g, 340, y, 100, 26
                                          , Horaire.EnMinutes(Config.Lire("h_fin"), 7 * 60)
                                          , (v) => Planificateur._Ecrire("h_fin", Horloge.Texte(v)))
            }
            y += 40

            ;  L'intensite de jour n'a pas de commande : elle vaut zero,
            ;  c'est-a-dire filtre coupe, dans tous les cas ou l'on veut un
            ;  horaire. Qui tient a un fond de filtre en pleine journee la
            ;  pose dans ocre.ini.
            g.Add("Text", "x24 y" . (y + 5) . " w60 h18", S("fondu_court"))
            c["h_fondu"] := Compteur.Creer(g, 88, y, 84, 26
                                         , Max(15, Config.LireNombre("h_fondu"))
                                         , 15, 300, (v) => Planificateur._Ecrire("h_fondu", v), 15)
            g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
            g.Add("Text", "x178 y" . (y + 5) . " w60 h18", S("minutes"))

            g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
            g.Add("Text", "x244 y" . (y + 5) . " w110 h18", S("int_nuit"))
            c["h_nuit"] := Compteur.Creer(g, 356, y, 84, 26
                                        , Config.LireNombre("h_nuit"), 0, 100, (v) => Planificateur._Ecrire("h_nuit", v), 5)
            y += 36

            ;  L'aide dit ce que le mode courant demande d'expliquer, et rien
            ;  de plus : les deux textes tiennent dans la meme place.
            g.SetFont("s7 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
            g.Add("Text", "x24 y" . y . " w416 h44"
                , mode = "soleil" ? S("aide_soleil") : S("aide_horaire"))
            y += 48
        }

        ;--- le rappel des 20-20-20 -------------------------------------------
        ;  Il n'a rien a voir avec le fondu, mais tout a voir avec l'heure, et
        ;  la fenetre principale n'a plus de hauteur a lui donner (voir
        ;  Rappel.ahk).
        g.Add("Text", "x24 y" . y . " w416 h1 Background" . Theme.TRAIT)
        c["rappel"] := Bascule.Creer(g, 24, y + 14, Config.Lire("rappel") = "1"
                                   , (a) => Planificateur._Ecrire("rappel", a ? 1 : 0))
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x72 y" . (y + 16) . " w368 h18", S("rappel"))
        y += 56

        ;  Pas de boutons : chaque commande s'applique quand on la touche, et
        ;  la fenetre se ferme par sa croix ou par Echap.
        yb := y - 34

        Planificateur.gui := porteur.fenetre
        Planificateur.porteur := porteur
        Planificateur.c := c

        place := Planificateur.place
        Planificateur.place := 0
        Cadre.Presenter(porteur, yb + 34, "planificateur", () => Planificateur.Fermer(), place)
    }

    ;  Changer de mode change la nature des commandes : on reconstruit, a la
    ;  place exacte de l'ancienne fenetre pour qu'elle ne saute pas sous la
    ;  souris. Le mode est ecrit tout de suite, sans quoi la fenetre
    ;  reconstruite relirait l'ancien.
    static _Mode(m) {
        if (m = Planificateur.mode)
            return
        Planificateur.mode := m
        Config.Ecrire("horaire", m = "manuel" ? 0 : 1)
        if (m != "manuel")
            Config.Ecrire("h_soleil", m = "soleil" ? 1 : 0)

        ancien := Planificateur.porteur
        Planificateur.place := 0
        try {
            WinGetPos(&x, &y, , , "ahk_id " . ancien.fenetre.Hwnd)
            Planificateur.place := { x: x, y: y }
        }
        Planificateur.gui := 0
        Planificateur.porteur := 0
        Planificateur._Construire()
        Cadre.Detruire(ancien)
        Planificateur._Signaler()
    }

    static _Lieu(c) {
        Lieu.Ouvrir((lat, lon, libelle) => Planificateur._LieuChoisi(c))
    }

    static _LieuChoisi(c) {
        try {
            c["lieu"].texte := Lieu.Resume()
            Bouton.Redessiner(c["lieu"])
        }
        Planificateur._Signaler()
    }

    ;  Chaque commande ecrit sa cle, et le programme relit l'horaire -- avec
    ;  un temps de regroupement, pour qu'une horloge qu'on avance de trois
    ;  demi-heures ne relance pas trois fois le planificateur.
    static tic := 0

    static _Ecrire(cle, valeur) {
        Config.Ecrire(cle, valeur)
        Planificateur._Signaler()
    }

    static _Signaler() {
        if (!Planificateur.tic)
            Planificateur.tic := () => Planificateur._Appliquer()
        SetTimer(Planificateur.tic, -300)
    }

    static _Appliquer() {
        if (Planificateur.surValider)
            (Planificateur.surValider)()
    }

    static Fermer() {
        if (Planificateur.porteur) {
            Cadre.Detruire(Planificateur.porteur)
            Planificateur.porteur := 0
            Planificateur.gui := 0
            Planificateur.c := 0
        }
    }
}
