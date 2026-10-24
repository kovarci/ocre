;  test-perf.ahk -- Ocre demarre-t-il vite, et se tait-il au repos ?
;
;  Deux choses qu'aucun autre test ne voit, et qui font qu'un utilitaire de
;  zone de notification reste installe ou non. Un demarrage lent retarde le
;  filtre chaque matin ; un pour cent de processeur en permanence se voit
;  dans le gestionnaire des taches et se fait desinstaller.
;
;  Le demarrage : ce script se relance lui-meme en enfant, qui charge tout
;  ce qu'Ocre charge -- les memes modules, la configuration, les ecrans, une
;  icone -- puis s'en va ; on chronometre du lancement a la sortie. Ce n'est
;  pas Ocre.exe lui-meme : lancer Ocre.ahk remplacerait l'instance en place.
;
;  Le repos : les minuteurs d'Ocre -- inactivite, horaire, rappel, chien de
;  garde -- tournent ici pendant quelques secondes, et l'on mesure le temps
;  processeur du processus par GetProcessTimes. Si Ocre.exe tourne, il est
;  mesure aussi, en vrai.
;
;  Le rapport part sur la sortie standard et dans perf-out.txt ; le code de
;  retour vaut 0 ou 1.

#Requires AutoHotkey v2.0
#SingleInstance Off
#Include %A_LineFile%\..\..\lib\Gamma.ahk
#Include %A_LineFile%\..\..\lib\Ecrans.ahk
#Include %A_LineFile%\..\..\lib\Retro.ahk
#Include %A_LineFile%\..\..\lib\Filtre.ahk
#Include %A_LineFile%\..\..\lib\Fondu.ahk
#Include %A_LineFile%\..\..\lib\Blob.ahk
#Include %A_LineFile%\..\..\lib\Theme.ahk
#Include %A_LineFile%\..\..\lib\Config.ahk
#Include %A_LineFile%\..\..\lib\I18n.ahk
#Include %A_LineFile%\..\..\lib\Osd.ahk
#Include %A_LineFile%\..\..\lib\Widgets.ahk
#Include %A_LineFile%\..\..\lib\Lieu.ahk
#Include %A_LineFile%\..\..\lib\Reglages.ahk
#Include %A_LineFile%\..\..\lib\Panneau.ahk
#Include %A_LineFile%\..\..\lib\Soleil.ahk
#Include %A_LineFile%\..\..\lib\Horaire.ahk
#Include %A_LineFile%\..\..\lib\Unite.ahk
#Include %A_LineFile%\..\..\lib\Rappel.ahk
#Include %A_LineFile%\..\..\lib\Inactif.ahk
#Include %A_LineFile%\..\..\lib\Batterie.ahk
#Include %A_LineFile%\..\..\lib\Concurrents.ahk

;  Jamais la vraie configuration.
Config.DOSSIER := A_Temp . "\ocre-test-perf"
Config.FICHIER := Config.DOSSIER . "\essai.ini"

;------------------------------------------------------------------ enfant ----
;  Ce qu'Ocre fait avant de poser sa premiere rampe, sans la poser.
if (A_Args.Length && A_Args[1] = "enfant") {
    I18n.Definir(Config.Lire("langue"))
    Filtre.Charger()
    for e in Ecrans.Lister()
        continue
    h := Blob.Icone(60, 32)
    DllCall("DestroyIcon", "ptr", h)
    Concurrents.NightLight()
    Concurrents.Programmes()
    ExitApp(0)
}

rates := 0
total := 0
rapport := ""

OnError(Rapporter)
Rapporter(e, mode) {
    Dire("")
    Dire("  ERREUR  " . e.Message)
    Dire("          " . e.File . " ligne " . e.Line)
    Ecrire()
    ExitApp(1)
    return -1
}

Dire(s) {
    global rapport
    rapport .= s . "`r`n"
    try FileAppend(s . "`r`n", "*")
}

Ecrire() {
    global rapport
    f := A_ScriptDir . "\perf-out.txt"
    try FileDelete(f)
    try FileAppend(rapport, f, "UTF-8")
}

Verifier(nom, condition, detail := "") {
    global rates, total
    total += 1
    if (condition) {
        Dire("  ok    " . nom)
        return
    }
    rates += 1
    Dire("  RATE  " . nom . (detail != "" ? "   -> " . detail : ""))
}

;  Le temps processeur d'un processus, en millisecondes : noyau + utilisateur,
;  FILETIME en centaines de nanosecondes.
Cpu(h) {
    c := Buffer(8), s := Buffer(8), k := Buffer(8), u := Buffer(8)
    if (!DllCall("GetProcessTimes", "ptr", h, "ptr", c, "ptr", s, "ptr", k, "ptr", u))
        return -1
    return (NumGet(k, 0, "Int64") + NumGet(u, 0, "Int64")) / 10000.0
}

;  Le pourcentage de processeur d'un processus sur "duree" ms, un coeur.
Repos(h, duree) {
    t0 := A_TickCount, c0 := Cpu(h)
    Sleep(duree)
    dt := A_TickCount - t0, dc := Cpu(h) - c0
    return dt > 0 ? 100.0 * dc / dt : 0
}

try DirCreate(Config.DOSSIER)
try FileDelete(Config.FICHIER)
Config.Ecrire("langue", "fr")
Config.Ecrire("inactif", 1), Config.Ecrire("inactif_minutes", 1)
Config.Ecrire("rappel", 1), Config.Ecrire("rappel_minutes", 20)
Config.Ecrire("horaire", 1), Config.Ecrire("h_soleil", 0)
Config.Vider()

Dire("")
Dire("Ocre -- demarrage et repos")
Dire("")

;-------------------------------------------------------------- demarrage ----
;  Trois lancements, on garde le meilleur : le premier paie le cache disque.
meilleur := 999999
Loop 3 {
    t0 := A_TickCount
    RunWait('"' . A_AhkPath . '" /ErrorStdOut "' . A_ScriptFullPath . '" enfant', , "Hide")
    meilleur := Min(meilleur, A_TickCount - t0)
}
Dire(Format("  demarrage : {} ms (le meilleur de trois, interpreteur compris)", meilleur))
Verifier("tout se charge en moins d'une seconde et demie", meilleur < 1500, meilleur . " ms")

;------------------------------------------------------------------ repos ----
;  Les minuteurs d'Ocre, ici, pendant six secondes. Le chien de garde est
;  celui d'Ocre.ahk, reproduit : relire la rampe et l'alimentation.
I18n.Definir("fr")
Filtre.Charger()
Horaire.Init((v) => 0, () => 0)
Rappel.Init((e) => 0, () => true)
Inactif.Init((d) => 0, (d) => 0)
Batterie.Init((p, d) => 0, (d) => 0)
garde := () => (Ecrans.Verifier(), Filtre.Devie())
SetTimer(garde, 10000)

moi := DllCall("GetCurrentProcess", "ptr")
Sleep(500)                       ; le temps que tout se pose
;  Le seuil est large : un chien de garde qui tombe dans la fenetre, une
;  souris qui bouge, et la mesure varie du simple au quintuple. Ce qu'on
;  cherche, c'est une boucle qui tourne a vide -- dix pour cent, pas un.
pct := Repos(moi, 6000)
Dire(Format("  repos, les minuteurs d'Ocre ici : {:.2f} % d'un coeur", pct))
Verifier("les minuteurs coutent moins de trois pour cent", pct < 3.0, Format("{:.2f} %", pct))
SetTimer(garde, 0)

;  Et Ocre.exe lui-meme, s'il tourne : PROCESS_QUERY_LIMITED_INFORMATION.
pid := ProcessExist("Ocre.exe")
if (pid) {
    h := DllCall("OpenProcess", "uint", 0x1000, "int", 0, "uint", pid, "ptr")
    if (h) {
        ;  Dix secondes : le chien de garde y passe au moins une fois. Le
        ;  hook souris de la molette sur l'icone compte aussi, des que la
        ;  souris bouge : c'est le prix de ce geste, et il reste sous le
        ;  demi pour cent.
        ;
        ;  Lance juste apres test-ui et test-fuites, Ocre.exe redessine encore
        ;  son icone et repose ses fenetres : cinq secondes de calme d'abord,
        ;  sinon la mesure disait 1,25 % la ou seul il fait 0,6.
        Sleep(5000)
        pct := Repos(h, 10000)
        DllCall("CloseHandle", "ptr", h)
        Dire(Format("  repos, Ocre.exe en place (pid {}) : {:.2f} % d'un coeur", pid, pct))
        Verifier("Ocre.exe au repos coute moins d'un pour cent", pct < 1.0, Format("{:.2f} %", pct))
    }
} else {
    Dire("  (Ocre.exe ne tourne pas : son repos n'est pas mesure)")
}

try FileDelete(Config.FICHIER)
try DirDelete(Config.DOSSIER)

Dire("")
Dire(rates = 0
   ? Format("  {} verifications, aucune erreur.", total)
   : Format("  {} verifications, {} ERREURS.", total, rates))
Dire("")

Ecrire()
ExitApp(rates = 0 ? 0 : 1)
