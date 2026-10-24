;==============================================================================
;  Soleil.ahk -- lever et coucher du soleil, calcules sur place.
;
;  Pourquoi cela existe. Un horaire fixe derive : a Paris le soleil se couche
;  a 17:00 en decembre et a 21:55 en juin, soit cinq heures d'ecart. Une
;  montee qui commence a 21:00 toute l'annee est donc quatre heures trop tard
;  la moitie du temps -- et le fondu de trois heures, qui est tout l'interet du
;  planificateur, perd son ancrage.
;
;  L'algorithme est celui de la NOAA, dans la forme publiee par son Solar
;  Calculator. Il ne demande que la date, une latitude et une longitude : pas
;  de reseau, pas de service, rien a tenir a jour. Sa precision est de l'ordre
;  de la minute aux latitudes habitables, ce qui est trois ordres de grandeur
;  au-dela de ce qu'un fondu de trois heures peut distinguer.
;
;  Le zenith retenu est 90,833 degres : les 90 degres geometriques, plus 0,833
;  qui tient compte de la refraction atmospherique et du demi-diametre du
;  disque solaire. C'est la convention du lever et du coucher "officiels",
;  celle des almanachs et des applications du genre.
;
;  Ce fichier ne lit aucun reglage et ne touche a rien : il calcule. C'est ce
;  qui permet a tools/test-soleil.ahk de le verifier sans materiel ni horaire.
;==============================================================================

#Requires AutoHotkey v2.0

class Soleil {

    static ZENITH := 90.833

    ;  Renvoye par Lever et Coucher quand l'evenement n'existe pas ce jour-la.
    ;  Au-dela des cercles polaires, le soleil peut ne pas se lever de la
    ;  journee ou ne pas se coucher de la nuit ; l'appelant doit le savoir
    ;  plutot que de recevoir une heure inventee.
    static JAMAIS := -1

    static Rad(deg) {
        return deg * 3.14159265358979 / 180
    }

    static Deg(rad) {
        return rad * 180 / 3.14159265358979
    }

    ;--------------------------------------------------------------------------
    ;  Jour julien a 0 h UTC. La bascule de fevrier -- les mois de janvier et
    ;  fevrier comptent pour le 13e et le 14e de l'annee precedente -- est
    ;  celle de l'algorithme de Meeus, et le calendrier gregorien impose la
    ;  correction B.
    ;--------------------------------------------------------------------------
    static JourJulien(annee, mois, jour) {
        if (mois <= 2) {
            annee -= 1
            mois += 12
        }
        a := Floor(annee / 100)
        b := 2 - a + Floor(a / 4)
        return Floor(365.25 * (annee + 4716)) + Floor(30.6001 * (mois + 1))
             + jour + b - 1524.5
    }

    ;--------------------------------------------------------------------------
    ;  Position du soleil pour un siecle julien donne : declinaison, et
    ;  equation du temps.
    ;
    ;  L'equation du temps est l'ecart entre le midi de l'horloge et le midi du
    ;  soleil. Elle atteint un quart d'heure en novembre : l'ignorer suffirait
    ;  a faire mentir le calcul de plus que tout le reste reuni.
    ;--------------------------------------------------------------------------
    static _Position(t) {
        ;  Longitude et anomalie moyennes du soleil.
        l0 := Mod(280.46646 + t * (36000.76983 + t * 0.0003032), 360)
        if (l0 < 0)
            l0 += 360
        m := 357.52911 + t * (35999.05029 - 0.0001537 * t)

        ;  Excentricite de l'orbite terrestre, et equation du centre.
        e := 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        c := Sin(Soleil.Rad(m)) * (1.914602 - t * (0.004817 + 0.000014 * t))
           + Sin(Soleil.Rad(2 * m)) * (0.019993 - 0.000101 * t)
           + Sin(Soleil.Rad(3 * m)) * 0.000289

        ;  Longitude apparente : la vraie, corrigee de la nutation et de
        ;  l'aberration.
        omega := 125.04 - 1934.136 * t
        lambda := (l0 + c) - 0.00569 - 0.00478 * Sin(Soleil.Rad(omega))

        ;  Obliquite de l'ecliptique, corrigee elle aussi.
        eps0 := 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        eps := eps0 + 0.00256 * Cos(Soleil.Rad(omega))

        decl := Soleil.Deg(ASin(Sin(Soleil.Rad(eps)) * Sin(Soleil.Rad(lambda))))

        y := Tan(Soleil.Rad(eps / 2)) ** 2
        eqt := 4 * Soleil.Deg(
                 y * Sin(Soleil.Rad(2 * l0))
               - 2 * e * Sin(Soleil.Rad(m))
               + 4 * e * y * Sin(Soleil.Rad(m)) * Cos(Soleil.Rad(2 * l0))
               - 0.5 * y * y * Sin(Soleil.Rad(4 * l0))
               - 1.25 * e * e * Sin(Soleil.Rad(2 * m)))

        return { decl: decl, eqt: eqt }
    }

    ;--------------------------------------------------------------------------
    ;  Lever et coucher, en minutes depuis minuit UTC.
    ;
    ;  L'angle horaire est l'arc que le soleil parcourt entre le zenith local
    ;  et l'horizon. Au-dela des cercles polaires, son cosinus sort de [-1, 1]
    ;  aux solstices : c'est le jour ou la nuit sans fin, et il n'y a alors
    ;  aucune heure a renvoyer.
    ;--------------------------------------------------------------------------
    static _Utc(annee, mois, jour, lat, lon) {
        jj := Soleil.JourJulien(annee, mois, jour)

        lever := Soleil._Evenement(jj, lat, lon, true)
        coucher := Soleil._Evenement(jj, lat, lon, false)

        if (lever = Soleil.JAMAIS || coucher = Soleil.JAMAIS) {
            ;  Le signe du cosinus dit lequel des deux : au-dessus de 1, le
            ;  soleil ne monte jamais assez haut -- nuit permanente ; en
            ;  dessous de -1, il ne descend jamais assez bas -- jour permanent.
            p := Soleil._Position((jj - 2451545.0) / 36525.0)
            return { lever: Soleil.JAMAIS, coucher: Soleil.JAMAIS
                   , polaire: (Soleil._CosH(p.decl, lat) > 1 ? "nuit" : "jour") }
        }

        return { lever: lever, coucher: coucher, polaire: "" }
    }

    ;--------------------------------------------------------------------------
    ;  Un evenement, en deux passes.
    ;
    ;  La premiere prend la position du soleil a 0 h UTC, ce qui suffit sous
    ;  nos latitudes. Plus haut, l'astre rase l'horizon : il y passe une heure
    ;  la ou il met dix minutes a Paris, et la declinaison a 0 h n'est plus
    ;  celle qu'il aura au moment du coucher. Mesure faite contre une autre
    ;  implementation : 4 minutes d'erreur a Tromso et a Reykjavik en
    ;  septembre, ramenees a une seule par la seconde passe, qui recalcule la
    ;  position a l'heure trouvee par la premiere.
    ;--------------------------------------------------------------------------
    static _Evenement(jj, lat, lon, lever) {
        m := Soleil._Passe(jj, lat, lon, lever)
        if (m = Soleil.JAMAIS)
            return Soleil.JAMAIS

        m2 := Soleil._Passe(jj + m / 1440.0, lat, lon, lever)
        return (m2 = Soleil.JAMAIS) ? m : m2
    }

    static _Passe(jj, lat, lon, lever) {
        p := Soleil._Position((jj - 2451545.0) / 36525.0)

        cosH := Soleil._CosH(p.decl, lat)
        if (cosH > 1 || cosH < -1)
            return Soleil.JAMAIS

        h := Soleil.Deg(ACos(cosH))

        ;  Midi solaire a 720 minutes, avance ou retarde par la longitude
        ;  (quatre minutes par degre) et par l'equation du temps.
        return lever ? 720 - 4 * (lon + h) - p.eqt
                     : 720 - 4 * (lon - h) - p.eqt
    }

    static _CosH(decl, lat) {
        return Cos(Soleil.Rad(Soleil.ZENITH))
               / (Cos(Soleil.Rad(lat)) * Cos(Soleil.Rad(decl)))
             - Tan(Soleil.Rad(lat)) * Tan(Soleil.Rad(decl))
    }

    ;--------------------------------------------------------------------------
    ;  Les memes, ramenes a l'heure locale de la machine.
    ;
    ;  Le decalage est pris sur A_Now et A_NowUTC plutot que dans le registre :
    ;  il porte ainsi l'heure d'ete telle qu'elle est appliquee aujourd'hui,
    ;  sans avoir a savoir quand elle change ni ou.
    ;
    ;  Les minutes sont ramenees dans [0, 1440[ : un coucher qui tombe apres
    ;  minuit UTC -- ou avant, selon le sens du decalage -- appartient bien a
    ;  la journee locale en cours.
    ;--------------------------------------------------------------------------
    ;  decalage vaut "" pour prendre celui de la machine. Le passer permet a
    ;  tools/test-soleil.ahk d'interroger une date de decembre depuis une
    ;  machine en heure d'ete, ce que le decalage courant rendrait faux d'une
    ;  heure.
    static Aujourdhui(lat, lon) {
        return Soleil.Jour(A_YYYY + 0, A_MM + 0, A_DD + 0, lat, lon)
    }

    static Jour(annee, mois, jour, lat, lon, decalage := "") {
        u := Soleil._Utc(annee, mois, jour, lat, lon)
        if (u.lever = Soleil.JAMAIS)
            return u

        d := (decalage = "") ? Soleil.Decalage() : decalage
        return { lever:   Soleil._Cadran(u.lever + d)
               , coucher: Soleil._Cadran(u.coucher + d)
               , polaire: "" }
    }

    ;  Decalage local par rapport a UTC, en minutes.
    static Decalage() {
        return DateDiff(A_Now, A_NowUTC, "Minutes")
    }

    static _Cadran(minutes) {
        m := Mod(Mod(Round(minutes), 1440) + 1440, 1440)
        return m
    }

    ;--------------------------------------------------------------------------
    ;  Une latitude ou une longitude est-elle utilisable ?
    ;
    ;  Zero est une coordonnee parfaitement legale -- elle designe un point du
    ;  golfe de Guinee -- mais c'est aussi ce que renvoie un reglage vide. On
    ;  demande donc les deux : un lieu jamais renseigne a lat ET lon nulles, et
    ;  personne n'habite la.
    ;--------------------------------------------------------------------------
    static Valide(lat, lon) {
        if (!IsNumber(lat) || !IsNumber(lon))
            return false
        if (Abs(lat) > 90 || Abs(lon) > 180)
            return false
        return !(lat = 0 && lon = 0)
    }
}
