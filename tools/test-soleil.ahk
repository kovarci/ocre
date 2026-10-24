;==============================================================================
;  test-soleil.ahk -- verifie le calcul solaire, sans materiel.
;
;  Les valeurs de reference ne viennent pas de la meme source que le code
;  teste : elles ont ete produites par la bibliotheque Python "astral", qui
;  implemente le meme algorithme NOAA a partir de la publication d'origine.
;  Comparer une transcription a une autre transcription independante est ce
;  qui attrape les fautes de recopie -- une constante inversee, un signe de
;  longitude a l'envers, un degre pris pour un radian.
;
;  Les heures sont en UTC pour ne dependre d'aucun fuseau. La tolerance est de
;  deux minutes : les deux implementations arrondissent differemment, et un
;  fondu de trois heures ne distingue pas mieux.
;
;  Sept lieux, choisis pour les pieges : l'hemisphere sud (declinaison
;  inversee), l'equateur (jour constant), les longitudes negatives, et Tromso,
;  au-dela du cercle polaire, ou le soleil ne se leve ni ne se couche aux
;  solstices.
;
;  Un mot sur les valeurs de reference, parce qu'elles ont failli faire
;  condamner du code juste. La fonction sun() d'astral calcule d'un coup
;  l'aube, le lever, midi, le coucher et le crepuscule ; a Reykjavik en juin
;  elle echoue -- mais sur l'AUBE, qui se prend a 96 degres et n'existe pas
;  la-bas ce jour-la. Le lever, lui, existe. Prendre cet echec pour une nuit
;  polaire donnait une reference fausse a 64 degres de latitude, ou le soleil
;  se leve parfaitement. Les references viennent donc de sunrise() et sunset()
;  appelees separement.
;
;  Usage : AutoHotkey64.exe tools\test-soleil.ahk
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\..\lib\Soleil.ahk

CAS := [
    ; lieu,        lat,      lon,     annee, mois, jour, lever, coucher
      ["Paris",     48.8566,   2.3522, 2026,  6, 21, "03:47", "19:57"]
    , ["Paris",     48.8566,   2.3522, 2026, 12, 21, "07:41", "15:55"]
    , ["Paris",     48.8566,   2.3522, 2026,  9, 10, "05:20", "18:14"]
    , ["Reykjavik", 64.13,   -21.90,   2026, 12, 21, "11:22", "15:28"]
    , ["Reykjavik", 64.13,   -21.90,   2026,  9, 10, "06:36", "20:10"]
    , ["Reykjavik", 64.13,   -21.90,   2026,  6, 21, "02:56", "00:02"]
    , ["Sydney",   -33.87,   151.21,   2026,  6, 21, "21:00", "06:53"]
    , ["Sydney",   -33.87,   151.21,   2026, 12, 21, "18:41", "09:05"]
    , ["Sydney",   -33.87,   151.21,   2026,  9, 10, "20:00", "07:42"]
    , ["Singapour",  1.29,   103.85,   2026,  6, 21, "23:00", "11:12"]
    , ["Singapour",  1.29,   103.85,   2026, 12, 21, "23:01", "11:03"]
    , ["New York",  40.71,   -74.01,   2026,  6, 21, "09:25", "00:30"]
    , ["New York",  40.71,   -74.01,   2026, 12, 21, "12:16", "21:31"]
    , ["Ushuaia",  -54.80,   -68.30,   2026,  6, 21, "12:59", "20:10"]
    , ["Ushuaia",  -54.80,   -68.30,   2026, 12, 21, "07:51", "01:10"]
    , ["Tromso",    69.65,    18.96,   2026,  6, 21, "polaire", "polaire"]
    , ["Tromso",    69.65,    18.96,   2026, 12, 21, "polaire", "polaire"]
    , ["Tromso",    69.65,    18.96,   2026,  9, 10, "03:37", "17:42"]]

TOLERANCE := 2

rapport := "Calcul solaire -- " . CAS.Length . " cas, tolerance "
         . TOLERANCE . " min`n`n"
fautes := 0

for cas in CAS {
    lieu := cas[1], lat := cas[2], lon := cas[3]
    u := Soleil._Utc(cas[4], cas[5], cas[6], lat, lon)

    date := Format("{:04}-{:02}-{:02}", cas[4], cas[5], cas[6])
    entete := Format("{:-11}{}  ", lieu, date)

    if (cas[7] = "polaire") {
        if (u.lever = Soleil.JAMAIS) {
            rapport .= entete . "polaire (" . u.polaire . ")            ok`n"
        } else {
            rapport .= entete . "attendu polaire, obtenu "
                     . Hhmm(u.lever) . " / " . Hhmm(u.coucher) . "   FAUX`n"
            fautes += 1
        }
        continue
    }

    if (u.lever = Soleil.JAMAIS) {
        rapport .= entete . "attendu " . cas[7] . ", obtenu polaire        FAUX`n"
        fautes += 1
        continue
    }

    dl := Ecart(u.lever, cas[7])
    dc := Ecart(u.coucher, cas[8])
    bon := (dl <= TOLERANCE && dc <= TOLERANCE)
    if (!bon)
        fautes += 1

    rapport .= entete
             . "lever " . Hhmm(u.lever) . " / " . cas[7] . " " . Signe(dl) . "  "
             . "coucher " . Hhmm(u.coucher) . " / " . cas[8] . " " . Signe(dc)
             . (bon ? "   ok" : "   FAUX") . "`n"
}

;------------------------------------------------------------------ bornes ----
;  Deux verifications qui ne demandent aucune reference : le lieu vide, qu'il
;  faut refuser, et la coherence du cadran.
rapport .= "`n"
rapport .= "Valide(0, 0)          " . (Soleil.Valide(0, 0) ? "vrai  FAUX" : "faux  ok") . "`n"
rapport .= "Valide(48.85, 2.35)   " . (Soleil.Valide(48.85, 2.35) ? "vrai  ok" : "faux  FAUX") . "`n"
rapport .= "Valide(91, 0)         " . (Soleil.Valide(91, 0) ? "vrai  FAUX" : "faux  ok") . "`n"
rapport .= "Valide(-, -)          " . (Soleil.Valide("x", "y") ? "vrai  FAUX" : "faux  ok") . "`n"
if (Soleil.Valide(0, 0) || !Soleil.Valide(48.85, 2.35) || Soleil.Valide(91, 0)
 || Soleil.Valide("x", "y"))
    fautes += 1

rapport .= "`n" . (fautes ? fautes . " cas faux" : "tout est juste") . "`n"

;  Sur la sortie standard si on nous la donne, sinon dans une boite : le
;  fichier se lance aussi bien depuis un terminal que par double-clic.
try FileAppend(rapport, "*")
catch
    MsgBox(rapport, "Ocre -- test du calcul solaire")
ExitApp(fautes ? 1 : 0)

;------------------------------------------------------------------------------
Hhmm(minutes) {
    m := Mod(Mod(Round(minutes), 1440) + 1440, 1440)
    return Format("{:02}:{:02}", m // 60, Mod(m, 60))
}

;  Ecart en minutes, sur un cadran qui boucle : 23:59 et 00:01 sont a deux
;  minutes l'une de l'autre, pas a 1438.
Ecart(minutes, attenduTexte) {
    a := StrSplit(attenduTexte, ":")
    attendu := Integer(a[1]) * 60 + Integer(a[2])
    obtenu := Mod(Mod(Round(minutes), 1440) + 1440, 1440)
    d := Abs(obtenu - attendu)
    return Min(d, 1440 - d)
}

Signe(d) {
    return "(" . (d = 0 ? "=" : "ecart " . d) . ")"
}
