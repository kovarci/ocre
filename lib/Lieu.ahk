;==============================================================================
;  Lieu.ahk -- ou sommes-nous.
;
;  Une fenetre a part, et non deux champs de plus dans les reglages : la
;  recherche a besoin de place pour ses resultats, et la fenetre de reglages
;  n'a plus de hauteur a donner.
;
;  Deux facons de repondre, parce qu'elles ne s'adressent pas aux memes gens :
;
;  - le nom de la ville, pour a peu pres tout le monde. La table couvre les
;    villes de plus de 20 000 habitants (voir Villes.ahk) ;
;  - la latitude et la longitude, pour qui les connait, habite un village, ou
;    tient a la precision.
;
;  La fenetre affiche en permanence le lever et le coucher du jour pour le lieu
;  retenu. Ce n'est pas une decoration : c'est ce qui rend une erreur visible
;  tout de suite. Il existe un Laval au Quebec et un Laval en Mayenne, et la
;  seule facon de savoir qu'on a pris le mauvais est de voir le soleil s'y
;  coucher six heures trop tot.
;
;  La saisie passe par des controles Edit natifs et non par des Picture
;  peintes, contrairement au reste de l'interface : un champ de texte veut un
;  curseur clignotant, une selection, le collage et les touches de direction.
;  Les redessiner serait un projet a soi seul, et SetWindowTheme suffit ici a
;  les mettre au sombre -- ce qu'il ne savait pas faire pour le controle
;  Hotkey, d'ou les champs peints de Reglages.ahk.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Theme.ahk
#Include %A_LineFile%\..\I18n.ahk
#Include %A_LineFile%\..\Widgets.ahk
#Include %A_LineFile%\..\Villes.ahk
#Include %A_LineFile%\..\Fuseau.ahk
#Include %A_LineFile%\..\Soleil.ahk
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\Cadre.ahk

class Lieu {

    static L := 396
    static porteur := 0        ; le cadre redimensionnable (voir Cadre.ahk)
    static LIGNES := 6            ; resultats affiches au plus
    static DELAI := 220           ; regroupement de la frappe, en ms

    static gui := 0
    static c := 0
    static rangees := 0
    static trouves := 0
    static tic := 0
    static surChoix := 0

    static lat := 0
    static lon := 0
    static libelle := ""

    ;--------------------------------------------------------------------------
    ;  surChoix(lat, lon, libelle) est appele a la validation, jamais avant :
    ;  fermer la fenetre par Echap doit laisser le reglage precedent en place.
    ;--------------------------------------------------------------------------
    static Ouvrir(surChoix) {
        if (Lieu.gui) {
            try WinActivate("ahk_id " . Lieu.gui.Hwnd)
            return
        }
        Lieu.surChoix := surChoix
        Lieu.lat := Lieu._Nombre(Config.Lire("lat"))
        Lieu.lon := Lieu._Nombre(Config.Lire("lon"))
        Lieu.libelle := Config.Lire("lieu")
        Lieu.trouves := []
        Lieu._Construire()
    }

    static _Nombre(texte) {
        texte := StrReplace(Trim(texte . ""), ",", ".")
        return IsNumber(texte) ? texte + 0 : 0
    }

    static _Construire() {
        c := Map()
        S := (k) => I18n.S(k)

        porteur := Cadre.Creer("Ocre", Lieu.L, "+Owner")
        g := porteur.contenu

        ;--- en-tete ----------------------------------------------------------
        g.SetFont("s12 w600 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y20 w300 h24", S("lieu_titre"))
        g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x24 y46 w" . (Lieu.L - 48) . " h30", S("lieu_aide"))

        ;--- recherche --------------------------------------------------------
        g.SetFont("s10 w400 c" . Theme.TEXTE, "Segoe UI")
        c["q"] := g.Add("Edit", "x24 y84 w" . (Lieu.L - 48) . " h30 -E0x200 Background"
                              . Theme.CHAMP)
        Theme.Controle(c["q"])
        c["q"].OnEvent("Change", (*) => Lieu._Frappe())

        ;--- resultats --------------------------------------------------------
        ;  Les rangees sont creees une fois pour toutes et masquees : les
        ;  detruire et les recreer a chaque frappe ferait clignoter la fenetre,
        ;  et laisserait derriere elle des zones de survol orphelines.
        Lieu.rangees := []
        y := 122
        Loop Lieu.LIGNES {
            i := A_Index
            r := Rangee.Creer(g, 16, y, Lieu.L - 32, 28, "", false
                            , () => Lieu._Choisir(i))
            r.ctrl.Visible := false
            Lieu.rangees.Push(r)
            y += 28
        }

        ;--- coordonnees ------------------------------------------------------
        yc := 122 + Lieu.LIGNES * 28 + 8
        g.Add("Text", "x24 y" . yc . " w" . (Lieu.L - 48) . " h1 Background" . Theme.TRAIT)

        g.SetFont("s7 w600 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x24 y" . (yc + 14) . " w200 h14", S("coordonnees"))

        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y" . (yc + 40) . " w62 h18", S("latitude"))
        c["lat"] := g.Add("Edit", "x88 y" . (yc + 35) . " w92 h26 -E0x200 Background"
                                . Theme.CHAMP, Lieu._Ecrire(Lieu.lat))
        g.Add("Text", "x196 y" . (yc + 40) . " w62 h18", S("longitude"))
        c["lon"] := g.Add("Edit", "x260 y" . (yc + 35) . " w92 h26 -E0x200 Background"
                                . Theme.CHAMP, Lieu._Ecrire(Lieu.lon))
        Theme.Controle(c["lat"])
        Theme.Controle(c["lon"])
        c["lat"].OnEvent("Change", (*) => Lieu._Coordonnees())
        c["lon"].OnEvent("Change", (*) => Lieu._Coordonnees())

        ;--- ce que cela donne ------------------------------------------------
        ;  La verification par les consequences : si le soleil se couche a une
        ;  heure qui ne ressemble a rien, ce n'est pas le bon Laval.
        g.SetFont("s9 w400 c" . Theme.ACCENT, "Segoe UI")
        c["soleil"] := g.Add("Text", "x24 y" . (yc + 76) . " w" . (Lieu.L - 48) . " h20", "")

        ;  Pas de boutons : une ville choisie, une coordonnee tapee sont le
        ;  lieu a l'instant meme ; la croix ou Echap ferment.
        yb := yc + 82

        Lieu.gui := porteur.fenetre
        Lieu.porteur := porteur
        Lieu.c := c

        Cadre.Presenter(porteur, yb + 34, "lieu", () => Lieu.Fermer())
        Lieu._Montrer()

        ;  Le champ de recherche prend le focus : on ouvre cette fenetre pour
        ;  taper un nom de ville, pas pour la regarder.
        try c["q"].Focus()
    }

    ;--------------------------------------------------------------------------
    ;  La frappe est regroupee. Une recherche coute une trentaine de
    ;  millisecondes sur 26 000 villes -- assez peu pour ne pas se voir, assez
    ;  pour se sentir si on la relance a chaque caractere d'une saisie rapide.
    ;--------------------------------------------------------------------------
    static _Frappe() {
        if (!Lieu.tic)
            Lieu.tic := () => Lieu._Chercher()
        SetTimer(Lieu.tic, -Lieu.DELAI)
    }

    static _Chercher() {
        if (!Lieu.gui)
            return
        Lieu.trouves := Villes.Chercher(Lieu.c["q"].Value, Lieu.LIGNES)

        for i, r in Lieu.rangees {
            if (i <= Lieu.trouves.Length) {
                v := Lieu.trouves[i]
                Rangee.Definir(r, v.nom . "   " . Pays.Nom(v.pays, I18n.langue))
                r.ctrl.Visible := true
            } else {
                r.ctrl.Visible := false
            }
        }
    }

    static _Choisir(i) {
        if (i > Lieu.trouves.Length)
            return
        v := Lieu.trouves[i]
        Lieu.lat := v.lat
        Lieu.lon := v.lon
        Lieu.libelle := v.nom . ", " . Pays.Nom(v.pays, I18n.langue)

        ;  Les champs de coordonnees suivent le choix : ils montrent ce qui a
        ;  ete retenu, et restent modifiables pour l'ajuster.
        Lieu.c["lat"].Value := Lieu._Ecrire(Lieu.lat)
        Lieu.c["lon"].Value := Lieu._Ecrire(Lieu.lon)
        Lieu._Montrer()
        Lieu._Appliquer()
    }

    ;  Une coordonnee saisie a la main efface le libelle : garder "Lyon" en
    ;  face d'une latitude qu'on vient de changer serait mentir.
    static _Coordonnees() {
        lat := Lieu._Nombre(Lieu.c["lat"].Value)
        lon := Lieu._Nombre(Lieu.c["lon"].Value)
        if (lat = Lieu.lat && lon = Lieu.lon)
            return
        Lieu.lat := lat
        Lieu.lon := lon
        Lieu.libelle := ""
        Lieu._Montrer()
        Lieu._Appliquer()
    }

    static _Ecrire(v) {
        return v = 0 ? "" : Format("{:.4f}", v)
    }

    ;--------------------------------------------------------------------------
    ;  Le lever et le coucher du jour pour le lieu retenu.
    ;--------------------------------------------------------------------------
    static _Montrer() {
        if (!Lieu.gui)
            return

        if (!Soleil.Valide(Lieu.lat, Lieu.lon)) {
            Lieu.c["soleil"].Text := I18n.S("lieu_vide")
            return
        }

        s := Soleil.Aujourdhui(Lieu.lat, Lieu.lon)
        if (s.lever = Soleil.JAMAIS) {
            Lieu.c["soleil"].Text := (s.polaire = "jour")
                                   ? I18n.S("jour_permanent")
                                   : I18n.S("nuit_permanente")
            return
        }

        nom := Lieu.libelle != "" ? Lieu.libelle . "  --  " : ""
        Lieu.c["soleil"].Text := nom . I18n.S("lever_court") . " " . Lieu._Hhmm(s.lever)
                              . "   " . I18n.S("coucher_court") . " " . Lieu._Hhmm(s.coucher)
    }

    static _Hhmm(m) {
        return I18n.Heure(m)
    }

    ;  Le lieu s'ecrit a chaque choix, et le planificateur le relit. Quatre
    ;  decimales : c'est le format du champ, et un flottant ecrit tel quel
    ;  donnait "48.850000000000001" dans le fichier. En differe : les champs
    ;  de coordonnees passent par ici a chaque touche frappee.
    static _Appliquer() {
        Config.EcrireDiffere("lat", Format("{:.4f}", Lieu.lat))
        Config.EcrireDiffere("lon", Format("{:.4f}", Lieu.lon))
        Config.EcrireDiffere("lieu", Lieu.libelle)
        if (Lieu.surChoix)
            try (Lieu.surChoix)(Lieu.lat, Lieu.lon, Lieu.libelle)
    }

    static Fermer() {
        if (Lieu.tic) {
            SetTimer(Lieu.tic, 0)
            Lieu.tic := 0
        }
        if (Lieu.porteur) {
            Cadre.Detruire(Lieu.porteur)
            Lieu.porteur := 0
            Lieu.gui := 0
            Lieu.c := 0
            Lieu.rangees := 0
        }
    }

    ;--------------------------------------------------------------------------
    ;  Le libelle a afficher dans les reglages : le nom de la ville s'il y en a
    ;  un, sinon les coordonnees, sinon rien.
    ;--------------------------------------------------------------------------
    static Resume() {
        nom := Config.Lire("lieu")
        if (nom != "")
            return nom

        lat := Lieu._Nombre(Config.Lire("lat"))
        lon := Lieu._Nombre(Config.Lire("lon"))
        if (!Soleil.Valide(lat, lon)) {
            ;  Rien de saisi : le fuseau horaire donne une ville approchee,
            ;  et on le dit -- c'est un defaut, pas un choix.
            f := Fuseau.Lieu()
            return f ? Format(I18n.S("lieu_devine"), f.nom) : I18n.S("aucun_lieu")
        }

        return Format("{:.2f}", lat) . "  " . Format("{:.2f}", lon)
    }
}
