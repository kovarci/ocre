;  selftest.ahk -- verifie le codec SANS rien ecrire dans le registre.
;  Resultat dans selftest-out.txt
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\NightLight.ahk

; toute erreur non rattrapee part dans le fichier, jamais dans une boite de dialogue
OnError(Fatal)
Fatal(e, mode) {
    FileAppend("`r`nERREUR FATALE`r`n  message : " . e.Message
             . "`r`n  fichier : " . e.File
             . "`r`n  ligne   : " . e.Line
             . "`r`n  contexte: " . e.What
             . "`r`n  extra   : " . e.Extra . "`r`n"
             , A_ScriptDir . "\selftest-out.txt", "UTF-8")
    ExitApp 1
}

out := ""
Log(s) {
    global out
    out .= s . "`r`n"
}

Try2(name, fn) {
    try {
        Log(name . " : " . fn())
    } catch as e {
        Log(name . " : ERREUR -> " . e.Message)
    }
}

Log("=== lecture ===")

raw := NightLight.ReadBytes(NightLight.K_SETTINGS)
Log("settings brut (" . raw.Length . " o) : " . NightLight.ToHex(raw))
env := NightLight.ParseEnvelope(raw)
Log("  timestamp enveloppe : " . env.ts)
Log("  payload (" . env.inner.Length . " o) : " . NightLight.ToHex(env.inner))

rebuilt := NightLight.BuildEnvelope(env.ts, env.inner)
Log("  aller-retour settings : " . (NightLight.ToHex(raw) = NightLight.ToHex(rebuilt) ? "IDENTIQUE" : "DIFFERENT !!"))
if (NightLight.ToHex(raw) != NightLight.ToHex(rebuilt))
    Log("  reconstruit : " . NightLight.ToHex(rebuilt))

raw2 := NightLight.ReadBytes(NightLight.K_STATE)
Log("state brut (" . raw2.Length . " o) : " . NightLight.ToHex(raw2))
env2 := NightLight.ParseEnvelope(raw2)
Log("  timestamp enveloppe : " . env2.ts)
Log("  payload (" . env2.inner.Length . " o) : " . NightLight.ToHex(env2.inner))

rebuilt2 := NightLight.BuildEnvelope(env2.ts, env2.inner)
Log("  aller-retour state : " . (NightLight.ToHex(raw2) = NightLight.ToHex(rebuilt2) ? "IDENTIQUE" : "DIFFERENT !!"))

Log("")
Log("=== decodage ===")
Try2("temperature (K)", () => NightLight.GetTemp())
Try2("intensite (%)", () => NightLight.KelvinToPercent(NightLight.GetTemp()))
Try2("planification active", () => NightLight.ScheduleActive() ? "OUI" : "NON (mode manuel)")
Try2("night light actif", () => NightLight.IsEnabled() ? "OUI" : "NON")

Log("")
Log("=== simulation d'ecriture (rien n'est ecrit) ===")
; on refait exactement ce que ferait SetTemp, mais on affiche au lieu d'ecrire
for k in [3426, 4500, 2400, 1200, 6500] {
    z := NightLight.ZigzagEncode(k)
    v := NightLight.WriteVarint(z)
    i := 1
    back := NightLight.ZigzagDecode(NightLight.ReadVarint(v, &i))
    Log(k . " K -> zigzag " . z . " -> varint " . NightLight.ToHex(v)
        . " -> relu " . back . (back = k ? "  OK" : "  ECHEC"))
}

; simulation du basculement on/off : longueurs attendues 21 <-> 19 octets internes
inner := env2.inner.Clone()
has := (inner.Length >= 6 && inner[5] = 0x10 && inner[6] = 0x00)
Log("")
Log("payload state actuel : " . inner.Length . " o, flag ON " . (has ? "present" : "absent"))
if (has) {
    inner.RemoveAt(5, 2)
    Log("  -> apres extinction : " . inner.Length . " o : " . NightLight.ToHex(inner))
} else {
    inner.InsertAt(5, 0x10, 0x00)
    Log("  -> apres allumage : " . inner.Length . " o : " . NightLight.ToHex(inner))
}

try FileDelete(A_ScriptDir . "\selftest-out.txt")
FileAppend(out, A_ScriptDir . "\selftest-out.txt", "UTF-8")
ExitApp
