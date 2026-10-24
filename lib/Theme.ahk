;==============================================================================
;  Theme.ahk -- mise au sombre des elements dessines par Windows.
;
;  Les menus contextuels, la barre de titre et les champs de saisie ne suivent
;  pas la couleur de fond d'une fenetre : c'est Windows qui les peint. Trois
;  leviers permettent de les basculer en sombre.
;==============================================================================

#Requires AutoHotkey v2.0

class Theme {

    ;--------------------------------------------------------------------------
    ;  Palette. Deux plans seulement -- le fond de la fenetre et la surface des
    ;  encarts -- pour que la couleur d'accent, seule teinte de l'interface,
    ;  garde toute sa valeur de signal.
    ;--------------------------------------------------------------------------
    static FOND        := "17171A"    ; fond des fenetres
    static SURFACE     := "202024"    ; champs, encarts, boutons secondaires
    static SURFACE_VIF := "27272C"    ; le meme, survole
    static TRAIT       := "2E2E34"    ; filets et pistes inactives
    static TRAIT_VIF   := "3A3A42"
    static TEXTE       := "EDEDF0"
    static TEXTE_BAS   := "8B8B94"    ; libelles secondaires, intitules
    static CHAMP       := "202024"

    ;  L'ocre de l'application. SUR_ACCENT est la couleur du texte pose dessus.
    static ACCENT      := "C8783C"
    static ACCENT_VIF  := "D98844"
    static SUR_ACCENT  := "1A1208"

    ;  Le rouge de l'alerte, et lui seul : il n'apparait que si un filtre de
    ;  Windows se cumule au notre (voir Concurrents.ahk). Un second signal
    ;  colore dans une interface qui n'en a qu'un doit rester rare.
    static ALERTE_FOND  := "3A1C1C"
    static ALERTE_TEXTE := "F0A0A0"

    static _menusFaits := false

    ;--------------------------------------------------------------------------
    ;  Menus contextuels sombres.
    ;
    ;  SetPreferredAppMode et FlushMenuThemes ne sont exportees par uxtheme.dll
    ;  que par ordinal (135 et 136), sans nom. Non documentees, presentes depuis
    ;  Windows 10 1809. On echoue en silence si elles manquent : un menu clair
    ;  reste un menu utilisable.
    ;--------------------------------------------------------------------------
    static MenusSombres() {
        if (Theme._menusFaits)
            return true
        try {
            h := DllCall("GetModuleHandle", "str", "uxtheme", "ptr")
            if (!h)
                h := DllCall("LoadLibrary", "str", "uxtheme", "ptr")
            if (!h)
                return false

            pSet := DllCall("GetProcAddress", "ptr", h, "ptr", 135, "ptr")
            pFlush := DllCall("GetProcAddress", "ptr", h, "ptr", 136, "ptr")
            if (!pSet)
                return false

            DllCall(pSet, "int", 2)          ; 2 = ForceDark
            if (pFlush)
                DllCall(pFlush)

            Theme._menusFaits := true
            return true
        }
        return false
    }

    ;  Appele avec le hwnd de chaque fenetre qui passe par Fenetre(). C'est
    ;  par la que l'icone teintee arrive sur une fenetre qui vient de
    ;  s'ouvrir : toutes passent ici, aucune n'a a savoir ce que vaut le
    ;  filtre a cet instant.
    static surFenetre := 0

    ;--------------------------------------------------------------------------
    ;  Barre de titre sombre + coins arrondis Windows 11.
    ;--------------------------------------------------------------------------
    static Fenetre(hwnd, arrondi := true) {
        if (Theme.surFenetre)
            try (Theme.surFenetre)(hwnd)
        try {
            v := Buffer(4, 0)
            NumPut("Int", 1, v)
            ; DWMWA_USE_IMMERSIVE_DARK_MODE = 20 (19 sur les builds 1809-1903)
            if (DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 20
                      , "ptr", v, "int", 4) != 0)
                DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 19
                      , "ptr", v, "int", 4)
        }
        if (arrondi) {
            try {
                v := Buffer(4, 0)
                NumPut("Int", 2, v)          ; DWMWCP_ROUND
                DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 33
                      , "ptr", v, "int", 4)  ; DWMWA_WINDOW_CORNER_PREFERENCE
            }
        }
    }

    ;--------------------------------------------------------------------------
    ;  Champs de saisie, listes et boutons sombres.
    ;    "DarkMode_CFD"      -> Edit, ComboBox, Hotkey
    ;    "DarkMode_Explorer" -> Button, CheckBox, ScrollBar
    ;--------------------------------------------------------------------------
    static Controle(ctrl, sousType := "DarkMode_CFD") {
        try DllCall("uxtheme\SetWindowTheme", "ptr", ctrl.Hwnd, "str", sousType, "ptr", 0)
    }

}
