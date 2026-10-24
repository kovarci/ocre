;==============================================================================
;  Raccourcis.ahk -- la fenetre des raccourcis.
;
;  Six champs pour le filtre, un pour le gris seul, deux molettes, l'aide,
;  la liste des refus et un bouton de test : deux cents points de hauteur
;  que la fenetre principale n'avait plus. Elle en sort comme le
;  planificateur avant elle, et pour la meme raison mesurable -- avec le
;  bandeau d'alerte et deux ecrans, la principale debordait sous la barre
;  des taches a 150 %.
;
;  Le bouton "Tester" repond a la premiere question du README : les touches
;  arrivent-elles seulement a Windows ? Sur beaucoup de portables le
;  firmware avale F5 a F7 en mode multimedia, et aucun programme ne peut le
;  savoir autrement qu'en ecoutant. Cinq secondes de crochet clavier, et la
;  fenetre dit quels raccourcis ont ete recus et lesquels ne sont jamais
;  arrives.
;
;  Comme les autres fenetres secondaires, elle enregistre en validant.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Theme.ahk
#Include %A_LineFile%\..\I18n.ahk
#Include %A_LineFile%\..\Widgets.ahk
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\Cadre.ahk

class Raccourcis {

    static L := 464
    static porteur := 0        ; le cadre redimensionnable (voir Cadre.ahk)
    static gui := 0
    static c := 0
    static combos := 0
    static enCapture := false
    static surValider := 0

    ;  Les six raccourcis du filtre, et celui du gris seul, qui a le droit de
    ;  n'en pas avoir : son defaut est vide, et Reinitialiser l'y ramene.
    static CLES := ["hk_moins", "hk_plus", "hk_off", "hk2_moins", "hk2_plus", "hk2_off"
                  , "hk_gris"]

    ;  Les modificateurs que la molette peut prendre. Un jeu ferme plutot
    ;  qu'une capture : une combinaison de modificateurs seuls ne se capture
    ;  pas proprement, et huit choix couvrent ce qu'un clavier offre.
    static MOLETTES := ["^!", "^!+", "^+", "!+", "#", "#^", "#!", "#+"]

    ;  Les raccourcis que Windows a refuses au dernier Lier, poses par le
    ;  programme principal.
    static refuses := []

    static Ouvrir(surValider := 0) {
        if (Raccourcis.gui) {
            try WinActivate("ahk_id " . Raccourcis.gui.Hwnd)
            return
        }
        Raccourcis.surValider := surValider
        Raccourcis.combos := Map()
        for cle in Raccourcis.CLES
            Raccourcis.combos[cle] := Config.Lire(cle)
        Raccourcis.combos["mol_filtre"] := Raccourcis._Molette(Config.Lire("mol_filtre"), "^!")
        Raccourcis.combos["mol_lum"] := Raccourcis._Molette(Config.Lire("mol_lum"), "^!+")
        Raccourcis._Construire()
    }

    ;  Une valeur de molette inconnue retombe sur le defaut.
    static _Molette(v, defaut) {
        for m in Raccourcis.MOLETTES {
            if (m = v)
                return v
        }
        return defaut
    }

    static _Construire() {
        c := Map()
        S := (k) => I18n.S(k)

        porteur := Cadre.Creer("Ocre", Raccourcis.L)
        g := porteur.contenu

        g.SetFont("s12 w600 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y20 w300 h24", S("raccourcis_titre"))

        ;--- les touches ------------------------------------------------------
        g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x176 y58 w120 h14", S("principal"))
        g.Add("Text", "x306 y58 w134 h14", S("secours"))

        lignes := [[S("moins_fort"), "hk_moins", "hk2_moins"]
                 , [S("plus_fort"),  "hk_plus",  "hk2_plus"]
                 , [S("couper"),     "hk_off",   "hk2_off"]]

        y := 76
        for ligne in lignes {
            g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
            g.Add("Text", "x24 y" . (y + 5) . " w146 h18", ligne[1])
            c[ligne[2]] := Raccourcis._Champ(g, c, 176, y, 120, ligne[2])
            c[ligne[3]] := Raccourcis._Champ(g, c, 306, y, 134, ligne[3])
            y += 30
        }

        ;  Le gris seul n'a qu'un jeu, et peut n'en avoir aucun : le champ
        ;  prend les deux colonnes, et Echap le vide.
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y" . (y + 5) . " w146 h18", S("gris_seul"))
        c["hk_gris"] := Raccourcis._Champ(g, c, 176, y, 264, "hk_gris")
        y += 30

        ;--- les molettes -----------------------------------------------------
        ;  Deux boutons qui font defiler les modificateurs : un clic, le
        ;  suivant. Les deux ne peuvent pas etre egaux -- la luminosite
        ;  saute le choix que prend deja le filtre.
        y += 8
        g.Add("Text", "x24 y" . (y + 5) . " w146 h18", S("molette_filtre"))
        c["mol_filtre"] := Bouton.Creer(g, 176, y, 264, 26
                                      , Raccourcis._Joli(Raccourcis.combos["mol_filtre"] . "WheelUp")
                                      , false, () => Raccourcis._Defiler(c, "mol_filtre"))
        y += 30
        g.Add("Text", "x24 y" . (y + 5) . " w146 h18", S("molette_lum"))
        c["mol_lum"] := Bouton.Creer(g, 176, y, 264, 26
                                   , Raccourcis._Joli(Raccourcis.combos["mol_lum"] . "WheelUp")
                                   , false, () => Raccourcis._Defiler(c, "mol_lum"))
        y += 36

        ;--- aide, refus, test ------------------------------------------------
        g.SetFont("s7 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x24 y" . y . " w416 h30", S("aide_touches"))
        y += 32

        ;  Un raccourci que Windows a refuse ne doit pas passer pour en place.
        liste := ""
        for combo in Raccourcis.refuses
            liste .= (liste != "" ? ", " : "") . Raccourcis._Joli(combo)
        g.SetFont("s7 w600 c" . Theme.ACCENT, "Segoe UI")
        c["refuses"] := g.Add("Text", "x24 y" . y . " w416 h14"
                            , liste != "" ? S("refuses") . liste : "")
        y += 18

        ;  Le test : cinq secondes d'ecoute, et le verdict sur la ligne.
        c["tester"] := Bouton.Creer(g, 24, y, 96, 26, S("tester"), false
                                  , () => Raccourcis._Tester(c))
        g.SetFont("s8 w400 c" . Theme.TEXTE, "Segoe UI")
        c["verdict"] := g.Add("Text", "x130 y" . (y + 5) . " w310 h18", S("aide_tester"))
        y += 44

        ;--- boutons ----------------------------------------------------------
        yb := y
        c["reset"] := Bouton.Creer(g, 24, yb + 4, 120, 26, S("reinitialiser"), false
                                 , () => Raccourcis._Reinitialiser(c))

        Raccourcis.gui := porteur.fenetre
        Raccourcis.porteur := porteur
        Raccourcis.c := c

        Cadre.Presenter(porteur, yb + 34, "raccourcis", () => Raccourcis.Fermer())
    }

    static _Champ(g, c, x, y, w, cle) {
        return Champ.Creer(g, x, y, w, 26, Raccourcis._Joli(Raccourcis.combos[cle])
                         , () => Raccourcis._Capturer(c, cle))
    }

    ;--------------------------------------------------------------------------
    ;  "^!Enter" devient "Ctrl + Alt + Entree"
    ;--------------------------------------------------------------------------
    static _Joli(combo) {
        if (combo = "")
            return I18n.S("aucun")

        ;  Seule la touche Maj a un nom qui change de langue : Ctrl, Alt et
        ;  Win s'ecrivent pareil des deux cotes.
        prefixes := Map("^", "Ctrl + ", "!", "Alt + ", "#", "Win + "
                      , "+", I18n.langue = "en" ? "Shift + " : "Maj + ")
        libelle := ""
        i := 1
        while (i <= StrLen(combo) && prefixes.Has(SubStr(combo, i, 1))) {
            libelle .= prefixes[SubStr(combo, i, 1)]
            i += 1
        }

        touche := SubStr(combo, i)
        noms := Map("Enter", "Entrée", "Space", "Espace", "BS", "Retour"
                  , "Backspace", "Retour", "Escape", "Échap", "Delete", "Suppr"
                  , "Insert", "Inser", "Home", "Origine", "End", "Fin"
                  , "PgUp", "Page haut", "PgDn", "Page bas"
                  , "Up", "Haut", "Down", "Bas", "Left", "Gauche", "Right", "Droite"
                  , "WheelUp", "molette")
        if (I18n.langue = "en")
            noms := Map("BS", "Backspace", "WheelUp", "wheel")
        if (noms.Has(touche))
            return libelle . noms[touche]
        ;  Une touche captee sous son code ("vkBB", "sc029") : Windows lui
        ;  connait peut-etre un nom, ou au moins le caractere qu'elle ecrit.
        if (RegExMatch(touche, "i)^(vk[0-9a-f]+|sc[0-9a-f]+)$")) {
            try {
                n := GetKeyName(touche)
                if (n != "" && n != touche)
                    return libelle . StrUpper(n)
            }
        }
        return libelle . StrUpper(touche)
    }

    ;--------------------------------------------------------------------------
    ;  Capture de la prochaine combinaison.
    ;
    ;  InputHook prefixe les modificateurs de "<" ou ">" pour distinguer la
    ;  touche gauche de la droite : "<^<#" pour Ctrl et Win gauches. Un tel
    ;  prefixe n'a pas de sens dans une definition de raccourci et donnait des
    ;  champs illisibles -- on ne garde donc que les symboles.
    ;
    ;  Les raccourcis du programme sont suspendus le temps de la capture,
    ;  comme pour le test. Un raccourci actif CONSOMME sa touche avant que
    ;  l'InputHook ne la voie : sans cela, Echap fermait la fenetre (c'est le
    ;  raccourci "fermer") pendant que la capture attendait ses huit secondes
    ;  sur un champ detruit, et Ctrl+F6 montait le filtre au lieu d'etre
    ;  capture -- impossible, donc, d'echanger deux raccourcis d'Ocre.
    ;
    ;  Une touche seule, sans modificateur, est refusee si c'est une touche
    ;  de frappe : "Espace" comme raccourci de coupure, c'est la barre
    ;  d'espace qui ne fonctionne plus nulle part. Les touches de fonction et
    ;  les touches speciales, qui n'ecrivent rien, restent permises.
    ;--------------------------------------------------------------------------
    static _Capturer(c, cle) {
        if (Raccourcis.enCapture)
            return
        Raccourcis.enCapture := true

        ;  La variable ne peut pas s'appeler "champ" : AutoHotkey compare les
        ;  noms sans tenir compte de la casse, et "champ" designerait alors la
        ;  classe Champ.
        cible := c[cle]
        ancien := cible.texte
        texte := ancien
        avis := ""

        Suspend(true)
        try {
            Champ.Definir(cible, I18n.S("appuyez"), true)

            ih := InputHook("L0 T8")
            ih.KeyOpt("{All}", "E")
            ih.KeyOpt("{LControl}{RControl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-E")
            ih.Start()
            ih.Wait()

            touche := ih.EndKey
            mods := RegExReplace(ih.EndMods, "[<>]")

            ;  Echap efface le raccourci du gris -- qui a le droit de n'en pas
            ;  avoir -- mais rend son ancienne valeur a un raccourci de filtre,
            ;  qui, lui, doit toujours en porter un.
            if (touche = "Escape" && cle = "hk_gris") {
                Raccourcis.combos[cle] := ""
                texte := Raccourcis._Joli("")
            } else if (touche = "" || touche = "Escape") {
                texte := ancien
            } else if (mods = "" && Raccourcis._Frappe(touche)) {
                texte := ancien
                avis := I18n.S("touche_seule")
            } else if (Raccourcis._Pris(mods . touche, cle) != "") {
                ;  Deja pris par un autre champ : Hotkey() remplacerait le
                ;  premier rappel par le second, et le premier raccourci
                ;  mourrait sans un mot.
                texte := ancien
                avis := Format(I18n.S("touche_prise"), Raccourcis._Joli(mods . touche))
            } else {
                combo := mods . touche
                Raccourcis.combos[cle] := combo
                texte := Raccourcis._Joli(combo)
            }
        } finally {
            Suspend(false)
            Raccourcis.enCapture := false
        }

        ;  La fenetre a pu etre fermee pendant l'attente : les controles
        ;  n'existent plus, et l'on n'a plus rien a redessiner.
        try Champ.Definir(cible, texte)
        if (avis != "")
            try c["verdict"].Text := avis
        Raccourcis._Appliquer()
    }

    ;  Le champ qui porte deja cette combinaison, ou "" : deux champs ne
    ;  peuvent pas se partager un raccourci.
    static _Pris(combo, sauf := "") {
        n := Raccourcis._Normal(combo)
        for cle in Raccourcis.CLES {
            if (cle != sauf && Raccourcis.combos.Has(cle) && Raccourcis.combos[cle] != ""
             && Raccourcis._Normal(Raccourcis.combos[cle]) = n)
                return cle
        }
        return ""
    }

    ;  Une touche qui ecrit quelque chose, ou qui sert a tout le monde :
    ;  interdite seule. Un caractere, ou l'une de celles-ci.
    static _Frappe(touche) {
        if (StrLen(touche) = 1)
            return true
        for t in ["Space", "Enter", "Tab", "Backspace", "BS", "Delete", "Del"
                , "Insert", "Ins", "Home", "End", "PgUp", "PgDn"
                , "Up", "Down", "Left", "Right", "CapsLock", "NumLock"
                , "Numpad0", "Numpad1", "Numpad2", "Numpad3", "Numpad4"
                , "Numpad5", "Numpad6", "Numpad7", "Numpad8", "Numpad9"
                , "NumpadDot", "NumpadEnter", "NumpadAdd", "NumpadSub"
                , "NumpadMult", "NumpadDiv", "AppsKey", "PrintScreen"] {
            if (t = touche)
                return true
        }
        return false
    }

    ;  Le modificateur suivant de la liste, en sautant celui de l'autre
    ;  molette.
    static _Defiler(c, cle) {
        autre := (cle = "mol_filtre") ? "mol_lum" : "mol_filtre"
        courant := Raccourcis.combos[cle]
        i := 1
        for k, m in Raccourcis.MOLETTES {
            if (m = courant)
                i := k
        }
        Loop Raccourcis.MOLETTES.Length {
            i := Mod(i, Raccourcis.MOLETTES.Length) + 1
            if (Raccourcis.MOLETTES[i] != Raccourcis.combos[autre])
                break
        }
        Raccourcis.combos[cle] := Raccourcis.MOLETTES[i]
        c[cle].texte := Raccourcis._Joli(Raccourcis.MOLETTES[i] . "WheelUp")
        Bouton.Redessiner(c[cle])
        Raccourcis._Appliquer()
    }

    static _Reinitialiser(c) {
        for cle in Raccourcis.CLES {
            Raccourcis.combos[cle] := Config.DEFAUTS[cle]
            Champ.Definir(c[cle], Raccourcis._Joli(Config.DEFAUTS[cle]))
        }
        for cle in ["mol_filtre", "mol_lum"] {
            Raccourcis.combos[cle] := Config.DEFAUTS[cle]
            c[cle].texte := Raccourcis._Joli(Config.DEFAUTS[cle] . "WheelUp")
            Bouton.Redessiner(c[cle])
        }
        Raccourcis._Appliquer()
    }

    ;--------------------------------------------------------------------------
    ;  Le test. Les raccourcis du programme sont suspendus le temps de
    ;  l'ecoute -- sans quoi chaque appui changerait aussi le filtre -- et
    ;  un crochet clavier note chaque touche avec les modificateurs tenus a
    ;  ce moment. A la fin, chaque raccourci configure est "recu" ou "rien".
    ;
    ;  On compare des formes normalisees : les symboles de modificateurs
    ;  tries, la touche en minuscules, et quelques alias -- "BS" et
    ;  "Backspace" sont la meme touche sous deux noms.
    ;--------------------------------------------------------------------------
    static _Tester(c) {
        if (Raccourcis.enCapture)
            return
        Raccourcis.enCapture := true
        c["verdict"].Text := I18n.S("test_en_cours")

        vus := Map()
        tenus := Map()
        ih := InputHook("L0 T5")
        ih.KeyOpt("{All}", "N")
        ih.OnKeyDown := (ih, vk, sc) => Raccourcis._Noter(vus, tenus, vk, sc, true)
        ih.OnKeyUp := (ih, vk, sc) => Raccourcis._Noter(vus, tenus, vk, sc, false)

        Suspend(true)
        try {
            ih.Start()
            ih.Wait()
        } finally {
            Suspend(false)
            Raccourcis.enCapture := false
        }

        recus := "", rien := ""
        for cle in Raccourcis.CLES {
            combo := Raccourcis.combos[cle]
            if (combo = "")
                continue
            joli := Raccourcis._Joli(combo)
            if (vus.Has(Raccourcis._Normal(combo)))
                recus .= (recus != "" ? ", " : "") . joli
            else
                rien .= (rien != "" ? ", " : "") . joli
        }
        ;  La fenetre a pu etre fermee pendant les cinq secondes.
        try c["verdict"].Text := I18n.S("test_recu") . (recus != "" ? recus : I18n.S("aucun"))
                               . "   |   " . I18n.S("test_rien") . (rien != "" ? rien : I18n.S("aucun"))
    }

    ;  Les modificateurs sont suivis par le crochet lui-meme, enfoncement et
    ;  relachement, plutot que lus par GetKeyState : le rappel du crochet
    ;  arrive apres coup, et pour une sequence rapide l'etat des touches a
    ;  deja change.
    static _Noter(vus, tenus, vk, sc, enfonce) {
        nom := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
        if (nom = "")
            return
        if (RegExMatch(nom, "i)^[LR]?(Control|Ctrl|Alt|Shift|Win)$", &m)) {
            symbole := Map("control", "^", "ctrl", "^", "alt", "!", "shift", "+", "win", "#")[StrLower(m[1])]
            if (enfonce)
                tenus[symbole] := true
            else if (tenus.Has(symbole))
                tenus.Delete(symbole)
            return
        }
        if (!enfonce)
            return
        mods := ""
        for symbole in tenus
            mods .= symbole
        vus[Raccourcis._Normal(mods . nom)] := true
    }

    static _Normal(combo) {
        mods := "", i := 1
        while (i <= StrLen(combo) && InStr("^!+#", SubStr(combo, i, 1))) {
            mods .= SubStr(combo, i, 1)
            i += 1
        }
        touche := StrLower(SubStr(combo, i))
        alias := Map("bs", "backspace", "esc", "escape", "del", "delete", "ins", "insert"
                   , "pgup", "pgup", "pgdn", "pgdn", "return", "enter")
        if (alias.Has(touche))
            touche := alias[touche]
        ;  Les modificateurs dans un ordre fixe, quel que soit celui d'arrivee.
        return (InStr(mods, "^") ? "^" : "") . (InStr(mods, "!") ? "!" : "")
             . (InStr(mods, "+") ? "+" : "") . (InStr(mods, "#") ? "#" : "") . touche
    }

    ;  Un raccourci capture, une molette changee, une remise a zero : tout
    ;  s'ecrit et se relie a l'instant, avec un temps de regroupement.
    static tic := 0

    static _Appliquer() {
        for cle in Raccourcis.CLES
            Config.Ecrire(cle, Raccourcis.combos[cle])
        Config.Ecrire("mol_filtre", Raccourcis.combos["mol_filtre"])
        Config.Ecrire("mol_lum", Raccourcis.combos["mol_lum"])
        if (!Raccourcis.tic)
            Raccourcis.tic := () => Raccourcis._Relier()
        SetTimer(Raccourcis.tic, -300)
    }

    static _Relier() {
        if (Raccourcis.surValider)
            (Raccourcis.surValider)()
    }

    static Fermer() {
        if (Raccourcis.porteur) {
            Cadre.Detruire(Raccourcis.porteur)
            Raccourcis.porteur := 0
            Raccourcis.gui := 0
            Raccourcis.c := 0
        }
    }
}
