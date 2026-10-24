;  test-cli.ahk -- ce qui a ete ajoute en 1.3 tient-il ses promesses ?
;
;  Les Kelvin, l'unite, la sinusoide du rappel, la normalisation des
;  raccourcis, la lecture des prereglages : du calcul pur, verifie sans
;  materiel. Puis la ligne de commande elle-meme, lancee en sous-processus,
;  jugee sur son code de retour -- ces essais-la ne tournent que si une
;  console est la pour recevoir ce qu'Ocre y ecrit ; par double-clic, on les
;  saute plutot que d'ouvrir des boites.
;
;  Le rapport part sur la sortie standard et dans cli-out.txt ; le code de
;  retour vaut 0 ou 1.

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\lib\Gamma.ahk
#Include %A_LineFile%\..\..\lib\Unite.ahk
#Include %A_LineFile%\..\..\lib\Rappel.ahk
#Include %A_LineFile%\..\..\lib\Raccourcis.ahk
#Include %A_LineFile%\..\..\lib\Prereglages.ahk
#Include %A_LineFile%\..\..\lib\Config.ahk
#Include %A_LineFile%\..\..\lib\Villes.ahk
#Include %A_LineFile%\..\..\lib\Inactif.ahk
#Include %A_LineFile%\..\..\lib\Fuseau.ahk
#Include %A_LineFile%\..\..\lib\Osd.ahk
#Include %A_LineFile%\..\..\lib\Batterie.ahk
#Include %A_LineFile%\..\..\lib\Blob.ahk
#Include %A_LineFile%\..\..\lib\Adaptatif.ahk
#Include %A_LineFile%\..\..\lib\Habitudes.ahk

rates := 0
total := 0
rapport := ""

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
    f := A_ScriptDir . "\cli-out.txt"
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

;  Jamais la vraie configuration.
Config.DOSSIER := A_Temp . "\ocre-essai"
Config.FICHIER := Config.DOSSIER . "\essai.ini"
try FileDelete(Config.FICHIER)

Dire("")
Dire("Ocre -- verification de la 1.3")
Dire("")

;------------------------------------------------------------------ Kelvin ----
Verifier("0 % vaut 6500 K", Gamma.Kelvin(0) = 6500, Gamma.Kelvin(0))
Verifier("100 % vaut 1200 K", Gamma.Kelvin(100) = 1200, Gamma.Kelvin(100))
Verifier("6500 K vaut 0 %", Gamma.Intensite(6500) = 0)
Verifier("1200 K vaut 100 %", Gamma.Intensite(1200) = 100)
Verifier("3400 K tombe entre 58 et 59 %", Gamma.Intensite(3400) = 58 || Gamma.Intensite(3400) = 59
       , Gamma.Intensite(3400))
allerRetour := true
Loop 101 {
    p := A_Index - 1
    if (Abs(Gamma.Intensite(Gamma.Kelvin(p)) - p) > 1)
        allerRetour := false
}
Verifier("% -> K -> % revient a un point pres sur toute la course", allerRetour)
Verifier("un Kelvin hors bornes est ramene", Gamma.Intensite(99999) = 0 && Gamma.Intensite(-5) = 100)

;------------------------------------------------------------------- unite ----
Config.Ecrire("unite", "pct")
Verifier("en pour cent, 40 s'ecrit '40 %'", Unite.Texte(40) = "40 %", Unite.Texte(40))
Unite.Basculer()
Verifier("basculer passe en Kelvin", Unite.Kelvin())
Verifier("en Kelvin, 40 s'ecrit '4380 K'", Unite.Texte(40) = "4380 K", Unite.Texte(40))
Verifier("six caracteres au plus, pour la pastille", StrLen(Unite.Texte(100)) <= 6 && StrLen(Unite.Texte(0)) <= 6)
Unite.Basculer()
Verifier("rebasculer revient en pour cent", !Unite.Kelvin())

;------------------------------------------------------------------ rappel ----
;  La sinusoide, rejouee sans minuteur : on appelle _Image a des instants
;  choisis en posant debut nous-memes.
echelles := []
Rappel.respirer := (e) => echelles.Push(e)
Rappel.permis := () => true
Rappel.tac := () => 0                   ; fait croire a une respiration en cours
Rappel.debut := A_TickCount
Rappel._Image()
Verifier("la respiration part de la taille normale", Abs(echelles[1] - 1.0) < 0.02, echelles[1])
mini := 2, maxi := 0
Loop 100 {
    Rappel.debut := A_TickCount - Round(Rappel.CYCLE * (A_Index - 1) / 100)
    Rappel.tac := () => 0
    Rappel._Image()
    e := echelles[echelles.Length]
    mini := Min(mini, e), maxi := Max(maxi, e)
}
Verifier("elle descend jusqu'a MINI", Abs(mini - Rappel.MINI) < 0.02, mini)
Verifier("elle monte jusqu'a MAXI", Abs(maxi - Rappel.MAXI) < 0.02, maxi)
Verifier("MAXI ne depasse pas ce que Blob sait dessiner", Rappel.MAXI <= 1.12)
Rappel.tac := () => 0
Rappel.debut := A_TickCount - Rappel.CYCLES * Rappel.CYCLE - 1
Rappel._Image()
Verifier("au bout des cycles, l'icone est rendue (-1)", echelles[echelles.Length] = -1)
Rappel.permis := () => false
Rappel.tac := () => 0
Rappel.debut := A_TickCount
Rappel._Image()
Verifier("filtre coupe, la respiration s'arrete sur-le-champ", echelles[echelles.Length] = -1)

;-------------------------------------------------------------- raccourcis ----
Verifier("les modificateurs se normalisent dans un ordre fixe"
       , Raccourcis._Normal("!^F5") = Raccourcis._Normal("^!F5"))
Verifier("BS et Backspace sont la meme touche"
       , Raccourcis._Normal("^!BS") = Raccourcis._Normal("^!Backspace"))
Verifier("la casse de la touche ne compte pas"
       , Raccourcis._Normal("^f5") = Raccourcis._Normal("^F5"))
Verifier("deux raccourcis differents restent differents"
       , Raccourcis._Normal("^F5") != Raccourcis._Normal("^F6"))
Verifier("'Ctrl + Alt + Entree' se lit bien (avec son accent)", Raccourcis._Joli("^!Enter") = "Ctrl + Alt + Entr" . Chr(0xE9) . "e"
       , Raccourcis._Joli("^!Enter"))
I18n.Definir("en")
Verifier("en anglais, Maj devient Shift", Raccourcis._Joli("+F5") = "Shift + F5", Raccourcis._Joli("+F5"))
I18n.Definir("fr")
Verifier("une molette inconnue retombe sur le defaut", Raccourcis._Molette("zzz", "^!") = "^!")

;------------------------------------------------------------- prereglages ----
Config.Ecrire("pre_film", "15,70")
v := Prereglages.Lire("pre_film")
Verifier("'15,70' donne 15 et 70", v.i = 15 && v.l = 70)
Config.Ecrire("pre_film", "n'importe quoi")
v := Prereglages.Lire("pre_film")
Verifier("une valeur illisible retombe sur le defaut de la cle", v.i = 15 && v.l = 70)
Config.Ecrire("pre_film", "150,-3")
v := Prereglages.Lire("pre_film")
Verifier("les bornes tiennent", v.i = 100 && v.l = 0)

;----------------------------------------------------------------- inactif ----
;  L'inactivite ne se simule pas ; on abaisse le seuil a zero et on regarde
;  que les deux rappels sont appeles dans le bon ordre.
journal := []
Inactif.assombrir := (d) => journal.Push("sombre " . d)
Inactif.eclaircir := (d) => journal.Push("clair " . d)
Inactif.actif := true
Inactif.minutes := 0
Inactif.PERIODE := 0        ; sinon un geste de l'utilisateur pendant le test "reveillerait"
Inactif.assombri := false
Inactif._Battre()
Verifier("seuil atteint : on assombrit en fondu"
       , journal.Length = 1 && journal[1] = "sombre " . Inactif.FONDU
       , journal.Length ? journal[journal.Length] : "rien")
Inactif._Battre()
Verifier("deja assombri : on n'assombrit pas deux fois", journal.Length = 1)
Inactif.Rendre(0)
Verifier("Rendre(0) remonte d'un coup", journal.Length = 2 && journal[2] = "clair 0")
Inactif.Rendre(0)
Verifier("Rendre sans assombrissement ne fait rien", journal.Length = 2)
Verifier("le fondu est plus long que celui de la bascule", Inactif.FONDU >= 1000)

;------------------------------------------------------------------ villes ----
;  La table vit desormais dans un fichier lu a la demande : elle doit encore
;  se lire, et se chercher.
t0 := A_TickCount
r := Villes.Chercher("paris")
Verifier("'paris' donne Paris en premier", r.Length && r[1].nom = "Paris" && r[1].pays = "FR"
       , r.Length ? r[1].nom : "rien")
Verifier("la table compte plus de 26 000 villes", StrLen(Villes.TABLE) > 600000, StrLen(Villes.TABLE))
r := Villes.Chercher("geneve")
Verifier("'geneve' trouve Geneva par l'exonyme", r.Length && r[1].nom = "Geneva", r.Length ? r[1].nom : "rien")
r := Villes.Chercher("lyon, fr")
Verifier("'lyon, fr' restreint au pays", r.Length && r[1].pays = "FR")
Verifier("'zzzzzz' ne trouve rien", Villes.Chercher("zzzzzz").Length = 0)

;  Chaque ville de la table des fuseaux doit exister telle quelle : une
;  faute de frappe ici laisserait le mode solaire sans lieu en silence.
manquantes := ""
for nomFuseau, ville in Fuseau.VILLES {
    r := Villes.Chercher(ville, 1)
    if (!r.Length || r[1].nom != ville)
        manquantes .= (manquantes != "" ? ", " : "") . ville
}
Verifier("toutes les villes des fuseaux existent dans la table", manquantes = "", manquantes)
Verifier("le fuseau de cette machine donne une ville ou rien, sans erreur"
       , Fuseau.Lieu() = 0 || Fuseau.Lieu().nom != "", Fuseau.Nom())

;----------------------------------------------------------- export, import --
Config.Ecrire("intensite", 42)
Config.Ecrire("langue", "en")
copie := Config.DOSSIER . "\copie.ini"
Config.Exporter(copie)
Verifier("l'export ecrit une copie du fichier", FileExist(copie) != "")
Verifier("la copie porte les valeurs en attente", IniRead(copie, "ocre", "intensite", "") = "42")

Config.Ecrire("intensite", 7)
Config.Ecrire("langue", "fr")
Verifier("l'import d'un fichier sans section [ocre] est refuse"
       , !Config.Importer(A_LineFile) && Config.Lire("intensite") = 7)
vide := Config.DOSSIER . "\vide.ini"
try FileDelete(vide)
FileAppend("[autre]`r`nx=1`r`n", vide)
Verifier("l'import d'une section [ocre] vide est refuse", !Config.Importer(vide))
Verifier("l'import de la copie est pris", Config.Importer(copie))
Verifier("le fichier importe fait foi, meme sur ce qui attendait"
       , Config.Lire("intensite") = "42" && Config.Lire("langue") = "en"
       , Config.Lire("intensite") . " " . Config.Lire("langue"))
try FileDelete(copie)
try FileDelete(vide)

;---------------------------------------------------------------- pastille ----
Verifier("la pastille est permise par defaut", Osd.Permise())
Osd.Basculer()
Verifier("basculer la coupe", !Osd.Permise() && Config.Lire("pastille") = "0")
Osd.Basculer()
Verifier("rebasculer la rend", Osd.Permise())

;---------------------------------------------------------------- batterie ----
;  L'etat reel se lit sans erreur ; le reste se joue avec une alimentation
;  simulee, pour ne pas dependre du chargeur de la machine qui teste.
etat := Batterie._Etat()
Verifier("l'alimentation se lit", etat.secteur = 0 || etat.secteur = 1 || etat.secteur = 255, etat.secteur)
Verifier("Presente et SurBatterie repondent vrai ou faux"
       , (Batterie.Presente() = 0 || Batterie.Presente() = 1) && (Batterie.SurBatterie() = 0 || Batterie.SurBatterie() = 1))

simule := { sur: false }
Batterie.DefineProp("SurBatterie", { Call: (this) => simule.sur })
Batterie.DefineProp("Presente", { Call: (this) => true })
journal := []
Config.Ecrire("batterie", 1), Config.Ecrire("batterie_pourcent", 30)
Batterie.Init((p, d) => journal.Push("baisse " . p), (d) => journal.Push("remonte"))
Verifier("sur secteur a l'ouverture, rien ne bouge", journal.Length = 0 && !Batterie.applique)
simule.sur := true
Batterie.Message(Batterie.PBT_APMPOWERSTATUSCHANGE)
Verifier("le debranchement baisse du nombre de points regle"
       , journal.Length = 1 && journal[1] = "baisse 30" && Batterie.applique, journal.Length ? journal[journal.Length] : "rien")
Batterie.Message(Batterie.PBT_APMPOWERSTATUSCHANGE)
Verifier("un second avis sur batterie ne baisse pas deux fois", journal.Length = 1)
Batterie.Message(0x04)
Verifier("la veille (PBT_APMSUSPEND) est ignoree", journal.Length = 1)
simule.sur := false
Batterie.Message(Batterie.PBT_APMPOWERSTATUSCHANGE)
Verifier("le rebranchement remonte", journal.Length = 2 && journal[2] = "remonte" && !Batterie.applique)
simule.sur := true
Batterie.Message(Batterie.PBT_APMPOWERSTATUSCHANGE)
Config.Ecrire("batterie", 0)
Batterie.Relire()
Verifier("couper le reglage pendant la baisse remonte", journal.Length = 4 && journal[4] = "remonte")
Batterie.Relire()
Verifier("... une seule fois", journal.Length = 4)
Config.Ecrire("batterie", 1)
Batterie.Relire()
Verifier("l'ouvrir sur batterie baisse tout de suite", journal.Length = 5 && journal[5] = "baisse 30")
Batterie.Rendre(0)
Config.Ecrire("batterie", 0)

;-------------------------------------------------------------- adaptatif ----
;  La mesure reelle, par GDI : un nombre entre 0 et 1, en quelques millisecondes.
;  La premiere copie d'ecran par GDI paie la mise en place de la composition :
;  on mesure la seconde, et l'on tolere 200 ms -- la machine fait aussi
;  autre chose pendant la suite de tests, et 125 ms ont ete vus sous charge.
Adaptatif.Mesurer()
t := A_TickCount
luma := Adaptatif.Mesurer()
Verifier("la luminance de l'ecran se mesure par GDI, entre 0 et 1 (ou -1, ecran noir)"
       , (luma >= 0 && luma <= 1) || luma = -1, luma)
Verifier("... en moins de 200 ms", A_TickCount - t < 200, (A_TickCount - t) . " ms")

;  Et par la duplication DXGI (voir Capture.ahk) : la premiere image n'en
;  est pas une (-2), la seconde vaut celle de GDI a quelques centiemes pres
;  -- une moyenne de tout l'ecran contre un echantillon --, et une image sans
;  changement rend -2. Sans Direct3D (-3), on le dit et l'on passe.
ecran := Ecrans.Actif()
d1 := Capture.Luma(ecran)
Sleep(80)
d2 := Capture.Luma(ecran)
Loop 5 {
    if (d2 >= 0 || d2 = -3)
        break
    Sleep(80)
    d2 := Capture.Luma(ecran)
}
if (d1 = -3 || d2 = -3) {
    Dire("  (pas de duplication DXGI ici : Capture n'est pas essayee)")
} else {
    Verifier("la duplication DXGI donne une luminance", d2 >= 0 && d2 <= 1, d2)
    ;  Les deux ne sont pas la meme moyenne -- lineaire puis encodee d'un
    ;  cote, moyenne des octets sRGB de l'autre -- et s'ecartent sur un
    ;  contenu contraste ; sur un gris uni elles se rejoignent au centieme.
    Verifier("... du meme ordre que celle de GDI", Abs(d2 - luma) < 0.25, Format("dxgi {:.3f} gdi {:.3f}", d2, luma))
    t := A_TickCount, c0 := 0
    Loop 20
        Capture.Luma(ecran)
    Verifier("vingt mesures DXGI en moins de 200 ms", A_TickCount - t < 200, (A_TickCount - t) . " ms")
    Capture.Oublier()
    Verifier("les duplications se rendent", Capture.dups.Count = 0)
}

;  La courbe, puis le suivi avec une mesure simulee.
;  adaptatif reste a 0 : Relire lit les bornes sans lancer le minuteur, qui
;  viendrait sinon battre au milieu des comptes.
Config.Ecrire("adaptatif", 0), Config.Ecrire("adapt_mini", 30), Config.Ecrire("adapt_maxi", 100)
Adaptatif.Relire()
Verifier("contenu noir : la borne haute", Adaptatif.Cible(0) = 100, Adaptatif.Cible(0))
Verifier("contenu blanc : la borne basse", Adaptatif.Cible(1) = 30, Adaptatif.Cible(1))
Verifier("a mi-chemin : le milieu", Adaptatif.Cible(0.5) = 65, Adaptatif.Cible(0.5))
Config.Ecrire("adapt_mini", 80), Config.Ecrire("adapt_maxi", 40)
Adaptatif.Relire()
Verifier("des bornes croisees se remettent dans l'ordre", Adaptatif.maxi >= Adaptatif.mini)
Config.Ecrire("adapt_mini", 30), Config.Ecrire("adapt_maxi", 100)
Adaptatif.Relire()

simule := { luma: 0.0 }
Adaptatif.DefineProp("Mesurer", { Call: (this, e := 0) => simule.luma })
Capture.DefineProp("Luma", { Call: (this, e) => simule.luma })
poses := []
Adaptatif.Init((l, e, d) => poses.Push(l), () => true, () => 0)
Filtre.separes := false
Adaptatif._Battre()
Verifier("premiere mesure, ecran sombre : la luminosite monte a la borne haute"
       , poses.Length = 1 && poses[1] = 100, poses.Length ? poses[poses.Length] : "rien")
Adaptatif._Battre()
Verifier("meme contenu : rien ne bouge", poses.Length = 1)
simule.luma := 1.0
Adaptatif._Battre()
Verifier("page blanche : la moyenne glissante fait six dixiemes du chemin"
       , poses.Length = 2 && poses[2] = 58, poses.Length ? poses[poses.Length] : "rien")
Adaptatif._Battre()
Adaptatif._Battre()
Verifier("... et rejoint la borne basse a deux points pres en trois mesures"
       , poses[poses.Length] <= 35, poses[poses.Length])
Verifier("le rythme et le fondu par defaut : 150 ms, 600 ms"
       , Adaptatif.cadence = 150 && Adaptatif.mouvement = 600, Adaptatif.cadence . "/" . Adaptatif.mouvement)
n := poses.Length
simule.luma := -1
Adaptatif._Battre()
Verifier("un ecran tout noir ne dit rien : on garde", poses.Length = n)
simule.luma := 0.0
Adaptatif.Init((l, e, d) => poses.Push(l), () => false, () => 0)
Adaptatif._Battre()
Verifier("interdit (fenetre ouverte, ecran assombri) : on ne bouge pas", poses.Length = n)
Adaptatif.Init((l, e, d) => poses.Push(l), () => true, () => 20)
Adaptatif._Battre()
Verifier("la batterie retire ses points de la cible", poses[poses.Length] = 80, poses[poses.Length])
Adaptatif.Arreter()

;-------------------------------------------------------------- habitudes ----
;  Le modele, joue sur des mois entiers avec une horloge injectee. Un
;  "jour" est une date AAAAMMJJ ; l'heure se donne en minutes ; le tick
;  avance a la main. Le soleil, la presence, l'automate et l'application au
;  premier plan sont des bouchons. Le minuteur reel n'est jamais lance
;  (habitudes = 0 dans le fichier, actif force a la main).
Habitudes.Oublier()
Config.Ecrire("habitudes", 0)
hor := { tick: 1000000, minutes: 21 * 60 + 5, date: "20260901", we: 0 }
Habitudes.horloge := () => hor
Habitudes.soleil := 0
pres := { ok: true }
Habitudes.presence := () => pres.ok
auto := { intensite: "", luminosite: "" }
bloc := { intensite: false, luminosite: false }
appli := { nom: "" }
posesH := [], propositions := [], journalH := []
Habitudes.Init((voie, v, cible) => posesH.Push(voie . ":" . v)
             , (voie) => 50
             , (voie) => auto.%voie%
             , (voie) => bloc.%voie%
             , () => appli.nom
             , (voie, v, cible, accepter) => propositions.Push({ voie: voie, v: v, accepter: accepter })
             , (t) => journalH.Push(t))
Habitudes.actif := true
Avancer(ms) {
    global hor
    hor.tick += ms
}
Jour(date, minutes, we := 0) {
    global hor
    hor.date := date, hor.minutes := minutes, hor.we := we
    hor.tick += 24 * 3600000
}
Geste(voie, v) {
    Habitudes.Noter(voie, v), Avancer(130000), Habitudes._Battre()
}
Compter(liste, motif) {
    n := 0
    for l in liste
        n += InStr(l, motif) ? 1 : 0
    return n
}

;  1. la decantation : cinquante gestes en cinq minutes, une observation
Loop 50 {
    Habitudes.Noter("intensite", Mod(A_Index * 37, 101))
    Avancer(6000)
}
Habitudes.Noter("intensite", 80)
Habitudes._Battre()
Verifier("cinquante gestes en cinq minutes : rien tant que la main bouge", Habitudes.Compte("intensite") = 0)
Avancer(130000)
Habitudes._Battre()
Verifier("... puis deux minutes de calme : une seule observation, la valeur d'arret"
       , Habitudes.Compte("intensite") = 1 && Habitudes.obs["intensite"][1].v = 80, Habitudes.Compte("intensite"))
p := Habitudes.Predire("intensite", hor)
Verifier("une observation ne suffit ni pour agir ni pour proposer", !p.confiant && !p.proposable && p.poids = 1
       , Format("{:.2f}", p.poids))

;  2. deux soirs : on propose ; accepter vaut un geste
Jour("20260902", 21 * 60 + 10), Geste("intensite", 80)
Jour("20260903", 21 * 60 + 12), Avancer(20 * 60000)
Habitudes._Battre()
Verifier("deux soirs concordants : une proposition, pas une pose"
       , propositions.Length = 1 && propositions[1].v = 80 && posesH.Length = 0
       , propositions.Length . " proposition(s), " . posesH.Length . " pose(s)")
Habitudes._Battre()
Verifier("... une seule fois par jour", propositions.Length = 1)
(propositions[1].accepter)()
Verifier("accepter pose la valeur et compte pour un geste"
       , posesH.Length = 1 && posesH[1] = "intensite:80" && Habitudes.Compte("intensite") = 3
       , posesH.Length . " pose(s), " . Habitudes.Compte("intensite") . " obs")
p := Habitudes.Predire("intensite", hor)
Verifier("trois soirs a 80 : le modele est sur de lui", p.confiant && p.valeur = 80 && p.accord = 1
       , Format("valeur {} poids {:.2f} accord {:.2f}", p.valeur, p.poids, p.accord))

;  3. le quatrieme soir : pose au bon moment, ni une heure avant
Jour("20260904", 20 * 60)
Avancer(20 * 60000), Habitudes._Battre()
Verifier("a 20 h, rien : les gestes se font vers 21 h", posesH.Length = 1)
hor.minutes := 21 * 60 + 2
Habitudes._Battre()
Verifier("a 21 h 02, le filtre est pose a 80 tout seul", posesH.Length = 2 && posesH[2] = "intensite:80"
       , posesH.Length ? posesH[posesH.Length] : "rien")
Habitudes._Battre()
Verifier("... et pas deux fois la meme valeur", posesH.Length = 2)

;  4. l'approbation : trente minutes de silence DEVANT l'ecran
n := Habitudes.Compte("intensite")
Avancer(31 * 60000), hor.minutes := 21 * 60 + 33
Habitudes._Battre()
o := Habitudes.obs["intensite"]
Verifier("trente minutes de silence, quelqu'un devant : une observation implicite a demi-poids"
       , Habitudes.Compte("intensite") = n + 1 && o[o.Length].implicite = 1 && o[o.Length].poids = 0.5
       , Habitudes.Compte("intensite") . " obs")
Jour("20260905", 21 * 60 + 2), Avancer(20 * 60000)
pres.ok := false
Habitudes._Battre()
Verifier("le cinquieme soir, pose a 80", posesH[posesH.Length] = "intensite:80" && posesH.Length = 3)
n := Habitudes.Compte("intensite")
Avancer(31 * 60000), hor.minutes := 21 * 60 + 33
Habitudes._Battre()
Verifier("... mais personne devant l'ecran : pas d'approbation", Habitudes.Compte("intensite") = n)
pres.ok := true

;  5. la demonstration a un ami : un soir a 100, la mediane ne bronche pas
Jour("20260906", 21 * 60 + 5)
Loop 40 {
    Habitudes.Noter("intensite", Mod(A_Index * 53, 101))
    Avancer(4000)
}
Geste("intensite", 100)
p := Habitudes.Predire("intensite", hor)
Verifier("un soir de demonstration laisse a 100 : la mediane reste a 80, la confiance aussi"
       , p.confiant && p.valeur = 80 && !p.bascule, Format("valeur {} accord {:.2f}", p.valeur, p.accord))

;  6. la correction pese double ; trois soirs a 60 font basculer l'habitude
Jour("20260907", 21 * 60 + 2), Avancer(20 * 60000), Habitudes._Battre()
Verifier("le septieme soir, pose a 80", posesH[posesH.Length] = "intensite:80")
Avancer(3 * 60000)
Geste("intensite", 60)
o := Habitudes.obs["intensite"]
Verifier("un geste trois minutes apres la pose : une correction, poids double"
       , o[o.Length].v = 60 && o[o.Length].poids = 2, o[o.Length].v . " x" . o[o.Length].poids)
Jour("20260908", 21 * 60 + 5), Avancer(20 * 60000), Geste("intensite", 60)
p := Habitudes.Predire("intensite", hor)
Verifier("deux soirs a 60 : pas encore", p.valeur != 60 || !p.confiant, p.valeur)
Jour("20260909", 21 * 60 + 5), Avancer(20 * 60000), Geste("intensite", 60)
p := Habitudes.Predire("intensite", hor)
Verifier("trois soirs a 60 : la memoire courte l'emporte, l'habitude a bascule"
       , p.confiant && p.valeur = 60 && p.bascule, Format("valeur {} bascule {} accord {:.2f}", p.valeur, p.bascule, p.accord))

;  7. l'hesitation : 30, 80, 30, 80 n'est pas une habitude
Loop 4 {
    Jour("2026091" . A_Index, 8 * 60 + 10), Geste("luminosite", Mod(A_Index, 2) ? 30 : 80)
}
p := Habitudes.Predire("luminosite", hor)
Verifier("tantot 30 tantot 80 : assez d'observations, mais on se tait", !p.confiant && p.poids >= 2.5
       , Format("poids {:.2f} accord {:.2f}", p.poids, p.accord))

;  8. la retenue : la main encore la, un etat passager, un geste qui suspend
Jour("20260915", 21 * 60 + 5)
n := posesH.Length
Geste("intensite", 60)
Verifier("un geste il y a deux minutes : on ne pose rien", posesH.Length = n)
Avancer(20 * 60000)
bloc.intensite := true
Habitudes._Battre()
Verifier("un etat passager tient la voie : on ne pose rien", posesH.Length = n)
bloc.intensite := false
Habitudes._Battre()
Verifier("la main a repris le curseur : l'habitude est suspendue tant que sa cible ne bouge pas", posesH.Length = n)
Habitudes.suspendu := Map()

;  9. la rampe : 60 vers 21 h, 30 vers 23 h -> entre les deux a 22 h
Loop 3 {
    Jour("2026091" . (A_Index + 5), 23 * 60 + 10), Geste("intensite", 30)
}
c22 := Habitudes.Cible("intensite", Habitudes._A(hor, 22 * 60 + 10))
c23 := Habitudes.Cible("intensite", Habitudes._A(hor, 23 * 60 + 15))
Verifier("entre 21 h (60) et 23 h (30), la cible de 22 h glisse entre les deux : c'est une rampe"
       , c22.confiant && c22.rampe && c22.valeur > 30 && c22.valeur < 60, c22.valeur)
Verifier("a 23 h 15, la cible est 30, sans rampe", c23.confiant && !c23.rampe && c23.valeur = 30, c23.valeur)

;  10. le contexte : le lecteur video a ses habitudes, a toute heure, et le plein ecran les siennes
Loop 3 {
    Jour("2026092" . A_Index, 60 * (9 + 4 * A_Index))          ; 13 h, 17 h, 21 h
    appli.nom := "vlc.exe", Geste("luminosite", 35)
}
Loop 3 {
    Jour("2026092" . (A_Index + 3), 60 * (10 + 4 * A_Index))
    appli.nom := "vlc.exe+", Geste("luminosite", 20)
}
appli.nom := ""
q := Habitudes._A(hor, 15 * 60)
cv := Habitudes.Cible("luminosite", q, "vlc.exe")
cp := Habitudes.Cible("luminosite", q, "vlc.exe+")
cs := Habitudes.Cible("luminosite", q, "")
Verifier("VLC devant, a 15 h ou l'heure ne sait rien : 35, par l'application"
       , cv.confiant && cv.valeur = 35 && cv.contexte = "vlc.exe", cv.valeur . " " . cv.contexte)
Verifier("VLC en plein ecran : 20, un autre contexte", cp.confiant && cp.valeur = 20, cp.valeur)
Verifier("VLC parti : l'heure reprend la main, et ne sait rien a 15 h", !cs.confiant && !cs.proposable)

;  11. le week-end ecoute le week-end
Loop 3 {
    Jour("2026100" . A_Index, 10 * 60, 1), Geste("luminosite", 40)
}
Loop 3 {
    Jour("2026100" . (A_Index + 3), 10 * 60, 0), Geste("luminosite", 90)
}
pw := Habitudes.Predire("luminosite", { tick: hor.tick, minutes: 10 * 60, date: "20261007", we: 1, lever: "", coucher: "" })
pj := Habitudes.Predire("luminosite", { tick: hor.tick, minutes: 10 * 60, date: "20261008", we: 0, lever: "", coucher: "" })
Verifier("a 10 h, 40 le week-end et 90 en semaine", pw.valeur = 40 && pj.valeur = 90, pw.valeur . " / " . pj.valeur)

;  12. le temps solaire : une habitude d'une heure avant le lever suit le lever
Habitudes.soleil := (date) => date < "20261014" ? { lever: 420, coucher: 1200 } : { lever: 480, coucher: 1080 }
Loop 3 {
    Jour("2026101" . A_Index, 6 * 60), Geste("intensite", 20)               ; lever a 7 h : une heure avant
}
hor2 := { tick: hor.tick, minutes: 7 * 60, date: "20261015", we: 0 }     ; lever a 8 h, calcule par le bouchon
pa := Habitudes.Predire("intensite", hor2)
hor2.minutes := 6 * 60
pb := Habitudes.Predire("intensite", hor2)
Verifier("le lever passe de 7 h a 8 h : l'habitude 'une heure avant le lever' est a 7 h, plus a 6 h"
       , pa.confiant && pa.valeur = 20 && !pb.confiant, Format("7h {:.2f} / 6h {:.2f}", pa.poids, pb.poids))
Habitudes.soleil := 0

;  13. les residus : le planificateur tient l'intensite, on apprend l'ecart
auto.intensite := 50
Loop 3 {
    Jour("2026102" . A_Index, 15 * 60), Geste("intensite", 65)
}
o := Habitudes.obs["intensite"]
Verifier("sous le planificateur, l'observation retient la brute", o[o.Length].brute = 50 && o[o.Length].v = 65)
n := posesH.Length
Avancer(20 * 60000), Habitudes._Battre()
Verifier("le planificateur reste maitre : pas de pose, mais un ecart de +15 pour lui"
       , posesH.Length = n && Habitudes.Decalage("intensite") = 15, Habitudes.Decalage("intensite"))
auto.intensite := ""
p := Habitudes.Predire("intensite", hor)
Verifier("planificateur coupe : les ecarts ne disent rien d'absolu", !p.confiant && !p.proposable)
Habitudes.decalages := Map()

;  14. le fichier : ecrit, relu, identique, champs compris
avant := Habitudes.Compte("intensite") . "/" . Habitudes.Compte("luminosite")
Habitudes.Enregistrer()
Verifier("habitudes.ini est ecrit", FileExist(Habitudes.Fichier()) != "")
Habitudes.obs := Map()
Habitudes.Charger()
Verifier("... et relu a l'identique", Habitudes.Compte("intensite") . "/" . Habitudes.Compte("luminosite") = avant
       , Habitudes.Compte("intensite") . "/" . Habitudes.Compte("luminosite") . " vs " . avant)
o := Habitudes.obs["intensite"]
Verifier("brute, lever, coucher et contexte survivent au fichier"
       , o[o.Length].brute = 50 && o[o.Length - 3].lever = 420 && Habitudes.obs["luminosite"][8].app = "vlc.exe+"
       , o[o.Length].brute . " " . o[o.Length - 3].lever)

;  15. l'oubli
Habitudes.Observer("intensite", 20, { tick: 0, minutes: 3 * 60, date: "20260601", we: 0 })
p := Habitudes.Predire("intensite", { tick: 0, minutes: 3 * 60, date: "20261023", we: 0, lever: "", coucher: "" })
Verifier("une observation de plus de soixante jours est oubliee", p.poids = 0)
Habitudes.Observer("intensite", 20, { tick: 0, minutes: 3 * 60, date: "20260922", we: 0 })
p := Habitudes.Predire("intensite", { tick: 0, minutes: 3 * 60, date: "20261023", we: 0, lever: "", coucher: "" })
Verifier("une observation d'un mois pese la moitie", Abs(p.poids - 0.5) < 0.05, Format("{:.2f}", p.poids))

;  16. la cloture et le journal
Jour("20261024", 12 * 60)
Habitudes.Noter("luminosite", 55), Avancer(40000)
n := Habitudes.Compte("luminosite")
Habitudes.Clore()
Verifier("a la sortie, un geste calme depuis trente secondes est retenu", Habitudes.Compte("luminosite") = n + 1)
Habitudes.Noter("luminosite", 56), Avancer(5000)
n := Habitudes.Compte("luminosite")
Habitudes.Clore()
Verifier("... mais pas un geste fait en fermant", Habitudes.Compte("luminosite") = n)
Verifier("le journal a tout note : observations, poses, propositions, approbations, ecart"
       , journalH.Length > 30 && Compter(journalH, "pose ") >= 3
       && Compter(journalH, "propose") >= 1 && Compter(journalH, "approbation") >= 1
       && Compter(journalH, "ecart +15") >= 1, journalH.Length . " lignes")

Habitudes.Oublier()
Habitudes.horloge := 0
Habitudes.presence := 0
Habitudes.actif := false

;--------------------------------------------------------------- demarrage ----
;  CreerTache est un try qui avale tout : une propriete mal nommee
;  (MultipleInstancesPolicy, le nom de l'element XML, au lieu de
;  MultipleInstances, celui de l'interface) la faisait echouer en silence, et
;  Definir se rabattait sur le raccourci -- celui des 46 secondes. On l'essaie
;  donc pour de bon, sous un autre nom de tache que la vraie, et l'on relit ce
;  que le planificateur a retenu.
Demarrage.TACHE := "OcreEssai"
Demarrage.SupprimerTache()
try {
    Verifier("la tache d'essai n'existe pas au depart", !Demarrage.TacheExiste())
    Verifier("CreerTache enregistre la tache", Demarrage.CreerTache())
    service := ComObject("Schedule.Service")
    service.Connect()
    def := service.GetFolder("\").GetTask(Demarrage.TACHE).Definition
    s := def.Settings
    Verifier("la tache ne depend pas de la batterie"
           , !s.StopIfGoingOnBatteries && !s.DisallowStartIfOnBatteries)
    Verifier("la tache n'a pas de limite de duree", s.ExecutionTimeLimit = "PT0S", s.ExecutionTimeLimit)
    Verifier("la tache ignore un second lancement", s.MultipleInstances = 2, s.MultipleInstances)
    Verifier("la tache tourne sans elevation", def.Principal.RunLevel = 0, def.Principal.RunLevel)
} catch as e {
    Verifier("la tache d'essai se cree et se relit", false, e.Message)
} finally {
    Demarrage.SupprimerTache()
}
Verifier("la tache d'essai est retiree", !Demarrage.TacheExiste())
Demarrage.TACHE := "Ocre"

;------------------------------------------------------------------ icone ----
h1 := Blob.Icone(50, 32)
h2 := Blob.Icone(50, 32, 1.0, true)
Verifier("l'icone se dessine avec et sans point", h1 && h2)
DllCall("DestroyIcon", "ptr", h1), DllCall("DestroyIcon", "ptr", h2)

;--------------------------------------------------------- ligne de commande --
;  Seulement si l'on a une console : Ocre y ecrit son aide, et sans console
;  il ouvrirait une boite a chaque essai.
if (DllCall("AttachConsole", "uint", -1)) {
    ahk := A_AhkPath
    src := A_ScriptDir . "\..\Ocre.ahk"
    Code(args) {
        return RunWait('"' . ahk . '" /ErrorStdOut "' . src . '" ' . args, , "Hide")
    }
    Verifier("/help rend 0", Code("/help") = 0)
    Verifier("/set sans nombre rend 2 et ne fait rien", Code("/set") = 2)
    Verifier("/set abc rend 2", Code("/set abc") = 2)
    Verifier("/kelvin sans nombre rend 2", Code("/kelvin") = 2)
    Verifier("/preset inconnu rend 2", Code("/preset foo") = 2)
    Verifier("/horaire peut-etre rend 2", Code("/horaire peut-etre") = 2)
    Verifier("une commande inconnue rend 2", Code("/zzz") = 2)
    c := Code("/get")
    Verifier("/get rend l'intensite, entre 0 et 100", c >= 0 && c <= 100, c)

    ;  /export ecrit la VRAIE configuration dans un fichier temporaire, et
    ;  /import la reprend telle quelle : rien ne change pour l'utilisateur.
    Verifier("/export sans fichier rend 2", Code("/export") = 2)
    Verifier("/import sans fichier rend 2", Code("/import") = 2)
    Verifier("/import d'un fichier absent rend 2", Code('/import "' . A_Temp . '\ocre-nulle-part.ini"') = 2)
    sauve := A_Temp . "\ocre-export-essai.ini"
    try FileDelete(sauve)
    Verifier("/export ecrit le fichier et rend 0", Code('/export "' . sauve . '"') = 0 && FileExist(sauve))
    Verifier("/import du meme fichier rend 0", Code('/import "' . sauve . '"') = 0)
    try FileDelete(sauve)
} else {
    Dire("  (pas de console : la ligne de commande n'est pas essayee)")
}

try FileDelete(Config.FICHIER)
try DirDelete(Config.DOSSIER)

Dire("")
Dire(rates = 0
   ? Format("  {} verifications, aucune erreur.", total)
   : Format("  {} verifications, {} ERREURS.", total, rates))
Dire("")

Ecrire()
ExitApp(rates = 0 ? 0 : 1)
