;==============================================================================
;  sonde-luminosite.ahk -- la touche de luminosite est-elle visible du logiciel ?
;
;  Question posee : peut-on accrocher un raccourci a "Ctrl + baisser la
;  luminosite" ? Cela suppose que l'appui produise un evenement que Windows
;  transmette aux applications. Sur beaucoup de portables il n'en produit
;  aucun : le pilote d'affichage traite la touche sans passer par le clavier.
;
;  La sonde ecoute trois canaux a la fois :
;    - le crochet clavier   (toute touche, y compris les codes exotiques)
;    - WM_APPCOMMAND        (les commandes multimedia)
;    - WM_HOTKEY du systeme (au cas ou)
;
;  Elle n'intercepte rien et annonce son verdict elle-meme.
;==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

RECU := 0

Journal(s) {
    FileAppend(s . "`r`n", A_Temp . "\sonde-luminosite.txt", "UTF-8")
}

Consigne() {
    global RECU
    ToolTip("SONDE  -  touche de luminosite"
          . "`n`nAppuyez plusieurs fois sur  F5  SEUL,"
          . "`npuis sur  F6  SEUL."
          . "`n(la luminosite doit changer a l'ecran)"
          . "`n`nevenements captes : " . RECU
          . "`n`nCtrl + Alt + Q  pour connaitre le resultat", 40, 40)
}

try FileDelete(A_Temp . "\sonde-luminosite.txt")
Journal("--- sonde luminosite " . FormatTime(, "HH:mm:ss") . " ---")

;--- canal 1 : crochet clavier ------------------------------------------------
Touche(hook, vk, sc) {
    global RECU
    nom := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    ; on ignore les modificateurs seuls, qui noieraient le journal
    if (vk = 0xA0 || vk = 0xA1 || vk = 0xA2 || vk = 0xA3
     || vk = 0xA4 || vk = 0xA5 || vk = 0x5B || vk = 0x5C)
        return
    RECU += 1
    Journal("clavier : " . (nom = "" ? "sans nom" : nom)
          . "   vk" . Format("{:02X}", vk) . " sc" . Format("{:03X}", sc))
    Consigne()
}

ih := InputHook()
ih.VisibleText := true
ih.VisibleNonText := true
ih.KeyOpt("{All}", "N")
ih.OnKeyDown := Touche
ih.Start()

;--- canal 2 : commandes multimedia ------------------------------------------
;  WM_APPCOMMAND ne parvient qu'a la fenetre active : la sonde s'affiche donc
;  et se met au premier plan, sans quoi ce canal ne dirait rien.
AppCommand(wParam, lParam, msg, hwnd) {
    global RECU
    RECU += 1
    cmd := (lParam >> 16) & 0x0FFF
    Journal("appcommand : " . cmd)
    Consigne()
}
OnMessage(0x0319, AppCommand)

f := Gui("+AlwaysOnTop -MaximizeBox", "Sonde Ocre")
f.BackColor := "17171A"
f.SetFont("s10 cEDEDF0", "Segoe UI")
f.Add("Text", "x20 y20 w320 h60"
    , "Gardez cette fenetre au premier plan.`nAppuyez sur F5 seul, puis F6 seul.")
f.Show("w360 h100")
try WinActivate("ahk_id " . f.Hwnd)

Consigne()

^!q:: {
    global RECU
    ToolTip()
    Journal("--- fin, " . RECU . " evenement(s) ---")
    if (RECU > 0) {
        MsgBox("La touche produit bien " . RECU . " evenement(s) visibles.`n`n"
             . "Un raccourci peut donc s'y accrocher. Le detail est dans :`n"
             . A_Temp . "\sonde-luminosite.txt"
             , "Sonde Ocre - resultat", 64)
    } else {
        MsgBox("Aucun evenement recu.`n`n"
             . "La touche de luminosite est traitee par le pilote d'affichage "
             . "sans jamais parvenir aux applications. Aucun programme ne peut "
             . "s'y accrocher, avec ou sans Ctrl."
             , "Sonde Ocre - resultat", 48)
    }
    ExitApp()
}
