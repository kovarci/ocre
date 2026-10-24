;==============================================================================
;  Hdr.ahk -- l'ecran est-il en HDR ?
;
;  La question compte parce que la reponse change la facon de filtrer. En HDR,
;  Windows compose en virgule flottante 10 ou 16 bits et ne consulte plus la
;  table gamma : SetDeviceGammaRamp reussit, et ne fait rien. Le filtre passe
;  alors par le compositeur (voir Compositeur.ahk).
;
;  Deux API repondent, et la premiere ment. GET_ADVANCED_COLOR_INFO (requete 9,
;  Windows 10) leve "couleur avancee active" aussi bien pour le HDR que pour la
;  gestion automatique des couleurs (ACM), que Windows 11 active tout seul sur
;  les dalles a gamme etendue -- et qui, elle, laisse la rampe gamma intacte.
;  Mesure sur la machine de developpement : drapeau a 1, HDR eteint, Ocre
;  fonctionne. S'y fier aurait fait basculer sur le compositeur des gens pour
;  qui la rampe marche tres bien.
;
;  GET_ADVANCED_COLOR_INFO_2 (requete 15, Windows 11 24H2) distingue SDR, WCG
;  et HDR. C'est elle qu'on lit. Sur un Windows plus ancien elle repond
;  ERROR_INVALID_PARAMETER, et l'on conclut "pas HDR" : mieux vaut ne rien
;  dire que crier faux -- et il reste la cle "voie" de la configuration pour
;  forcer le compositeur a la main.
;
;  Le resultat est mis en cache et oublie a chaque changement d'affichage :
;  interroger la configuration d'affichage coute une allocation et deux
;  appels, ce que le chien de garde n'a pas a payer toutes les dix secondes.
;==============================================================================

#Requires AutoHotkey v2.0

class Hdr {

    static cache := ""          ; "" = pas encore interroge

    ;  activeColorMode de DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO_2
    static SDR := 0
    static WCG := 1
    static HDR := 2

    ;--------------------------------------------------------------------------
    ;  Le mode couleur le plus "avance" parmi les ecrans actifs.
    ;
    ;  L'effet du compositeur est plein ecran : le mode le plus haut d'un seul
    ;  ecran justifie la bascule, les autres suivront par la meme voie. HDR > WCG
    ;  > SDR.
    ;--------------------------------------------------------------------------
    static Mode() {
        if (Hdr.cache = "")
            Hdr.cache := Hdr._Sonder()
        return Hdr.cache
    }

    ;  Vrai en HDR strict. Sert a l'exposant du compositeur, qui ne travaille
    ;  en lumiere lineaire qu'en vrai HDR.
    static Actif() {
        return Hdr.Mode() = Hdr.HDR
    }

    ;  Vrai des que la rampe gamma est ignoree a l'affichage : en HDR, et en
    ;  HDR seulement.
    ;
    ;  Le WCG n'y est PAS. On a cru un temps que la gestion automatique des
    ;  couleurs ignorait la rampe comme le HDR, et fait basculer Ocre sur le
    ;  compositeur des le mode WCG. Faux, et mesure a l'oeil : sur la machine
    ;  de developpement, en WCG, une rampe (1, 0.3, 0) posee par
    ;  SetDeviceGammaRamp teinte l'ecran tres visiblement. La bascule avait
    ;  deux effets de bord : le curseur materiel, que la matrice du
    ;  compositeur ne touche pas, restait blanc ; et la teinte etait plus
    ;  faible qu'a la rampe, le compositeur composant en lineaire sous WCG
    ;  sans que l'exposant 2,2 ne soit applique.
    static RampeIgnoree() {
        return Hdr.Mode() = Hdr.HDR
    }

    static Oublier() {
        Hdr.cache := ""
    }

    static _Sonder() {
        pire := Hdr.SDR
        try {
            ;  QDC_ONLY_ACTIVE_PATHS = 2
            if (DllCall("GetDisplayConfigBufferSizes", "uint", 2
                      , "uint*", &nP := 0, "uint*", &nM := 0))
                return Hdr.SDR

            ;  DISPLAYCONFIG_PATH_INFO fait 72 octets ; DISPLAYCONFIG_MODE_INFO
            ;  64. Dans le chemin, targetInfo commence a +20 : adapterId (LUID,
            ;  8 octets) puis id.
            paths := Buffer(72 * Max(1, nP), 0)
            modes := Buffer(64 * Max(1, nM), 0)
            if (DllCall("QueryDisplayConfig", "uint", 2, "uint*", &nP, "ptr", paths
                      , "uint*", &nM, "ptr", modes, "ptr", 0))
                return Hdr.SDR

            Loop nP {
                base := (A_Index - 1) * 72
                m := Hdr._Mode(NumGet(paths, base + 20, "Int64")
                             , NumGet(paths, base + 28, "UInt"))
                if (m > pire)
                    pire := m
            }
        }
        return pire
    }

    ;  DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO_2 : en-tete de 20 octets (type,
    ;  taille, adapterId, id), puis value, colorEncoding, bitsPerColorChannel,
    ;  activeColorMode. 36 octets en tout.
    static _Mode(adaptateur, cible) {
        req := Buffer(36, 0)
        NumPut("UInt", 15, req, 0)
        NumPut("UInt", 36, req, 4)
        NumPut("Int64", adaptateur, req, 8)
        NumPut("UInt", cible, req, 16)
        if (DllCall("DisplayConfigGetDeviceInfo", "ptr", req))
            return -1                        ; API absente : on ne sait pas
        return NumGet(req, 32, "UInt")
    }
}
