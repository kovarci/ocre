;  nlctl.ahk -- pilotage du Night Light en ligne de commande.
;
;    nlctl status          etat courant
;    nlctl temp <kelvin>   temperature 1200-6500
;    nlctl pct <0-100>     intensite en pourcent
;    nlctl on / nlctl off  allume / eteint
;
;  Avant d'ecrire, les deux valeurs du registre sont exportees dans backup\
;  (une fois par jour) : nl-settings-auto-<date>.reg, nl-state-auto-<date>.reg.
;
;  Sert aux tests et a l'installation. Le pilotage au clavier est dans
;  nightlight.ahk, qui utilise la meme bibliotheque.

#Requires AutoHotkey v2.0
#SingleInstance Off
#Include %A_LineFile%\..\NightLight.ahk

OnError(Fatal)
Fatal(e, mode) {
    Say("erreur : " . e.Message . (e.Extra ? " (" . e.Extra . ")" : ""))
    ExitApp 1
}

Say(s) {
    FileAppend(s . "`r`n", "*")      ; "*" = sortie standard
}

Status() {
    k := NightLight.GetTemp()
    Say("night light   : " . (NightLight.IsEnabled() ? "ON" : "OFF"))
    Say("temperature   : " . k . " K")
    Say("intensite     : " . NightLight.KelvinToPercent(k) . " %")
    Say("planification : " . (NightLight.ScheduleActive() ? "ACTIVE" : "off (manuel)"))
}

if (A_Args.Length = 0) {
    Say("usage : nlctl status | temp <1200-6500> | pct <0-100> | on | off")
    ExitApp 0
}

cmd := StrLower(A_Args[1])
arg := A_Args.Length >= 2 ? A_Args[2] : ""

;  Toute commande qui ecrit sauvegarde d'abord les deux valeurs, une fois
;  par jour au plus, dans backup a cote du script : "reg export" les rend
;  telles quelles, et l'on peut toujours revenir en arriere par un double
;  clic sur le .reg. Sans cela, un essai curieux n'avait aucun retour.
Sauvegarder() {
    dossier := A_ScriptDir . "\backup"
    try DirCreate(dossier)
    date := FormatTime(, "yyyyMMdd")
    for paire in [["nl-settings", NightLight.K_SETTINGS], ["nl-state", NightLight.K_STATE]] {
        f := dossier . "\" . paire[1] . "-auto-" . date . ".reg"
        if (FileExist(f))
            continue
        try RunWait('reg.exe export "' . paire[2] . '" "' . f . '" /y', , "Hide")
        Say("sauvegarde : " . f)
    }
}

if (cmd != "status")
    Sauvegarder()

switch cmd {
    case "status":
        Status()
    case "temp":
        if (arg = "" || !IsNumber(arg)) {
            Say("erreur : temperature manquante ou non numerique")
            ExitApp 1
        }
        Say("temperature reglee a " . NightLight.SetTemp(Integer(arg)) . " K")
    case "templive":
        if (arg = "" || !IsNumber(arg)) {
            Say("erreur : temperature manquante ou non numerique")
            ExitApp 1
        }
        Say("temperature appliquee a chaud : " . NightLight.SetTempLive(Integer(arg)) . " K")
    case "pct":
        if (arg = "" || !IsNumber(arg)) {
            Say("erreur : pourcentage manquant ou non numerique")
            ExitApp 1
        }
        k := NightLight.SetTemp(NightLight.PercentToKelvin(Integer(arg)))
        Say("intensite reglee a " . NightLight.KelvinToPercent(k) . " % (" . k . " K)")
    case "on":
        NightLight.On()
        Say("night light allume")
    case "off":
        NightLight.Off()
        Say("night light eteint")
    default:
        Say("commande inconnue : " . cmd)
        ExitApp 1
}

ExitApp 0
