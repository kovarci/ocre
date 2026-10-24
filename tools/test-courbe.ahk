;  test-courbe.ahk -- la courbe du filtre tient-elle ses promesses ?
;
;  Purement arithmetique : rien n'est pose sur l'ecran, aucun materiel n'est
;  interroge, et le test peut donc tourner n'importe ou. Il verifie les
;  proprietes dont le reste du programme depend sans jamais les revalider :
;  que 0 % est exactement l'identite, que la courbe ne remonte jamais, que les
;  bornes tiennent. Ce sont les plus faciles a casser en retouchant la courbe,
;  et les plus difficiles a voir a l'oeil.
;
;  Le rapport part sur la sortie standard et dans courbe-out.txt : ecrire sur
;  la seule sortie standard ne suffit pas, AutoHotkey n'y met rien quand elle
;  est redirigee vers un fichier plutot que vers un tube. Le code de retour
;  vaut 0 ou 1, pour un usage automatise.

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\lib\Gamma.ahk
#Include %A_LineFile%\..\..\lib\Retro.ahk
#Include %A_LineFile%\..\..\lib\Horaire.ahk
#Include %A_LineFile%\..\..\lib\Config.ahk
#Include %A_LineFile%\..\..\lib\Filtre.ahk

rates := 0
total := 0
rapport := ""

;  Une erreur ne doit pas ouvrir de boite de dialogue : le test peut tourner
;  sans personne devant l'ecran, et une boite l'y ferait attendre indefiniment.
OnError(Rapporter)
Rapporter(e, mode) {
    Dire("")
    Dire("  ERREUR  " . e.Message)
    Dire("          " . e.File . " ligne " . e.Line)
    Ecrire()
    ExitApp(1)
    return -1
}

Dire(s) {
    global rapport
    rapport .= s . "`r`n"
    try FileAppend(s . "`r`n", "*")
}

Ecrire() {
    global rapport
    f := A_ScriptDir . "\courbe-out.txt"
    try FileDelete(f)
    try FileAppend(rapport, f, "UTF-8")
}

Verifier(nom, condition, detail := "") {
    global rates, total
    total += 1
    if (condition) {
        Dire("  ok    " . nom)
        return
    }
    rates += 1
    Dire("  RATE  " . nom . (detail != "" ? "   -> " . detail : ""))
}

;  Deux flottants calcules par des chemins differents ne sont jamais egaux au
;  bit pres : on compare a une tolerance.
Proche(a, b, eps := 0.000001) {
    return Abs(a - b) <= eps
}

Dire("")
Dire("Ocre -- verification de la courbe")
Dire("")

;--- l'identite a 0 % ---------------------------------------------------------
;  Sans la normalisation par la reference a 6500 K, le modele brut laisse un
;  residu chaud a intensite nulle : filtre coupe, l'ecran ne serait pas neutre.
c0 := Gamma.Multiplicateurs(0)
Verifier("0 % laisse le rouge intact", Proche(c0.r, 1.0), Round(c0.r, 6))
Verifier("0 % laisse le vert intact",  Proche(c0.g, 1.0), Round(c0.g, 6))
Verifier("0 % laisse le bleu intact",  Proche(c0.b, 1.0), Round(c0.b, 6))

;--- le rouge n'est jamais retranche ------------------------------------------
;  Toute la course reste sous 6600 K, ou le modele tient le rouge a 255. Si ce
;  n'etait plus vrai, le filtre assombrirait au lieu de rechauffer.
rougeConstant := true
p := 0
while (p <= 100) {
    if (!Proche(Gamma.Multiplicateurs(p).r, 1.0))
        rougeConstant := false
    p += 1
}
Verifier("le rouge reste a 1.0 sur toute la course", rougeConstant)

;--- monotonie ----------------------------------------------------------------
;  Un cran de plus doit toujours rechauffer davantage. Une courbe qui remonte,
;  meme d'un millieme, donne un raccourci qui semble parfois faire l'inverse.
vertDecroit := true
bleuDecroit := true
precedent := Gamma.Multiplicateurs(0)
p := 1
while (p <= 100) {
    c := Gamma.Multiplicateurs(p)
    if (c.g > precedent.g + 0.000001)
        vertDecroit := false
    if (c.b > precedent.b + 0.000001)
        bleuDecroit := false
    precedent := c
    p += 1
}
Verifier("le vert ne remonte jamais", vertDecroit)
Verifier("le bleu ne remonte jamais", bleuDecroit)

;--- la butee haute -----------------------------------------------------------
c100 := Gamma.Multiplicateurs(100)
Verifier("100 % eteint completement le bleu", Proche(c100.b, 0.0), Round(c100.b, 6))
Verifier("100 % laisse un peu de vert", c100.g > 0.05 && c100.g < 0.25
       , Round(c100.g, 4))

;--- les bornes ---------------------------------------------------------------
;  Les raccourcis appellent la courbe avec des valeurs hors bornes : c'est elle
;  qui doit les ramener, pas l'appelant.
cm := Gamma.Multiplicateurs(-40)
cp := Gamma.Multiplicateurs(180)
Verifier("une intensite negative vaut 0 %", Proche(cm.b, c0.b))
Verifier("une intensite au-dela de 100 vaut 100 %", Proche(cp.b, c100.b))

;--- la luminosite ------------------------------------------------------------
;  La repartition entre le retroeclairage et la rampe (voir Retro.ahk) est
;  interrogee sur un ecran fictif : Retro.Repartir ne touche a rien tant qu'on
;  ne lui demande pas de poser, et un ecran sans HMONITOR ni entree en cache
;  est traite comme depourvu de retroeclairage pilotable -- ce qui est
;  precisement le cas a verifier ici.
faux := { id: "test-sans-retroeclairage", hmon: 0 }

Verifier("100 de luminosite ne change rien"
       , Proche(Retro.Repartir(faux, 100, Gamma.PLANCHER_LUM).gamma, 1.0))
Verifier("la luminosite ne descend pas sous le plancher"
       , Proche(Retro.Repartir(faux, 0, Gamma.PLANCHER_LUM).gamma, Gamma.PLANCHER_LUM)
       , Round(Retro.Repartir(faux, 0, Gamma.PLANCHER_LUM).gamma, 4))
Verifier("la luminosite ne depasse pas 1.0"
       , Proche(Retro.Repartir(faux, 400, Gamma.PLANCHER_LUM).gamma, 1.0))

;  Sans retroeclairage pilotable, la rampe reprend toute la course : le bas du
;  curseur doit vouloir dire "aussi sombre que possible" sur toute machine.
Verifier("la course est monotone"
       , Retro.Repartir(faux, 25, Gamma.PLANCHER_LUM).gamma
         > Retro.Repartir(faux, 10, Gamma.PLANCHER_LUM).gamma)

;  Le facteur multiplie les trois canaux a l'identique : c'est ce qui garantit
;  que baisser la luminosite ne deplace pas la teinte.
cRef := Gamma.Multiplicateurs(50)
f := Retro.Repartir(faux, 60, Gamma.PLANCHER_LUM).gamma
cf := Gamma.Couleur(50, f)
Verifier("la luminosite ne deplace pas la teinte"
       , Proche(cf.r / cRef.r, cf.b / cRef.b))

;--- la rampe posee -----------------------------------------------------------
;  256 entrees par canal, croissantes, jamais au-dela de 65535 : une rampe qui
;  ne respecte pas cela est refusee par le pilote, ou pire, acceptee et rendue
;  n'importe comment.
Entree(ramp, voie, i) {
    return NumGet(ramp, (voie * 256 + i) * 2, "UShort")
}

ramp := Gamma.Rampe(Gamma.Multiplicateurs(0))
Verifier("rampe neutre : premiere entree a 0", Entree(ramp, 0, 0) = 0)
Verifier("rampe neutre : derniere entree a 65280", Entree(ramp, 0, 255) = 65280
       , Entree(ramp, 0, 255))

croissante := true
plafond := true
for niveau in [0, 25, 50, 75, 100] {
    r := Gamma.Rampe(Gamma.Multiplicateurs(niveau))
    canal := 0
    while (canal <= 2) {
        i := 1
        while (i <= 255) {
            if (Entree(r, canal, i) < Entree(r, canal, i - 1))
                croissante := false
            if (Entree(r, canal, i) > 65535)
                plafond := false
            i += 1
        }
        canal += 1
    }
}
Verifier("la rampe est croissante sur les trois canaux", croissante)
Verifier("la rampe ne depasse jamais 65535", plafond)

;--- le noir profond ------------------------------------------------------------
;  Tout niveau au plus egal au seuil est eteint, le blanc reste le blanc, et
;  la rampe reste croissante -- sans quoi Windows la refuserait.
noir := Gamma.Rampe({ r: 1.0, g: 1.0, b: 1.0 }, 28)
Verifier("noir profond : le niveau 0 est eteint", Entree(noir, 0, 0) = 0)
Verifier("noir profond : le seuil (28) est eteint", Entree(noir, 2, 28) = 0)
Verifier("noir profond : juste au-dessus, on rallume", Entree(noir, 2, 29) > 0 && Entree(noir, 2, 29) < 600)
Verifier("noir profond : le blanc reste le blanc", Entree(noir, 1, 255) = 65280, Entree(noir, 1, 255))
croissante := true
Loop 255 {
    if (Entree(noir, 2, A_Index) < Entree(noir, 2, A_Index - 1))
        croissante := false
}
Verifier("noir profond : la rampe reste croissante", croissante)
Verifier("noir profond : le sommet ne trahit rien (le chien de garde relit le seuil)"
       , Entree(noir, 2, 255) = Entree(ramp, 2, 255))
Verifier("sans seuil, la rampe est celle d'avant", Entree(Gamma.Rampe({ r: 1.0, g: 1.0, b: 1.0 }, 0), 2, 28) = 28 * 256)
m := Compositeur.NoirProfond(28)
Verifier("la matrice du compositeur eteint le seuil", Abs(m[1] * 28 / 255.0 + m[21]) < 0.0001, m[1] * 28 / 255.0 + m[21])
Verifier("... et garde le blanc", Abs(m[1] + m[21] - 1.0) < 0.0001, m[1] + m[21])
Verifier("... et vaut l'identite a zero", Compositeur.NoirProfond(0)[21] = 0)
;  Sans contexte, la pose echoue proprement -- mais la signature a trois
;  parametres est exercee : Filtre.Appliquer n'est jamais joue ici, il
;  touche l'ecran, et une signature oubliee a deja fait planter l'instance.
leve := false
try Gamma.Poser(0, { r: 1.0, g: 1.0, b: 1.0 }, 28)
catch
    leve := true
Verifier("Gamma.Poser accepte le seuil du noir profond", !leve)

;--- le chien de garde --------------------------------------------------------
;  Il compare le bleu relu au bleu attendu avec une tolerance de 256. Si deux
;  intensites voisines tiennent dans cette tolerance, il ne verrait pas une
;  rampe remise a plat par Windows.
Bleu(p, lum := 100) {
    return Gamma.BleuAttendu(
        Gamma.Couleur(p, Retro.Repartir({ id: "test", hmon: 0 }, lum
                                      , Gamma.PLANCHER_LUM).gamma))
}

Verifier("le bleu attendu a 0 % est celui de la rampe neutre"
       , Bleu(0) = 65280, Bleu(0))
Verifier("une remise a plat est detectable des 1 %"
       , Abs(65280 - Bleu(1)) > 256, Bleu(1))
Verifier("un assombrissement seul est detectable"
       , Abs(65280 - Bleu(0, 95)) > 256, Bleu(0, 95))

;--- le planificateur ---------------------------------------------------------
;  Cible() est arithmetique elle aussi : on lui pose les bornes a la main
;  plutot que de passer par la configuration, et on interroge la journee heure
;  par heure. Le passage de minuit est le cas ou un calcul naif se trompe.
Horaire.debut := 21 * 60
Horaire.fin := 7 * 60
Horaire.fondu := 180
Horaire.nuit := 60
Horaire.jour := 0

Cible(h, m := 0) {
    return Horaire.Cible(h * 60 + m)
}

Verifier("a 21:00 le fondu demarre a l'intensite de jour"
       , Proche(Cible(21).valeur, 0, 0.01))
Verifier("a 22:30 le fondu est a mi-chemin"
       , Proche(Cible(22, 30).valeur, 30, 0.01), Round(Cible(22, 30).valeur, 2))
Verifier("a minuit le fondu est termine"
       , Proche(Cible(0).valeur, 60, 0.01), Round(Cible(0).valeur, 2))
Verifier("a 3:00 la nuit tient", Proche(Cible(3).valeur, 60, 0.01))
Verifier("a 7:00 la descente demarre a l'intensite de nuit"
       , Proche(Cible(7).valeur, 60, 0.01))
Verifier("a 8:30 la descente est a mi-chemin"
       , Proche(Cible(8, 30).valeur, 30, 0.01), Round(Cible(8, 30).valeur, 2))
Verifier("a 10:00 la descente est terminee", Proche(Cible(10).valeur, 0, 0.01))
Verifier("a 20:00 le jour tient encore", Proche(Cible(20).valeur, 0, 0.01))

Verifier("la phase de nuit est reconnue", Cible(23).phase = "n")
Verifier("la phase de jour est reconnue", Cible(12).phase = "j")

;  Une heure illisible ne doit pas passer pour minuit : ce serait un reglage
;  d'apparence volontaire, et le filtre basculerait a une heure absurde.
Verifier("une heure valide est lue", Horaire.EnMinutes("21:00", 0) = 1260)
Verifier("une heure sans zero initial est lue", Horaire.EnMinutes("7:5", 0) = 425)
Verifier("une heure illisible retombe sur le defaut"
       , Horaire.EnMinutes("plus tard", 99) = 99)
Verifier("une heure impossible retombe sur le defaut"
       , Horaire.EnMinutes("25:00", 99) = 99)
Verifier("l'heure se reecrit telle quelle", Horaire.EnTexte(1260) = "21:00")

;--- la configuration ---------------------------------------------------------
;  Config.Ecrire a longtemps appele attente.Delete sans condition. Map.Delete
;  leve quand la cle est absente -- ce qu'elle est presque toujours -- et toute
;  ecriture immediate plantait : changer de langue, couper le filtre,
;  enregistrer les reglages. Rien ne le voyait, parce que rien ici ne touchait
;  au fichier de configuration.
;
;  On detourne Config vers un fichier d'essai : ces verifications ne doivent
;  jamais approcher la vraie configuration de l'utilisateur.
Config.DOSSIER := A_Temp . "\ocre-essai"
Config.FICHIER := Config.DOSSIER . "\essai.ini"
try FileDelete(Config.FICHIER)

leve := false
try Config.Ecrire("essai", 1)
catch
    leve := true
Verifier("une ecriture sur une cle jamais differee ne leve pas", !leve)
Verifier("ce qui est ecrit se relit", Config.Lire("essai") = "1")

Config.EcrireDiffere("essai", 2)
Verifier("une ecriture differee se relit avant d'etre posee"
       , Config.Lire("essai") = "2", Config.Lire("essai"))
Verifier("le fichier, lui, porte encore l'ancienne valeur"
       , IniRead(Config.FICHIER, "ocre", "essai", "") = "1")

Config.Vider()
Verifier("apres vidange, le fichier porte la nouvelle valeur"
       , IniRead(Config.FICHIER, "ocre", "essai", "") = "2")

;  Une ecriture immediate doit annuler celle qui attendait sur la meme cle,
;  sinon l'ancienne valeur reviendrait 200 ms plus tard.
Config.EcrireDiffere("essai", 3)
Config.Ecrire("essai", 4)
Config.Vider()
Verifier("une ecriture immediate annule celle qui attendait"
       , IniRead(Config.FICHIER, "ocre", "essai", "") = "4"
       , IniRead(Config.FICHIER, "ocre", "essai", ""))

Verifier("une cle inconnue retombe sur son defaut"
       , Config.Lire("h_fondu") = "180", Config.Lire("h_fondu"))

;--- les valeurs relues au demarrage -------------------------------------------
;  Zero est une valeur, pas une absence : une luminosite au plancher ou un
;  ecran coupe seul doivent revenir tels quels. Seule une cle absente ou
;  illisible retombe sur le defaut.
Config.Ecrire("luminosite", 0)
Verifier("une luminosite a zero se relit a zero", Filtre._Borne("luminosite", 100) = 0)
Config.Ecrire("luminosite", "abc")
Verifier("une luminosite illisible retombe sur le defaut", Filtre._Borne("luminosite", 100) = 100)
Verifier("une cle absente retombe sur le defaut", Filtre._Borne("jamais_ecrite", 42) = 42)
Config.Ecrire("luminosite", 250)
Verifier("les bornes tiennent a la relecture", Filtre._Borne("luminosite", 100) = 100)

;--- la suspension de l'horaire ------------------------------------------------
;  Un reglage a la main suspend l'horaire jusqu'au basculement suivant. Une
;  relecture des reglages qui ne touche pas a l'horaire -- n'importe quelle
;  bascule de la fenetre -- ne doit pas le faire reprendre ; un changement
;  de l'horaire lui-meme, si.
Config.Ecrire("horaire", 1)
Config.Ecrire("h_soleil", 0)
Config.Ecrire("h_nuit", 60)
poses := []
Horaire.Init((v) => poses.Push(v), () => 50)
Horaire.Suspendre()
Verifier("un reglage a la main suspend l'horaire", Horaire.Suspendu())
Horaire.Relire()
Verifier("une relecture sans changement d'horaire le laisse suspendu", Horaire.Suspendu())
Config.Ecrire("h_nuit", 70)
Horaire.Relire()
Verifier("un changement de l'horaire lui-meme le fait reprendre", !Horaire.Suspendu())
Config.Ecrire("horaire", 0)
Horaire.Relire()

;--- le code materiel d'un ecran ----------------------------------------------
;  C'est ce qui apparie la dalle du portable au nom d'instance WMI.
Verifier("le code materiel se lit dans l'identifiant du moniteur"
       , Retro._CodeMateriel("MONITOR\SDC41B5\{4d36e96e-e325-11ce-bfc1-08002be10318}\0001") = "SDC41B5")
Verifier("... et dans le nom d'instance WMI"
       , Retro._CodeMateriel("DISPLAY\SDC41B5\4&2c6a8b6&0&UID8388688_0") = "SDC41B5")
Verifier("un nom d'affichage n'en a pas", Retro._CodeMateriel("\\.\DISPLAY1") = "")

;--- la version ----------------------------------------------------------------
;  Compile, la version des ressources a quatre nombres ; on ote le quatrieme
;  s'il est nul pour retomber sur l'ecriture de la directive SetVersion.
Version(v) {
    return RegExReplace(v, "^(\d+\.\d+\.\d+)\.0$", "$1")
}
Verifier("1.3.0.0 se lit 1.3.0", Version("1.3.0.0") = "1.3.0", Version("1.3.0.0"))
Verifier("1.3.1.0 se lit 1.3.1", Version("1.3.1.0") = "1.3.1")
Verifier("2.0.0.0 se lit 2.0.0", Version("2.0.0.0") = "2.0.0")

try FileDelete(Config.FICHIER)
try DirDelete(Config.DOSSIER)

Dire("")
Dire(rates = 0
   ? Format("  {} verifications, aucune erreur.", total)
   : Format("  {} verifications, {} ERREURS.", total, rates))
Dire("")

Ecrire()
ExitApp(rates = 0 ? 0 : 1)
