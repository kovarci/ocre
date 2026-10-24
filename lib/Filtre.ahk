;==============================================================================
;  Filtre.ahk -- l'etat du filtre, et sa pose sur les ecrans.
;
;  Trois choses vivaient dans Ocre.ahk et n'y avaient plus leur place des lors
;  qu'un reglage peut differer d'un ecran a l'autre : ce que valent l'intensite
;  et la luminosite, ou l'on pose ces valeurs, et comment on verifie qu'elles y
;  sont encore.
;
;  Deux modes, et un seul est visible quand il n'y a qu'un ecran :
;
;  - ensemble (par defaut). Un couple de valeurs, pose a l'identique partout.
;    C'est exactement ce que faisait Ocre avant, et c'est le seul mode possible
;    -- et le seul propose -- sur une machine a un ecran.
;
;  - separes. Un couple par ecran. Une dalle de portable et un IPS externe
;    n'ont pas la meme temperature native : a 60 % l'un vire a l'orange quand
;    l'autre reste jaune, et il n'y a pas de reglage unique qui aille aux deux.
;
;  En mode separe, un raccourci doit bien s'appliquer quelque part : c'est
;  l'ecran de la fenetre active pour le clavier, celui que survole la souris
;  pour la molette. On regle ce qu'on regarde.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Gamma.ahk
#Include %A_LineFile%\..\Ecrans.ahk
#Include %A_LineFile%\..\Retro.ahk
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\Compositeur.ahk
#Include %A_LineFile%\..\Hdr.ahk

class Filtre {

    static separes := false
    static valeurs := Map()          ; identifiant d'ecran -> { i, l }
    static ensemble := { i: 0, l: 100 }

    ;  La chambre noire (voir Compositeur.CHAMBRE). Un etat de session, pas
    ;  un reglage : elle n'est pas ecrite dans ocre.ini, et une session
    ;  s'ouvre toujours en couleur. Un ecran noir a texte rouge des
    ;  l'ouverture, sans qu'on se souvienne pourquoi, serait pris pour une
    ;  panne. Elle n'a ni raccourci ni case dans les reglages : seule une
    ;  ligne du panneau du clic droit y mene.
    static chambre := false

    ;--------------------------------------------------------------------------
    ;  Relit les reglages persistes.
    ;
    ;  Le mode separe est ignore s'il n'y a qu'un ecran : quelqu'un qui l'a
    ;  active sur une station a deux ecrans puis rentre chez lui avec le
    ;  portable seul ne doit pas retrouver une application qui se comporte
    ;  autrement. Le reglage reste ecrit, il redeviendra actif au rebranchement.
    ;--------------------------------------------------------------------------
    static Charger() {
        Filtre.separes := (Config.Lire("separes") = "1") && Ecrans.Nombre() > 1

        Filtre.ensemble := { i: Filtre._Borne("intensite", 0)
                           , l: Filtre._Borne("luminosite", 100) }

        Filtre.valeurs := Map()
        for e in Ecrans.Lister() {
            cle := Config.CleEcran(e.id)
            Filtre.valeurs[e.id] := {
                i: Filtre._Borne(cle . "_i", Filtre.ensemble.i)
              , l: Filtre._Borne(cle . "_l", Filtre.ensemble.l) }
        }
    }

    ;  Une cle absente ou illisible vaut le defaut. Zero, lui, est une valeur
    ;  : un ecran coupe seul en mode separe, ou une luminosite au plancher,
    ;  doivent revenir tels quels au demarrage suivant -- ils revenaient a
    ;  l'ensemble, ou a cent.
    static _Borne(cle, defaut) {
        v := Config.Lire(cle)
        if (!IsNumber(v))
            return defaut
        return Max(0, Min(100, Integer(v)))
    }

    ;--------------------------------------------------------------------------
    ;  Les valeurs d'un ecran. Sans ecran, celles qui font foi -- l'ensemble,
    ;  ou l'ecran actif quand les reglages sont separes.
    ;--------------------------------------------------------------------------
    static Lire(ecran := 0) {
        if (!Filtre.separes)
            return Filtre.ensemble
        if (!ecran)
            ecran := Ecrans.Actif()
        if (Filtre.valeurs.Has(ecran.id))
            return Filtre.valeurs[ecran.id]

        ;  Un ecran branche depuis le dernier chargement n'a pas encore de
        ;  valeurs : il herite de l'ensemble plutot que de rester neutre au
        ;  milieu d'ecrans filtres.
        v := { i: Filtre.ensemble.i, l: Filtre.ensemble.l }
        Filtre.valeurs[ecran.id] := v
        return v
    }

    ;--------------------------------------------------------------------------
    ;  Pose des valeurs. ecran vaut 0 pour "partout" : l'ensemble en mode
    ;  ensemble, chaque ecran en mode separe. Les gestes qui visent un ecran
    ;  -- clavier, molette, curseurs -- passent toujours le leur (voir Vise) ;
    ;  ce qui arrive sans ecran vient d'un automate ou de la ligne de
    ;  commande, et n'a pas de raison de ne toucher que l'ecran de la fenetre
    ;  active : le planificateur posait l'intensite de nuit sur celui-la
    ;  seulement, et l'autre restait au jour toute la nuit.
    ;
    ;  i ou l vaut "" pour "ne pas y toucher" : l'intensite se pose sans
    ;  ecraser la luminosite propre a chaque ecran, et inversement.
    ;
    ;  Renvoie l'ecran effectivement touche, dont la pastille a besoin pour
    ;  savoir ou s'afficher.
    ;--------------------------------------------------------------------------
    ;  grisTaux ne concerne que la bascule : elle fait entrer et sortir le
    ;  gris au rythme de son fondu (voir Appliquer). Partout ailleurs le gris
    ;  est entier ou absent.
    ;  persister a faux pose les valeurs sans les ecrire dans ocre.ini : un
    ;  assombrissement passager (inactivite, batterie, suivi du contenu) ne
    ;  doit pas devenir la luminosite de la session suivante.
    static Definir(i, l, ecran := 0, grisTaux := 1.0, persister := true, noirTaux := 1.0) {
        if (i != "")
            i := Max(0, Min(100, Round(i)))
        if (l != "")
            l := Max(0, Min(100, Round(l)))

        if (!Filtre.separes) {
            if (i != "") {
                Filtre.ensemble.i := i
                if (persister)
                    Config.EcrireDiffere("intensite", i)
            }
            if (l != "") {
                Filtre.ensemble.l := l
                if (persister)
                    Config.EcrireDiffere("luminosite", l)
            }
            Filtre.Appliquer(grisTaux, noirTaux)
            return ecran ? ecran : Ecrans.Actif()
        }

        for e in (ecran ? [ecran] : Ecrans.Lister()) {
            v := Filtre.Lire(e)
            v := { i: i != "" ? i : v.i, l: l != "" ? l : v.l }
            Filtre.valeurs[e.id] := v
            if (!persister)
                continue
            cle := Config.CleEcran(e.id)
            Config.EcrireDiffere(cle . "_i", v.i)
            Config.EcrireDiffere(cle . "_l", v.l)
        }
        Filtre.Appliquer(grisTaux, noirTaux)
        return ecran ? ecran : Ecrans.Actif()
    }

    ;--------------------------------------------------------------------------
    ;  Pose l'etat courant sur tous les ecrans.
    ;
    ;  Un ecran qui refuse la rampe -- certains moniteurs externes n'ont pas de
    ;  table gamma -- ne prive pas les autres du filtre : la pose reussit des
    ;  qu'un seul l'accepte.
    ;--------------------------------------------------------------------------
    ;--------------------------------------------------------------------------
    ;  Par ou passe la teinte.
    ;
    ;  "gamma" est la voie d'origine : une rampe par ecran, qui permet un
    ;  reglage par ecran. "compositeur" pose une matrice de couleur sur tout
    ;  le bureau : c'est la seule qui marche en HDR, ou la rampe est ignoree.
    ;  "auto", le defaut, choisit selon ce que dit Hdr.RampeIgnoree() -- vrai
    ;  en HDR seulement, pas en WCG, ou la rampe marche encore.
    ;
    ;  La cle "voie" de ocre.ini force l'une ou l'autre : pour un Windows
    ;  anterieur a 24H2 ou la detection n'existe pas, ou pour essayer.
    ;--------------------------------------------------------------------------
    static Voie() {
        v := Config.Lire("voie")
        if (v = "compositeur" || v = "gamma")
            return v
        return Hdr.RampeIgnoree() ? "compositeur" : "gamma"
    }

    ;  grisTaux, entre 0 et 1, dose le gris quand il est couple au filtre.
    ;  Il vaut 1 partout sauf pendant le fondu de la bascule, ou il suit la
    ;  teinte : sans cela le gris tombait d'un bloc au premier point
    ;  d'intensite, pendant que la teinte, elle, arrivait en douceur.
    static Appliquer(grisTaux := 1.0, noirTaux := 1.0) {
        ;  Pas "compositeur" tout court : AutoHotkey ne distingue pas la casse,
        ;  et une locale de ce nom masquerait la classe Compositeur -- ce qui a
        ;  donne "Integer has no method named Teinte", une heure de perdue.
        parCompositeur := (Filtre.Voie() = "compositeur")
        gris := (Config.Lire("gris") = "1" && !Filtre.Coupe() && grisTaux > 0)

        ;  La chambre noire ne laisse sortir que du rouge : le gris n'y
        ;  changerait rien, on ne le compose pas. La teinte, elle, reste
        ;  posee -- son rouge vaut 1 a toute intensite, et le facteur de
        ;  luminosite continue d'assombrir.
        if (Filtre.chambre)
            gris := false

        noir := Filtre.NoirEffectif(noirTaux)
        ok := false
        for e in Ecrans.Lister() {
            v := Filtre.Lire(e)
            part := Retro.Repartir(e, v.l, Gamma.PLANCHER_LUM)
            Retro.Poser(e, part.materiel)

            ;  Par le compositeur, la rampe reste neutre : la reposer a chaque
            ;  fois est ce qui la remet d'aplomb si l'on vient de changer de
            ;  voie.
            if (parCompositeur) {
                Gamma.Neutre(e.hdc)
                ok := true
            } else if (Gamma.Poser(e.hdc, Gamma.Couleur(v.i, part.gamma), noir)) {
                ok := true
            }
        }

        if (parCompositeur) {
            ;  Une seule matrice pour tout le bureau : elle prend les valeurs
            ;  de l'ensemble, ou de l'ecran regarde si elles sont separees.
            ref := Filtre.separes ? Ecrans.Actif() : Ecrans.Principal()
            v := Filtre.Lire(ref)
            part := Retro.Repartir(ref, v.l, Gamma.PLANCHER_LUM)
            c := Gamma.Couleur(v.i, part.gamma)
            m := Compositeur.Teinte(c.r, c.g, c.b
                                  , Hdr.Actif() ? Compositeur.EXPOSANT_HDR : 1.0)
            if (gris)
                m := Compositeur.Multiplier(Compositeur.Desaturation(grisTaux), m)
            if (Filtre.chambre)
                m := Compositeur.Multiplier(Compositeur.CHAMBRE, m)
            if (noir)
                m := Compositeur.Multiplier(Compositeur.NoirProfond(noir, Hdr.Actif() ? Compositeur.EXPOSANT_HDR : 1.0), m)
            Compositeur.Poser(m)
            return ok
        }

        ;  Le gris suit le filtre : allume des qu'un ecran est filtre, coupe
        ;  quand tous le sont. Une seule commande pose les deux etats, et c'est
        ;  ce qui les empeche de se desynchroniser -- le probleme d'origine.
        ;  L'effet est plein ecran : il ne peut pas suivre un ecran plutot
        ;  qu'un autre.
        Compositeur.Poser(Filtre.chambre ? Compositeur.CHAMBRE
                        : gris ? Compositeur.Desaturation(grisTaux)
                        : Compositeur.IDENTITE)
        return ok
    }

    ;  Le seuil du noir profond (voir Gamma.Rampe), 0 pour rien. Borne a 64 :
    ;  au-dela, ce ne sont plus des fonds sombres qu'on eteint mais des
    ;  images qu'on bouche.
    static Noir() {
        return Max(0, Min(64, Config.LireNombre("noir")))
    }

    ;  Le seuil reellement pose : le noir profond suit le filtre, comme le
    ;  gris -- couper le filtre (Ctrl+F7) le coupe aussi, et le retablir le
    ;  ramene. Pendant le fondu de la bascule, taux va de 1 a 0 (ou
    ;  l'inverse) et le seuil descend avec lui, cran par cran, au lieu de
    ;  tomber d'un bloc : la teinte, le gris et le noir s'en vont ensemble.
    static NoirEffectif(taux := 1.0) {
        if (Filtre.Coupe())
            return 0
        return Round(Filtre.Noir() * Max(0.0, Min(1.0, taux)))
    }

    ;  Le filtre est-il coupe partout ? La luminosite ne compte pas : on peut
    ;  vouloir un ecran sombre sans le vouloir gris.
    static Coupe() {
        for e in Ecrans.Lister() {
            if (Filtre.Lire(e).i > 0)
                return false
        }
        return true
    }

    ;--------------------------------------------------------------------------
    ;  Repose tout, de force.
    ;
    ;  Pour le bouton "Reappliquer" et pour la sortie de veille. Deux caches
    ;  peuvent mentir apres coup : celui du compositeur, qui croit son effet
    ;  encore en place alors que Windows l'a efface ; et la detection HDR/WCG,
    ;  si l'on vient de basculer le mode couleur. On les vide, on reenumere les
    ;  ecrans, on relit les reglages, et on repose.
    ;
    ;  C'est la reponse au filtre qui "bugge" : un jeu plein ecran, une sortie
    ;  de veille ou un changement de mode couleur peut faire disparaitre
    ;  l'effet, et rien de ce que le chien de garde surveille ne le voit passer.
    ;--------------------------------------------------------------------------
    static Forcer() {
        Compositeur.posee := ""
        Hdr.Oublier()
        Filtre.Oublier()
        Filtre.Charger()
        return Filtre.Appliquer()
    }

    ;--------------------------------------------------------------------------
    ;  La rampe en place est-elle encore la notre ?
    ;
    ;  Windows la reinitialise de lui-meme apres une veille, un changement de
    ;  resolution, une invite UAC ou la sortie d'un jeu plein ecran. Un seul
    ;  ecran remis a plat suffit a declencher la remise en place : on repose de
    ;  toute facon sur tous.
    ;
    ;  La tolerance de 256 est large a dessein. La rampe posee n'est pas
    ;  toujours relue au bit pres -- le pilote arrondit -- et un chien de garde
    ;  qui reposerait la rampe toutes les dix secondes pour un ecart de deux
    ;  unites ferait clignoter l'ecran sans raison.
    ;--------------------------------------------------------------------------
    static Devie() {
        ;  Par le compositeur, la rampe est neutre a dessein : la relire ne
        ;  dirait rien. L'effet du compositeur, lui, n'est pas remis a plat par
        ;  Windows de la meme facon -- il tient tant que le processus vit.
        if (Filtre.Voie() = "compositeur")
            return false
        noir := Filtre.NoirEffectif()
        for e in Ecrans.Lister() {
            v := Filtre.Lire(e)
            if (v.i = 0 && v.l >= 100 && !noir)
                continue

            ;  Le noir profond ne change pas le sommet de la rampe : c'est a
            ;  son seuil qu'une remise a plat se voit, la ou zero est attendu.
            if (noir && Gamma.BleuPose(e.hdc, noir) > 256)
                return true

            pose := Gamma.BleuPose(e.hdc)
            if (pose < 0)
                continue

            part := Retro.Repartir(e, v.l, Gamma.PLANCHER_LUM)
            attendu := Gamma.BleuAttendu(Gamma.Couleur(v.i, part.gamma))
            if (Abs(pose - attendu) > 256)
                return true
        }
        return false
    }

    ;  Y a-t-il quelque chose a surveiller ? Filtre coupe et luminosite pleine
    ;  partout, il n'y a rien a remettre en place.
    static Neutre() {
        if (Filtre.NoirEffectif())
            return false                 ; le noir profond est une rampe a tenir
        for e in Ecrans.Lister() {
            v := Filtre.Lire(e)
            if (v.i != 0 || v.l < 100)
                return false
        }
        return true
    }

    ;--------------------------------------------------------------------------
    ;  Rend l'ecran a son etat d'origine : rampe neutre et retroeclairage tel
    ;  qu'on l'a trouve.
    ;
    ;  Pour le retroeclairage ce n'est pas une politesse. Sur un portable il
    ;  passe par WMI, c'est-a-dire par le reglage de Windows lui-meme : le
    ;  laisser au fond laisserait quelqu'un devant un ecran sombre sans qu'une
    ;  seule commande visible n'explique pourquoi.
    ;--------------------------------------------------------------------------
    static Rendre() {
        for e in Ecrans.Lister()
            Gamma.Neutre(e.hdc)
        Retro.Rendre()
        Compositeur.Rendre()
    }

    ;  Contextes et moniteurs physiques ne valent plus rien apres un
    ;  debranchement. La prochaine pose reenumere.
    static Oublier() {
        Retro.Oublier()
        Ecrans.Oublier()
        Hdr.Oublier()
    }
}
