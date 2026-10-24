;==============================================================================
;  Reglages.ahk -- la fenetre de configuration.
;
;  Toutes les commandes sont dessinees (voir Widgets.ahk) : les widgets Windows
;  imposent leur bleu systeme et leurs champs blancs, incompatibles avec une
;  fenetre sombre. Ne restent natifs que les libelles, qui suivent sans peine
;  la couleur de fond.
;
;  La mise en page suit un rythme de 8 points et trois tailles de texte : titre,
;  corps, intitule. Les intitules de section ne sont pas soulignes d'un filet
;  pleine largeur -- l'espace suffit a les separer, et le filet ajoutait du
;  bruit sans porter d'information.
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Blob.ahk
#Include %A_LineFile%\..\Theme.ahk
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\Batterie.ahk
#Include %A_LineFile%\..\Cadre.ahk
#Include %A_LineFile%\..\Apprentissage.ahk
#Include %A_LineFile%\..\I18n.ahk
#Include %A_LineFile%\..\Widgets.ahk
#Include %A_LineFile%\..\Gamma.ahk
#Include %A_LineFile%\..\Horaire.ahk
#Include %A_LineFile%\..\Filtre.ahk
#Include %A_LineFile%\..\Ecrans.ahk
#Include %A_LineFile%\..\Lieu.ahk
#Include %A_LineFile%\..\Planificateur.ahk
#Include %A_LineFile%\..\Unite.ahk
#Include %A_LineFile%\..\Concurrents.ahk
#Include %A_LineFile%\..\Prereglages.ahk
#Include %A_LineFile%\..\Raccourcis.ahk
#Include %A_LineFile%\..\Apropos.ahk

class Reglages {

    static L := 464
    static porteur := 0        ; le cadre redimensionnable qui porte le contenu (voir Cadre.ahk)
    static gui := 0
    static surIntensite := 0
    static surLuminosite := 0
    static surRaccourcis := 0
    static surLangue := 0
    static intensite := 0
    static luminosite := 100

    ;  L'ecran que reglent les deux curseurs. Vaut 0 tant que les reglages ne
    ;  sont pas separes : les valeurs vont alors partout, et il n'y a rien a
    ;  choisir.
    static vise := 0

    static logo := 0          ; le controle, pour le redessiner sans passer par c
    static teinte := 0        ; la valeur qu'il doit porter
    static ticLogo := 0
    static place := 0         ; ou reposer la fenetre lors d'une reconstruction

    ;--------------------------------------------------------------------------
    ;  Les deux premiers rappels prennent (valeur, ecran) : en mode separe,
    ;  l'apercu en direct doit se voir sur l'ecran qu'on regle, pas sur tous.
    static Ouvrir(surIntensite, surLuminosite, surRaccourcis, surLangue := 0) {
        if (Reglages.gui) {
            try WinActivate("ahk_id " . Reglages.gui.Hwnd)
            return
        }
        Reglages.surIntensite := surIntensite
        Reglages.surLuminosite := surLuminosite
        Reglages.surRaccourcis := surRaccourcis
        Reglages.surLangue := surLangue

        ;  On ouvre sur l'ecran de la fenetre qu'on vient de quitter -- le plus
        ;  souvent celui ou l'on travaille.
        Reglages.vise := Filtre.separes ? Ecrans.Actif() : 0
        Reglages._RelireValeurs()
        Reglages._Construire()
    }

    static _RelireValeurs() {
        v := Filtre.Lire(Reglages.vise)
        Reglages.intensite := v.i
        Reglages.luminosite := v.l
    }

    ;--------------------------------------------------------------------------
    ;  Changer de langue reconstruit la fenetre : plus simple et plus sur que de
    ;  retraduire chaque controle un par un.
    ;
    ;  Mais l'ordre compte. Detruire d'abord puis reconstruire laissait un trou
    ;  d'une seconde -- le bureau, puis une fenetre blanche le temps du premier
    ;  rendu : on voyait l'application se fermer et se rouvrir. On construit
    ;  donc la nouvelle a la place exacte de l'ancienne, on l'affiche, et on ne
    ;  detruit l'ancienne qu'ensuite : elle disparait derriere sa remplacante,
    ;  et il ne reste qu'un changement de textes.
    ;--------------------------------------------------------------------------
    static _Relangue(code) {
        I18n.Definir(code)
        Config.Ecrire("langue", code)
        ;  Les libelles de repli des ecrans ("Ecran 2") sont poses a
        ;  l'enumeration, dans la langue du moment : on la refait.
        Ecrans.Oublier()
        if (Reglages.surLangue)
            (Reglages.surLangue)()
        Reglages._Reconstruire()
    }

    static _Reconstruire() {
        if (!Reglages.gui)
            return

        ancien := Reglages.porteur
        Reglages.place := 0
        try {
            WinGetPos(&x, &y, , , "ahk_id " . ancien.fenetre.Hwnd)
            Reglages.place := { x: x, y: y }
        }

        Reglages.gui := 0
        Reglages.porteur := 0
        Reglages._Construire()

        Cadre.Detruire(ancien)
    }

    ;--------------------------------------------------------------------------
    ;  Separer les ecrans ne demande pas de reconstruction : le selecteur est
    ;  deja la, il change seulement d'etat. Mais il faut relire les valeurs --
    ;  en passant d'ensemble a separe, les curseurs cessent de montrer la
    ;  valeur commune pour montrer celle de l'ecran vise.
    ;--------------------------------------------------------------------------
    static _Separer(actif) {
        Config.Ecrire("separes", actif ? 1 : 0)
        Filtre.separes := actif && Ecrans.Nombre() > 1
        Reglages.vise := Filtre.separes ? Ecrans.Actif() : 0
        Reglages._Reconstruire()
    }

    ;--------------------------------------------------------------------------
    ;  Le selecteur d'ecran : une rangee de pastilles, une par ecran.
    ;
    ;  Chacune porte le nom du moniteur quand l'EDID en donne un, sinon
    ;  "Ecran 1", "Ecran 2" dans l'ordre de gauche a droite -- l'ordre ou on
    ;  les voit sur le bureau, qui est le seul que quelqu'un puisse relier a
    ;  ses ecrans reels.
    ;--------------------------------------------------------------------------
    static _Selecteur(g, x, y) {
        liste := Ecrans.Lister()
        boutons := []

        ;  ObjBindMethod et non une lambda : une lambda creee dans une boucle
        ;  capture la VARIABLE, pas sa valeur, et tous les boutons auraient
        ;  vise le dernier ecran de la liste.
        large := Min(140, (Reglages.L - 48) // liste.Length - 4)
        for i, e in liste {
            b := Bouton.Creer(g, x + (i - 1) * (large + 4), y, large, 26
                            , e.nom
                            , Filtre.separes && Reglages.vise
                              && Reglages.vise.id = e.id
                            , ObjBindMethod(Reglages, "_Viser", e))
            boutons.Push(b)
        }
        return boutons
    }

    static _Viser(ecran) {
        if (!Filtre.separes)
            return
        Reglages.vise := ecran
        Reglages._Reconstruire()
    }


    static _Construire() {
        c := Map()
        S := (k) => I18n.S(k)

        ;  Le contenu, a coordonnees fixes, vit dans une fenetre enfant que
        ;  le cadre centre et fait defiler (voir Cadre.ahk). Deux drapeaux
        ;  contre le scintillement, poses par le cadre, et il faut les deux :
        ;
        ;    WS_CLIPCHILDREN (0x02000000)    la fenetre cesse de repeindre son
        ;                                    fond sous ses controles
        ;    WS_EX_COMPOSITED (0x02000000)   elle est composee hors ecran avant
        ;                                    d'etre affichee
        ;
        ;  Le second seul ne suffit pas : sans le premier, le fond est efface
        ;  sous chaque Picture juste avant qu'elle ne se redessine, et un
        ;  curseur qu'on fait glisser vite bat visiblement.
        porteur := Cadre.Creer("Ocre", Reglages.L)
        g := porteur.contenu

        ;--- en-tete ----------------------------------------------------------
        c["logo"] := g.Add("Picture", "x24 y22 w40 h40")
        Blob.Poser(c["logo"], Reglages.intensite, 40)
        Reglages.logo := c["logo"]

        g.SetFont("s14 w600 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x78 y24 w200 h26", "Ocre")
        g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x78 y50 w240 h16", S("sous_titre"))

        c["fr"] := Drapeau.Creer(g, 376, 26, "fr", I18n.langue = "fr"
                               , (code) => Reglages._Relangue(code))
        c["en"] := Drapeau.Creer(g, 410, 26, "en", I18n.langue = "en"
                               , (code) => Reglages._Relangue(code))

        ;--- alerte -----------------------------------------------------------
        ;  Un filtre de Windows se cumule au notre ? Un bandeau rouge sous
        ;  l'en-tete, et tout le reste descend d'autant. Il n'existe que s'il
        ;  y a quelque chose a dire : le rouge doit rester un evenement.
        da := 0
        avis := Reglages._Alerte()
        if (avis != "") {
            da := 36
            c["alerte"] := Alerte.Creer(g, 24, 76, 416, 28, avis)
        }

        ;--- ecran ------------------------------------------------------------
        ;  Deux jauges de meme forme : le filtre, qui rechauffe, et la
        ;  luminosite, qui assombrit. La seconde est grise -- sa couleur ne
        ;  depend pas de la temperature choisie, et lui donner l'ocre du filtre
        ;  laisserait croire qu'elle le regle aussi.
        Reglages._Intitule(g, 24, 88 + da, S("ecran"))

        c["pct"] := 0
        c["pctLum"] := 0

        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y" . (112 + da) . " w70 h18", S("filtre"))
        c["curseur"] := Curseur.Creer(g, 92, 106 + da, 276, 26, Reglages.intensite
                                    , (v) => Reglages._Glisser(c, v))
        g.SetFont("s12 w600 c" . Theme.TEXTE, "Segoe UI")
        c["pct"] := g.Add("Text", "x376 y" . (110 + da) . " w64 h22 Right"
                        , Unite.Texte(Reglages.intensite))

        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y" . (144 + da) . " w70 h18", S("lum_court"))
        c["curseurLum"] := Curseur.Creer(g, 92, 138 + da, 276, 26, Reglages.luminosite
                                       , (v) => Reglages._GlisserLum(c, v)
                                       , 0, 100, Theme.TEXTE_BAS)
        g.SetFont("s12 w600 c" . Theme.TEXTE, "Segoe UI")
        c["pctLum"] := g.Add("Text", "x376 y" . (142 + da) . " w64 h22 Right"
                           , Reglages.luminosite . " %")

        ;  Les molettes se rappellent ici, sous les jauges qu'elles reglent,
        ;  plutot qu'au milieu de l'aide sur les raccourcis clavier : ce n'est
        ;  pas le meme geste, et cette aide-la etait deja pleine.
        g.SetFont("s7 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x24 y" . (170 + da) . " w416 h14"
            , Format(S("aide_molette")
                   , Raccourcis._Joli(Config.Lire("mol_filtre") . "WheelUp")
                   , Raccourcis._Joli(Config.Lire("mol_lum") . "WheelUp")))

        ;  Les fleches reglent le curseur vise, Tab passe de l'un a l'autre.
        ;  Le pas est celui des raccourcis, relu a chaque appui.
        Curseur.Clavier(g, () => Max(1, Config.LireNombre("pas")), porteur.fenetre.Hwnd)

        ;  La suite se place par rapport a l'alerte : dy cumule ce que les
        ;  sections optionnelles ajoutent.
        dy := da

        ;--- ecrans -----------------------------------------------------------
        ;  Cette section n'existe que s'il y a de quoi choisir. Sur une machine
        ;  a un seul ecran, une bascule "regler chaque ecran separement" et un
        ;  selecteur a une entree ne posent qu'une question sans objet -- et
        ;  volent trente points de hauteur a une fenetre qui n'en a plus. Elle
        ;  apparaitra d'elle-meme au branchement d'un second ecran, la fenetre
        ;  se reconstruisant a l'ouverture.
        if (Ecrans.Nombre() > 1) {
            Reglages._Intitule(g, 24, 186 + dy, S("ecrans"))

            c["separes"] := Bascule.Creer(g, 24, 204 + dy, Filtre.separes
                                        , (a) => Reglages._Separer(a))
            g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
            g.Add("Text", "x72 y" . (206 + dy) . " w368 h18", S("separer"))

            ;  Le selecteur d'ecran ne sert que separes : ensemble, les deux
            ;  curseurs vont partout et designer un ecran ne voudrait rien
            ;  dire. Il reste visible mais eteint, plutot que d'apparaitre et
            ;  disparaitre sous la bascule.
            c["choixEcran"] := Reglages._Selecteur(g, 24, 234 + dy)
            dy += 74
        }

        ;--- raccourcis -------------------------------------------------------
        ;  Les champs vivent dans leur fenetre (Raccourcis.ahk) : six champs,
        ;  deux molettes, l'aide et le test faisaient deux cents points, et
        ;  avec le bandeau d'alerte et deux ecrans la fenetre debordait sous
        ;  la barre des taches. Ici, une rangee, et le nombre de refus s'il y
        ;  en a -- c'est ce qu'on doit savoir sans ouvrir.
        Reglages._Intitule(g, 24, 186 + dy, S("raccourcis"))
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y" . (208 + dy) . " w200 h18", S("raccourcis_clavier"))
        c["raccourcis"] := Bouton.Creer(g, 228, 204 + dy, 212, 26, S("configurer"), false
                                      , () => Raccourcis.Ouvrir(Reglages.surRaccourcis))
        y := 216 + dy
        if (Raccourcis.refuses.Length) {
            g.SetFont("s7 w600 c" . Theme.ACCENT, "Segoe UI")
            g.Add("Text", "x24 y" . (y + 20) . " w416 h14"
                , S("refuses_n") . Raccourcis.refuses.Length)
            y += 16
        }

        ;--- comportement -----------------------------------------------------
        yb := y + 50
        Reglages._Intitule(g, 24, yb, S("comportement"))

        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y" . (yb + 30) . " w146 h18", S("pas"))
        c["pas"] := Compteur.Creer(g, 176, yb + 26, 92, 26
                                 , Max(1, Min(25, Config.LireNombre("pas"))), 1, 25, (v) => Reglages._Ecrire("pas", v))
        g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x278 y" . (yb + 30) . " w162 h18", S("points"))

        ;  La pastille et l'adoucissement des changements n'ont plus de bascule :
        ;  ils sont toujours actifs. Deux conforts sans contrepartie qu'un
        ;  interrupteur n'aidait qu'a eteindre par megarde.
        c["demarrage"] := Bascule.Creer(g, 24, yb + 66, Demarrage.Actif(), (a) => Reglages._Demarrage(c, a))
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x72 y" . (yb + 68) . " w368 h18", S("demarrage"))

        ;  Le retroeclairage materiel. Actif par defaut : sur un ecran externe
        ;  il vaut infiniment mieux que la rampe, qui ne fait qu'ecraser les
        ;  niveaux. La bascule existe pour le cas ou un moniteur reagit mal au
        ;  DDC/CI -- cela arrive, et il vaut mieux le couper que desinstaller.
        c["retro"] := Bascule.Creer(g, 24, yb + 98, Config.Lire("retro") = "1", (a) => Reglages._Ecrire("retro", a ? 1 : 0))
        g.Add("Text", "x72 y" . (yb + 100) . " w368 h18", S("retro"))

        ;  Le gris couple au filtre (voir Compositeur.ahk). Coupe par defaut : c'est
        ;  un gout, pas un reglage.
        c["gris"] := Bascule.Creer(g, 24, yb + 130, Config.Lire("gris") = "1", (a) => Reglages._Ecrire("gris", a ? 1 : 0))
        g.Add("Text", "x72 y" . (yb + 132) . " w238 h18", S("gris"))

        ;  Un bouton pour reposer le filtre de force. Un jeu plein ecran, une
        ;  sortie de veille ou un changement de mode couleur peut faire
        ;  disparaitre le filtre -- surtout le gris et la teinte du compositeur,
        ;  que le chien de garde ne surveille pas. Ce bouton vide les caches et
        ;  repose tout, sans avoir a redemarrer.
        c["reappliquer"] := Bouton.Creer(g, 316, yb + 128, 124, 24
                                       , S("reappliquer"), false
                                       , () => Filtre.Forcer())

        ;  Le noir profond, pour les dalles OLED (voir Gamma.Rampe) : une
        ;  bascule et le seuil sur la meme rangee. Le seuil se retient a part
        ;  ("noir_seuil") pour revenir a sa valeur quand on rallume.
        noir := Filtre.Noir()
        c["noir"] := Bascule.Creer(g, 24, yb + 162, noir > 0, (a) => Reglages._Noir(c, a))
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x72 y" . (yb + 164) . " w196 h18", S("noir"))
        c["noir_seuil"] := Compteur.Creer(g, 272, yb + 160, 84, 26
                                        , noir > 0 ? noir : Reglages._NoirRetenu(), 4, 64
                                        , (v) => Reglages._NoirSeuil(c, v), 4)
        g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x364 y" . (yb + 164) . " w76 h18", S("noir_unite"))

        ;  Les rangees suivantes descendent d'un cran.
        yn := yb + 32

        ;  Les trois prereglages du panneau ont leur fenetre, comme le
        ;  planificateur : trois rangees de compteurs n'auraient pas tenu ici.
        ;  Le rappel des 20-20-20 vit dans celle du planificateur, pour la
        ;  meme raison : la fenetre n'a plus de hauteur a donner.
        ;  Assombrir l'ecran qu'on ne regarde plus (voir Inactif.ahk) : la
        ;  bascule, et le nombre de minutes sur la meme rangee.
        c["inactif"] := Bascule.Creer(g, 24, yn + 162, Config.Lire("inactif") = "1", (a) => Reglages._Ecrire("inactif", a ? 1 : 0))
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x72 y" . (yn + 164) . " w196 h18", S("inactif"))
        c["inactif_minutes"] := Compteur.Creer(g, 272, yn + 160, 84, 26
                                             , Max(1, Config.LireNombre("inactif_minutes")), 1, 60
                                             , (v) => Reglages._Ecrire("inactif_minutes", v), 1)
        g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x364 y" . (yn + 164) . " w76 h18", S("minutes"))

        ;  Sur batterie, baisser la luminosite (voir Batterie.ahk) : la
        ;  rangee n'existe que sur une machine qui a une batterie. Les
        ;  suivantes descendent d'autant.
        db := 0
        if (Batterie.Presente()) {
            c["batterie"] := Bascule.Creer(g, 24, yn + 198, Config.Lire("batterie") = "1", (a) => Reglages._Ecrire("batterie", a ? 1 : 0))
            g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
            g.Add("Text", "x72 y" . (yn + 200) . " w196 h18", S("batterie"))
            c["batterie_pourcent"] := Compteur.Creer(g, 272, yn + 196, 84, 26
                                                   , Max(1, Config.LireNombre("batterie_pourcent")), 5, 100
                                                   , (v) => Reglages._Ecrire("batterie_pourcent", v), 5)
            g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
            g.Add("Text", "x364 y" . (yn + 200) . " w76 h18", "%")
            db := 36
        }

        ;  La luminosite qui suit le contenu de l'ecran (voir Adaptatif.ahk) :
        ;  la bascule, et les deux bornes sur la meme rangee.
        c["adaptatif"] := Bascule.Creer(g, 24, yn + db + 198, Config.Lire("adaptatif") = "1", (a) => Reglages._Ecrire("adaptatif", a ? 1 : 0))
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x72 y" . (yn + db + 200) . " w190 h18", S("adaptatif"))
        c["adapt_mini"] := Compteur.Creer(g, 262, yn + db + 196, 72, 26
                                        , Config.LireNombre("adapt_mini"), 0, 100, (v) => Reglages._Bornes(c), 5)
        g.SetFont("s8 w400 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x336 y" . (yn + db + 200) . " w22 h18 Center", S("adapt_a"))
        c["adapt_maxi"] := Compteur.Creer(g, 358, yn + db + 196, 72, 26
                                        , Config.LireNombre("adapt_maxi"), 0, 100, (v) => Reglages._Bornes(c), 5)
        g.Add("Text", "x432 y" . (yn + db + 200) . " w12 h18", "%")
        db += 36

        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y" . (yn + db + 202) . " w200 h18", S("prereglages"))
        c["prereglages"] := Bouton.Creer(g, 228, yn + db + 198, 212, 26, S("configurer"), false
                                       , () => Prereglages.Ouvrir())

        ;  Les habitudes apprises (voir Habitudes.ahk) : leur fenetre montre
        ;  ce qui a ete retenu, la bascule y est.
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x24 y" . (yn + db + 238) . " w200 h18", S("habitudes_titre"))
        c["habitudes"] := Bouton.Creer(g, 228, yn + db + 234, 212, 26, S("configurer"), false
                                     , () => Apprentissage.Ouvrir(() => Reglages._ApresHabitudes()))
        db += 36

        ;--- planificateur ----------------------------------------------------
        ;  Coupe par defaut : regler son filtre a la main est une preference
        ;  parfaitement legitime, et un programme qui bouge tout seul le
        ;  premier soir se fait desinstaller le lendemain.
        ;
        ;  Le detail -- soleil, lieu, heures, fondu -- vit dans sa propre
        ;  fenetre. Ce n'est pas un caprice de rangement : avec le mode
        ;  solaire, la fenetre atteignait 1244 pixels sur un ecran de 1200 a
        ;  150 % de mise a l'echelle, et ne tenait plus. Un horaire se regle
        ;  une fois et ne se retouche plus, alors que l'intensite et les
        ;  raccourcis se reprennent : c'etait le bon candidat au depart. La
        ;  bascule, elle, reste ici, ou elle se voit d'un coup d'oeil.
        yh := yn + db + 240
        Reglages._Intitule(g, 24, yh, S("planificateur"))

        c["horaire"] := Bascule.Creer(g, 24, yh + 18, Config.Lire("horaire") = "1", (a) => Reglages._Ecrire("horaire", a ? 1 : 0))
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
        g.Add("Text", "x72 y" . (yh + 20) . " w150 h18", S("suivre_horaire"))
        c["planif"] := Bouton.Creer(g, 228, yh + 16, 212, 26, S("configurer"), false
                                  , () => Planificateur.Ouvrir(() => Reglages._ApresPlanificateur(c)))

        ;--- boutons ----------------------------------------------------------
        ;  Ni Enregistrer ni Fermer : chaque commande s'applique a l'instant
        ;  ou on la touche, comme dans les reglages de Windows, et la fenetre
        ;  se ferme par sa croix ou par Echap. Restent ce qui touche au
        ;  fichier entier -- remise a zero derriere une confirmation, export,
        ;  import -- qui merite un geste explicite.
        yBtn := yh + 62
        c["tout"] := Bouton.Creer(g, 24, yBtn + 4, 100, 26, S("reset_tout"), false
                                , () => Reglages._ToutReinitialiser())
        c["exporter"] := Bouton.Creer(g, 130, yBtn + 4, 62, 26, S("exporter"), false
                                    , () => Reglages._Exporter())
        c["importer"] := Bouton.Creer(g, 198, yBtn + 4, 62, 26, S("importer"), false
                                    , () => Reglages._Importer())
        ;  A droite, seul : ce n'est pas un geste sur les reglages, c'est la
        ;  fenetre ou l'on cherche la version et de quoi signaler un probleme.
        c["apropos"] := Bouton.Creer(g, 338, yBtn + 4, 102, 26, S("apropos"), false
                                   , () => Apropos.Ouvrir())

        Reglages.gui := porteur.fenetre
        Reglages.porteur := porteur

        ;  La barre de titre passe au sombre AVANT le premier affichage (dans
        ;  Cadre.Montrer). Posee apres, elle apparaissait blanche le temps
        ;  que Windows la repeigne -- une seconde de bandeau clair a chaque
        ;  changement de langue, puisque la fenetre y est reconstruite. Une
        ;  reconstruction repose la fenetre ou elle etait : la recentrer la
        ;  ferait sauter sous la souris.
        place := Reglages.place
        Reglages.place := 0
        Cadre.Presenter(porteur, yBtn + 34, "reglages", () => Reglages.Fermer(), place)
    }

    static _Intitule(g, x, y, texte) {
        g.SetFont("s7 w600 c" . Theme.TEXTE_BAS, "Segoe UI")
        g.Add("Text", "x" . x . " y" . y . " w260 h14", texte)
        g.SetFont("s9 w400 c" . Theme.TEXTE, "Segoe UI")
    }

    ;--------------------------------------------------------------------------
    ;  Ce que le bandeau doit dire, ou rien.
    ;--------------------------------------------------------------------------
    static _Alerte() {
        apps := Concurrents.Programmes()
        if (apps != "")
            return Format(I18n.S("alerte_app"), apps)
        nl := Concurrents.NightLight()
        fc := Concurrents.FiltreCouleur()
        if (nl && fc)
            return I18n.S("alerte_deux")
        if (nl)
            return I18n.S("alerte_nl")
        if (fc)
            return I18n.S("alerte_fc")
        return ""
    }

    ;--------------------------------------------------------------------------
    ;  Le logo ne suit pas le curseur image par image.
    ;
    ;  Sa teinte bouge lentement -- il faut plusieurs points d'intensite pour la
    ;  voir changer -- alors qu'un glisser en demande soixante rendus par
    ;  seconde. Poser une icone sur un controle Picture le fait s'effacer puis
    ;  se redessiner : a cette cadence, il scintille. Un rendez-vous toutes les
    ;  60 ms le laisse suivre le geste sans battre.
    ;--------------------------------------------------------------------------
    static _Teinter(v) {
        Reglages.teinte := v
        if (!Reglages.ticLogo)
            Reglages.ticLogo := () => Reglages._PoserLogo()
        SetTimer(Reglages.ticLogo, -60)
    }

    static _PoserLogo() {
        if (Reglages.logo)
            Blob.Poser(Reglages.logo, Reglages.teinte, 40)
    }

    static _Glisser(c, v) {
        Reglages.intensite := v
        c["pct"].Text := Unite.Texte(v)
        Reglages._Teinter(v)
        if (Reglages.surIntensite)
            (Reglages.surIntensite)(v, Reglages.vise)
    }

    static _GlisserLum(c, v) {
        Reglages.luminosite := v
        c["pctLum"].Text := v . " %"
        if (Reglages.surLuminosite)
            (Reglages.surLuminosite)(v, Reglages.vise)
    }

    ;  Le planificateur a pu changer de mode : la bascule "suivre un horaire"
    ;  suit, sinon Enregistrer la reecrirait telle qu'elle etait.
    ;  La fenetre des habitudes a enregistre sa bascule : on relit tout.
    static _ApresHabitudes() {
        if (Reglages.surRaccourcis)
            (Reglages.surRaccourcis)()
    }

    static _ApresPlanificateur(c) {
        try Bascule.Definir(c["horaire"], Config.Lire("horaire") = "1")
        if (Reglages.surRaccourcis)
            (Reglages.surRaccourcis)()
    }

    ;--------------------------------------------------------------------------
    ;  Chaque commande ecrit sa cle et fait relire le programme -- avec un
    ;  temps de regroupement, pour qu'un compteur qu'on clique cinq fois de
    ;  suite ne relance pas cinq fois les raccourcis et la rampe.
    ;--------------------------------------------------------------------------
    static tic := 0

    static _Ecrire(cle, valeur) {
        Config.Ecrire(cle, valeur)
        Reglages._Planifier()
    }

    static _Planifier() {
        if (!Reglages.tic)
            Reglages.tic := () => Reglages._Appliquer()
        SetTimer(Reglages.tic, -300)
    }

    static _Appliquer() {
        if (Reglages.surRaccourcis)
            (Reglages.surRaccourcis)()
    }

    ;  Les bornes du suivi du contenu se remettent dans l'ordre si on les a
    ;  croisees.
    static _Bornes(c) {
        Config.Ecrire("adapt_mini", Min(c["adapt_mini"].valeur, c["adapt_maxi"].valeur))
        Config.Ecrire("adapt_maxi", Max(c["adapt_mini"].valeur, c["adapt_maxi"].valeur))
        Reglages._Planifier()
    }

    ;  Le noir profond : "noir" est le seuil en service (0 = coupe),
    ;  "noir_seuil" celui qu'on a choisi, garde pour le retrouver quand on
    ;  rallume. 28 par defaut : au-dessus du #191919 (25) de Notion et de
    ;  Discord, en dessous du #1E1E1E (30) de VS Code, que 32 prendrait
    ;  aussi -- mais chaque cran de plus bouche un peu plus les photos ; on
    ;  laisse choisir, par pas de 4.
    static _NoirRetenu() {
        v := Config.LireNombre("noir_seuil")
        return v > 0 ? Max(4, Min(64, v)) : 28
    }

    static _Noir(c, actif) {
        Config.Ecrire("noir", actif ? c["noir_seuil"].valeur : 0)
        Reglages._Planifier()
    }

    static _NoirSeuil(c, v) {
        Config.Ecrire("noir_seuil", v)
        if (c["noir"].actif) {
            Config.Ecrire("noir", v)
            Reglages._Planifier()
        }
    }

    ;  Le demarrage automatique peut etre refuse par Windows -- une tache
    ;  posee en administrateur ne se retire pas sans l'etre. Le dire, et
    ;  rendre a la bascule son vrai etat.
    static _Demarrage(c, actif) {
        if (Demarrage.Definir(actif))
            return
        MsgBox(I18n.S("demarrage_refuse"), "Ocre", 48)
        try Bascule.Definir(c["demarrage"], Demarrage.Actif())
    }

    ;--------------------------------------------------------------------------
    ;  Tout remettre a l'origine : le fichier de reglages est supprime, le
    ;  programme relit ses defauts, la fenetre se reconstruit. Le demarrage
    ;  automatique n'est pas touche -- c'est un etat de Windows, pas un
    ;  reglage d'Ocre, et il se retire de la bascule.
    ;--------------------------------------------------------------------------
    static _ToutReinitialiser() {
        if (MsgBox(I18n.S("reset_tout_confirmer"), "Ocre", 0x34) != "Yes")
            return
        Config.Vider()
        Config.attente := Map()
        try FileDelete(Config.FICHIER)
        Config.Oublier()
        Reglages._Recharger()
    }

    ;  Le fichier vient de changer sous nos pieds -- vide, ou remplace par
    ;  un import : on relit tout, comme apres Enregistrer, et on rebatit la
    ;  fenetre, dont la langue a pu changer.
    static _Recharger() {
        I18n.Definir(Config.Lire("langue"))
        if (Reglages.surLangue)
            (Reglages.surLangue)()
        if (Reglages.surRaccourcis)
            (Reglages.surRaccourcis)()

        Reglages.vise := 0
        Reglages._RelireValeurs()
        Reglages._Reconstruire()
    }

    ;  Export et import : une copie d'ocre.ini dans les deux sens. Les
    ;  boites de dialogue sont celles de Windows -- une fenetre peinte a la
    ;  main n'a rien a gagner a redessiner un explorateur de fichiers.
    static _Exporter() {
        Reglages.gui.Opt("+OwnDialogs")
        chemin := FileSelect("S16", A_MyDocuments . "\ocre.ini", I18n.S("exporter_titre")
                           , "ocre.ini (*.ini)")
        if (chemin = "")
            return
        if (SubStr(chemin, -4) != ".ini")
            chemin .= ".ini"
        try Config.Exporter(chemin)
        catch as e
            MsgBox(e.Message, "Ocre", 0x30)
    }

    static _Importer() {
        Reglages.gui.Opt("+OwnDialogs")
        chemin := FileSelect(1, A_MyDocuments, I18n.S("importer_titre"), "ocre.ini (*.ini)")
        if (chemin = "")
            return
        pris := false
        try pris := Config.Importer(chemin)
        catch as e
            MsgBox(e.Message, "Ocre", 0x30)
        if (!pris) {
            MsgBox(I18n.S("importer_refus"), "Ocre", 0x30)
            return
        }
        Reglages._Recharger()
    }

    static Fermer() {
        if (Reglages.ticLogo) {
            SetTimer(Reglages.ticLogo, 0)
            Reglages.ticLogo := 0
        }
        Reglages.logo := 0
        if (Reglages.porteur) {
            Cadre.Detruire(Reglages.porteur)
            Reglages.porteur := 0
            Reglages.gui := 0
        }
    }
}
