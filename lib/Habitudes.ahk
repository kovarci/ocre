;==============================================================================
;  Habitudes.ahk -- apprendre ce qu'on regle a la main, et le faire soi-meme.
;
;  Quelqu'un qui remonte la luminosite tous les soirs apres le coucher du
;  soleil, ou qui baisse le filtre des qu'un film passe en plein ecran, le
;  fait a la main des dizaines de fois avant de penser a un horaire. Ce
;  module regarde ces gestes, retient dans quelles circonstances ils menent
;  a quelle valeur, et quand une circonstance a ete confirmee assez de fois,
;  pose la valeur lui-meme, en fondu -- puis continue d'apprendre.
;
;  C'est un petit modele, pas une liste de regles, et chaque piece a une
;  raison :
;
;  1. La DECANTATION. Un geste n'est pas une observation. Quelqu'un qui
;     montre l'outil a un ami et fait monter et descendre le filtre comme un
;     fou pendant cinq minutes a fait cinquante gestes et zero choix. On
;     n'observe que la valeur ou la main s'ARRETE : deux minutes sans
;     nouveau geste, et c'est celle-la qui compte, une seule fois.
;
;  2. La MEDIANE, pas la moyenne. Une observation aberrante -- le jour de la
;     demonstration, on a laisse le filtre a 100 % -- tirerait une moyenne
;     de vingt points pendant des semaines. Une mediane ne bouge pas tant
;     qu'une minorite dit autre chose.
;
;  3. Le TEMPS SOLAIRE. Une habitude du soir est "une heure apres le
;     coucher", pas "21 h" : en decembre le soleil se couche a 17 h et
;     l'habitude horaire arriverait quatre heures trop tard, et le
;     changement d'heure decalerait tout d'un coup. Autour du coucher et du
;     lever, les gestes se comparent en minutes par rapport au soleil ; au
;     milieu du jour et de la nuit, a l'horloge. Sans lieu connu, tout est
;     a l'horloge.
;
;  4. Le NOYAU. Pas de grille : deux gestes se ressemblent d'autant plus
;     qu'ils sont proches, une gaussienne de vingt-cinq minutes d'ecart-type,
;     nulle au-dela de soixante-quinze. 21 h 29 et 21 h 31 sont le meme
;     geste ; 21 h et 22 h n'ont presque rien a se dire.
;
;  5. L'OUBLI, a deux vitesses. Une observation perd la moitie de son poids
;     tous les trente jours et disparait a soixante : l'hiver ne dicte pas
;     l'ete. Mais une memoire lente est lente a admettre un changement :
;     les quatre observations les plus recentes forment une memoire courte,
;     et si elles sont d'accord entre elles et en desaccord avec la longue,
;     c'est qu'une habitude a change -- la courte l'emporte, en trois
;     soirs, sans que la longue perde sa robustesse contre les aberrants.
;
;  6. La CONFIANCE. On n'agit que si le poids des observations atteint 2,5
;     -- trois gestes recents au bon moment -- ET si elles sont d'accord :
;     six dixiemes du poids a dix points ou moins de la mediane. Tantot 30,
;     tantot 80, ce n'est pas une habitude, c'est une hesitation, et l'on
;     se tait. En dessous de la confiance mais au-dessus d'un poids de 1,2
;     -- deux soirs concordants --, on PROPOSE : une pastille "80 comme
;     hier ?" qu'un clic accepte, et qui compte alors pour un geste.
;
;  7. La CORRECTION et l'APPROBATION. Un geste dans les dix minutes qui
;     suivent une pose automatique est un desaveu : l'observation pese
;     double. Trente minutes sans geste, MAIS avec quelqu'un devant l'ecran
;     -- une pose que personne n'a vue ne dit rien --, c'est une
;     approbation : la valeur posee devient une observation implicite a
;     demi-poids, la premiere a ceder la place quand on manque de place.
;     Sans cela, le modele tuait les habitudes qu'il reussissait a
;     automatiser : plus de geste, plus d'observation, et l'oubli faisait
;     le reste.
;
;  8. Les RESIDUS. Quand un automate tient la voie -- le planificateur pour
;     l'intensite, le suivi du contenu pour la luminosite --, on n'apprend
;     pas la valeur mais l'ECART a ce que l'automate donnait : "a cette
;     heure, toujours quinze de plus que le soleil". L'ecart appris devient
;     un decalage que l'automate applique lui-meme (voir Decalage) : il
;     reste maitre, l'habitude le corrige. L'assombrissement d'inactivite et
;     la baisse sur batterie, eux, sont des etats passagers : on n'y apprend
;     rien et l'on n'y pose rien.
;
;  9. La RETENUE. Rien dans le quart d'heure qui suit un geste, rien tant
;     qu'un geste decante, rien tant que la cible n'a pas bouge depuis le
;     dernier geste -- une correction suspend l'habitude, comme un reglage
;     a la main suspend le planificateur, et pas au-dela du jour.
;
;  10. Le CONTEXTE. Chaque observation retient l'application au premier
;     plan et si elle est en plein ecran : "quand le lecteur video est en
;     plein ecran, luminosite 40" vaut a toute heure. Un contexte qui a ses
;     propres observations, assez nombreuses et d'accord, l'emporte sur
;     l'heure tant qu'il est devant. Le week-end aussi est un contexte :
;     quand un moment a assez d'observations du meme genre de jour, il
;     n'ecoute qu'elles.
;
;  11. La RAMPE. Entre deux moments surs a des valeurs differentes -- 80 a
;     21 h, 60 a 23 h --, la valeur glisse de l'un a l'autre au lieu de
;     tomber par marches, comme le fait le planificateur solaire.
;
;  12. Le JOURNAL. Chaque observation, pose, proposition, approbation est
;     ecrite dans habitudes.log : un automate qu'on peut relire apres coup,
;     on le laisse allume.
;
;  Les observations vivent dans habitudes.ini, a cote d'ocre.ini : une
;  section par voie, une cle par observation, "valeur@date@weekend@poids@
;  minute@contexte@implicite@base@lever@coucher". Lisible, et effacable a
;  la main.
;
;  L'horloge, le soleil, la presence et l'application au premier plan sont
;  injectables : les tests jouent des mois entiers en quelques millisecondes.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Config.ahk

class Habitudes {

    static SILENCE := 120000       ; ms sans geste avant qu'une valeur compte
    static GARDE := 15             ; minutes apres un geste avant d'oser poser
    static CORRECTION := 10        ; minutes : un geste apres une pose est une correction
    static APPROBATION := 30       ; minutes de silence (et de presence) apres une pose : approuvee
    static MINIMUM := 2.5          ; poids d'observations pour agir
    static PROPOSITION := 1.2      ; poids pour proposer
    static TOLERANCE := 10         ; points : a cette distance de la mediane, on est d'accord
    static ACCORD := 0.6           ; part du poids qui doit etre d'accord
    static SEUIL := 4              ; ecart avec la valeur courante pour bouger
    static SIGMA := 25             ; minutes : l'ecart-type du noyau
    static PORTEE_NOYAU := 75      ; minutes : au-dela, une observation ne compte pas
    static JOURS := 60             ; au-dela, une observation est oubliee
    static DEMI_VIE := 30          ; jours : le poids est divise par deux
    static COURTE := 4             ; observations de la memoire courte
    static MAXIMUM := 400          ; observations gardees par voie
    static PORTEE_RAMPE := 360     ; minutes : jusqu'ou une rampe regarde
    static PAS_RAMPE := 10         ; minutes : le pas de la recherche d'une rampe
    static COUCHER_AVANT := 120    ; la zone du coucher : de deux heures avant...
    static COUCHER_APRES := 300    ; ... a cinq heures apres
    static LEVER_AVANT := 120
    static LEVER_APRES := 240
    static PERIODE := 30000        ; ms entre deux tours
    static VOIES := ["intensite", "luminosite"]
    static CRENEAUX := 48          ; les demi-heures de la fenetre (le modele, lui, n'a pas de grille)

    static actif := false
    static obs := Map()            ; voie -> [ { v, date, we, poids, minutes, app, implicite, brute, lever, coucher } ]
    static attente := Map()        ; voie -> { v, tick, poids, app, brute }, le geste qui decante
    static dernierGeste := Map()   ; voie -> tick
    static dernierePose := Map()   ; voie -> { tick, valeur, date, minutes, we, app, brute, vu, confirme }
    static suspendu := Map()       ; voie -> { valeur, date }
    static proposes := Map()       ; voie -> "date:valeur" deja propose
    static decalages := Map()      ; voie -> l'ecart appris, pour l'automate
    static tic := 0
    static poser := 0              ; (voie, valeur, cible) => ...
    static lire := 0               ; (voie) => valeur courante
    static automate := 0           ; (voie) => la valeur brute de l'automate qui tient la voie, ou ""
    static bloque := 0             ; (voie) => bool : etat passager, on ne fait rien
    static contexte := 0           ; () => "app.exe" ou "app.exe+" (plein ecran), ou ""
    static proposer := 0           ; (voie, valeur, cible, accepter) => ...
    static journal := 0            ; (texte) => ...
    static presence := 0           ; () => bool : quelqu'un est devant l'ecran
    static soleil := 0             ; (date) => { lever, coucher } en minutes, ou 0
    static horloge := 0            ; () => { tick, minutes, date, we }, injectable
    static sale := false           ; a ecrire

    static Init(poser, lire, automate := 0, bloque := 0, contexte := 0, proposer := 0, journal := 0) {
        Habitudes.poser := poser
        Habitudes.lire := lire
        Habitudes.automate := automate
        Habitudes.bloque := bloque
        Habitudes.contexte := contexte
        Habitudes.proposer := proposer
        Habitudes.journal := journal
        Habitudes.Charger()
        Habitudes.Relire()
    }

    static Relire() {
        if (Habitudes.tic)
            SetTimer(Habitudes.tic, 0)
        Habitudes.tic := 0
        Habitudes.actif := (Config.Lire("habitudes") = "1")
        if (!Habitudes.actif) {
            Habitudes.decalages := Map()
            return
        }
        Habitudes.tic := () => Habitudes._Battre()
        SetTimer(Habitudes.tic, Habitudes.PERIODE)
    }

    ;--------------------------------------------------------------------------
    ;  L'heure qu'il est : tick (ms), minutes depuis minuit, date AAAAMMJJ,
    ;  week-end, et le soleil du jour (lever, coucher, ou ""). Remplacable.
    ;--------------------------------------------------------------------------
    static Maintenant() {
        m := Habitudes.horloge ? (Habitudes.horloge)()
            : { tick: A_TickCount, minutes: A_Hour * 60 + A_Min
              , date: A_YYYY . A_MM . A_DD, we: (A_WDay = 1 || A_WDay = 7) ? 1 : 0 }
        return Habitudes._Complet(m)
    }

    ;  Un instant complet : une copie, avec le soleil du jour s'il manque.
    ;  Une copie, pour ne jamais ecrire dans l'objet qu'on nous a donne.
    static _Complet(m) {
        c := { tick: m.HasProp("tick") ? m.tick : 0, minutes: m.minutes, date: m.date
             , we: m.HasProp("we") && m.we ? 1 : 0
             , lever: m.HasProp("lever") ? m.lever : "", coucher: m.HasProp("coucher") ? m.coucher : "" }
        if (!m.HasProp("lever")) {
            s := Habitudes._Soleil(m.date)
            c.lever := s ? s.lever : "", c.coucher := s ? s.coucher : ""
        }
        return c
    }

    static _Soleil(date) {
        if (!Habitudes.soleil)
            return 0
        try {
            s := (Habitudes.soleil)(date)
            if (s && IsNumber(s.lever) && IsNumber(s.coucher))
                return s
        }
        return 0
    }

    ;  La demi-heure d'une minute, pour la fenetre et son detail.
    static Creneau(minutes) {
        return Mod(Mod(minutes, 1440) + 1440, 1440) // 30
    }

    static Application() {
        if (!Habitudes.contexte)
            return ""
        try return StrLower((Habitudes.contexte)())
        return ""
    }

    static _Present() {
        if (!Habitudes.presence)
            return true
        try return (Habitudes.presence)() ? true : false
        return true
    }

    static _Automate(voie) {
        if (!Habitudes.automate)
            return ""
        try {
            b := (Habitudes.automate)(voie)
            return IsNumber(b) ? Round(b) : ""
        }
        return ""
    }

    static _Bloque(voie) {
        if (!Habitudes.bloque)
            return false
        try return (Habitudes.bloque)(voie) ? true : false
        return false
    }

    static _Journal(texte) {
        if (Habitudes.journal)
            try (Habitudes.journal)(texte)
    }

    ;--------------------------------------------------------------------------
    ;  Un geste a la main vient de mener a "v". Rien n'est retenu tout de
    ;  suite : la valeur decante (voir _Battre). Un geste dans les dix
    ;  minutes qui suivent une pose est une correction ; tout geste suspend
    ;  l'habitude jusqu'a ce que sa cible change.
    ;--------------------------------------------------------------------------
    static Noter(voie, v) {
        if (!Habitudes.actif)
            return
        m := Habitudes.Maintenant()
        app := Habitudes.Application()
        poids := 1
        brute := ""
        if (Habitudes.attente.Has(voie)) {
            poids := Habitudes.attente[voie].poids
            brute := Habitudes.attente[voie].brute
        } else {
            brute := Habitudes._Automate(voie)
            cible := Habitudes.Cible(voie, m, app)
            if (cible.confiant)
                Habitudes.suspendu[voie] := { valeur: cible.valeur, date: m.date }
        }
        if (Habitudes.dernierePose.Has(voie)
            && m.tick - Habitudes.dernierePose[voie].tick < Habitudes.CORRECTION * 60000)
            poids := 2
        Habitudes.attente[voie] := { v: Round(v), tick: m.tick, poids: poids, app: app, brute: brute }
        Habitudes.dernierGeste[voie] := m.tick
    }

    ;  Un tour : ce qui a fini de decanter devient observation, une pose
    ;  restee sans reponse devant quelqu'un devient approbation, puis chaque
    ;  voie est comparee a ce que le modele attend.
    static _Battre() {
        m := Habitudes.Maintenant()
        app := Habitudes.Application()
        present := Habitudes._Present()
        for voie in Habitudes.VOIES {
            Habitudes._Decanter(voie, m)
            Habitudes._Approuver(voie, m, present)
            Habitudes._Poser(voie, m, app)
        }
        if (Habitudes.sale)
            Habitudes.Enregistrer()
    }

    static _Decanter(voie, m, force := false) {
        if (!Habitudes.attente.Has(voie))
            return
        a := Habitudes.attente[voie]
        if (!force && m.tick - a.tick < Habitudes.SILENCE)
            return
        Habitudes.attente.Delete(voie)
        if (Habitudes._Bloque(voie))
            return                                   ; un etat passager tenait la voie
        Habitudes.Observer(voie, a.v, m, a.poids, a.app, 0, a.brute)
    }

    ;  Une pose que rien n'a contredite pendant trente minutes, devant
    ;  quelqu'un : la valeur posee devient une observation implicite.
    static _Approuver(voie, m, present) {
        if (!Habitudes.dernierePose.Has(voie))
            return
        p := Habitudes.dernierePose[voie]
        if (p.confirme)
            return
        if (present)
            p.vu := true
        if (m.tick - p.tick < Habitudes.APPROBATION * 60000)
            return
        p.confirme := true
        if (Habitudes.dernierGeste.Has(voie) && Habitudes.dernierGeste[voie] >= p.tick)
            return                                   ; corrigee : pas une approbation
        if (!p.vu) {
            Habitudes._Journal(voie . " : pose " . p.valeur . " restee sans temoin, pas d'approbation")
            return
        }
        mp := { minutes: p.minutes, date: p.date, we: p.we, lever: m.lever, coucher: m.coucher }
        Habitudes.Observer(voie, p.valeur, mp, 0.5, p.app, 1, p.brute)
    }

    ;--------------------------------------------------------------------------
    ;  Une observation de plus. base est la valeur de l'automate au moment
    ;  du geste ("" si aucun) : l'observation retient alors l'ecart.
    ;--------------------------------------------------------------------------
    static Observer(voie, v, m := 0, poids := 1, app := "", implicite := 0, brute := "") {
        m := m ? Habitudes._Complet(m) : Habitudes.Maintenant()
        if (!Habitudes.obs.Has(voie))
            Habitudes.obs[voie] := []
        liste := Habitudes.obs[voie]
        o := { v: Round(v), date: m.date, we: m.we, poids: poids, minutes: m.minutes
             , app: app, implicite: implicite ? 1 : 0, brute: brute, lever: m.lever, coucher: m.coucher }
        liste.Push(o)
        while (liste.Length > Habitudes.MAXIMUM) {
            retire := 1
            for i, x in liste {
                if (x.implicite) {
                    retire := i
                    break
                }
            }
            liste.RemoveAt(retire)
        }
        Habitudes.sale := true
        Habitudes._Journal(Format("{} : observe {}{} a {} ({}{}{}{})", voie, o.v
            , brute != "" ? " (ecart " . (o.v - brute) . " sur " . brute . ")" : ""
            , Habitudes._Hhmm(m.minutes), m.date
            , app != "" ? ", " . app : "", poids >= 2 ? ", correction" : "", implicite ? ", approbation" : ""))
    }

    ;--------------------------------------------------------------------------
    ;  La distance en minutes entre une observation et un instant, dans la
    ;  coordonnee qui convient : le coucher, le lever, ou l'horloge.
    ;--------------------------------------------------------------------------
    static _Distance(o, m) {
        if (m.coucher != "" && o.coucher != ""
            && Habitudes._Dans(m.minutes, m.coucher, Habitudes.COUCHER_AVANT, Habitudes.COUCHER_APRES))
            return Habitudes._Circ((m.minutes - m.coucher) - (o.minutes - o.coucher))
        if (m.lever != "" && o.lever != ""
            && Habitudes._Dans(m.minutes, m.lever, Habitudes.LEVER_AVANT, Habitudes.LEVER_APRES))
            return Habitudes._Circ((m.minutes - m.lever) - (o.minutes - o.lever))
        return Habitudes._Circ(m.minutes - o.minutes)
    }

    static _Dans(minutes, repere, avant, apres) {
        d := Habitudes._Circ(minutes - repere)
        return d >= -avant && d <= apres
    }

    ;  Un ecart de minutes ramene dans [-720, 720).
    static _Circ(d) {
        return Mod(Mod(d + 720, 1440) + 1440, 1440) - 720
    }

    static _Noyau(d) {
        if (Abs(d) > Habitudes.PORTEE_NOYAU)
            return 0
        return Exp(-0.5 * (d / Habitudes.SIGMA) ** 2)
    }

    ;--------------------------------------------------------------------------
    ;  Les points qui comptent pour un instant : chaque observation du bon
    ;  regime (absolue, ou ecart a l'automate), pesant son poids propre, fois
    ;  le noyau, fois l'oubli. Le meme genre de jour d'abord, s'il suffit.
    ;--------------------------------------------------------------------------
    static _Points(voie, m, regime) {
        if (!Habitudes.obs.Has(voie))
            return []
        tous := [], memes := []
        for o in Habitudes.obs[voie] {
            if ((o.brute != "") != (regime != ""))
                continue
            age := Habitudes._Jours(o.date, m.date)
            if (age > Habitudes.JOURS || age < 0)
                continue
            k := Habitudes._Noyau(Habitudes._Distance(o, m))
            if (!k)
                continue
            w := o.poids * k * (0.5 ** (age / Habitudes.DEMI_VIE))
            p := { v: regime != "" ? o.v - o.brute : o.v, w: w, date: o.date }
            tous.Push(p)
            if (o.we = m.we)
                memes.Push(p)
        }
        somme := 0
        for p in memes
            somme += p.w
        return somme >= Habitudes.MINIMUM ? memes : tous
    }

    ;  Les points d'un contexte (application), toutes heures confondues.
    static _PointsApp(voie, app, m, regime) {
        points := []
        if (app = "" || !Habitudes.obs.Has(voie))
            return points
        for o in Habitudes.obs[voie] {
            if (o.app != app || (o.brute != "") != (regime != ""))
                continue
            age := Habitudes._Jours(o.date, m.date)
            if (age > Habitudes.JOURS || age < 0)
                continue
            points.Push({ v: regime != "" ? o.v - o.brute : o.v
                        , w: o.poids * (0.5 ** (age / Habitudes.DEMI_VIE)), date: o.date })
        }
        return points
    }

    ;--------------------------------------------------------------------------
    ;  Ce que disent des points : { valeur, poids, accord, confiant,
    ;  proposable, bascule }. La memoire longue est la mediane ponderee de
    ;  tous ; la courte, celle des quatre plus recents. Si la courte est
    ;  d'accord avec elle-meme et en desaccord avec la longue, l'habitude a
    ;  change et la courte l'emporte.
    ;--------------------------------------------------------------------------
    static _Resumer(points) {
        vide := { valeur: 0, poids: 0, accord: 0, confiant: false, proposable: false, bascule: false }
        if (!points.Length)
            return vide
        valeur := Habitudes._MedianePonderee(points)
        total := 0
        for p in points
            total += p.w
        if (total <= 0)
            return vide                      ; rien qui pese : rien a dire, et pas de division par zero
        bascule := false
        if (points.Length >= 3) {
            recents := Habitudes._Recents(points, Habitudes.COURTE)
            vr := Habitudes._MedianePonderee(recents)
            wr := 0, dr := 0
            for p in recents {
                wr += p.w
                if (Abs(p.v - vr) <= Habitudes.TOLERANCE)
                    dr += p.w
            }
            if (recents.Length >= 3 && dr / wr >= 0.75 && Abs(vr - valeur) > Habitudes.TOLERANCE) {
                valeur := vr
                bascule := true
            }
        }
        proches := 0
        for p in points {
            if (Abs(p.v - valeur) <= Habitudes.TOLERANCE)
                proches += p.w
        }
        accord := bascule ? 1.0 : proches / total
        return { valeur: Round(valeur), poids: total, accord: accord
               , confiant: total >= Habitudes.MINIMUM && accord >= Habitudes.ACCORD
               , proposable: total >= Habitudes.PROPOSITION && accord >= Habitudes.ACCORD
               , bascule: bascule }
    }

    ;  Les n points les plus recents (par date), parmi ceux qui pesent.
    static _Recents(points, n) {
        tries := []
        for p in points {
            if (p.w >= 0.15)
                tries.Push(p)
        }
        Loop tries.Length - 1 {
            i := A_Index + 1
            p := tries[i]
            j := i - 1
            while (j >= 1 && tries[j].date < p.date) {
                tries[j + 1] := tries[j]
                j -= 1
            }
            tries[j + 1] := p
        }
        r := []
        Loop Min(n, tries.Length)
            r.Push(tries[A_Index])
        return r
    }

    ;  La mediane ponderee : on trie, on cumule, on s'arrete a la moitie.
    static _MedianePonderee(points) {
        if (!points.Length)
            return 0
        tries := points.Clone()
        Loop tries.Length - 1 {
            i := A_Index + 1
            p := tries[i]
            j := i - 1
            while (j >= 1 && tries[j].v > p.v) {
                tries[j + 1] := tries[j]
                j -= 1
            }
            tries[j + 1] := p
        }
        total := 0
        for p in tries
            total += p.w
        cumul := 0
        for p in tries {
            cumul += p.w
            if (cumul >= total / 2)
                return p.v
        }
        return tries[tries.Length].v
    }

    ;  Jours entre deux dates AAAAMMJJ.
    static _Jours(de, a) {
        try return DateDiff(a, de, "Days")
        return 0
    }

    ;--------------------------------------------------------------------------
    ;  Ce que le modele attend pour une voie a un instant : Predire regarde
    ;  l'heure (au sens du soleil), PredireApp le contexte. Tous deux rendent
    ;  { valeur, poids, accord, confiant, proposable, bascule }, valeur etant
    ;  un ecart quand regime n'est pas vide.
    ;--------------------------------------------------------------------------
    static Predire(voie, m, regime := "") {
        return Habitudes._Resumer(Habitudes._Points(voie, Habitudes._Complet(m), regime))
    }

    static PredireApp(voie, app, m, regime := "") {
        return Habitudes._Resumer(Habitudes._PointsApp(voie, app, Habitudes._Complet(m), regime))
    }

    ;  Un instant derive de m, a une autre minute du meme jour.
    static _A(m, minutes) {
        m := Habitudes._Complet(m)
        return { tick: m.tick, minutes: Mod(Mod(minutes, 1440) + 1440, 1440), date: m.date, we: m.we
               , lever: m.lever, coucher: m.coucher }
    }

    ;--------------------------------------------------------------------------
    ;  La cible du moment : { valeur, confiant, proposable, poids, contexte,
    ;  rampe, brute }. Le contexte devant s'il a ses habitudes, sinon
    ;  l'instant ; sinon le dernier instant sur dans les six heures, glissant
    ;  vers le prochain s'il vient a une autre valeur. En regime automate, la
    ;  valeur est l'ecart, et base la valeur brute de l'automate.
    ;--------------------------------------------------------------------------
    static Cible(voie, m, app := "") {
        m := Habitudes._Complet(m)
        brute := Habitudes._Automate(voie)
        rien := { valeur: 0, confiant: false, proposable: false, poids: 0, contexte: "", rampe: false, brute: brute }
        if (app != "") {
            pa := Habitudes.PredireApp(voie, app, m, brute)
            if (pa.confiant || pa.proposable)
                return { valeur: pa.valeur, confiant: pa.confiant, proposable: pa.proposable
                       , poids: pa.poids, contexte: app, rampe: false, brute: brute }
        }
        p := Habitudes.Predire(voie, m, brute)
        if (p.confiant)
            return { valeur: p.valeur, confiant: true, proposable: true, poids: p.poids
                   , contexte: "", rampe: false, brute: brute }
        ;  pas sur ici : le dernier instant sur avant, et le prochain apres
        avant := 0, apres := 0
        Loop Habitudes.PORTEE_RAMPE // Habitudes.PAS_RAMPE {
            d := A_Index * Habitudes.PAS_RAMPE
            if (!avant) {
                q := Habitudes.Predire(voie, Habitudes._A(m, m.minutes - d), brute)
                if (q.confiant)
                    avant := { t: -d, v: q.valeur, poids: q.poids }
            }
            if (!apres) {
                q := Habitudes.Predire(voie, Habitudes._A(m, m.minutes + d), brute)
                if (q.confiant)
                    apres := { t: d, v: q.valeur, poids: q.poids }
            }
            if (avant && apres)
                break
        }
        if (!avant) {
            if (p.proposable)
                return { valeur: p.valeur, confiant: false, proposable: true, poids: p.poids
                       , contexte: "", rampe: false, brute: brute }
            return rien
        }
        valeur := avant.v, rampe := false
        if (apres && apres.v != avant.v) {
            part := (0 - avant.t) / (apres.t - avant.t)
            valeur := Round(avant.v + (apres.v - avant.v) * part)
            rampe := true
        }
        return { valeur: valeur, confiant: true, proposable: true, poids: avant.poids
               , contexte: "", rampe: rampe, brute: brute }
    }

    ;  L'ecart appris pour une voie tenue par un automate, que celui-ci
    ;  ajoute a sa propre valeur. Zero tant que rien n'est sur.
    static Decalage(voie) {
        return Habitudes.decalages.Has(voie) ? Habitudes.decalages[voie] : 0
    }

    ;--------------------------------------------------------------------------
    ;  Poser ce que le modele attend, si tout le permet ; ou le proposer.
    ;--------------------------------------------------------------------------
    static _Poser(voie, m, app := "") {
        if (!Habitudes.poser || !Habitudes.lire)
            return
        if (Habitudes.attente.Has(voie))
            return                                   ; un geste decante
        if (Habitudes.dernierGeste.Has(voie)
            && m.tick - Habitudes.dernierGeste[voie] < Habitudes.GARDE * 60000)
            return                                   ; la main est encore la
        if (Habitudes._Bloque(voie))
            return                                   ; un etat passager tient la voie
        cible := Habitudes.Cible(voie, m, app)

        ;  En regime automate, on ne pose pas : on tend l'ecart a l'automate.
        if (cible.brute != "") {
            nouveau := cible.confiant ? cible.valeur : 0
            if (Habitudes.Decalage(voie) != nouveau) {
                Habitudes.decalages[voie] := nouveau
                Habitudes._Journal(Format("{} : ecart {:+d} sur l'automate{}", voie, nouveau
                                        , cible.contexte != "" ? " (" . cible.contexte . ")" : ""))
            }
            return
        }
        if (!cible.confiant && !cible.proposable)
            return
        ;  suspendue par un geste, tant que la cible n'a pas bouge -- et pas
        ;  au-dela du jour : demain, l'habitude reprend.
        if (Habitudes.suspendu.Has(voie)) {
            su := Habitudes.suspendu[voie]
            if (su.date = m.date && Abs(cible.valeur - su.valeur) < Habitudes.SEUIL)
                return
            Habitudes.suspendu.Delete(voie)
        }
        courant := (Habitudes.lire)(voie)
        if (Abs(cible.valeur - courant) < Habitudes.SEUIL)
            return
        if (Habitudes.dernierePose.Has(voie)) {
            d := Habitudes.dernierePose[voie]
            if (Abs(cible.valeur - d.valeur) < Habitudes.SEUIL && d.date = m.date)
                return                               ; deja posee aujourd'hui
        }
        if (!cible.confiant) {
            Habitudes._Proposer(voie, m, cible, app)
            return
        }
        Habitudes.dernierePose[voie] := { tick: m.tick, valeur: cible.valeur, date: m.date
                                        , minutes: m.minutes, we: m.we, app: cible.contexte
                                        , brute: "", vu: false, confirme: false }
        Habitudes._Journal(Format("{} : pose {} a {} ({}{})", voie, cible.valeur, Habitudes._Hhmm(m.minutes)
                                , cible.rampe ? "rampe" : Format("{:.1f} de poids", cible.poids)
                                , cible.contexte != "" ? ", " . cible.contexte : ""))
        try (Habitudes.poser)(voie, cible.valeur, cible)
    }

    ;  Deux soirs concordants : on propose, une fois par jour et par valeur.
    ;  Accepter vaut un geste, et pose.
    static _Proposer(voie, m, cible, app) {
        if (!Habitudes.proposer)
            return
        cle := m.date . ":" . cible.valeur
        if (Habitudes.proposes.Has(voie) && Habitudes.proposes[voie] = cle)
            return
        Habitudes.proposes[voie] := cle
        Habitudes._Journal(Format("{} : propose {} a {}", voie, cible.valeur, Habitudes._Hhmm(m.minutes)))
        accepter := ObjBindMethod(Habitudes, "_Accepter", voie, cible.valeur, app)
        try (Habitudes.proposer)(voie, cible.valeur, cible, accepter)
    }

    static _Accepter(voie, valeur, app) {
        m := Habitudes.Maintenant()
        Habitudes._Journal(voie . " : proposition " . valeur . " acceptee")
        Habitudes.Observer(voie, valeur, m, 1, app, 0, "")
        Habitudes.dernierGeste[voie] := m.tick
        try (Habitudes.poser)(voie, valeur, { valeur: valeur, confiant: true, rampe: false
                                            , contexte: app, poids: 0, brute: "" })
    }

    static _Hhmm(minutes) {
        minutes := Mod(Mod(Round(minutes), 1440) + 1440, 1440)
        return Format("{:02}:{:02}", minutes // 60, Mod(minutes, 60))
    }

    ;--------------------------------------------------------------------------
    ;  Le fichier : une section par voie, une cle par observation.
    ;--------------------------------------------------------------------------
    static Fichier() {
        return Config.DOSSIER . "\habitudes.ini"
    }

    static Charger() {
        Habitudes.obs := Map()
        f := Habitudes.Fichier()
        if (!FileExist(f))
            return
        m := Habitudes.Maintenant()
        for voie in Habitudes.VOIES {
            liste := []
            Loop Habitudes.MAXIMUM {
                texte := IniRead(f, voie, "o" . A_Index, "")
                if (texte = "")
                    break
                ch := StrSplit(texte, "@")
                if (ch.Length < 5 || !IsNumber(ch[1]))
                    continue
                ;  Une date illisible ne vieillirait jamais : on la rejette. Un
                ;  poids nul ou negatif fausserait les medianes et divisait par
                ;  zero : il vaut un.
                if (!RegExMatch(ch[2], "^\d{8}$") || Habitudes._Jours(ch[2], m.date) > Habitudes.JOURS)
                    continue
                liste.Push({ v: Integer(ch[1]), date: ch[2], we: ch[3] = "1" ? 1 : 0
                           , poids: IsNumber(ch[4]) && ch[4] > 0 ? ch[4] + 0 : 1
                           , minutes: IsNumber(ch[5]) ? Integer(ch[5]) : 0
                           , app: ch.Length >= 6 ? ch[6] : ""
                           , implicite: ch.Length >= 7 && ch[7] = "1" ? 1 : 0
                           , brute: ch.Length >= 8 && IsNumber(ch[8]) ? Integer(ch[8]) : ""
                           , lever: ch.Length >= 9 && IsNumber(ch[9]) ? Integer(ch[9]) : ""
                           , coucher: ch.Length >= 10 && IsNumber(ch[10]) ? Integer(ch[10]) : "" })
            }
            Habitudes.obs[voie] := liste
        }
    }

    ;  Le fichier est ecrit d'un bloc. Une IniWrite par observation relisait
    ;  et reecrivait tout le fichier a chaque fois : huit cents observations,
    ;  c'etait plusieurs secondes de blocage -- fondus et raccourcis compris
    ;  -- a chaque tour ou quelque chose avait change, et a la fermeture de
    ;  session. Le format reste celui que IniRead relit, en UTF-16 avec
    ;  marque d'ordre, ce que lit aussi GetPrivateProfileString.
    static Enregistrer() {
        Habitudes.sale := false
        f := Habitudes.Fichier()
        try Config.Init()
        texte := ""
        for voie in Habitudes.VOIES {
            if (!Habitudes.obs.Has(voie))
                continue
            texte .= "[" . voie . "]`r`n"
            for i, o in Habitudes.obs[voie] {
                texte .= "o" . i . "=" . o.v . "@" . o.date . "@" . o.we . "@" . o.poids . "@" . o.minutes . "@" . o.app
                       . "@" . o.implicite . "@" . o.brute . "@" . o.lever . "@" . o.coucher . "`r`n"
            }
        }
        try {
            fichier := FileOpen(f, "w", "UTF-16")
            fichier.Write(texte)
            fichier.Close()
        }
    }

    ;  Tout oublier : les observations, le fichier, ce qui decante.
    static Oublier() {
        Habitudes.obs := Map()
        Habitudes.attente := Map()
        Habitudes.dernierePose := Map()
        Habitudes.suspendu := Map()
        Habitudes.proposes := Map()
        Habitudes.decalages := Map()
        Habitudes.sale := false
        try FileDelete(Habitudes.Fichier())
        Habitudes._Journal("tout oublie")
    }

    ;  A la sortie : ce qui decantait compte, s'il a eu au moins un moment
    ;  de calme -- on ne retient pas un geste qu'on a fait en fermant.
    static Clore() {
        m := Habitudes.Maintenant()
        for voie in Habitudes.VOIES {
            if (Habitudes.attente.Has(voie) && m.tick - Habitudes.attente[voie].tick >= 30000)
                Habitudes._Decanter(voie, m, true)
        }
        if (Habitudes.sale)
            Habitudes.Enregistrer()
    }

    ;--------------------------------------------------------------------------
    ;  Pour la fenetre : 48 predictions d'une voie (une par demi-heure, au
    ;  milieu), le compte des observations, le detail d'une demi-heure.
    ;--------------------------------------------------------------------------
    static Courbe(voie, we := -1) {
        m := Habitudes.Maintenant()
        if (we >= 0)
            m.we := we
        ;  le regime le plus observe : absolu, ou ecart
        absolues := 0, ecarts := 0
        if (Habitudes.obs.Has(voie)) {
            for o in Habitudes.obs[voie]
                (o.brute = "") ? absolues++ : ecarts++
        }
        regime := ecarts > absolues ? 50 : ""
        courbe := []
        Loop 48 {
            p := Habitudes.Predire(voie, Habitudes._A(m, (A_Index - 1) * 30 + 15), regime)
            if (regime != "")
                p.valeur := Max(0, Min(100, 50 + p.valeur))
            courbe.Push(p)
        }
        return courbe
    }

    static Compte(voie) {
        return Habitudes.obs.Has(voie) ? Habitudes.obs[voie].Length : 0
    }

    ;  Les observations d'une demi-heure (a l'horloge), les recentes d'abord.
    static Detail(voie, k) {
        liste := []
        if (!Habitudes.obs.Has(voie))
            return liste
        src := Habitudes.obs[voie]
        Loop src.Length {
            o := src[src.Length - A_Index + 1]
            if (o.minutes // 30 = k)
                liste.Push(o)
        }
        return liste
    }
}
