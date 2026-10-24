;==============================================================================
;  NightLight.ahk -- pilotage natif du Night Light de Windows 11
;
;  Aucune dependance externe. Decode l'enveloppe CloudStore et le payload
;  Microsoft Bond CompactBinary v1, ne modifie QUE le champ vise, re-encode.
;  Les horaires de lever / coucher du soleil calcules par Windows sont
;  integralement preserves : aucun blob binaire n'est ecrit en dur.
;
;  Format documente par kvnxiao/win-nightlight-cli (voir README.md).
;  Ce format n'est pas un contrat Microsoft, il peut changer entre versions.
;
;  Fichier volontairement en ASCII pur (AutoHotkey lit l'ANSI sans BOM).
;==============================================================================

#Requires AutoHotkey v2.0

class NightLight {

    static K_SETTINGS := "HKCU\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default$windows.data.bluelightreduction.settings\windows.data.bluelightreduction.settings"
    static K_STATE    := "HKCU\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default$windows.data.bluelightreduction.bluelightreductionstate\windows.data.bluelightreduction.bluelightreductionstate"


    static MIN_K := 1200   ; 100 % d'intensite
    static MAX_K := 6500   ; 0 %   d'intensite

    ;--------------------------------------------------------------------------
    ;  Conversions intensite <-> Kelvin (mapping lineaire)
    ;--------------------------------------------------------------------------
    static PercentToKelvin(p) {
        p := Max(0, Min(100, p))
        return Round(NightLight.MAX_K - (p / 100.0) * (NightLight.MAX_K - NightLight.MIN_K))
    }

    static KelvinToPercent(k) {
        k := Max(NightLight.MIN_K, Min(NightLight.MAX_K, k))
        return Round(100 - ((k - NightLight.MIN_K) / (NightLight.MAX_K - NightLight.MIN_K)) * 100)
    }

    ;--------------------------------------------------------------------------
    ;  Primitives varint / zigzag (Bond CompactBinary v1)
    ;--------------------------------------------------------------------------
    static ReadVarint(buf, &i) {
        val := 0
        shift := 0
        Loop {
            if (i > buf.Length)
                throw Error("varint tronque a l'offset " i)
            b := buf[i]
            i += 1
            val |= (b & 0x7F) << shift
            if !(b & 0x80)
                break
            shift += 7
            if (shift > 63)
                throw Error("varint trop long")
        }
        return val
    }

    static WriteVarint(val) {
        out := []
        Loop {
            b := val & 0x7F
            val := (val >> 7) & 0x01FFFFFFFFFFFFFF   ; force un decalage logique
            if (val) {
                out.Push(b | 0x80)
            } else {
                out.Push(b)
                break
            }
        }
        return out
    }

    static ZigzagEncode(n) {
        return (n << 1) ^ (n >> 63)
    }

    static ZigzagDecode(u) {
        return (u >> 1) ^ -(u & 1)
    }

    ;--------------------------------------------------------------------------
    ;  Registre <-> tableau d'octets
    ;--------------------------------------------------------------------------
    static ReadBytes(key) {
        hex := RegRead(key, "Data")
        hex := RegExReplace(hex, "[^0-9A-Fa-f]", "")
        buf := []
        Loop (StrLen(hex) // 2)
            buf.Push(Integer("0x" . SubStr(hex, (A_Index - 1) * 2 + 1, 2)))
        if (!buf.Length)
            throw Error("valeur Data vide ou illisible")
        return buf
    }

    static WriteBytes(key, buf) {
        hex := ""
        for b in buf
            hex .= Format("{:02X}", b & 0xFF)
        RegWrite(hex, "REG_BINARY", key, "Data")
    }

    static ToHex(buf) {
        hex := ""
        for b in buf
            hex .= Format("{:02X} ", b & 0xFF)
        return RTrim(hex)
    }

    ;--------------------------------------------------------------------------
    ;  Enveloppe CloudStore
    ;    43 42 01 00 | 0A 02 01 00 | 2A 06 <varint ts>
    ;               | 2A 2B 0E <varint n> | <n octets> | 00 00 00
    ;--------------------------------------------------------------------------
    static Expect(buf, idx, val, what) {
        if (buf.Length < idx || buf[idx] != val)
            throw Error("enveloppe CloudStore inattendue : " . what . " a l'offset " . idx)
    }

    static ParseEnvelope(buf) {
        NightLight.Expect(buf, 1, 0x43, "magic C")
        NightLight.Expect(buf, 2, 0x42, "magic B")
        NightLight.Expect(buf, 3, 0x01, "version 1")
        NightLight.Expect(buf, 4, 0x00, "octet reserve")
        NightLight.Expect(buf, 5, 0x0A, "champ 0 struct")
        NightLight.Expect(buf, 6, 0x02, "champ 0 bool")
        NightLight.Expect(buf, 7, 0x01, "valeur true")
        NightLight.Expect(buf, 8, 0x00, "stop")
        NightLight.Expect(buf, 9, 0x2A, "champ 1 struct")
        NightLight.Expect(buf, 10, 0x06, "champ 0 uint64")

        i := 11
        ts := NightLight.ReadVarint(buf, &i)

        NightLight.Expect(buf, i, 0x2A, "struct wrapper")
        i += 1
        NightLight.Expect(buf, i, 0x2B, "champ 1 list")
        i += 1
        NightLight.Expect(buf, i, 0x0E, "type element int8")
        i += 1
        n := NightLight.ReadVarint(buf, &i)

        if (i + n - 1 > buf.Length)
            throw Error("payload annonce " . n . " octets, buffer trop court")

        inner := []
        Loop n
            inner.Push(buf[i + A_Index - 1])

        return { ts: ts, inner: inner }
    }

    static BuildEnvelope(ts, inner) {
        out := [0x43, 0x42, 0x01, 0x00, 0x0A, 0x02, 0x01, 0x00, 0x2A, 0x06]
        for b in NightLight.WriteVarint(ts)
            out.Push(b)
        out.Push(0x2A, 0x2B, 0x0E)
        for b in NightLight.WriteVarint(inner.Length)
            out.Push(b)
        for b in inner
            out.Push(b)
        out.Push(0x00, 0x00, 0x00)
        return out
    }

    static NowUnix() {
        DllCall("GetSystemTimeAsFileTime", "int64*", &ft := 0)
        return (ft // 10000000) - 11644473600
    }

    static NowFiletime() {
        DllCall("GetSystemTimeAsFileTime", "int64*", &ft := 0)
        return ft
    }

    ;  Horodatage strictement croissant. Windows annule immediatement toute
    ;  ecriture dont l'horodatage est inferieur a celui deja stocke, et il
    ;  avance lui-meme le sien de quelques secondes a chaque changement : deux
    ;  ecritures rapprochees doivent donc se depasser explicitement.
    static NextTs(precedent) {
        n := NightLight.NowUnix()
        return (n > precedent) ? n : precedent + 1
    }

    ;  Champ 70 (BT_BOOL) : "reglage de la temperature en cours".
    ;  C'est le drapeau que leve l'interface Parametres pendant qu'on fait
    ;  glisser le curseur. Sa presence force le moteur a appliquer la
    ;  temperature sur-le-champ au lieu de se contenter de la memoriser.
    static SetPreviewFlag(inner, actif) {
        out := inner.Clone()
        pos := 0
        Loop (out.Length - 2) {
            if (out[A_Index] = 0xC2 && out[A_Index + 1] = 0x46) {
                pos := A_Index
                break
            }
        }
        if (actif) {
            if (pos)
                out[pos + 2] := 0x01
            else
                out.InsertAt(out.Length, 0xC2, 0x46, 0x01)   ; avant le stop final
        } else if (pos) {
            out.RemoveAt(pos, 3)
        }
        return out
    }

    ;--------------------------------------------------------------------------
    ;  Remplace le varint qui suit un en-tete de champ de 2 octets.
    ;  Renvoie un NOUVEAU tableau, ou 0 si le champ est absent.
    ;--------------------------------------------------------------------------
    static ReplaceVarintAfter(inner, tag0, tag1, newVal) {
        pos := 0
        Loop (inner.Length - 2) {
            if (inner[A_Index] = tag0 && inner[A_Index + 1] = tag1) {
                pos := A_Index
                break
            }
        }
        if (!pos)
            return 0

        i := pos + 2
        NightLight.ReadVarint(inner, &i)      ; i pointe apres l'ancien varint

        out := []
        Loop (pos + 1)
            out.Push(inner[A_Index])
        for b in NightLight.WriteVarint(newVal)
            out.Push(b)
        Loop (inner.Length - i + 1)
            out.Push(inner[i + A_Index - 1])
        return out
    }

    ;--------------------------------------------------------------------------
    ;  Temperature de couleur (payload settings, champ 40, BT_INT16)
    ;--------------------------------------------------------------------------
    static GetTemp() {
        inner := NightLight.ParseEnvelope(NightLight.ReadBytes(NightLight.K_SETTINGS)).inner
        Loop (inner.Length - 2) {
            if (inner[A_Index] = 0xCF && inner[A_Index + 1] = 0x28) {
                i := A_Index + 2
                return NightLight.ZigzagDecode(NightLight.ReadVarint(inner, &i))
            }
        }
        return 0      ; champ absent : Windows n'a encore jamais ecrit de temperature
    }

    static SetTemp(kelvin) {
        kelvin := Max(NightLight.MIN_K, Min(NightLight.MAX_K, Round(kelvin)))
        env := NightLight.ParseEnvelope(NightLight.ReadBytes(NightLight.K_SETTINGS))

        inner := NightLight.ReplaceVarintAfter(env.inner, 0xCF, 0x28, NightLight.ZigzagEncode(kelvin))
        if (!inner)
            throw Error("champ temperature (CF 28) introuvable dans le payload")

        ts := NightLight.NextTs(env.ts)
        NightLight.WriteBytes(NightLight.K_SETTINGS, NightLight.BuildEnvelope(ts, inner))
        return kelvin
    }

    ;  Comme SetTemp, mais applique la couleur immediatement.
    ;
    ;  Ecrire la temperature seule ne fait que la memoriser : le moteur ne la
    ;  relit qu'a l'ouverture de session. On leve donc le drapeau de reglage en
    ;  cours (champ 70), ce qui declenche l'application sur-le-champ, puis on
    ;  le retire aussitot -- le laisser actif desynchronise le moteur.
    static SetTempLive(kelvin, pause := 150) {
        kelvin := Max(NightLight.MIN_K, Min(NightLight.MAX_K, Round(kelvin)))
        env := NightLight.ParseEnvelope(NightLight.ReadBytes(NightLight.K_SETTINGS))

        inner := NightLight.ReplaceVarintAfter(env.inner, 0xCF, 0x28, NightLight.ZigzagEncode(kelvin))
        if (!inner)
            throw Error("champ temperature (CF 28) introuvable dans le payload")

        ts := NightLight.NextTs(env.ts)
        NightLight.WriteBytes(NightLight.K_SETTINGS
                            , NightLight.BuildEnvelope(ts, NightLight.SetPreviewFlag(inner, true)))
        Sleep(pause)
        NightLight.WriteBytes(NightLight.K_SETTINGS
                            , NightLight.BuildEnvelope(ts + 1, NightLight.SetPreviewFlag(inner, false)))
        return kelvin
    }

    ;--------------------------------------------------------------------------
    ;  Mode de planification (payload settings, champ 0 BT_BOOL)
    ;    absent                     -> Off
    ;    present, champ 10 absent   -> coucher / lever du soleil
    ;    present, champ 10 present  -> horaires manuels
    ;--------------------------------------------------------------------------
    static ScheduleActive() {
        inner := NightLight.ParseEnvelope(NightLight.ReadBytes(NightLight.K_SETTINGS)).inner
        ; le champ 0 suit immediatement l'en-tete interne 43 42 01 00
        return (inner.Length >= 6 && inner[5] = 0x02 && inner[6] = 0x01)
    }

    ;--------------------------------------------------------------------------
    ;  Etat on / off (payload state)
    ;    43 42 01 00 [10 00] D0 0A 02 C6 14 <filetime> 00
    ;  La PRESENCE de "10 00" (champ 0) signifie force ON.
    ;--------------------------------------------------------------------------
    static IsEnabled() {
        inner := NightLight.ParseEnvelope(NightLight.ReadBytes(NightLight.K_STATE)).inner
        return (inner.Length >= 6 && inner[5] = 0x10 && inner[6] = 0x00)
    }

    static SetEnabled(on) {
        env := NightLight.ParseEnvelope(NightLight.ReadBytes(NightLight.K_STATE))
        inner := env.inner
        has := (inner.Length >= 6 && inner[5] = 0x10 && inner[6] = 0x00)

        if (on && !has)
            inner.InsertAt(5, 0x10, 0x00)
        else if (!on && has)
            inner.RemoveAt(5, 2)
        else
            return on          ; deja dans l'etat voulu, on n'ecrit rien

        ; horodatage de transition : champ 20, BT_UINT64, FILETIME
        stamped := NightLight.ReplaceVarintAfter(inner, 0xC6, 0x14, NightLight.NowFiletime())
        if (stamped)
            inner := stamped

        NightLight.WriteBytes(NightLight.K_STATE, NightLight.BuildEnvelope(NightLight.NextTs(env.ts), inner))
        return on
    }

    ;  Reecrit la cle d'etat a l'identique avec un horodatage frais.
    ;  Sert a pousser le service Night Light a relire ses reglages quand un
    ;  simple changement de temperature ne suffit pas a declencher le rendu.
    static Touch() {
        env := NightLight.ParseEnvelope(NightLight.ReadBytes(NightLight.K_STATE))
        inner := env.inner
        stamped := NightLight.ReplaceVarintAfter(inner, 0xC6, 0x14, NightLight.NowFiletime())
        if (stamped)
            inner := stamped
        NightLight.WriteBytes(NightLight.K_STATE, NightLight.BuildEnvelope(NightLight.NextTs(env.ts), inner))
    }

    ;  Eteint puis rallume : le seul declencheur connu qui force le service
    ;  Night Light a relire la temperature. Le delai doit etre assez long pour
    ;  que Windows traite reellement l'etat intermediaire ; trop court, les
    ;  deux ecritures se confondent et rien ne se passe.
    static Cycle(pause := 800) {
        etait := NightLight.IsEnabled()
        NightLight.SetEnabled(!etait)
        Sleep(pause)
        NightLight.SetEnabled(etait)
    }

    static On() {
        return NightLight.SetEnabled(true)
    }

    static Off() {
        return NightLight.SetEnabled(false)
    }
}
