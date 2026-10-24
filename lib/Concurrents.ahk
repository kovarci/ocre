;==============================================================================
;  Concurrents.ahk -- les deux filtres de Windows qui se cumuleraient au notre.
;
;  L'eclairage nocturne (Night Light) teinte l'ecran comme Ocre ; le filtre
;  de couleur (Accessibilite) le passe en gris ou en daltonien. Aucun des
;  deux n'est pilote ici -- le README dit pourquoi -- mais les deux doivent
;  etre VUS : un ecran deux fois rechauffe, ou gris des qu'Ocre se coupe,
;  passe pour un defaut d'Ocre. La fenetre des reglages l'annonce en rouge.
;
;  Tout est en lecture, tout est sous try : une cle absente ou un format
;  inattendu vaut "pas actif", jamais une erreur.
;
;  Un mot de prudence sur le Night Light. Son etat marche/arret vit dans une
;  valeur binaire CloudStore relue a l'ouverture de session ; depuis 25H2,
;  Windows ne la reecrit plus quand on l'allume ou l'eteint a la main (voir
;  README). Mesure sur la machine de developpement : la cle disait "force
;  ON" avec l'horodatage du jour des essais de nlctl, deux jours plus tot, et
;  l'ecran n'etait pas teinte. Cette cle-la ne dit donc rien du present, et
;  on ne la lit pas.
;
;  La cle des REGLAGES, elle, est bien tenue a jour par les Parametres : le
;  curseur de temperature y suit, et le drapeau "horaire programme" avec. Un
;  horaire programme est ce qui merite d'etre signale -- le Night Light
;  s'allumera de lui-meme ce soir, par-dessus Ocre -- et c'est la seule
;  chose qu'on sache lire. Un Night Light allume a la main sans horaire
;  passe sous le radar ; c'est le prix de ne pas crier faux.
;==============================================================================

#Requires AutoHotkey v2.0

class Concurrents {

    static K_REGL := "HKCU\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default$windows.data.bluelightreduction.settings\windows.data.bluelightreduction.settings"

    ;  Les autres programmes du meme genre, par nom de processus. f.lux, Iris
    ;  ou LightBulb posent leur propre rampe ; Twinkle Tray se dispute le
    ;  retroeclairage. Deux programmes qui ecrivent la meme rampe se battent,
    ;  et c'est le conflit le plus probable chez quelqu'un qui essaie Ocre en
    ;  gardant l'ancien.
    static CONNUS := [["flux.exe", "f.lux"], ["Iris.exe", "Iris"], ["IrisMini.exe", "Iris mini"]
                        , ["LightBulb.exe", "LightBulb"], ["Twinkle Tray.exe", "Twinkle Tray"]
                        , ["SunsetScreen.exe", "SunsetScreen"], ["CareUEyes.exe", "CareUEyes"]
                        , ["redshift.exe", "Redshift"], ["RedshiftGUI.exe", "RedshiftGUI"]]

    ;  Les noms de ceux qui tournent, "f.lux, Iris" ou "".
    static Programmes() {
        noms := ""
        for p in Concurrents.CONNUS {
            try {
                if (ProcessExist(p[1]))
                    noms .= (noms != "" ? ", " : "") . p[2]
            }
        }
        return noms
    }

    ;  Le filtre de couleur de Windows : Accessibilite > Filtres de couleur.
    ;  Une seule valeur, relue a chaud par Windows, donc fiable.
    static FiltreCouleur() {
        try return RegRead("HKCU\Software\Microsoft\ColorFiltering", "Active") = 1
        return false
    }

    ;  L'eclairage nocturne : un horaire est-il programme ? Champ 0 de la
    ;  charge utile des reglages (BT_BOOL, octets 02 01), solaire ou manuel.
    static NightLight() {
        try {
            regl := Concurrents._Charge(Concurrents.K_REGL)
            return (regl.Length >= 6 && regl[5] = 0x02 && regl[6] = 0x01)
        }
        return false
    }

    ;--------------------------------------------------------------------------
    ;  La charge utile d'une valeur CloudStore, sous forme de tableau
    ;  d'octets. L'enveloppe est :
    ;
    ;    43 42 01 00 | 0A 02 01 00 | 2A 06 <varint horodatage>
    ;               | 2A 2B 0E <varint n> | <n octets>
    ;
    ;  Le format complet, et son codec, sont dans recherche/NightLight.ahk.
    ;  On ne recopie ici que ce qu'il faut pour lire deux octets.
    ;--------------------------------------------------------------------------
    static _Charge(cle) {
        hex := RegExReplace(RegRead(cle, "Data"), "[^0-9A-Fa-f]", "")
        buf := []
        Loop (StrLen(hex) // 2)
            buf.Push(Integer("0x" . SubStr(hex, (A_Index - 1) * 2 + 1, 2)))

        if (buf.Length < 12 || buf[1] != 0x43 || buf[2] != 0x42 || buf[9] != 0x2A)
            throw Error("enveloppe CloudStore inattendue")

        i := 11
        Concurrents._Varint(buf, &i)             ; horodatage, ignore
        if (buf[i] != 0x2A || buf[i + 1] != 0x2B || buf[i + 2] != 0x0E)
            throw Error("enveloppe CloudStore inattendue")
        i += 3
        n := Concurrents._Varint(buf, &i)

        charge := []
        Loop Min(n, buf.Length - i + 1)
            charge.Push(buf[i + A_Index - 1])
        return charge
    }

    static _Varint(buf, &i) {
        val := 0, dec := 0
        Loop {
            if (i > buf.Length || dec > 63)
                throw Error("varint tronque")
            b := buf[i], i += 1
            val |= (b & 0x7F) << dec
            if !(b & 0x80)
                break
            dec += 7
        }
        return val
    }
}
