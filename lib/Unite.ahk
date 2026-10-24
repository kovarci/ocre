;==============================================================================
;  Unite.ahk -- l'intensite s'affiche en pour cent ou en Kelvin.
;
;  Le curseur, les raccourcis et le fichier de configuration comptent en
;  pour cent : c'est la course du filtre, et c'est ce que l'on regle. Mais
;  qui vient de f.lux ou du Night Light raisonne en Kelvin -- 3400 K dit
;  quelque chose a qui a deja regle l'un ou l'autre, 58 % ne dit rien.
;
;  L'unite ne change donc que l'AFFICHAGE : la pastille, le panneau, la
;  fenetre des reglages et l'infobulle. Rien d'autre ne bouge. Elle se
;  bascule d'un clic sur la valeur, en haut du panneau du clic droit, et
;  nulle part ailleurs : c'est un gout qu'on choisit une fois.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Gamma.ahk
#Include %A_LineFile%\..\Config.ahk

class Unite {

    static Kelvin() {
        return Config.Lire("unite") = "k"
    }

    static Basculer() {
        Config.Ecrire("unite", Unite.Kelvin() ? "pct" : "k")
    }

    ;  "40 %" ou "4380 K". Pas d'espace fine ni de separateur de milliers :
    ;  la pastille dessine le texte a la police embarquee, et six caracteres
    ;  sont deja tout ce qui y tient.
    static Texte(intensite) {
        intensite := Round(intensite)
        return Unite.Kelvin() ? Gamma.Kelvin(intensite) . " K" : intensite . " %"
    }
}
