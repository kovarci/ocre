;==============================================================================
;  Horaire.ahk -- le planificateur.
;
;  Deux moments dans la journee : celui ou la montee vers l'intensite de nuit
;  commence, celui ou la descente vers l'intensite de jour commence. Entre les
;  deux, l'intensite ne bouge plus.
;
;  Le fondu est volontairement tres long -- trois heures par defaut, la ou les
;  outils du genre proposent vingt secondes ou une heure. Une intensite qui
;  monte d'un point toutes les trois minutes ne se voit pas : c'est tout
;  l'interet, l'oeil suit sans jamais rien remarquer. Un fondu court, lui, se
;  remarque, et c'est precisement ce qu'on reproche a ces outils.
;
;  Coupe par defaut. Beaucoup de gens preferent regler leur filtre a la main.
;
;  Un reglage a la main pendant un fondu suspend le planificateur jusqu'au
;  prochain basculement : sans cela, la valeur choisie serait reprise trois
;  minutes plus tard, ce qui donne l'impression d'un programme qui se bat
;  contre son utilisateur.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\I18n.ahk
#Include %A_LineFile%\..\Soleil.ahk
#Include %A_LineFile%\..\Fuseau.ahk

class Horaire {

    static PERIODE := 30000        ; un point de fondu se joue en minutes

    static actif := false
    static debutFixe := 21 * 60
    static finFixe := 7 * 60
    static fondu := 180
    static nuit := 60
    static jour := 0

    ;  Mode solaire : les deux basculements suivent le coucher et le lever, a
    ;  un decalage pres.
    ;
    ;  Un horaire fixe derive. A Paris le soleil se couche a 17:00 en decembre
    ;  et a 21:55 en juin : une montee calee sur 21:00 toute l'annee est quatre
    ;  heures trop tard la moitie du temps, et le fondu de trois heures -- qui
    ;  est tout l'interet du planificateur -- perd l'ancrage qui le justifie.
    static soleil := false
    static lat := 0
    static lon := 0
    static decNuit := 0
    static decJour := 0

    static appliquer := 0          ; (valeur) => ...
    static lire := 0               ; () => intensite courante
    static tic := 0
    static phaseSuspendue := ""    ; "n" ou "j" tant qu'un reglage manuel tient
    static derniereCible := -1

    ;--------------------------------------------------------------------------
    ;  appliquer : pose une intensite sans pastille ni memorisation.
    ;  lire      : renvoie l'intensite courante.
    ;--------------------------------------------------------------------------
    static Init(appliquer, lire) {
        Horaire.appliquer := appliquer
        Horaire.lire := lire
        Horaire.Relire()
    }

    ;  Relit la configuration et (re)arme le minuteur. Appelee au demarrage et
    ;  a chaque enregistrement des reglages.
    ;
    ;  Un horaire suspendu par un reglage a la main le reste si ses propres
    ;  parametres n'ont pas change : n'importe quelle bascule des reglages
    ;  passe par ici, et elle faisait reprendre le planificateur -- qui
    ;  reposait aussitot son intensite par-dessus celle qu'on venait de
    ;  choisir. Un changement de l'horaire lui-meme, lui, s'applique.
    static signature := ""

    static Relire(appliquerTout := true) {
        suspendue := Horaire.phaseSuspendue
        avant := Horaire.signature
        Horaire.actif := (Config.Lire("horaire") = "1")
        Horaire.debutFixe := Horaire.EnMinutes(Config.Lire("h_debut"), 21 * 60)
        Horaire.finFixe   := Horaire.EnMinutes(Config.Lire("h_fin"), 7 * 60)
        Horaire.fondu := Max(1, Config.LireNombre("h_fondu"))
        Horaire.nuit  := Max(0, Min(100, Config.LireNombre("h_nuit")))
        Horaire.jour  := Max(0, Min(100, Config.LireNombre("h_jour")))

        Horaire.lat := Horaire._Nombre(Config.Lire("lat"))
        Horaire.lon := Horaire._Nombre(Config.Lire("lon"))
        Horaire.decNuit := Horaire._Nombre(Config.Lire("h_dec_nuit"))
        Horaire.decJour := Horaire._Nombre(Config.Lire("h_dec_jour"))

        ;  Le mode solaire demande un lieu. Sans coordonnees saisies, le
        ;  fuseau horaire de Windows en donne un approximatif (voir
        ;  Fuseau.ahk) ; sans cela non plus, les heures fixes reprennent
        ;  plutot que de ne rien faire : mieux vaut un horaire approximatif
        ;  qu'un planificateur muet.
        if (Config.Lire("h_soleil") = "1" && !Soleil.Valide(Horaire.lat, Horaire.lon)) {
            f := Fuseau.Lieu()
            if (f)
                Horaire.lat := f.lat, Horaire.lon := f.lon
        }
        Horaire.soleil := (Config.Lire("h_soleil") = "1")
                       && Soleil.Valide(Horaire.lat, Horaire.lon)

        Horaire.signature := Horaire.actif . "|" . Horaire.soleil . "|" . Horaire.debutFixe . "|" . Horaire.finFixe
                           . "|" . Horaire.fondu . "|" . Horaire.nuit . "|" . Horaire.jour . "|" . Horaire.lat
                           . "|" . Horaire.lon . "|" . Horaire.decNuit . "|" . Horaire.decJour
        meme := (avant != "" && Horaire.signature = avant)

        Horaire.phaseSuspendue := meme ? suspendue : ""
        Horaire.derniereCible := -1

        if (Horaire.tic)
            SetTimer(Horaire.tic, 0)

        if (!Horaire.actif) {
            Horaire.tic := 0
            return
        }

        Horaire.tic := () => Horaire._Battre()
        SetTimer(Horaire.tic, Horaire.PERIODE)

        ;  Au demarrage, on ne fait pas de fondu depuis la valeur enregistree :
        ;  une machine allumee a 23 h doit ouvrir la session a l'intensite de
        ;  cette heure-la, pas a celle de la veille au soir.
        if (appliquerTout)
            Horaire._Battre(!meme)
    }

    ;--------------------------------------------------------------------------
    ;  "21:00" -> 1260, et aussi "9:00 PM", "9 pm", "21h" : ce qu'on ecrit
    ;  dans ocre.ini a la main, dans l'une ou l'autre habitude. Une saisie
    ;  incomprise retombe sur la valeur par defaut plutot que sur minuit, qui
    ;  passerait pour un reglage volontaire.
    ;--------------------------------------------------------------------------
    static EnMinutes(texte, defaut) {
        if (RegExMatch(texte, "i)^\s*(\d{1,2})(?:\s*[:h.]\s*(\d{1,2})?)?\s*([ap]m?)?\s*$", &m)) {
            h := Integer(m[1]), mn := m[2] != "" ? Integer(m[2]) : 0
            if (m[3] != "") {
                if (h < 1 || h > 12)
                    return defaut
                h := Mod(h, 12) + (SubStr(StrLower(m[3]), 1, 1) = "p" ? 12 : 0)
            } else if (m[2] = "" && !InStr(texte, "h")) {
                return defaut
            }
            if (h <= 23 && mn <= 59)
                return h * 60 + mn
        }
        return defaut
    }

    static EnTexte(minutes) {
        minutes := Mod(Mod(Round(minutes), 1440) + 1440, 1440)
        return Format("{:02}:{:02}", minutes // 60, Mod(minutes, 60))
    }

    ;  "48,85" comme "48.85" : la virgule est ce qu'un clavier francais donne,
    ;  et AutoHotkey n'y voit pas un nombre.
    static _Nombre(texte) {
        texte := StrReplace(Trim(texte . ""), ",", ".")
        return IsNumber(texte) ? texte + 0 : 0
    }

    ;--------------------------------------------------------------------------
    ;  Les deux basculements du jour, en minutes depuis minuit.
    ;
    ;  Recalcules a chaque battement plutot que retenus : le calcul coute
    ;  quelques microsecondes, et le retenir demanderait de savoir quand la
    ;  journee change -- ce qui est precisement le genre de detail qui casse a
    ;  minuit, au changement d'heure, ou apres une veille de trois jours.
    ;
    ;  Aux latitudes polaires il arrive qu'il n'y ait ni lever ni coucher. Les
    ;  heures fixes reprennent alors la main : elles ne veulent pas dire
    ;  grand-chose la-bas non plus, mais elles ne laissent pas le
    ;  planificateur sans reperes.
    ;--------------------------------------------------------------------------
    static Bascules() {
        if (!Horaire.soleil)
            return { debut: Horaire.debutFixe, fin: Horaire.finFixe, soleil: false }

        s := Soleil.Aujourdhui(Horaire.lat, Horaire.lon)
        if (s.lever = Soleil.JAMAIS)
            return { debut: Horaire.debutFixe, fin: Horaire.finFixe
                   , soleil: false, polaire: s.polaire }

        return { debut: Horaire._Cadran(s.coucher + Horaire.decNuit)
               , fin:   Horaire._Cadran(s.lever + Horaire.decJour)
               , soleil: true, lever: s.lever, coucher: s.coucher }
    }

    static _Cadran(m) {
        return Mod(Mod(Round(m), 1440) + 1440, 1440)
    }

    ;--------------------------------------------------------------------------
    ;  L'intensite visee a une minute donnee, et la phase en cours.
    ;
    ;  On mesure le temps ecoule depuis chacun des deux basculements, en
    ;  tournant sur 24 h ; le plus recent des deux donne la phase. Le fondu est
    ;  lineaire, et tronque si le basculement suivant arrive avant sa fin --
    ;  un fondu de six heures entre deux basculements espaces de quatre ne peut
    ;  pas faire autrement.
    ;--------------------------------------------------------------------------
    static Cible(minute) {
        b := Horaire.Bascules()
        depuisNuit := Mod(Mod(minute - b.debut, 1440) + 1440, 1440)
        depuisJour := Mod(Mod(minute - b.fin, 1440) + 1440, 1440)

        if (depuisNuit < depuisJour) {
            t := Min(1.0, depuisNuit / Horaire.fondu)
            return { valeur: Horaire.jour + (Horaire.nuit - Horaire.jour) * t
                   , phase: "n" }
        }
        t := Min(1.0, depuisJour / Horaire.fondu)
        return { valeur: Horaire.nuit + (Horaire.jour - Horaire.nuit) * t
               , phase: "j" }
    }

    ;--------------------------------------------------------------------------
    static _Battre(force := false) {
        if (!Horaire.actif)
            return

        maintenant := A_Hour * 60 + A_Min
        c := Horaire.Cible(maintenant)

        ;  Un reglage manuel tient jusqu'au prochain basculement.
        if (Horaire.phaseSuspendue != "") {
            if (Horaire.phaseSuspendue = c.phase && !force)
                return
            Horaire.phaseSuspendue := ""
            Horaire._Signaler()
        }

        ;  L'ecart appris par les habitudes s'ajoute ici, et compte dans
        ;  "deja la" : un ecart qui change fait bouger l'ecran sans attendre
        ;  le prochain basculement.
        v := Round(c.valeur)
        if (Horaire.decalage)
            try v := Max(0, Min(100, v + Round((Horaire.decalage)())))
        if (!force && v = Horaire.derniereCible)
            return
        Horaire.derniereCible := v

        ;  Rien a faire si l'ecran y est deja : la remise en place inutile
        ;  redessinerait l'icone et rallumerait la pastille pour rien.
        if (!force && Horaire.lire && (Horaire.lire)() = v)
            return

        if (Horaire.appliquer)
            (Horaire.appliquer)(v)
    }

    ;  Appelee des qu'une intensite est posee a la main -- raccourci, molette,
    ;  curseur. Le planificateur se tait jusqu'au prochain basculement.
    static Suspendre() {
        if (!Horaire.actif)
            return
        c := Horaire.Cible(A_Hour * 60 + A_Min)
        deja := (Horaire.phaseSuspendue != "")
        Horaire.phaseSuspendue := c.phase
        Horaire.derniereCible := -1
        if (!deja)
            Horaire._Signaler()
    }

    ;--------------------------------------------------------------------------
    ;  La suspension doit se voir. Un planificateur qui se tait sans le dire
    ;  passe pour un planificateur en panne : l'infobulle de l'icone et le
    ;  panneau du clic droit disent donc "horaire suspendu jusqu'a 07:00", et
    ;  une ligne du panneau permet de le reprendre sans attendre.
    ;--------------------------------------------------------------------------
    static surEtat := 0            ; () => ... appele a chaque changement
    static decalage := 0           ; () => points a ajouter a la cible : l'ecart appris (Habitudes)

    static _Signaler() {
        if (Horaire.surEtat)
            try (Horaire.surEtat)()
    }

    static Suspendu() {
        return Horaire.actif && Horaire.phaseSuspendue != ""
    }

    ;  L'heure du prochain basculement, en texte : c'est la que la suspension
    ;  prendra fin d'elle-meme. Une phase de nuit suspendue s'arrete au
    ;  basculement de jour, et inversement.
    static FinSuspension() {
        b := Horaire.Bascules()
        return I18n.Heure(Horaire.phaseSuspendue = "n" ? b.fin : b.debut)
    }

    ;  Reprend tout de suite, et repose l'intensite de l'heure.
    static Reprendre() {
        if (!Horaire.Suspendu())
            return
        Horaire.phaseSuspendue := ""
        Horaire.derniereCible := -1
        Horaire._Signaler()
        Horaire._Battre(true)
    }
}
