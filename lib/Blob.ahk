;==============================================================================
;  Blob.ahk -- la tache Ocre, dessinee a chaud.
;
;  Genere une icone dont la couleur suit l'intensite du filtre : gris bleute
;  quand le filtre est coupe, ambre a mi-course, ocre brulee a fond. La forme
;  est volontairement irreguliere, definie par des rayons polaires lisses par
;  une courbe fermee -- la meme table que tools/make-icon.ps1, pour que
;  l'icone du fichier et celle de la zone de notification soient soeurs.
;==============================================================================

#Requires AutoHotkey v2.0

class Blob {

    ;  Rayons en fraction du rayon max. Identiques a make-icon.ps1.
    static RAYONS := [1.00, 0.74, 0.93, 0.66, 0.90, 0.80, 0.99, 0.70, 0.86]

    static token := 0

    static Init() {
        if (Blob.token)
            return
        if (!DllCall("GetModuleHandle", "str", "gdiplus", "ptr"))
            DllCall("LoadLibrary", "str", "gdiplus", "ptr")
        entree := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", 1, entree, 0)                  ; GdiplusVersion
        DllCall("gdiplus\GdiplusStartup", "ptr*", &tok := 0, "ptr", entree, "ptr", 0)
        Blob.token := tok
    }

    ;--------------------------------------------------------------------------
    ;  Teinte pour une intensite 0-100, en RVB.
    ;--------------------------------------------------------------------------
    static Teinte(p) {
        p := Max(0, Min(100, p)) / 100.0
        froid := [136, 146, 160]      ; gris bleute
        moyen := [227, 163,  60]      ; ambre
        chaud := [200,  90,  30]      ; ocre brulee

        if (p < 0.5) {
            a := froid, b := moyen, t := p / 0.5
        } else {
            a := moyen, b := chaud, t := (p - 0.5) / 0.5
        }
        return { r: Round(a[1] + (b[1] - a[1]) * t)
               , g: Round(a[2] + (b[2] - a[2]) * t)
               , b: Round(a[3] + (b[3] - a[3]) * t) }
    }

    static Argb(c, alpha := 255) {
        return (alpha << 24) | (c.r << 16) | (c.g << 8) | c.b
    }

    ;  Couleur d'accent de la barre de la pastille, en "RRGGBB" pour les Gui.
    static Hex(p) {
        c := Blob.Teinte(p)
        return Format("{:02X}{:02X}{:02X}", c.r, c.g, c.b)
    }

    ;--------------------------------------------------------------------------
    ;  Fabrique une icone. Le handle est a l'appelant, qui doit le detruire :
    ;  passe sous la forme "HICON:*", AutoHotkey en prend une COPIE et n'a
    ;  jamais la charge de l'original. On l'a cru longtemps l'inverse ;
    ;  chaque redessin laissait alors trois objets GDI et un objet USER, et
    ;  c'est le test des fuites (tools/test-fuites.ahk) qui l'a vu. Poser et
    ;  Tray ci-dessous font les choses dans l'ordre.
    ;--------------------------------------------------------------------------
    ;  echelle change la taille de la tache dans son cadre : 1 est la taille
    ;  normale, moins la reduit, plus la grossit -- jusqu'a 1,12, ou elle
    ;  touche les bords. C'est la respiration du rappel des 20-20-20 (voir
    ;  Rappel.ahk), l'icone de la zone de notification qui grossit et
    ;  retrecit doucement.
    ;  point : un petit disque clair en bas a droite, pour dire un etat qui
    ;  ne se voit pas a la couleur -- l'horaire suspendu, dans la zone de
    ;  notification. Cercle sombre puis disque clair, pour tenir sur une
    ;  barre des taches claire comme sur une sombre.
    static Icone(p, taille := 32, echelle := 1.0, point := false) {
        bmp := Blob._Bitmap(p, taille, echelle, point)
        DllCall("gdiplus\GdipCreateHICONFromBitmap", "ptr", bmp, "ptr*", &hIcon := 0)
        DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
        return hIcon
    }

    ;  Pose l'icone sur un Picture, puis detruit la notre.
    static Poser(ctrl, p, taille, echelle := 1.0, point := false) {
        h := Blob.Icone(p, taille, echelle, point)
        try ctrl.Value := "HICON:*" . h
        DllCall("DestroyIcon", "ptr", h)
    }

    ;  La meme chose pour l'icone de la zone de notification.
    static Tray(p, echelle := 1.0, point := false) {
        h := Blob.Icone(p, 32, echelle, point)
        try TraySetIcon("HICON:*" . h)
        DllCall("DestroyIcon", "ptr", h)
    }

    ;--------------------------------------------------------------------------
    ;  La tache dans un bitmap GDI+ 32 bits, a l'appelant de le liberer.
    ;--------------------------------------------------------------------------
    static _Bitmap(p, taille, echelle := 1.0, point := false) {
        Blob.Init()

        ; bitmap 32 bits avec alpha
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", taille, "int", taille
              , "int", 0, "int", 0x26200A, "ptr", 0, "ptr*", &bmp := 0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bmp, "ptr*", &gfx := 0)
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 4)   ; anti-aliasing
        DllCall("gdiplus\GdipGraphicsClear", "ptr", gfx, "uint", 0x00000000)

        ; contour de la tache
        n := Blob.RAYONS.Length
        pts := Buffer(n * 8, 0)
        cx := taille / 2.0
        cy := taille / 2.0
        rMax := taille * 0.44 * Max(0.1, Min(1.12, echelle))
        Loop n {
            i := A_Index
            ang := 2.0 * 3.14159265358979 * (i - 1) / n
            r := rMax * Blob.RAYONS[i]
            NumPut("Float", cx + r * Cos(ang), pts, (i - 1) * 8)
            NumPut("Float", cy + r * Sin(ang), pts, (i - 1) * 8 + 4)
        }

        DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &path := 0)
        DllCall("gdiplus\GdipAddPathClosedCurve2", "ptr", path, "ptr", pts
              , "int", n, "float", 0.9)

        ; degrade diagonal, plus clair en haut a gauche
        c := Blob.Teinte(p)
        clair  := { r: Min(255, c.r + 38), g: Min(255, c.g + 32), b: Min(255, c.b + 24) }
        sombre := { r: Max(0, c.r - 42),   g: Max(0, c.g - 46),   b: Max(0, c.b - 40) }

        p1 := Buffer(8, 0), p2 := Buffer(8, 0)
        NumPut("Float", 0, p1, 0), NumPut("Float", 0, p1, 4)
        NumPut("Float", taille, p2, 0), NumPut("Float", taille, p2, 4)

        DllCall("gdiplus\GdipCreateLineBrush", "ptr", p1, "ptr", p2
              , "uint", Blob.Argb(clair), "uint", Blob.Argb(sombre)
              , "int", 0, "ptr*", &brush := 0)

        DllCall("gdiplus\GdipFillPath", "ptr", gfx, "ptr", brush, "ptr", path)

        DllCall("gdiplus\GdipDeleteBrush", "ptr", brush)
        DllCall("gdiplus\GdipDeletePath", "ptr", path)

        if (point)
            Blob._Point(gfx, taille)

        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gfx)
        return bmp
    }

    ;  Le disque du coin : un tiers de l'icone, borde d'un pixel sombre.
    static _Point(gfx, taille) {
        d := taille * 0.30
        x := taille - d - taille * 0.04
        y := x
        DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFF202020, "ptr*", &bord := 0)
        DllCall("gdiplus\GdipFillEllipse", "ptr", gfx, "ptr", bord
              , "float", x - 1, "float", y - 1, "float", d + 2, "float", d + 2)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", bord)
        DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFFF2F2F2, "ptr*", &plein := 0)
        DllCall("gdiplus\GdipFillEllipse", "ptr", gfx, "ptr", plein
              , "float", x, "float", y, "float", d, "float", d)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", plein)
    }
}
