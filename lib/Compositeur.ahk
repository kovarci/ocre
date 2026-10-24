;==============================================================================
;  Compositeur.ahk -- une matrice de couleur sur tout le bureau.
;
;  Ce fichier s'appelait Gris.ahk et ne savait faire que le gris. Il a grandi
;  le jour ou il a fallu filtrer en HDR.
;
;  En HDR, Windows compose en virgule flottante et ne consulte plus la table
;  gamma : SetDeviceGammaRamp reussit et ne fait rien. Mais le compositeur,
;  lui, accepte toujours une matrice de couleur -- c'est l'API Magnification,
;  celle que Windows emploie pour ses filtres d'accessibilite -- et une rampe
;  gamma qui multiplie chaque canal par un coefficient n'est rien d'autre
;  qu'une matrice diagonale. La meme teinte peut donc etre posee par l'une ou
;  par l'autre voie, et Filtre.ahk choisit selon l'ecran.
;
;  Le gris et la teinte se composent par produit de matrices : gris d'abord,
;  teinte ensuite, comme le ferait l'oeil.
;
;  Trois proprietes de cette voie, deux bonnes et une a savoir :
;
;  - c'est instantane, sans registre ni service, et l'effet appartient au
;    processus : un "Fin de tache" rend l'ecran a la couleur ;
;  - une seule commande pose tout -- le gris ne peut pas rester quand la
;    teinte part ;
;  - l'effet est PLEIN ECRAN. Il ne sait pas donner une teinte a un ecran et
;    une autre au voisin : en mode HDR, les reglages par ecran s'appliquent a
;    tous sous la valeur de l'ecran regarde.
;
;  Un piege, qui a coute une heure. DllCall("Magnification\...") charge la DLL,
;  appelle, puis la DECHARGE si rien d'autre ne la retient -- c'est documente.
;  MagInitialize s'executait, la bibliotheque etait liberee avec son etat, et
;  MagSetFullscreenColorEffect tombait sur une bibliotheque vierge :
;  ERROR_INVALID_FUNCTION, sans autre explication, alors que le meme appel
;  depuis Python reussissait. Un LoadLibrary explicite, garde le temps du
;  processus, regle tout.
;==============================================================================

#Requires AutoHotkey v2.0

class Compositeur {

    ;  Voir Teinte pour ce que vaut cet exposant et pourquoi. Il n'a pas
    ;  encore ete mesure sur un ecran HDR allume : c'est la valeur theorique de
    ;  la courbe sRGB, a ajuster si l'oeil dit autre chose.
    static EXPOSANT_HDR := 2.2

    static dll := 0
    static pret := false
    static posee := ""          ; la derniere matrice posee, pour ne pas reposer

    ;  MAGCOLOREFFECT : cinq lignes de cinq flottants, une ligne par canal
    ;  d'entree, la sortie valant vecteur x matrice. Les coefficients du gris
    ;  sont ceux de l'exemple Microsoft, qui sont aussi ceux du filtre
    ;  "niveaux de gris" des Parametres.
    static GRIS := [0.3, 0.3, 0.3, 0, 0
                  , 0.6, 0.6, 0.6, 0, 0
                  , 0.1, 0.1, 0.1, 0, 0
                  , 0,   0,   0,   1, 0
                  , 0,   0,   0,   0, 1]

    static IDENTITE := [1, 0, 0, 0, 0
                      , 0, 1, 0, 0, 0
                      , 0, 0, 1, 0, 0
                      , 0, 0, 0, 1, 0
                      , 0, 0, 0, 0, 1]

    ;  La chambre noire : l'image rendue sur le seul canal rouge. Ce qui est
    ;  sombre reste noir, ce qui est clair devient rouge ; l'ecran n'emet que
    ;  la lumiere qui derange le moins une vision adaptee a l'obscurite.
    ;
    ;  Le rouge de sortie vaut la luminance d'entree (les poids du gris), et
    ;  non le seul canal rouge : un texte bleu doit rester lisible. Vert et
    ;  bleu de sortie sont a zero, quoi qu'il entre. La premiere colonne
    ;  porte les poids.
    ;
    ;  f.lux, lui, INVERSE l'image en plus (rouge = 1 moins la luminance).
    ;  C'etait pense pour des fonds blancs, qui devenaient noirs. Sur des
    ;  applications deja en mode sombre, l'inversion fait l'inverse du but :
    ;  chaque fond noir devient rouge vif. Sans inversion, un mode sombre est
    ;  deja une chambre noire ; c'est ce qu'on pose.
    static CHAMBRE := [0.3, 0, 0, 0, 0
                     , 0.6, 0, 0, 0, 0
                     , 0.1, 0, 0, 0, 0
                     , 0,   0, 0, 1, 0
                     , 0,   0, 0, 0, 1]

    ;--------------------------------------------------------------------------
    ;  Le gris a un taux : 0 rend l'identite, 1 le gris entier, entre les deux
    ;  (Pas "Gris" : AutoHotkey ne distingue pas la casse, et une methode de ce
    ;  nom entre en collision avec la constante GRIS -- "Property is read-only".)
    ;  une desaturation partielle. Les deux matrices etant affines, la moyenne
    ;  ponderee coefficient par coefficient est bien la matrice intermediaire.
    ;  C'est ce qui permet au gris de suivre un fondu au lieu de tomber d'un
    ;  coup au premier point d'intensite.
    ;--------------------------------------------------------------------------
    static Desaturation(taux := 1.0) {
        taux := Max(0.0, Min(1.0, taux))
        if (taux >= 1.0)
            return Compositeur.GRIS
        m := []
        for i, g in Compositeur.GRIS
            m.Push(Compositeur.IDENTITE[i] * (1 - taux) + g * taux)
        return m
    }

    ;--------------------------------------------------------------------------
    ;  La matrice d'une teinte : les trois multiplicateurs sur la diagonale.
    ;
    ;  L'exposant est la ou la voie compositeur differe de la rampe, et il
    ;  faut le dire. La rampe multiplie des valeurs ENCODEES -- le sRGB tel
    ;  qu'il sort de l'application. En HDR, le compositeur travaille en lumiere
    ;  LINEAIRE : le meme coefficient y assombrit davantage, parce que 0,5 en
    ;  lineaire vaut environ 0,73 en encode. Pour que 60 % en HDR ressemble a
    ;  60 % en SDR, le coefficient est eleve a la puissance 2,2 -- l'inverse
    ;  approximatif de la courbe sRGB. En SDR, ou le compositeur voit les
    ;  valeurs encodees, l'exposant vaut 1 et la matrice reproduit la rampe
    ;  au coefficient pres.
    ;--------------------------------------------------------------------------
    static Teinte(r, g, b, exposant := 1.0) {
        m := Compositeur.IDENTITE.Clone()
        m[1] := r ** exposant
        m[7] := g ** exposant
        m[13] := b ** exposant
        return m
    }

    ;  Le noir profond en matrice (voir Gamma.Rampe) : x -> (x - seuil) *
    ;  255 / (255 - seuil), le seuil sur 0-255. C'est une pente sur la
    ;  diagonale et un decalage negatif sur la cinquieme ligne, celle des
    ;  translations ; le compositeur ramene a zero ce qui passe en dessous.
    ;  En HDR, le compositeur voit de la lumiere lineaire : le seuil encode
    ;  y est converti par la meme puissance que la teinte.
    static NoirProfond(seuil, exposant := 1.0) {
        seuil := Max(0, Min(128, seuil)) / 255.0
        if (seuil <= 0)
            return Compositeur.IDENTITE
        seuil := seuil ** exposant
        pente := 1 / (1 - seuil)
        m := Compositeur.IDENTITE.Clone()
        m[1] := pente, m[7] := pente, m[13] := pente
        m[21] := -seuil * pente, m[22] := -seuil * pente, m[23] := -seuil * pente
        return m
    }

    ;  Produit a x b, l'un et l'autre en 5 x 5 ranges par lignes. La sortie
    ;  valant vecteur x matrice, appliquer a puis b revient a poser a x b.
    static Multiplier(a, b) {
        p := []
        Loop 5 {
            i := A_Index
            Loop 5 {
                j := A_Index
                s := 0.0
                Loop 5
                    s += a[(i - 1) * 5 + A_Index] * b[(A_Index - 1) * 5 + j]
                p.Push(s)
            }
        }
        return p
    }

    static _Preparer() {
        if (Compositeur.pret)
            return true
        try {
            if (!Compositeur.dll)
                Compositeur.dll := DllCall("LoadLibrary", "str", "Magnification.dll", "ptr")
            if (!Compositeur.dll)
                return false
            Compositeur.pret := DllCall("Magnification\MagInitialize") ? true : false
        }
        return Compositeur.pret
    }

    static _Tampon(coefs) {
        t := Buffer(100, 0)
        for i, v in coefs
            NumPut("Float", v, t, (i - 1) * 4)
        return t
    }

    static _Cle(coefs) {
        s := ""
        for v in coefs
            s .= Round(v, 5) . ","
        return s
    }

    ;--------------------------------------------------------------------------
    ;  Pose une matrice. Idempotent : reposer celle qui est deja en place ne
    ;  coute qu'une comparaison. Poser l'identite alors que rien n'a jamais ete
    ;  pose ne charge meme pas la bibliotheque : la plupart des gens n'auront
    ;  jamais besoin de cette voie.
    ;--------------------------------------------------------------------------
    static Poser(coefs) {
        cle := Compositeur._Cle(coefs)
        if (cle = Compositeur.posee)
            return true
        if (!Compositeur.pret && cle = Compositeur._Cle(Compositeur.IDENTITE)) {
            Compositeur.posee := cle
            return true
        }
        if (!Compositeur._Preparer())
            return false

        ok := DllCall("Magnification\MagSetFullscreenColorEffect"
                    , "ptr", Compositeur._Tampon(coefs))
        if (ok)
            Compositeur.posee := cle
        return ok ? true : false
    }

    static Neutre() {
        return Compositeur.Poser(Compositeur.IDENTITE)
    }

    ;  A la sortie. MagUninitialize retire l'effet ; le faire explicitement
    ;  vaut mieux que de compter sur la mort du processus, qui le ferait aussi.
    static Rendre() {
        if (!Compositeur.pret)
            return
        try {
            DllCall("Magnification\MagSetFullscreenColorEffect"
                  , "ptr", Compositeur._Tampon(Compositeur.IDENTITE))
            DllCall("Magnification\MagUninitialize")
        }
        Compositeur.pret := false
        Compositeur.posee := ""
    }
}
