;==============================================================================
;  Apprentissage.ahk -- la fenetre des habitudes.
;
;  Ce que le modele (voir Habitudes.ahk) a retenu doit se voir : une
;  automatisation qui agit sans qu'on sache pourquoi se fait desinstaller.
;  Deux courbes de la journee, une par voie, un baton par demi-heure : la
;  valeur attendue en hauteur, l'ocre quand le modele est sur de lui, le
;  gris quand il a des observations mais pas assez, rien quand il n'en a
;  pas. Un trait marque l'heure qu'il est. En dessous, le compte des
;  observations et des creneaux surs ; un clic sur un baton en liste les
;  observations -- date, valeur, application, correction ou approbation --,
;  et le bouton pour tout oublier.
;
;  Comme les autres fenetres, elle n'a pas de bouton : la bascule s'ecrit
;  quand on la touche, et la croix ou Echap ferment. Elle vit dans un cadre
;  (voir Cadre.ahk).
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Theme.ahk
#Include %A_LineFile%\..\I18n.ahk
#Include %A_LineFile%\..\Widgets.ahk
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\Cadre.ahk
#Include %A_LineFile%\..\Habitudes.ahk

class Apprentissage {

    static L := 464
    static porteur := 0        ; le cadre redimensionnable (voir Cadre.ahk)
    static gui := 0
    static c := 0
    static surValider := 0

    static Ouvrir(surValider := 0) {
        if (Apprentissage.gui) {
            try WinActivate("ahk_id " . Apprentissage.gui.Hwnd)
            return
        }
        Apprentissage.surValider := surValider
        Apprentissage._Construire()
    }

    static _Construire() {
        c := Map()
        S := (k) => I18n.S(k)

        porteur := Cadre.Creer("Ocre", Apprentissage.L)
        g := porteur.contenu

        g.SetFont("s12 w600 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y20 w300 h24", S("habitudes_titre"))
        g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x24 y46 w416 h44", S("habitudes_aide"))

        c["actif"] := Bascule.Creer(g, 24, 96, Config.Lire("habitudes") = "1", (a) => Apprentissage._Basculer(a))
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x72 y98 w360 h18", S("habitudes"))

        ;  Les deux courbes.
        y := 134
        for voie in Habitudes.VOIES {
            g.SetFont("s7 w600 c" . Theme.TEXTE_BAS, "Segoe UI")
            g.Add("Text", "x24 y" . y . " w200 h14", StrUpper(S(voie = "intensite" ? "filtre" : "lum_court")))
            c["courbe_" . voie] := Apprentissage._Courbe(g, 24, y + 18, 416, 72, voie, c)
            g.SetFont("s7 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
            c["compte_" . voie] := g.Add("Text", "x24 y" . (y + 94) . " w416 h14", Apprentissage._Compte(voie))
            c["detail_" . voie] := g.Add("Text", "x24 y" . (y + 110) . " w416 h28", S("habitudes_vide"))
            y += 146
        }

        yb := y + 8
        c["oublier"] := Bouton.Creer(g, 24, yb + 4, 120, 26, S("habitudes_oublier"), false
                                   , () => Apprentissage._Oublier(c))

        Apprentissage.gui := porteur.fenetre
        Apprentissage.porteur := porteur
        Apprentissage.c := c

        Cadre.Presenter(porteur, yb + 34, "habitudes", () => Apprentissage.Fermer())
    }

    ;  Un baton par demi-heure, sur une piste avec les heures en dessous.
    static _Courbe(g, x, y, w, h, voie, c) {
        ctrl := g.Add("Picture", "x" . x . " y" . y . " w" . w . " h" . h)
        o := { ctrl: ctrl, w: w, h: h, voie: voie }
        o.zone := Ui.Ajouter(ctrl, (z) => Apprentissage._Peindre(o))
        ctrl.OnEvent("Click", (*) => Apprentissage._Cliquer(o, c))
        return o
    }

    ;  Un clic sur un baton : les observations du creneau, en toutes lettres.
    static _Cliquer(o, c) {
        px := Ui.PosLocale(o.ctrl, o.w)
        k := Max(0, Min(Habitudes.CRENEAUX - 1, Floor(px * Habitudes.CRENEAUX / o.w)))
        c["detail_" . o.voie].Text := Apprentissage.Detail(o.voie, k)
    }

    ;  "21:00 : 80 (12/09, vlc), 80 (11/09, correction), 78 (10/09)"
    static Detail(voie, k) {
        liste := Habitudes.Detail(voie, k)
        if (!liste.Length)
            return Format("{:02}:{:02} : -", k // 2, Mod(k, 2) * 30)
        texte := ""
        for i, obs in liste {
            if (i > 6) {
                texte .= ", ..."
                break
            }
            notes := []
            if (obs.app != "")
                notes.Push(RegExReplace(obs.app, "\.exe\+?$") . (InStr(obs.app, "+") ? " " . I18n.S("plein_ecran") : ""))
            if (obs.brute != "")
                notes.Push(Format("{:+d}", obs.v - obs.brute))
            if (obs.poids >= 2)
                notes.Push(I18n.S("habitudes_correction"))
            if (obs.implicite)
                notes.Push(I18n.S("habitudes_implicite"))
            jour := SubStr(obs.date, 7, 2) . "/" . SubStr(obs.date, 5, 2)
            texte .= (texte != "" ? ", " : "") . obs.v . " (" . jour
                   . (notes.Length ? ", " . Apprentissage._Joindre(notes) : "") . ")"
        }
        return Format("{:02}:{:02} : ", k // 2, Mod(k, 2) * 30) . texte
    }

    static _Joindre(liste) {
        t := ""
        for x in liste
            t .= (t != "" ? ", " : "") . x
        return t
    }

    static _Peindre(o) {
        d := Dessin.Creer(o.ctrl, o.w, o.h)
        Dessin.Fond(d, Ui.Coul(Theme.FOND))
        haut := o.h - 16                                 ; la place des heures
        Dessin.Rect(d, 0, 0, o.w, haut, 6, Ui.Coul(Theme.SURFACE))

        courbe := Habitudes.Courbe(o.voie)
        n := Habitudes.CRENEAUX
        pas := o.w / n
        m := Habitudes.Maintenant()
        actuel := Habitudes.Creneau(m.minutes)
        for i, p in courbe {
            if (!p.poids)
                continue
            hb := Max(2, (haut - 8) * p.valeur / 100.0)
            coul := p.confiant ? Theme.ACCENT : Theme.TEXTE_BAS
            Dessin.Rect(d, (i - 1) * pas + 1, haut - 4 - hb, pas - 2, hb, 2, Ui.Coul(coul, p.confiant ? 255 : 140))
        }
        ;  le trait de l'heure
        Dessin.Ligne(d, actuel * pas + pas / 2, 2, actuel * pas + pas / 2, haut - 2, 1, Ui.Coul(Theme.TEXTE, 120))
        ;  les heures
        for hh in [0, 6, 12, 18] {
            xx := hh * 2 * pas
            Dessin.Texte(d, hh . "h", xx, haut + 1, 40, 14, 10, false, Ui.Coul(Theme.TEXTE_BAS), 0)
        }
        Dessin.Texte(d, "24h", o.w - 30, haut + 1, 30, 14, 10, false, Ui.Coul(Theme.TEXTE_BAS), 2)
        Dessin.Poser(d, o.ctrl)
    }

    static _Compte(voie) {
        surs := 0
        for p in Habitudes.Courbe(voie)
            surs += p.confiant ? 1 : 0
        return Format(I18n.S("habitudes_compte"), Habitudes.Compte(voie), surs)
    }

    static _Repeindre(c) {
        for voie in Habitudes.VOIES {
            o := c["courbe_" . voie]
            Apprentissage._Peindre(o)
            c["compte_" . voie].Text := Apprentissage._Compte(voie)
            c["detail_" . voie].Text := I18n.S("habitudes_vide")
        }
    }

    static _Oublier(c) {
        if (MsgBox(I18n.S("habitudes_oublier_confirmer"), "Ocre", 0x34) != "Yes")
            return
        Habitudes.Oublier()
        Apprentissage._Repeindre(c)
    }

    ;  La bascule s'ecrit a l'instant, et le programme relit.
    static _Basculer(actif) {
        Config.Ecrire("habitudes", actif ? 1 : 0)
        if (Apprentissage.surValider)
            (Apprentissage.surValider)()
    }

    static Fermer() {
        if (Apprentissage.porteur) {
            Cadre.Detruire(Apprentissage.porteur)
            Apprentissage.porteur := 0
            Apprentissage.gui := 0
            Apprentissage.c := 0
        }
    }
}
