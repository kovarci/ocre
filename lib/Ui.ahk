;==============================================================================
;  Ui.ahk -- controles dessines.
;
;  Les widgets Windows trahissent leur age dans une fenetre sombre : le curseur
;  et les cases a cocher se peignent en bleu systeme, le champ numerique reste
;  blanc. Ils sont donc remplaces par des Picture dont on peint le contenu en
;  GDI+, ce qui rend la palette entierement notre.
;
;  Deux precautions gouvernent tout le fichier :
;
;  - Un Gui met ses coordonnees a l'echelle du facteur d'affichage. Une image
;    dessinee a la taille demandee serait etiree et floue : on interroge donc
;    la taille REELLE du controle et l'on peint a cette resolution, en
;    multipliant chaque coordonnee par le facteur obtenu.
;
;  - Le survol n'existe pas nativement sur une Picture. Un minuteur unique
;    releve la position de la souris et redessine les zones concernees.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Blob.ahk
#Include %A_LineFile%\..\Ecrans.ahk

class Dessin {

    ;  Prepare une surface aux dimensions reelles du controle.
    static Creer(ctrl, wLog, hLog) {
        Blob.Init()

        r := Buffer(16, 0)
        DllCall("GetWindowRect", "ptr", ctrl.Hwnd, "ptr", r)
        w := NumGet(r, 8, "Int") - NumGet(r, 0, "Int")
        h := NumGet(r, 12, "Int") - NumGet(r, 4, "Int")
        if (w <= 0 || h <= 0)
            w := wLog, h := hLog

        DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h
              , "int", 0, "int", 0x26200A, "ptr", 0, "ptr*", &bmp := 0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bmp, "ptr*", &gfx := 0)
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 4)
        DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gfx, "int", 4)

        return { bmp: bmp, gfx: gfx, w: w, h: h, s: w / wLog }
    }

    static Fond(d, coul) {
        DllCall("gdiplus\GdipGraphicsClear", "ptr", d.gfx, "uint", coul)
    }

    ;  Rectangle a coins arrondis. rayon = 0 donne un rectangle franc.
    static Rect(d, x, y, w, h, rayon, coul, epaisseur := 0) {
        x *= d.s, y *= d.s, w *= d.s, h *= d.s, rayon *= d.s
        rayon := Min(rayon, Min(w, h) / 2)

        DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &p := 0)
        if (rayon > 0) {
            dia := rayon * 2
            DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", x, "float", y
                  , "float", dia, "float", dia, "float", 180, "float", 90)
            DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", x + w - dia, "float", y
                  , "float", dia, "float", dia, "float", 270, "float", 90)
            DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", x + w - dia, "float", y + h - dia
                  , "float", dia, "float", dia, "float", 0, "float", 90)
            DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", x, "float", y + h - dia
                  , "float", dia, "float", dia, "float", 90, "float", 90)
        } else {
            DllCall("gdiplus\GdipAddPathRectangle", "ptr", p, "float", x, "float", y
                  , "float", w, "float", h)
        }
        DllCall("gdiplus\GdipClosePathFigure", "ptr", p)

        if (epaisseur > 0) {
            DllCall("gdiplus\GdipCreatePen1", "uint", coul, "float", epaisseur * d.s
                  , "int", 2, "ptr*", &pen := 0)
            DllCall("gdiplus\GdipDrawPath", "ptr", d.gfx, "ptr", pen, "ptr", p)
            DllCall("gdiplus\GdipDeletePen", "ptr", pen)
        } else {
            DllCall("gdiplus\GdipCreateSolidFill", "uint", coul, "ptr*", &br := 0)
            DllCall("gdiplus\GdipFillPath", "ptr", d.gfx, "ptr", br, "ptr", p)
            DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
        }
        DllCall("gdiplus\GdipDeletePath", "ptr", p)
    }

    static Ligne(d, x1, y1, x2, y2, epaisseur, coul) {
        DllCall("gdiplus\GdipCreatePen1", "uint", coul, "float", epaisseur * d.s
              , "int", 2, "ptr*", &pen := 0)
        DllCall("gdiplus\GdipDrawLine", "ptr", d.gfx, "ptr", pen
              , "float", x1 * d.s, "float", y1 * d.s
              , "float", x2 * d.s, "float", y2 * d.s)
        DllCall("gdiplus\GdipDeletePen", "ptr", pen)
    }

    ;  Restreint le dessin a un rectangle arrondi : indispensable pour les
    ;  drapeaux, dont les diagonales deborderaient sinon du gabarit.
    static Limiter(d, x, y, w, h, rayon) {
        x *= d.s, y *= d.s, w *= d.s, h *= d.s, rayon *= d.s
        dia := rayon * 2
        DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &p := 0)
        DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", x, "float", y
              , "float", dia, "float", dia, "float", 180, "float", 90)
        DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", x + w - dia, "float", y
              , "float", dia, "float", dia, "float", 270, "float", 90)
        DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", x + w - dia, "float", y + h - dia
              , "float", dia, "float", dia, "float", 0, "float", 90)
        DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", x, "float", y + h - dia
              , "float", dia, "float", dia, "float", 90, "float", 90)
        DllCall("gdiplus\GdipClosePathFigure", "ptr", p)
        DllCall("gdiplus\GdipSetClipPath", "ptr", d.gfx, "ptr", p, "int", 0)
        DllCall("gdiplus\GdipDeletePath", "ptr", p)
    }

    static Liberer(d) {
        DllCall("gdiplus\GdipResetClip", "ptr", d.gfx)
    }

    static Cercle(d, x, y, dia, coul) {
        DllCall("gdiplus\GdipCreateSolidFill", "uint", coul, "ptr*", &br := 0)
        DllCall("gdiplus\GdipFillEllipse", "ptr", d.gfx, "ptr", br
              , "float", x * d.s, "float", y * d.s
              , "float", dia * d.s, "float", dia * d.s)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    }

    ;  align : 0 gauche, 1 centre, 2 droite. Toujours centre verticalement.
    ;  police vaut Segoe UI par defaut, celle de toute l'interface. On peut
    ;  passer un nom, ou directement une famille GDI+ (un handle) -- c'est
    ;  ainsi qu'arrive la police embarquee de Police.ahk, qui n'a pas de nom
    ;  connu du systeme. Une famille recue n'est pas a nous : on ne la
    ;  detruit pas. Une police absente retombe sur Segoe UI, puis sur Arial.
    static Texte(d, txt, x, y, w, h, px, gras, coul, align := 0, police := "Segoe UI") {
        fam := 0, aNous := true
        if (police is Integer) {
            fam := police, aNous := false
        } else {
            DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", police
                  , "ptr", 0, "ptr*", &fam := 0)
        }
        if (!fam) {
            aNous := true
            DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", "Segoe UI"
                  , "ptr", 0, "ptr*", &fam := 0)
        }
        if (!fam)
            DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", "Arial"
                  , "ptr", 0, "ptr*", &fam := 0)
        DllCall("gdiplus\GdipCreateFont", "ptr", fam, "float", px * d.s
              , "int", gras ? 1 : 0, "int", 2, "ptr*", &fnt := 0)

        ;  StringFormatFlagsNoWrap (0x1000). Tous les textes dessines ici sont
        ;  des libelles d'une ligne : sans ce drapeau, "21:00" dans un cadre un
        ;  peu juste se replie en "21:" puis "00", ce qui est pire que de
        ;  deborder. Un texte trop long est desormais rogne, jamais casse.
        DllCall("gdiplus\GdipCreateStringFormat", "int", 0x1000, "int", 0, "ptr*", &fmt := 0)
        DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", fmt, "int", align)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", fmt, "int", 1)

        rect := Buffer(16, 0)
        NumPut("Float", x * d.s, rect, 0)
        NumPut("Float", y * d.s, rect, 4)
        NumPut("Float", w * d.s, rect, 8)
        NumPut("Float", h * d.s, rect, 12)

        DllCall("gdiplus\GdipCreateSolidFill", "uint", coul, "ptr*", &br := 0)
        DllCall("gdiplus\GdipDrawString", "ptr", d.gfx, "wstr", txt, "int", -1
              , "ptr", fnt, "ptr", rect, "ptr", fmt, "ptr", br)

        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
        DllCall("gdiplus\GdipDeleteStringFormat", "ptr", fmt)
        DllCall("gdiplus\GdipDeleteFont", "ptr", fnt)
        if (aNous)
            DllCall("gdiplus\GdipDeleteFontFamily", "ptr", fam)
    }

    ;  Transfere le dessin dans le controle et libere la surface.
    ;  "HBITMAP:*" : le controle prend une COPIE du bitmap, et l'original
    ;  reste a nous -- a detruire, sans quoi chaque survol, chaque cran de
    ;  curseur laissait un bitmap derriere lui (voir tools/test-fuites.ahk).
    static Poser(d, ctrl) {
        DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr", d.bmp
              , "ptr*", &hbm := 0, "uint", 0xFF000000)
        try ctrl.Value := "HBITMAP:*" . hbm
        DllCall("DeleteObject", "ptr", hbm)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", d.gfx)
        DllCall("gdiplus\GdipDisposeImage", "ptr", d.bmp)
    }
}

;==============================================================================
;  Zones interactives
;==============================================================================
class Ui {

    static zones := []
    static minuteur := 0

    static Coul(hex, alpha := 255) {
        return (alpha << 24) | Integer("0x" . hex)
    }

    ;--------------------------------------------------------------------------
    ;  Affiche une fenetre centree sur l'ecran ou est la souris.
    ;
    ;  "Center" et MonitorGetPrimary centrent sur l'ecran principal. Sur deux
    ;  ecrans, quelqu'un qui clique l'icone depuis le second voyait la fenetre
    ;  s'ouvrir sur l'autre, derriere lui. La souris, elle, est toujours la ou
    ;  l'on vient de cliquer.
    ;
    ;  Sans DetectHiddenWindows, WinGetPos echoue sur une fenetre cachee et
    ;  tout le calcul partirait en silence dans le catch.
    ;--------------------------------------------------------------------------
    static Centrer(g, largeur, hauteur) {
        g.Show("Hide w" . largeur . " h" . hauteur)
        try {
            ancien := A_DetectHiddenWindows
            DetectHiddenWindows(true)
            WinGetPos(, , &w, &h, "ahk_id " . g.Hwnd)
            DetectHiddenWindows(ancien)
            e := Ecrans.SousSouris()
            x := e.tx + Max(0, (e.tw - w) // 2)
            y := e.ty + Max(0, (e.th - h) // 2)
            g.Show("x" . x . " y" . y . " w" . largeur . " h" . hauteur)
        } catch {
            g.Show("w" . largeur . " h" . hauteur . " Center")
        }
    }

    ;--------------------------------------------------------------------------
    ;  Enregistre une zone dessinee et son rappel de rendu.
    ;--------------------------------------------------------------------------
    static Ajouter(ctrl, peindre) {
        hw := 0
        try hw := ctrl.Gui.Hwnd
        z := { ctrl: ctrl, peindre: peindre, survol: false, gui: hw }
        Ui.zones.Push(z)
        peindre(z)
        return z
    }

    ;  Les zones sont retenues par fenetre : le panneau et les reglages peuvent
    ;  coexister sans que la fermeture de l'un prive l'autre de son survol.
    static Oublier(hwnd := 0) {
        if (!hwnd) {
            Ui.zones := []
        } else {
            restantes := []
            for z in Ui.zones {
                if (z.gui != hwnd)
                    restantes.Push(z)
            }
            Ui.zones := restantes
        }
        if (!Ui.zones.Length && Ui.minuteur) {
            SetTimer(Ui.minuteur, 0)
            Ui.minuteur := 0
        }
    }

    ;--------------------------------------------------------------------------
    ;  Pendant qu'on tient un widget, le survol ne veut plus rien dire : la
    ;  souris peut sortir du controle sans que le geste s'arrete.
    ;
    ;  Le laisser courir avait un effet tres visible. Le pouce d'un curseur
    ;  mesure 16 points survole et 14 sinon ; en glissant vite, la souris sort
    ;  du controle par le haut ou par le bas, le releve bascule toutes les
    ;  90 ms, et le pouce change de taille sans arret -- ce qui se lit comme
    ;  une vibration, pas comme un survol.
    ;--------------------------------------------------------------------------
    static gele := false

    ;  Un minuteur unique suffit : les Picture ne recoivent pas d'evenement de
    ;  survol, et poser un hook souris pour si peu serait disproportionne.
    static Suivre() {
        if (Ui.minuteur)
            return
        Ui.minuteur := () => Ui._Survol()
        SetTimer(Ui.minuteur, 90)
    }

    static _Survol() {
        if (Ui.gele)
            return
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        for z in Ui.zones {
            try {
                r := Buffer(16, 0)
                DllCall("GetWindowRect", "ptr", z.ctrl.Hwnd, "ptr", r)
                dedans := (mx >= NumGet(r, 0, "Int") && mx < NumGet(r, 8, "Int")
                        && my >= NumGet(r, 4, "Int") && my < NumGet(r, 12, "Int"))
                if (dedans != z.survol) {
                    z.survol := dedans
                    (z.peindre)(z)
                }
            }
        }
    }

    ;  Position de la souris dans le controle, en coordonnees logiques.
    static PosLocale(ctrl, wLog) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        r := Buffer(16, 0)
        DllCall("GetWindowRect", "ptr", ctrl.Hwnd, "ptr", r)
        larg := NumGet(r, 8, "Int") - NumGet(r, 0, "Int")
        if (larg <= 0)
            return 0
        return (mx - NumGet(r, 0, "Int")) * wLog / larg
    }
}
