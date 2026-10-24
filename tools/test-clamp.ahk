;  test-clamp.ahk -- Windows applique-t-il vraiment la rampe qu'on lui donne ?
;  On ecrit une rampe extreme, on la relit, on compare. Aucune interaction.

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\lib\Gamma.ahk
#Include %A_LineFile%\..\..\lib\Ecrans.ahk

OnExit((*) => Rendre())          ; la rampe extreme ne survit pas a une erreur

out := ""
Log(s) {
    global out
    out .= s . "`r`n"
}

Lire() {
    buf := Buffer(3 * 256 * 2, 0)
    hdc := DllCall("GetDC", "ptr", 0, "ptr")
    ok := DllCall("gdi32\GetDeviceGammaRamp", "ptr", hdc, "ptr", buf)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)
    return ok ? buf : 0
}

Canal(buf, canal, i) {
    return NumGet(buf, (canal * 256 + i) * 2, "UShort")
}

Log("GdiIcmGammaRange leve : " . (Gamma.ClampLeve() ? "OUI (256)" : "NON"))

c := Gamma.Multiplicateurs(100)
Log(Format("multiplicateurs a 100 % (1200 K) : R={:.3f}  V={:.3f}  B={:.3f}", c.r, c.g, c.b))

;  La rampe extreme, posee sur chaque ecran comme le fait Ocre.
ok := false
for e in Ecrans.Lister()
    ok := Gamma.Poser(e.hdc, c) || ok
Log("SetDeviceGammaRamp(100 %) : " . (ok ? "accepte" : "REFUSE"))
Sleep(400)

buf := Lire()
if (!buf) {
    Log("GetDeviceGammaRamp a echoue")
} else {
    Log("")
    Log("indice |  ecrit R / V / B    |  relu R / V / B")
    for i in [64, 128, 192, 255] {
        base := i * 256
        eR := Round(Min(65535, base * c.r))
        eV := Round(Min(65535, base * c.g))
        eB := Round(Min(65535, base * c.b))
        Log(Format("  {:3}  |  {:5} {:5} {:5}  |  {:5} {:5} {:5}"
                 , i, eR, eV, eB, Canal(buf, 0, i), Canal(buf, 1, i), Canal(buf, 2, i)))
    }

    ; verdict sur le canal bleu, le plus revelateur
    bleuRelu := Canal(buf, 2, 255)
    bleuEcrit := Round(Min(65535, 255 * 256 * c.b))
    Log("")
    if (Abs(bleuRelu - bleuEcrit) <= 512)
        Log("VERDICT : la rampe est appliquee telle quelle. Le bridage est bien leve.")
    else
        Log("VERDICT : Windows a ROGNE la rampe (bleu demande " . bleuEcrit
          . ", obtenu " . bleuRelu . "). Une reouverture de session est necessaire.")
}

Rendre()

try FileDelete(A_ScriptDir . "\clamp-out.txt")
FileAppend(out, A_ScriptDir . "\clamp-out.txt", "UTF-8")
try FileAppend(out, "*")
ExitApp(InStr(out, "ROGNE") || InStr(out, "REFUSE") || InStr(out, "echoue") ? 1 : 0)

;  La rampe extreme est retiree quoi qu'il arrive -- une erreur au milieu la
;  laissait posee --, et si Ocre tourne, on lui demande de reposer la sienne
;  tout de suite plutot que d'attendre son chien de garde.
Rendre() {
    static fait := false
    if (fait)
        return
    fait := true
    for e in Ecrans.Lister()
        Gamma.Neutre(e.hdc)
    Ecrans.Oublier()
    exe := A_ScriptDir . "\..\Ocre.exe"
    if (ProcessExist("Ocre.exe") && FileExist(exe))
        try Run('"' . exe . '" /set +0', , "Hide")
}
