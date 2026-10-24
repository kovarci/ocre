;==============================================================================
;  Fondu.ahk -- adoucir un changement fait a la main.
;
;  Le planificateur a son fondu de trois heures, dont tout l'interet est de ne
;  pas se voir. Un appui sur un raccourci, lui, sautait d'un cran a l'autre :
;  cinq points d'intensite d'un coup, c'est un clignement. Le meme argument
;  vaut aux deux echelles -- une transition qui se remarque est une transition
;  ratee -- et il ne coute ici qu'un sixieme de seconde.
;
;  Ce qui NE passe PAS par ici, et a dessein :
;
;  - la molette et les curseurs. Ils sont deja continus : le geste EST le
;    fondu. Y ajouter une interpolation ferait trainer l'image derriere la
;    main, ce qui se lit comme de la lenteur, pas comme de la douceur.
;
;  - le planificateur et la pose au demarrage. Le premier a son propre fondu ;
;    la seconde doit etre immediate, une session qui s'ouvre en s'eclaircissant
;    pendant une seconde ayant l'air d'un defaut.
;
;  Un fondu en cours est abandonne des qu'un autre commence sur la meme voie :
;  trois appuis rapides doivent mener au troisieme cran, pas jouer trois
;  animations a la suite.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Config.ahk

class Fondu {

    static DUREE := 160        ; millisecondes, pour un pas
    static PERIODE := 16       ; environ soixante pas par seconde

    ;  La bascule et les prereglages ne font pas un pas de cinq points : ils
    ;  vont de zero a cent d'un coup. Les memes cent soixante millisecondes
    ;  qui effacent un pas font de ce saut un flash. Ils ont donc leur duree,
    ;  lue dans ocre.ini (cle "fondu_bascule", en millisecondes) : qui prefere
    ;  l'ancien coup sec y remet 160.
    static DUREE_BASCULE := 1000

    ;  Un seuil, en dessous duquel on pose directement. Un fondu d'un point ne
    ;  se voit pas, mais son minuteur coute autant qu'un fondu de cinquante.
    static SEUIL := 2

    static voies := Map()      ; nom -> etat du fondu en cours

    ;--------------------------------------------------------------------------
    ;  Va de "de" vers "a", en appelant poser a chaque pas.
    ;
    ;  voie separe les fondus qui n'ont rien a voir : l'intensite et la
    ;  luminosite se reglent parfois dans la meme seconde, et chacune doit
    ;  poursuivre la sienne.
    ;
    ;  duree vaut DUREE par defaut ; la bascule passe la sienne.
    ;--------------------------------------------------------------------------
    static Vers(voie, de, a, poser, duree := 0) {
        Fondu.Arreter(voie)

        if (duree <= 0)
            duree := Fondu.DUREE
        if (Abs(a - de) < Fondu.SEUIL) {
            poser(a)
            return
        }

        etat := { de: de, a: a, poser: poser, t0: A_TickCount, tic: 0, duree: duree }
        etat.tic := () => Fondu._Pas(voie)
        Fondu.voies[voie] := etat

        SetTimer(etat.tic, Fondu.PERIODE)
        Fondu._Pas(voie)
    }

    static _Pas(voie) {
        if (!Fondu.voies.Has(voie))
            return
        e := Fondu.voies[voie]

        t := (A_TickCount - e.t0) / e.duree
        if (t >= 1) {
            Fondu.Arreter(voie)
            (e.poser)(e.a)
            return
        }

        ;  Une progression lineaire donnerait un depart et un arret secs. Le
        ;  lissage classique -- t carre, trois moins deux t -- part et s'arrete
        ;  a vitesse nulle, ce qui est precisement ce qu'on cherche : que rien
        ;  n'attire l'oeil.
        d := t * t * (3 - 2 * t)
        (e.poser)(Round(e.de + (e.a - e.de) * d))
    }

    ;--------------------------------------------------------------------------
    ;  Arrete un fondu sans poser sa valeur d'arrivee : l'appelant a mieux a
    ;  proposer, sans quoi il n'interromprait pas.
    ;--------------------------------------------------------------------------
    static Arreter(voie) {
        if (!Fondu.voies.Has(voie))
            return
        SetTimer(Fondu.voies[voie].tic, 0)
        Fondu.voies.Delete(voie)
    }

    static EnCours(voie) {
        return Fondu.voies.Has(voie)
    }

    ;  La duree de la bascule, telle que configuree. Zero ou absent : la
    ;  valeur par defaut.
    static DureeBascule() {
        d := Config.LireNombre("fondu_bascule")
        return d > 0 ? d : Fondu.DUREE_BASCULE
    }

    ;  La valeur vers laquelle un fondu se dirige. C'est d'elle qu'un nouveau
    ;  pas doit se compter : une touche maintenue envoie ses appuis plus vite
    ;  que le fondu ne les joue, et compter depuis la valeur en cours donnerait
    ;  100, 92, 91, 89 au lieu de 100, 95, 90, 85.
    static Cible(voie) {
        return Fondu.voies.Has(voie) ? Fondu.voies[voie].a : ""
    }

    ;  A la sortie, et avant toute pose immediate : un minuteur qui survivrait
    ;  reposerait une valeur perimee un seizieme de seconde plus tard.
    static ArreterTout() {
        for voie, e in Fondu.voies.Clone()
            Fondu.Arreter(voie)
    }
}
