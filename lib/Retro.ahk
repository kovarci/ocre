;==============================================================================
;  Retro.ahk -- le retroeclairage, quand le materiel veut bien.
;
;  Ocre assombrissait par la rampe gamma seule. Sur un portable c'est un bon
;  procede : il descend l'ecran SOUS le minimum du retroeclairage, ce que le
;  materiel ne sait pas faire. Sur un moniteur de bureau c'est le mauvais : le
;  retroeclairage reste a fond, on ne fait qu'ecraser les niveaux, le noir
;  cesse d'etre noir et le contraste s'effondre. Twinkle Tray et Monitorian
;  n'existent que pour cette raison.
;
;  Les deux se completent au lieu de se concurrencer, et c'est tout le propos
;  de ce fichier :
;
;      100 %  ......  le materiel a fond
;        |            on descend le retroeclairage
;      SEUIL  ......  le materiel a son plancher
;        |            la rampe gamma prend le relais
;        0 %  ......  aussi sombre que cette machine sait l'etre
;
;  Deux mecanismes selon l'ecran, et ils n'ont rien en commun :
;
;  - DDC/CI (dxva2.dll) parle au moniteur par le cable video. C'est le seul
;    moyen pour un ecran externe. C'est aussi lent -- de l'ordre de 50 ms par
;    ecriture -- d'ou le regroupement plus bas.
;
;  - WMI (root\WMI, WmiMonitorBrightnessMethods) pilote la dalle integree d'un
;    portable. C'est le meme chemin que le curseur de Windows, et donc le meme
;    reglage : ce qu'on ecrit ici, Windows l'affiche et le retient. La valeur
;    trouvee au demarrage est donc relevee et rendue en sortant, exactement
;    comme la rampe gamma.
;
;  Tout est sous try. Un moniteur sans DDC/CI, un pilote qui refuse, une
;  strategie d'entreprise qui ferme WMI : rien de tout cela ne doit empecher
;  le filtre de fonctionner. L'absence de retroeclairage pilotable ramene
;  simplement au comportement d'avant, la rampe pour tout.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Ecrans.ahk

class Retro {

    ;  En dessous de ce point du curseur, le materiel est a son plancher et
    ;  c'est la rampe qui continue. Au-dessus, la rampe reste neutre.
    static SEUIL := 25

    ;  Le plancher materiel n'est pas le minimum annonce mais un dixieme de la
    ;  course au-dessus. Ce n'est pas de la timidite : sur beaucoup de dalles
    ;  la valeur zero eteint franchement le retroeclairage, et un ecran noir
    ;  emporte avec lui la commande qui permettrait de remonter. Le dixieme
    ;  restant est rendu par la rampe, qui elle ne peut pas noircir tout a
    ;  fait.
    static MARGE := 0.10

    ;  Regroupement des ecritures, en millisecondes. Une ecriture DDC/CI coute
    ;  environ 50 ms et la molette en demanderait plusieurs dizaines par
    ;  seconde ; certains moniteurs Dell se figent quand on les martele. On ne
    ;  garde donc que la derniere valeur d'un geste.
    static DELAI := 120

    static etat := Map()      ; id d'ecran -> ce qu'on sait de lui
    static tic := 0
    static attente := Map()   ; id d'ecran -> valeur materielle en attente

    ;--------------------------------------------------------------------------
    ;  Ce que vaut le curseur, traduit pour un ecran donne.
    ;
    ;  Renvoie { materiel, gamma } : le pourcentage a poser sur le
    ;  retroeclairage -- ou -1 s'il n'y en a pas -- et le facteur a appliquer a
    ;  la rampe.
    ;
    ;  Sans retroeclairage pilotable, la rampe reprend toute la course : le bas
    ;  du curseur veut toujours dire "aussi sombre que possible", quelle que
    ;  soit la machine.
    ;--------------------------------------------------------------------------
    static Repartir(ecran, lum, plancherGamma) {
        lum := Max(0, Min(100, lum))

        if (!Retro.Pilotable(ecran)) {
            return { materiel: -1
                   , gamma: plancherGamma + (1 - plancherGamma) * lum / 100 }
        }

        if (lum >= Retro.SEUIL) {
            part := (lum - Retro.SEUIL) / (100 - Retro.SEUIL)
            return { materiel: Round(100 * part), gamma: 1.0 }
        }

        return { materiel: 0
               , gamma: plancherGamma + (1 - plancherGamma) * lum / Retro.SEUIL }
    }

    ;--------------------------------------------------------------------------
    ;  Cet ecran a-t-il un retroeclairage pilotable ?
    ;
    ;  La reponse est mise en cache : la sonde ouvre un moniteur physique et
    ;  interroge WMI, ce qui prend plusieurs dizaines de millisecondes -- bien
    ;  trop pour etre refait a chaque cran de molette.
    ;--------------------------------------------------------------------------
    static Pilotable(ecran) {
        return Retro._Etat(ecran).voie != ""
    }

    ;  Le niveau trouve a la premiere ouverture, par ecran, garde a part :
    ;  c'est lui que Rendre doit restituer. Les etats, eux, sont jetes a
    ;  chaque sortie de veille ou changement d'ecran (Oublier), et une
    ;  reouverture lisait alors comme "origine" le niveau qu'Ocre venait de
    ;  poser -- quitter ne rendait plus la luminosite qu'avait l'utilisateur.
    static origines := Map()

    static _Etat(ecran) {
        if (Retro.etat.Has(ecran.id))
            return Retro.etat[ecran.id]

        e := { voie: "", phys: 0, mini: 0, maxi: 100, origine: -1, posee: -1 }

        ;  DDC/CI d'abord : c'est le seul qui distingue deux ecrans externes.
        ;  WMI, lui, ne connait que la dalle integree et ne saurait pas de quel
        ;  ecran on parle.
        d := Retro._OuvrirDdc(ecran)
        if (d) {
            e := d
        } else if (Retro._WmiNiveau() >= 0) {
            ;  Un seul ecran peut passer par WMI, et c'est la dalle integree :
            ;  on la reconnait a son code materiel, le meme dans l'identifiant
            ;  du moniteur et dans le nom d'instance WMI. Sans ce test, un
            ;  externe sans DDC/CI place a gauche prenait le retroeclairage
            ;  du portable, qui n'en avait plus.
            if (!Retro._WmiPris() && Retro._WmiConvient(ecran)) {
                e := { voie: "wmi", phys: 0, mini: 0, maxi: 100
                     , origine: Retro._WmiNiveau(), posee: -1 }
            }
        }

        if (e.voie != "") {
            if (Retro.origines.Has(ecran.id))
                e.origine := Retro.origines[ecran.id]
            else if (e.origine >= 0)
                Retro.origines[ecran.id] := e.origine
        }

        Retro.etat[ecran.id] := e
        return e
    }

    ;  WMI est-il deja attribue a un autre ecran ?
    static _WmiPris() {
        for id, e in Retro.etat {
            if (e.voie = "wmi")
                return true
        }
        return false
    }

    ;  Cet ecran est-il celui que WMI pilote ? L'identifiant d'un moniteur
    ;  ressemble a MONITOR\SDC41B5\{...}\0001, le nom d'instance WMI a
    ;  DISPLAY\SDC41B5\4&2c6a8b6&0&UID8388688_0 : le deuxieme segment est le
    ;  code du materiel, lu dans l'EDID. Quand WMI ne dit pas le sien, on
    ;  s'en remet au premier venu, comme avant.
    static _WmiConvient(ecran) {
        codeWmi := Retro._CodeMateriel(Retro._WmiInstance())
        code := Retro._CodeMateriel(ecran.id)
        if (codeWmi = "" || code = "")
            return true                  ; l'un des deux ne se nomme pas : on ne peut pas exclure
        return code = codeWmi
    }

    static _CodeMateriel(chemin) {
        parts := StrSplit(chemin, "\")
        return (parts.Length >= 2 && RegExMatch(parts[2], "^[A-Za-z0-9]{3,8}$")) ? StrUpper(parts[2]) : ""
    }

    static _WmiInstance() {
        try {
            for m in Retro._Wmi().ExecQuery("SELECT InstanceName FROM WmiMonitorBrightness")
                return m.InstanceName
        } catch {
            Retro.wmi := 0
        }
        return ""
    }

    ;--------------------------------------------------------------------------
    ;  DDC/CI
    ;
    ;  PHYSICAL_MONITOR vaut 8 octets de handle suivis de 128 caracteres larges
    ;  de description, soit 264 octets en 64 bits. On n'en ouvre qu'un par
    ;  HMONITOR : un HMONITOR qui en porterait plusieurs designe un mur
    ;  d'ecrans clone, cas ou la question ne se pose pas.
    ;--------------------------------------------------------------------------
    static _OuvrirDdc(ecran) {
        if (!ecran.hmon)
            return 0
        try {
            if (!DllCall("dxva2\GetNumberOfPhysicalMonitorsFromHMONITOR"
                       , "ptr", ecran.hmon, "uint*", &n := 0) || n < 1)
                return 0

            tableau := Buffer(264 * n, 0)
            if (!DllCall("dxva2\GetPhysicalMonitorsFromHMONITOR"
                       , "ptr", ecran.hmon, "uint", n, "ptr", tableau))
                return 0

            phys := NumGet(tableau, 0, "ptr")

            ;  Les handles au-dela du premier ne servent pas : on les rend
            ;  tout de suite, sinon ils fuient a chaque reenumeration.
            Loop n - 1
                DllCall("dxva2\DestroyPhysicalMonitor", "ptr", NumGet(tableau, A_Index * 264, "ptr"))

            ;  Un moniteur peut s'ouvrir et n'avoir aucune table de luminosite
            ;  -- c'est le cas des dalles de portable vues par DDC/CI. La
            ;  lecture est donc la vraie sonde, pas l'ouverture.
            if (!DllCall("dxva2\GetMonitorBrightness", "ptr", phys
                       , "uint*", &mini := 0, "uint*", &cur := 0
                       , "uint*", &maxi := 0) || maxi <= mini) {
                DllCall("dxva2\DestroyPhysicalMonitor", "ptr", phys)
                return 0
            }

            return { voie: "ddc", phys: phys, mini: mini, maxi: maxi
                   , origine: cur, posee: -1 }
        }
        return 0
    }

    ;--------------------------------------------------------------------------
    ;  WMI : la dalle integree.
    ;
    ;  ComObjGet echoue si le service WMI est arrete ou si la machine n'a pas
    ;  de dalle pilotable -- un ordinateur de bureau, typiquement. La classe
    ;  n'existe alors pas, et l'enumeration ne rend rien.
    ;--------------------------------------------------------------------------
    ;  Le service WMI, garde d'un appel a l'autre : ComObjGet coute trois
    ;  fois la requete elle-meme, et le chien de garde relit la valeur
    ;  toutes les dix secondes (voir AdopterLuminosite). Un service tombe --
    ;  arrete entre-temps -- est oublie et redemande la fois suivante.
    static wmi := 0

    static _Wmi() {
        if (!Retro.wmi)
            Retro.wmi := ComObjGet("winmgmts:\\.\root\WMI")
        return Retro.wmi
    }

    static _WmiNiveau() {
        try {
            for m in Retro._Wmi().ExecQuery("SELECT CurrentBrightness FROM WmiMonitorBrightness")
                return m.CurrentBrightness
        } catch {
            Retro.wmi := 0
        }
        return -1
    }

    static _WmiPoser(niveau) {
        try {
            for m in Retro._Wmi().ExecQuery("SELECT * FROM WmiMonitorBrightnessMethods") {
                ;  Le premier argument est un delai en secondes accorde a la
                ;  transition. Zero demande l'application immediate.
                m.WmiSetBrightness(0, niveau)
                return true
            }
        } catch {
            Retro.wmi := 0
        }
        return false
    }

    ;--------------------------------------------------------------------------
    ;  Pose une valeur materielle, en differe.
    ;
    ;  Le minuteur repart a chaque appel : sous la molette, seule la derniere
    ;  valeur d'un geste atteint le moniteur. C'est ce qui rend le DDC/CI
    ;  utilisable au geste continu malgre ses 50 ms.
    ;--------------------------------------------------------------------------
    static Poser(ecran, pourcent) {
        if (pourcent < 0 || !Retro.Pilotable(ecran))
            return
        Retro.attente[ecran.id] := pourcent
        if (!Retro.tic)
            Retro.tic := () => Retro.Vider()
        SetTimer(Retro.tic, -Retro.DELAI)
    }

    static Vider() {
        if (Retro.tic)
            SetTimer(Retro.tic, 0)
        if (!Retro.attente.Count)
            return

        for id, pourcent in Retro.attente.Clone() {
            e := Retro.etat.Has(id) ? Retro.etat[id] : 0
            if (!e || e.voie = "")
                continue
            Retro._Ecrire(e, pourcent)
        }
        Retro.attente := Map()
    }

    ;  pourcent va de 0 a 100 sur la course utile, laquelle s'arrete une marge
    ;  au-dessus du minimum annonce -- voir MARGE.
    static _Ecrire(e, pourcent) {
        pourcent := Max(0, Min(100, pourcent))
        try {
            if (e.voie = "ddc") {
                course := e.maxi - e.mini
                bas := e.mini + course * Retro.MARGE
                brut := Round(bas + (e.maxi - bas) * pourcent / 100)
                DllCall("dxva2\SetMonitorBrightness", "ptr", e.phys, "uint", brut)
                e.posee := brut
            } else if (e.voie = "wmi") {
                bas := 100 * Retro.MARGE
                brut := Round(bas + (100 - bas) * pourcent / 100)
                Retro._WmiPoser(brut)
                e.posee := brut
            }
        }
    }

    ;--------------------------------------------------------------------------
    ;  Quelqu'un d'autre a-t-il touche au retroeclairage ?
    ;
    ;  Les touches Fn du portable, le curseur de Windows, Twinkle Tray :
    ;  tous ecrivent la meme valeur qu'Ocre. Ocre la relit et compare a ce
    ;  qu'il a pose lui-meme en dernier. Deux consequences :
    ;
    ;  - a la sortie, Ocre ne rend la valeur d'origine QUE si c'est encore la
    ;    sienne qui est en place. Rendre la valeur du matin par-dessus un
    ;    reglage fait a la main dans la journee etait une surprise.
    ;
    ;  - en cours de route, le chien de garde ADOPTE le changement : la
    ;    luminosite d'Ocre se recale sur ce que les touches Fn ont pose, au
    ;    lieu de le reecraser au geste suivant. Le curseur de Windows et
    ;    celui d'Ocre disent alors la meme chose.
    ;
    ;  La tolerance de deux unites absorbe les moniteurs qui arrondissent ce
    ;  qu'on leur ecrit -- sans elle, une valeur relue a 58 pour 57 ecrit
    ;  passerait pour un reglage exterieur, serait adoptee, reecrite,
    ;  relue... sans fin.
    ;--------------------------------------------------------------------------
    static TOLERANCE := 2

    static _Lire(e) {
        try {
            if (e.voie = "ddc") {
                if (DllCall("dxva2\GetMonitorBrightness", "ptr", e.phys
                          , "uint*", &mini := 0, "uint*", &cur := 0, "uint*", &maxi := 0))
                    return cur
            } else if (e.voie = "wmi") {
                return Retro._WmiNiveau()
            }
        }
        return -1
    }

    static _Bouge(e) {
        if (e.posee < 0)
            return false
        cur := Retro._Lire(e)
        return cur >= 0 && Abs(cur - e.posee) > Retro.TOLERANCE
    }

    ;  Une valeur brute du moniteur, ramenee sur le curseur d'Ocre : la course
    ;  utile va d'une marge au-dessus du minimum jusqu'au maximum, et
    ;  correspond a la partie du curseur au-dessus de SEUIL. En dessous de la
    ;  marge, on ne peut rien dire de plus que "au plancher".
    static _EnPourcent(e, brut) {
        course := e.maxi - e.mini
        bas := e.mini + course * Retro.MARGE
        if (brut <= bas)
            return Retro.SEUIL
        part := (brut - bas) / (e.maxi - bas)
        return Round(Retro.SEUIL + (100 - Retro.SEUIL) * Max(0, Min(1, part)))
    }

    ;  Les ecrans dont le retroeclairage a ete change ailleurs, avec la
    ;  luminosite d'Ocre qui y correspond : [{ id, pourcent }]. L'appelant
    ;  la pose comme si elle venait du curseur ; la valeur adoptee devient la
    ;  notre, pour ne pas etre adoptee deux fois.
    static Adopter() {
        changes := []
        for id, e in Retro.etat {
            if (e.voie = "" || e.posee < 0)
                continue
            cur := Retro._Lire(e)
            if (cur < 0 || Abs(cur - e.posee) <= Retro.TOLERANCE)
                continue
            e.posee := cur
            ;  Un niveau choisi a la main devient aussi celui qu'on rendra
            ;  en quittant : c'est le sien, pas celui qu'on avait trouve.
            e.origine := cur
            Retro.origines[id] := cur
            changes.Push({ id: id, pourcent: Retro._EnPourcent(e, cur) })
        }
        return changes
    }

    ;--------------------------------------------------------------------------
    ;  Rend a chaque ecran la luminosite qu'il avait, et referme.
    ;
    ;  Le pendant de Gamma.Reset. Pour WMI c'est plus qu'une politesse : le
    ;  reglage est celui de Windows, il persiste, et le laisser au fond
    ;  laisserait quelqu'un devant un ecran sombre sans savoir pourquoi.
    ;--------------------------------------------------------------------------
    ;  Sauf si ce n'est plus la notre : une valeur posee entre-temps par les
    ;  touches Fn ou le curseur de Windows reste en place (voir Adopter).
    static Rendre() {
        Retro.Vider()
        for id, e in Retro.etat {
            try {
                rendre := (e.origine >= 0 && e.posee >= 0 && !Retro._Bouge(e))
                if (e.voie = "ddc") {
                    if (rendre)
                        DllCall("dxva2\SetMonitorBrightness", "ptr", e.phys
                              , "uint", e.origine)
                    DllCall("dxva2\DestroyPhysicalMonitor", "ptr", e.phys)
                } else if (e.voie = "wmi" && rendre) {
                    Retro._WmiPoser(e.origine)
                }
            }
        }
        Retro.etat := Map()
        Retro.origines := Map()
    }

    ;  Les moniteurs physiques ouverts ne valent plus rien apres un
    ;  debranchement : on referme sans rien rendre, l'ecran n'etant plus la.
    static Oublier() {
        for id, e in Retro.etat {
            try {
                if (e.voie = "ddc")
                    DllCall("dxva2\DestroyPhysicalMonitor", "ptr", e.phys)
            }
        }
        Retro.etat := Map()
        Retro.attente := Map()
    }
}
