;==============================================================================
;  Prereglages.ahk -- la fenetre des trois prereglages du panneau.
;
;  Lecture, Film, Nuit : un couple intensite / luminosite chacun, que le
;  panneau du clic droit pose d'un clic. Ils se reglaient dans ocre.ini,
;  faute de place dans la fenetre principale ; une fenetre a part, ouverte
;  par un bouton comme celle du planificateur, ne lui coute qu'une rangee.
;
;  Chaque clic sur un compteur ecrit le prereglage et pose le couple de sa
;  rangee sur l'ecran : 3 400 K ne se choisit pas a l'aveugle. La fenetre
;  rend l'etat d'avant en se fermant -- un prereglage est une valeur qu'on
;  rejoindra depuis le panneau, pas celle du moment.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Theme.ahk
#Include %A_LineFile%\..\I18n.ahk
#Include %A_LineFile%\..\Widgets.ahk
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\Cadre.ahk

class Prereglages {

    static L := 464
    static porteur := 0        ; le cadre redimensionnable (voir Cadre.ahk)
    static gui := 0
    static c := 0

    static CLES := ["pre_lecture", "pre_film", "pre_nuit"]

    ;  L'apercu : poser(i, l) met le couple a l'ecran. Ce qu'on voit en
    ;  fermant reste : comme partout dans les reglages, il n'y a ni Valider
    ;  ni retour en arriere -- la valeur qu'on vient de regler est celle
    ;  qu'on garde. Sans Init, la fenetre regle a l'aveugle, comme avant.
    static poser := 0

    static Init(poser, lecteur := 0) {
        Prereglages.poser := poser
    }

    static Ouvrir() {
        if (Prereglages.gui) {
            try WinActivate("ahk_id " . Prereglages.gui.Hwnd)
            return
        }
        Prereglages._Construire()
    }

    ;  Un compteur a bouge : sa rangee s'ecrit, et va a l'ecran.
    static _Apercu(c, cle, *) {
        Config.Ecrire(cle, c[cle . "_i"].valeur . "," . c[cle . "_l"].valeur)
        if (Prereglages.poser)
            try (Prereglages.poser)(c[cle . "_i"].valeur, c[cle . "_l"].valeur)
    }

    ;  "35,85" -> { i: 35, l: 85 }. Une valeur illisible retombe sur le
    ;  defaut de la cle plutot que sur zero, qui passerait pour un choix.
    static Lire(cle) {
        parts := StrSplit(Config.Lire(cle), ",")
        if (parts.Length < 2 || !IsNumber(Trim(parts[1])) || !IsNumber(Trim(parts[2])))
            parts := StrSplit(Config.DEFAUTS[cle], ",")
        return { i: Max(0, Min(100, Integer(Trim(parts[1]))))
               , l: Max(0, Min(100, Integer(Trim(parts[2])))) }
    }

    static _Construire() {
        c := Map()
        S := (k) => I18n.S(k)

        porteur := Cadre.Creer("Ocre", Prereglages.L)
        g := porteur.contenu

        g.SetFont("s12 w600 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y20 w300 h24", S("prereglages_titre"))

        ;  Deux colonnes de compteurs, par pas de cinq : c'est le pas des
        ;  raccourcis, et une valeur au point pres ne se voit pas.
        g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x196 y60 w110 h14", S("filtre"))
        g.Add("Text", "x340 y60 w110 h14", S("lum_court"))

        y := 80
        for cle in Prereglages.CLES {
            v := Prereglages.Lire(cle)
            g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
            g.Add("Text", "x24 y" . (y + 5) . " w150 h18", S(cle))
            apercu := ObjBindMethod(Prereglages, "_Apercu", c, cle)
            c[cle . "_i"] := Compteur.Creer(g, 196, y, 100, 26, v.i, 0, 100, apercu, 5)
            c[cle . "_l"] := Compteur.Creer(g, 340, y, 100, 26, v.l, 5, 100, apercu, 5)
            y += 36
        }

        g.SetFont("s7 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x24 y" . (y + 4) . " w416 h30", S("aide_prereglages"))

        ;  Pas de boutons : tout s'ecrit au clic, la croix ou Echap ferment.
        yb := y + 10

        Prereglages.gui := porteur.fenetre
        Prereglages.porteur := porteur
        Prereglages.c := c

        Cadre.Presenter(porteur, yb + 34, "prereglages", () => Prereglages.Fermer())
    }

    static Fermer() {
        if (Prereglages.porteur) {
            Cadre.Detruire(Prereglages.porteur)
            Prereglages.porteur := 0
            Prereglages.gui := 0
            Prereglages.c := 0
        }
    }
}
