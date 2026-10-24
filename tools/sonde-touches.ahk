;==============================================================================
;  sonde-touches.ahk -- que recoit reellement Windows quand vous appuyez ?
;
;  Sur beaucoup de portables, le firmware consomme les touches de fonction
;  avant que Windows les voie. Aucun programme ne peut alors les intercepter,
;  et il est impossible de le deviner autrement qu'en mesurant.
;
;  La sonde n'avale rien : elle observe et inscrit chaque touche recue dans
;  %TEMP%\sonde-touches.txt. Elle attend aussi longtemps qu'il le faut, et
;  annonce elle-meme son verdict des qu'elle a vu F5.
;==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

VU_F5 := false
VU_CTRL_F5 := false
VERDICT_RENDU := false

Journal(s) {
    FileAppend(s . "`r`n", A_Temp . "\sonde-touches.txt", "UTF-8")
}

Consigne() {
    global VU_F5, VU_CTRL_F5
    etat := "Ctrl+F5 : " . (VU_CTRL_F5 ? "RECU" : "pas encore")
          . "     F5 seul : " . (VU_F5 ? "RECU" : "pas encore")
    ToolTip("SONDE OCRE  -  aucune touche n'est interceptee"
          . "`n`n1.  appuyez sur  Ctrl + F5"
          . "`n2.  appuyez sur  F5  seul"
          . "`n3.  appuyez sur  Fn + F5"
          . "`n`n" . etat
          . "`n`nCtrl + Alt + Q  pour arreter", 40, 40)
}

try FileDelete(A_Temp . "\sonde-touches.txt")
Journal("--- sonde demarree " . FormatTime(, "HH:mm:ss") . " ---")

Touche(hook, vk, sc) {
    global VU_F5, VU_CTRL_F5, VERDICT_RENDU

    nom := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    if (nom = "")
        nom := "inconnue"
    ;  Seules les touches de fonction et les modificateurs sont nommes dans
    ;  le journal : la sonde n'a pas a savoir ce qu'on tape a cote -- un mot
    ;  de passe saisi pendant qu'elle tourne n'y laisserait aucune trace.
    if (!RegExMatch(nom, "i)^(F\d{1,2}|[LR]?(Control|Ctrl|Alt|Shift|Win)|Escape|Space|Enter|Backspace|Tab)$"))
        nom := "(touche)"

    mods := ""
    if (GetKeyState("Ctrl", "P"))
        mods .= "Ctrl+"
    if (GetKeyState("Alt", "P"))
        mods .= "Alt+"
    if (GetKeyState("Shift", "P"))
        mods .= "Maj+"
    if (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
        mods .= "Win+"

    Journal(mods . nom . (nom = "(touche)" ? "" : "   (vk" . Format("{:02X}", vk) . " sc" . Format("{:03X}", sc) . ")"))

    if (vk = 0x74) {                       ; VK_F5
        VU_F5 := true
        if (InStr(mods, "Ctrl+"))
            VU_CTRL_F5 := true
        if (!VERDICT_RENDU) {
            VERDICT_RENDU := true
            SetTimer(Verdict, -400)        ; on laisse la frappe se terminer
        }
    }
    Consigne()
}

Verdict() {
    global VU_CTRL_F5
    ToolTip()
    MsgBox("F5 atteint bien Windows.`n`n"
         . (VU_CTRL_F5
            ? "Ctrl+F5 a ete recu : le raccourci principal devrait fonctionner. "
            . "Si Ocre n'y repond pas, le probleme vient de l'application et non "
            . "du clavier."
            : "Seul F5 sans Ctrl a ete vu pour l'instant. Reessayez avec Ctrl "
            . "enfonce pour completer le diagnostic.")
         . "`n`nLe detail est dans :`n" . A_Temp . "\sonde-touches.txt"
         , "Sonde Ocre - resultat", 64)
    Consigne()
}

;  VisibleText et VisibleNonText a vrai : la sonde observe sans rien retenir,
;  les touches continuent d'aller a l'application au premier plan.
ih := InputHook()
ih.VisibleText := true
ih.VisibleNonText := true
ih.KeyOpt("{All}", "N")
ih.OnKeyDown := Touche
ih.Start()

Consigne()

^!q:: {
    global VU_F5
    ToolTip()
    Journal("--- arret demande ---")
    if (!VU_F5) {
        MsgBox("F5 n'est jamais parvenu a Windows.`n`n"
             . "Le firmware du portable le consomme avant le systeme : aucun "
             . "programme ne peut l'intercepter dans cet etat. Basculez le "
             . "Fn-lock (souvent Fn+Esc), ou dans le BIOS :`n"
             . "Main > Function key behavior > Function key.`n`n"
             . "En attendant, le jeu de secours d'Ocre reste operationnel."
             , "Sonde Ocre - resultat", 48)
    }
    ExitApp()
}
