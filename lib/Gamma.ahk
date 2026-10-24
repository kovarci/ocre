;==============================================================================
;  Gamma.ahk -- la courbe, et la rampe qui la porte.
;
;  Independant du Night Light de Windows : s'applique instantanement, sans
;  passer par le registre ni par aucun service. C'est ce qui le rend utilisable
;  au clavier, la ou le Night Light natif n'est plus pilotable a chaud depuis
;  Windows 11 25H2 (voir README).
;
;  Ce fichier ne sait plus qui sont les ecrans -- c'est Ecrans.ahk -- ni
;  comment repartir un assombrissement entre le retroeclairage et la rampe --
;  c'est Retro.ahk. Il ne reste ici que la couleur : une temperature vers des
;  multiplicateurs, des multiplicateurs vers une table de 3 x 256 entrees, et
;  la pose de cette table sur un contexte.
;
;  L'amplitude depend d'un garde-fou systeme :
;
;    HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM
;      GdiIcmGammaRange = 256   (REG_DWORD)
;
;  Sans lui, SetDeviceGammaRamp rogne les rampes trop marquees. Une reouverture
;  de session est necessaire apres l'avoir pose.
;==============================================================================

#Requires AutoHotkey v2.0

class Gamma {

    static MIN_K := 1200          ; bas du modele Kelvin
    static MAX_K := 6500          ; neutre

    ;--------------------------------------------------------------------------
    ;  Intensite <-> temperature de couleur.
    ;
    ;  C'est la meme droite que celle de Multiplicateurs : 0 % vaut 6500 K,
    ;  100 % vaut 1200 K. Le Kelvin affiche est donc bien celui du modele,
    ;  pas une decoration -- au-dela de 60 % le renfort ecrase le vert et le
    ;  bleu un peu plus que la temperature ne le dirait, mais c'est un
    ;  prolongement, pas un autre modele.
    ;--------------------------------------------------------------------------
    static Kelvin(p) {
        p := Max(0, Min(100, p))
        return Round(Gamma.MAX_K - p / 100.0 * (Gamma.MAX_K - Gamma.MIN_K))
    }

    static Intensite(k) {
        k := Max(Gamma.MIN_K, Min(Gamma.MAX_K, k))
        return Round((Gamma.MAX_K - k) * 100.0 / (Gamma.MAX_K - Gamma.MIN_K))
    }

    ;  Le facteur le plus sombre que la rampe puisse porter.
    ;
    ;  Ce n'est pas une precaution de principe : a facteur nul l'ecran est
    ;  noir, et avec lui la commande qui permettrait de remonter. C'est aussi
    ;  ce qui garantit qu'un curseur de luminosite pose au minimum laisse
    ;  toujours de quoi le remonter, retroeclairage au plancher ou non.
    static PLANCHER_LUM := 0.30

    ;--------------------------------------------------------------------------
    ;  Approximation de Tanner Helland : temperature de couleur -> RVB 0-255.
    ;--------------------------------------------------------------------------
    static KelvinToRGB(k) {
        k := Max(1000, Min(40000, k))
        t := k / 100.0

        r := (t <= 66) ? 255 : 329.698727446 * ((t - 60) ** -0.1332047592)
        g := (t <= 66) ? (99.4708025861 * Ln(t) - 161.1195681661)
                       : 288.1221695283 * ((t - 60) ** -0.0755148492)
        b := (t >= 66) ? 255
           : (t <= 19) ? 0
           : 138.5177312231 * Ln(t - 10) - 305.0447927307

        return { r: Max(0, Min(255, r))
               , g: Max(0, Min(255, g))
               , b: Max(0, Min(255, b)) }
    }

    ;--------------------------------------------------------------------------
    ;  Multiplicateurs pour une intensite 0-100.
    ;
    ;  Deux corrections par rapport au modele brut :
    ;
    ;  - Normalisation. A 6500 K le modele renvoie (255, 254, 250), soit un
    ;    leger residu chaud. On divise par cette reference pour que 0 % soit
    ;    exactement l'identite.
    ;
    ;  - Prolongement. Le modele plafonne : a 1200 K il laisse encore le vert a
    ;    0,34, en deca du Night Light natif a fond. Au-dela de 60 % on ecrase
    ;    donc le vert davantage. En dessous, le rendu reste celui d'une vraie
    ;    temperature de couleur.
    ;--------------------------------------------------------------------------
    static Multiplicateurs(p) {
        p := Max(0, Min(100, p)) / 100.0

        ref := Gamma.KelvinToRGB(Gamma.MAX_K)
        c   := Gamma.KelvinToRGB(Gamma.MAX_K - p * (Gamma.MAX_K - Gamma.MIN_K))

        r := Min(1.0, c.r / ref.r)
        g := Min(1.0, c.g / ref.g)
        b := Min(1.0, c.b / ref.b)

        renfort := Max(0, (p - 0.60) / 0.40)      ; 0 jusqu'a 60 %, 1 a 100 %
        return { r: r
               , g: g * (1 - 0.55 * renfort)
               , b: b * (1 - 1.00 * renfort) }
    }

    ;--------------------------------------------------------------------------
    ;  La table des 3 x 256 entrees, isolee de sa pose : c'est ce qui permet de
    ;  la verifier sans toucher a l'ecran (voir tools/test-courbe.ahk).
    ;--------------------------------------------------------------------------
    ;  noir : le seuil du noir profond, 0 pour rien. Sur une dalle OLED, un
    ;  pixel noir est eteint et un gris tres sombre est allume : les fonds
    ;  "sombres" des applications -- #191919 chez Notion, #1E1E1E chez VS Code
    ;  -- sont donc de la lumiere. Tout niveau au plus egal au seuil est
    ;  envoye a zero, et ce qui est au-dessus est etire pour que le blanc
    ;  reste le blanc : la rampe reste croissante, et 255 reste 255, ce que
    ;  le chien de garde (BleuPose) relit.
    static Rampe(c, noir := 0) {
        noir := Max(0, Min(128, Round(noir)))
        ramp := Buffer(3 * 256 * 2, 0)
        Loop 256 {
            i := A_Index - 1
            niveau := noir ? Max(0, i - noir) * 255.0 / (255 - noir) : i
            base := niveau * 256
            NumPut("UShort", Round(Min(65535, base * c.r)), ramp, (0 * 256 + i) * 2)
            NumPut("UShort", Round(Min(65535, base * c.g)), ramp, (1 * 256 + i) * 2)
            NumPut("UShort", Round(Min(65535, base * c.b)), ramp, (2 * 256 + i) * 2)
        }
        return ramp
    }

    ;  Les multiplicateurs d'un couple (intensite, facteur de luminosite). Le
    ;  facteur multiplie les trois canaux a l'identique, donc sans deplacer la
    ;  teinte.
    static Couleur(p, facteur := 1.0) {
        c := Gamma.Multiplicateurs(p)
        return { r: c.r * facteur, g: c.g * facteur, b: c.b * facteur }
    }

    ;--------------------------------------------------------------------------
    ;  Pose sur un contexte. Renvoie faux si l'ecran refuse -- certains
    ;  moniteurs externes n'ont pas de table gamma.
    ;--------------------------------------------------------------------------
    static Poser(hdc, c, noir := 0) {
        return DllCall("gdi32\SetDeviceGammaRamp", "ptr", hdc, "ptr", Gamma.Rampe(c, noir))
             ? true : false
    }

    static Neutre(hdc) {
        return Gamma.Poser(hdc, { r: 1.0, g: 1.0, b: 1.0 })
    }

    ;--------------------------------------------------------------------------
    ;  Relit le sommet du canal bleu reellement en place.
    ;
    ;  Sert au chien de garde : Windows reinitialise la rampe de lui-meme apres
    ;  une mise en veille, un changement de resolution, une invite UAC ou la
    ;  sortie d'un jeu plein ecran. Le bleu est le canal le plus deplace par le
    ;  filtre, donc celui qui trahit le mieux une remise a plat.
    ;--------------------------------------------------------------------------
    ;  i : l'entree relue, le sommet par defaut. Le noir profond se verifie
    ;  a son seuil, ou la rampe doit valoir zero : au sommet, elle ne differe
    ;  pas de la rampe neutre.
    static BleuPose(hdc, i := 255) {
        buf := Buffer(3 * 256 * 2, 0)
        if (!DllCall("gdi32\GetDeviceGammaRamp", "ptr", hdc, "ptr", buf))
            return -1
        return NumGet(buf, (2 * 256 + i) * 2, "UShort")
    }

    static BleuAttendu(c) {
        return Round(Min(65535, 255 * 256 * c.b))
    }

    ;  Le garde-fou est-il leve ?
    static ClampLeve() {
        try {
            return (RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM"
                          , "GdiIcmGammaRange") = 256)
        }
        return 0
    }
}
