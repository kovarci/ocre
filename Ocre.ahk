;==============================================================================
;  Ocre -- filtre de lumiere chaude pilote au clavier, sur Windows 11.
;
;  Le filtre est applique par rampe gamma, pas par le Night Light de Windows :
;  depuis 25H2 celui-ci n'est plus pilotable a chaud (voir README).
;
;  Laisser l'eclairage nocturne de Windows desactive : les deux se cumuleraient.
;==============================================================================

#Requires AutoHotkey v2.0

;  Pas de #SingleInstance Force : la ligne de commande a besoin de PARLER a
;  l'instance en cours, pas de la remplacer. "Ocre.exe /set 40" qui tuerait
;  l'application pour la relancer donnerait le bon resultat par le plus mauvais
;  chemin -- et un raccourci de clavier programmable en envoie plusieurs par
;  seconde. La gestion d'instance est donc faite a la main, plus bas.
#SingleInstance Off

#Include lib\Gamma.ahk
#Include lib\Ecrans.ahk
#Include lib\Retro.ahk
#Include lib\Filtre.ahk
#Include lib\Fondu.ahk
#Include lib\Blob.ahk
#Include lib\Theme.ahk
#Include lib\Config.ahk
#Include lib\I18n.ahk
#Include lib\Osd.ahk
#Include lib\Widgets.ahk
#Include lib\Lieu.ahk
#Include lib\Reglages.ahk
#Include lib\Panneau.ahk
#Include lib\Soleil.ahk
#Include lib\Horaire.ahk
#Include lib\Unite.ahk
#Include lib\Rappel.ahk
#Include lib\Inactif.ahk
#Include lib\Batterie.ahk
#Include lib\Adaptatif.ahk
#Include lib\Habitudes.ahk

Persistent

;  Le gestionnaire des taches affiche FileDescription, pas le nom du fichier :
;  c'est donc elle qui doit dire "Ocre". La phrase longue n'a sa place nulle
;  part : mise dans ProductName, le gestionnaire des taches de Windows 11
;  l'affichait quand meme comme nom de groupe ("Filtre de lumiere chaude
;  pilote au clavier"), depouillee du prefixe "Ocre - ". Tout dit "Ocre".
;@Ahk2Exe-SetName Ocre
;@Ahk2Exe-SetDescription Ocre
;@Ahk2Exe-SetProductName Ocre
;@Ahk2Exe-SetCompanyName Ocre contributors
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Ocre contributors
;@Ahk2Exe-SetOrigFilename Ocre.exe
;@Ahk2Exe-SetVersion 1.3.0
;@Ahk2Exe-SetMainIcon Ocre.ico
;  La police de la pastille, embarquee en ressource (voir lib\Police.ahk).
;@Ahk2Exe-AddResource lib\Inter-Medium.ttf, INTER
;  La table des villes, lue a la premiere recherche (voir lib\Villes.ahk).
;@Ahk2Exe-AddResource lib\villes.txt, VILLES

;  Une erreur s'ecrit avant de s'afficher. Ocre demarre avec Windows : une
;  boite ouverte a ce moment-la se retrouve derriere les autres fenetres, ou se
;  ferme d'un reflexe -- et il ne reste plus rien. Le journal, lui, se relit.
;  La pile d'appel est notee avec le message. Dans un executable, tous les
;  fichiers inclus sont fondus en un seul : le numero de ligne rapporte ne
;  correspond a aucune source, et seule la pile dit quelle fonction a echoue.
;  La version. Une seule source : la directive SetVersion ci-dessus. Compile,
;  elle est dans les ressources de l'exe, sur quatre nombres dont on ote le
;  quatrieme s'il est nul, pour retomber sur l'ecriture de la directive ;
;  interprete, on la relit dans ce fichier. Elle ne s'affiche qu'a un endroit, l'infobulle de l'icone --
;  la ou l'on va la chercher quand on en a besoin, et nulle part ou elle
;  encombrerait.
Version() {
    static v := ""
    if (v != "")
        return v
    try {
        if (A_IsCompiled)
            v := RegExReplace(FileGetVersion(A_ScriptFullPath), "^(\d+\.\d+\.\d+)\.0$", "$1")
        else if (RegExMatch(FileRead(A_ScriptFullPath), "m)^;@Ahk2Exe-SetVersion\s+(\S+)", &m))
            v := m[1]
    }
    return v != "" ? v : "?"
}

OnError(Fatal)
Fatal(e, mode) {
    pile := ""
    try pile := "`n" . e.Stack
    Journal("erreurs.log", e.Message . "  --  " . e.File . " ligne " . e.Line . pile)
    MsgBox("Ocre a rencontre une erreur.`n`n" . e.Message
         . "`n`nFichier : " . e.File . "  ligne " . e.Line
         . "`n`nCette erreur est notee dans :`n" . Config.DOSSIER . "\erreurs.log"
         , "Ocre", 16)
    return -1
}

;========================================================== ligne de commande ==
;  Ocre.exe /set 40      pose l'intensite            /set +5, /set -5 : relatif
;  Ocre.exe /kelvin 3400 pose la temperature (1200 a 6500 K)
;  Ocre.exe /lum 60      pose la luminosite          /lum +5, /lum -5 : relatif
;  Ocre.exe /plus        un pas plus chaud
;  Ocre.exe /moins       un pas moins chaud
;  Ocre.exe /toggle      coupe ou retablit
;  Ocre.exe /preset nuit un prereglage : lecture, film, nuit
;  Ocre.exe /gris        niveaux de gris, active ou coupe
;  Ocre.exe /chambre     chambre noire, entre ou sort
;  Ocre.exe /horaire on  planificateur : on, off, ou rien pour basculer
;  Ocre.exe /rappel      fait respirer l'icone, comme le rappel des 20-20-20
;  Ocre.exe /get         ecrit l'etat sur la sortie standard ; code de retour
;                        = intensite
;  Ocre.exe /reset       rampe neutre et arret
;  Ocre.exe /quit        arret propre
;  Ocre.exe /help        cette liste
;
;  Ces commandes existent pour ce qui n'est pas un clavier : un boitier a
;  boutons, une macro, un script de mise en veille. Les raccourcis couvrent le
;  reste.
;
;  Une commande adressee a une instance vivante lui est POSTEE, pas appliquee
;  ici : deux processus qui poseraient chacun leur rampe se battraient. La
;  diffusion evite d'avoir a retrouver la fenetre, qui est cachee.
;
;  Une commande qui attend un nombre et n'en recoit pas -- "/set" tout court,
;  "/set abc" -- ne fait RIEN et le dit. Elle valait zero, et zero coupe le
;  filtre : une macro mal ecrite eteignait l'ecran en silence.
COMMANDE := DllCall("RegisterWindowMessage", "str", "OcreCommande", "uint")
DIFFUSION := 0xFFFF        ; HWND_BROADCAST

CMD_INTENSITE := 1
CMD_LUMINOSITE := 2
CMD_PLUS := 3
CMD_MOINS := 4
CMD_BASCULE := 5
CMD_QUITTER := 6
CMD_RESET := 7
CMD_GRIS := 8
CMD_PRESET := 9            ; valeur : 1 lecture, 2 film, 3 nuit
CMD_CHAMBRE := 10
CMD_HORAIRE := 11          ; valeur : 0 off, 1 on, 2 bascule
CMD_INTENSITE_REL := 12    ; valeur : delta + DECALAGE (lParam n'est pas signe)
CMD_LUMINOSITE_REL := 13
CMD_RAPPEL := 14
CMD_RELIRE := 15           ; le fichier de reglages a change sous nos pieds (/import)

;  Un lParam poste par PostMessage arrive non signe : un delta negatif y
;  passe decale de cette constante, et on la retranche a l'arrivee.
DECALAGE := 1000

;  Les trois codes qui ne se postent pas : ils vivent le temps de LireArguments
;  et de la reponse sur la console.
CMD_ETAT := 90
CMD_AIDE := 91
CMD_ERREUR := 92
CMD_EXPORT := 93           ; ordre.chemin : le fichier
CMD_IMPORT := 94

AIDE := "
(
Ocre -- filtre de lumiere chaude / warm light filter

  Ocre.exe /set 40        intensite 0-100        /set +5, /set -5 : relatif
  Ocre.exe /kelvin 3400   temperature 1200-6500 K
  Ocre.exe /lum 60        luminosite 0-100       /lum +5, /lum -5 : relatif
  Ocre.exe /plus          un pas plus chaud      (warmer)
  Ocre.exe /moins         un pas moins chaud     (cooler)
  Ocre.exe /toggle        coupe ou retablit
  Ocre.exe /preset nuit   prereglage : lecture, film, nuit  (reading, movie, night)
  Ocre.exe /gris          niveaux de gris        (grey)
  Ocre.exe /chambre       chambre noire          (darkroom)
  Ocre.exe /horaire on    planificateur : on, off, ou rien pour basculer  (schedule)
  Ocre.exe /rappel        fait respirer l'icone, comme le rappel des 20-20-20  (reminder)
  Ocre.exe /get           etat courant ; code de retour = intensite
  Ocre.exe /export f.ini  copie les reglages dans un fichier   (export)
  Ocre.exe /import f.ini  prend les reglages d'un fichier      (import)
  Ocre.exe /reset         rampe neutre et arret
  Ocre.exe /quit          arret propre
  Ocre.exe /help          cette liste

  -set vaut /set : les deux conventions ont cours.
)"

;  Un mutex nomme repond a "suis-je le premier ?" sans avoir a chercher de
;  fenetre ni de processus. ERROR_ALREADY_EXISTS vaut 183.
;
;  Une seule barre oblique inverse. AutoHotkey n'en fait pas un echappement --
;  c'est l'accent grave qui joue ce role -- et "Local\\OcreInstance" nommerait
;  un espace de noms vide, que Windows refuse : les deux instances se
;  croiraient alors seules, et la ligne de commande demarrerait un second Ocre
;  au lieu de parler au premier.
MUTEX := DllCall("CreateMutexW", "ptr", 0, "int", 1, "wstr", "Local\OcreInstance", "ptr")
dejaLa := (A_LastError = 183)

ordre := LireArguments()

;  Trois commandes ne s'adressent a aucune instance : elles parlent a la
;  console d'ou l'on vient, et s'en vont.
if (ordre.code = CMD_AIDE || ordre.code = CMD_ERREUR) {
    Console((ordre.code = CMD_ERREUR ? ordre.texte . "`n`n" : "") . AIDE)
    ExitApp(ordre.code = CMD_ERREUR ? 2 : 0)
}
if (ordre.code = CMD_ETAT) {
    Console(Etat())
    ExitApp(Config.LireNombre("intensite"))
}

;  /export et /import travaillent sur le fichier eux-memes -- un chemin ne
;  passe pas dans un message -- puis, pour l'import, previennent l'instance
;  en place que tout a change (CMD_RELIRE). Un chemin relatif l'est au
;  dossier d'ou l'on nous lance, pas a celui de l'executable.
if (ordre.code = CMD_EXPORT || ordre.code = CMD_IMPORT) {
    chemin := ordre.chemin
    if (!RegExMatch(chemin, "^(?:[A-Za-z]:|\\\\)"))
        chemin := A_InitialWorkingDir . "\" . chemin
    if (ordre.code = CMD_EXPORT) {
        try {
            Config.Exporter(chemin)
            Console("Ocre : reglages exportes dans " . chemin)
            ExitApp(0)
        } catch as e {
            Console("Ocre : export impossible -- " . e.Message)
            ExitApp(2)
        }
    }
    pris := false
    try pris := Config.Importer(chemin)
    if (!pris) {
        Console("Ocre : " . chemin . " n'est pas un fichier de reglages d'Ocre -- rien n'a ete fait.")
        ExitApp(2)
    }
    if (dejaLa)
        DllCall("PostMessage", "ptr", DIFFUSION, "uint", COMMANDE, "ptr", CMD_RELIRE, "ptr", 0)
    Console("Ocre : reglages importes de " . chemin . (dejaLa ? " et appliques" : ""))
    ExitApp(0)
}

if (ordre.code) {
    if (dejaLa) {
        ;  L'instance en place fait le travail ; celle-ci n'avait qu'a
        ;  transmettre.
        DllCall("PostMessage", "ptr", DIFFUSION, "uint", COMMANDE
              , "ptr", ordre.code, "ptr", ordre.valeur)
        ExitApp(0)
    }

    ;  Personne pour ecouter. /reset et /quit n'ont alors plus d'objet, sinon
    ;  de remettre l'ecran a plat -- ce qui est justement le cas ou l'on s'en
    ;  sert : apres un "Fin de tache" qui n'a laisse rien s'executer.
    if (ordre.code = CMD_RESET || ordre.code = CMD_QUITTER) {
        for e in Ecrans.Lister()
            Gamma.Neutre(e.hdc)
        Ecrans.Oublier()
        ExitApp(0)
    }
    ;  Les autres demarrent l'application, puis s'appliquent : voir la fin du
    ;  fichier.
}

if (dejaLa && !ordre.code) {
    ;  Un lancement ordinaire alors qu'Ocre tourne deja remplace l'instance en
    ;  place, comme le faisait #SingleInstance Force. On lui demande de partir
    ;  proprement -- elle rendra la rampe et ses moniteurs physiques -- et on
    ;  ATTEND qu'elle soit partie : le mutex lui appartient tant qu'elle vit,
    ;  et nous revient (abandonne, 0x80) a sa mort. Un delai fixe ne suffisait
    ;  pas : sa sortie peut prendre plus d'une demi-seconde, et sa rampe
    ;  neutre arrivait alors APRES la notre, qui restait a plat dix secondes
    ;  jusqu'au chien de garde. Cinq secondes au plus ; si elle est toujours
    ;  la, c'est qu'elle n'a pas recu l'ordre -- une instance elevee, que
    ;  l'UIPI protege des messages d'un processus ordinaire -- et l'on ne
    ;  demarre PAS une seconde instance a cote : deux Ocre se disputeraient la
    ;  rampe. On le dit, et l'on s'en va.
    DllCall("PostMessage", "ptr", DIFFUSION, "uint", COMMANDE
          , "ptr", CMD_QUITTER, "ptr", 0)
    if (DllCall("WaitForSingleObject", "ptr", MUTEX, "uint", 5000) = 0x102) {
        I18n.Definir(Config.Lire("langue"))
        MsgBox(I18n.S("deja_lance"), "Ocre", 48)
        ExitApp(1)
    }
    Sleep(100)
}

LireArguments() {
    global CMD_INTENSITE, CMD_LUMINOSITE, CMD_PLUS, CMD_MOINS
    global CMD_BASCULE, CMD_QUITTER, CMD_RESET, CMD_GRIS
    global CMD_PRESET, CMD_CHAMBRE, CMD_HORAIRE, CMD_RAPPEL
    global CMD_INTENSITE_REL, CMD_LUMINOSITE_REL, DECALAGE
    global CMD_ETAT, CMD_AIDE, CMD_ERREUR, CMD_EXPORT, CMD_IMPORT

    if (!A_Args.Length)
        return { code: 0, valeur: 0 }

    ;  "/set" et "-set" indifferemment : les deux conventions ont cours sur
    ;  Windows, et refuser l'une pour l'autre n'apprend rien a personne.
    mot := StrLower(RegExReplace(A_Args[1], "^[-/]+"))
    arg := A_Args.Length > 1 ? Trim(A_Args[2]) : ""

    ;  "+5" et "-5" sont relatifs, "5" est absolu : le signe est ce qui les
    ;  distingue, et IsNumber accepte les deux.
    nombre := IsNumber(arg)
    relatif := nombre && RegExMatch(arg, "^[+-]")
    val := nombre ? Integer(arg) : 0

    switch mot {
        case "set", "intensite", "intensity":
            if (!nombre)
                return Refus("/set attend un nombre de 0 a 100, ou +n / -n")
            if (relatif)
                return { code: CMD_INTENSITE_REL, valeur: Max(-100, Min(100, val)) + DECALAGE }
            return { code: CMD_INTENSITE, valeur: Max(0, Min(100, val)) }

        case "kelvin", "k", "temp":
            if (!nombre || relatif)
                return Refus("/kelvin attend une temperature de 1200 a 6500")
            return { code: CMD_INTENSITE, valeur: Gamma.Intensite(val) }

        case "lum", "luminosite", "brightness":
            if (!nombre)
                return Refus("/lum attend un nombre de 0 a 100, ou +n / -n")
            if (relatif)
                return { code: CMD_LUMINOSITE_REL, valeur: Max(-100, Min(100, val)) + DECALAGE }
            return { code: CMD_LUMINOSITE, valeur: Max(0, Min(100, val)) }

        case "preset", "prereglage":
            switch StrLower(arg) {
                case "lecture", "reading": return { code: CMD_PRESET, valeur: 1 }
                case "film", "movie":      return { code: CMD_PRESET, valeur: 2 }
                case "nuit", "night":      return { code: CMD_PRESET, valeur: 3 }
            }
            return Refus("/preset attend lecture, film ou nuit")

        case "horaire", "schedule":
            switch StrLower(arg) {
                case "":               return { code: CMD_HORAIRE, valeur: 2 }
                case "on", "1", "oui": return { code: CMD_HORAIRE, valeur: 1 }
                case "off", "0", "non": return { code: CMD_HORAIRE, valeur: 0 }
            }
            return Refus("/horaire attend on, off, ou rien")

        case "plus", "up", "warmer":   return { code: CMD_PLUS, valeur: 0 }
        case "moins", "down", "cooler": return { code: CMD_MOINS, valeur: 0 }
        case "toggle", "bascule":      return { code: CMD_BASCULE, valeur: 0 }
        case "gris", "grey", "grayscale": return { code: CMD_GRIS, valeur: 0 }
        case "chambre", "darkroom":    return { code: CMD_CHAMBRE, valeur: 0 }
        case "rappel", "reminder":     return { code: CMD_RAPPEL, valeur: 0 }
        case "get", "etat", "status":  return { code: CMD_ETAT, valeur: 0 }
        case "export", "exporter":
            if (arg = "")
                return Refus("/export attend un nom de fichier")
            return { code: CMD_EXPORT, valeur: 0, chemin: arg }
        case "import", "importer":
            if (arg = "")
                return Refus("/import attend un nom de fichier")
            return { code: CMD_IMPORT, valeur: 0, chemin: arg }
        case "help", "aide", "?", "h": return { code: CMD_AIDE, valeur: 0 }
        case "reset":                  return { code: CMD_RESET, valeur: 0 }
        case "quit", "quitter", "exit": return { code: CMD_QUITTER, valeur: 0 }
    }
    return Refus("commande inconnue : " . A_Args[1])
}

Refus(quoi) {
    global CMD_ERREUR
    return { code: CMD_ERREUR, valeur: 0
           , texte: "Ocre : " . quoi . " -- rien n'a ete fait." }
}

;  Ecrit sur la console d'ou l'on vient. Un executable sans console -- c'est
;  le cas d'une application a icone -- n'ecrit nulle part de lui-meme : on se
;  rattache a celle du parent, le terminal qui nous a lances. Lance par
;  double-clic, il n'y en a pas, et une boite fait l'affaire.
;
;  Mais d'abord la sortie standard HERITEE, si le parent en a donne une :
;  "Ocre.exe /get > etat.txt" ou "| find" nous remettent un fichier ou un
;  tube, et AttachConsole les ecraserait par la console -- le fichier
;  restait vide. Un handle de fichier ou de tube se reconnait a son type ;
;  celui d'une console (ou rien) renvoie a la voie d'avant.
Console(texte) {
    h := DllCall("GetStdHandle", "int", -11, "ptr")
    type := h ? DllCall("GetFileType", "ptr", h, "uint") : 0
    if (type = 1 || type = 3) {                  ; FILE_TYPE_DISK, FILE_TYPE_PIPE
        try {
            FileAppend(texte . "`n", "*")
            return
        }
    }
    if (DllCall("AttachConsole", "uint", -1)) {
        try {
            FileAppend("`n" . texte . "`n", "*")
            return
        }
    }
    MsgBox(texte, "Ocre")
}

;  L'etat, pour /get. Lu dans la configuration plutot que demande a l'instance
;  en place : une reponse par message demanderait une fenetre pour la
;  recevoir, et la configuration a la bonne valeur au plus 200 ms apres le
;  dernier geste (voir Config.EcrireDiffere). Une ligne "cle=valeur" par
;  ligne, ce qu'un script lit sans effort.
Etat() {
    i := Config.LireNombre("intensite")
    return "intensite=" . i
         . "`nkelvin=" . Gamma.Kelvin(i)
         . "`nluminosite=" . Max(0, Min(100, Config.LireNombre("luminosite")))
         . "`ncoupe=" . (i = 0 ? 1 : 0)
         . "`nhoraire=" . (Config.Lire("horaire") = "1" ? 1 : 0)
         . "`ngris=" . (Config.Lire("gris") = "1" ? 1 : 0)
         . "`nnoir=" . Filtre.Noir()
         . "`nunite=" . (Unite.Kelvin() ? "k" : "pct")
         . "`nportable=" . (Config.portable ? 1 : 0)
         . "`nfichier=" . Config.FICHIER
         . "`nsepares=" . (Config.Lire("separes") = "1" ? 1 : 0)
         . EtatEcrans()
}

;  En mode separe, une ligne par ecran avec ses propres valeurs : la valeur
;  d'ensemble ne dit alors rien de ce qu'on voit. Les contextes ouverts pour
;  enumerer sont rendus aussitot -- ce processus ne pose rien.
EtatEcrans() {
    if (Config.Lire("separes") != "1")
        return ""
    lignes := ""
    try {
        for i, e in Ecrans.Lister() {
            cle := Config.CleEcran(e.id)
            lignes .= "`necran" . i . "=" . e.nom
                    . "`necran" . i . "_intensite=" . Max(0, Config.LireNombre(cle . "_i"))
                    . "`necran" . i . "_luminosite=" . Max(0, Config.LireNombre(cle . "_l"))
        }
        Ecrans.Oublier()
    }
    return lignes
}

;  Ce qu'une instance vivante fait d'une commande recue.
;
;  Une diffusion atteint TOUTES les fenetres de premier niveau du processus --
;  la fenetre cachee du script, mais aussi la pastille, le panneau, les
;  reglages des qu'ils existent -- et OnMessage se declenche pour chacune. Cinq
;  appuis rapides sur /moins en faisaient sept, mesure. On ne repond qu'a la
;  fenetre principale : la commande n'a de sens qu'une fois.
Recevoir(wParam, lParam, msg, hwnd) {
    global CMD_INTENSITE, CMD_LUMINOSITE, CMD_PLUS, CMD_MOINS
    global CMD_BASCULE, CMD_QUITTER, CMD_RESET, CMD_GRIS
    global CMD_PRESET, CMD_CHAMBRE, CMD_HORAIRE, CMD_RAPPEL, CMD_RELIRE
    global CMD_INTENSITE_REL, CMD_LUMINOSITE_REL, DECALAGE

    if (hwnd != A_ScriptHwnd)
        return 0

    switch wParam {
        case CMD_INTENSITE:  Appliquer(lParam)
        case CMD_LUMINOSITE: AppliquerLum(lParam)
        case CMD_INTENSITE_REL:  Ajuster(lParam - DECALAGE, Vise())
        case CMD_LUMINOSITE_REL: AjusterLum(lParam - DECALAGE, Vise())
        case CMD_PLUS:       Plus()
        case CMD_MOINS:      Moins()
        case CMD_BASCULE:    Basculer()
        case CMD_GRIS:       BasculerGris()
        case CMD_CHAMBRE:    BasculerChambre()
        case CMD_PRESET:     Prereglage(NomPrereglage(lParam))
        case CMD_HORAIRE:    DefinirHoraire(lParam)
        case CMD_RAPPEL:     Rappel.Lancer()
        case CMD_RELIRE:     Relire()
        case CMD_RESET:      ExitApp(0)
        case CMD_QUITTER:    ExitApp(0)
    }
    return 0
}
;  Si cette instance tourne elevee -- lancee d'un install.ps1 administrateur
;  d'une version precedente, ou a la main --, l'UIPI jetterait les messages
;  d'un terminal ordinaire : on declare la commande bienvenue quel que soit
;  le niveau de l'expediteur. MSGFLT_ALLOW = 1.
try DllCall("ChangeWindowMessageFilterEx", "ptr", A_ScriptHwnd, "uint", COMMANDE, "uint", 1, "ptr", 0)
OnMessage(COMMANDE, Recevoir)

NomPrereglage(n) {
    return n = 1 ? "pre_lecture" : n = 2 ? "pre_film" : "pre_nuit"
}

;  "Ocre.exe /import" a remplace le fichier : ce qui attendait d'etre ecrit
;  est abandonne -- le fichier importe fait foi --, et tout est relu, langue
;  comprise. La fenetre des reglages, si elle est ouverte, se rebatit.
Relire() {
    if (Config.tic)
        SetTimer(Config.tic, 0)
    Config.attente := Map()
    Config.Oublier()
    I18n.Definir(Config.Lire("langue"))
    Ecrans.Oublier()
    Enregistres()
    ConstruireTray()
    if (Reglages.gui)
        Reglages._Recharger()
}

;------------------------------------------------------------------- etat -----
;  Un fichier de reglages qu'on ne peut pas ecrire (voir Config._Poser) :
;  une ligne dans le journal, une boite une fois, et l'on continue.
Config.surRefus := RefusEcriture
RefusEcriture(message) {
    Journal("erreurs.log", "reglages non ecrits : " . Config.FICHIER . "  --  " . message)
    SetTimer(() => MsgBox(Format(I18n.S("config_refus"), Config.FICHIER), "Ocre", 48), -100)
}

;  Premier lancement : le fichier de reglages n'existe pas encore. A noter
;  AVANT la premiere ecriture, qui le cree.
premierLancement := !FileExist(Config.FICHIER)

derniere := Config.LireNombre("derniere")
chambreDerniere := false        ; la chambre noire etait-elle active a la coupure ?
pas      := Max(1, Config.LireNombre("pas"))     ; comme RelierTout : 1 au moins
lies     := []
refuses  := []                  ; les raccourcis que Windows n'a pas voulus
tray     := 0
iconeGrande := 0                ; icones posees sur les fenetres, a detruire
iconePetite := 0
Theme.surFenetre := IconerFenetre

if (derniere <= 0)
    derniere := 60

I18n.Definir(Config.Lire("langue"))
Theme.MenusSombres()
Config.Reveler("fondu_bascule")
Config.Reveler("hk_gris")
Config.Reveler("pastille")
Config.Reveler("adapt_periode")
Config.Reveler("adapt_fondu")
Config.Reveler("adapt_lissage")
Filtre.Charger()

;  Le garde-fou n'est pas leve : on le dit, mais APRES avoir tout mis en
;  place, et sans bloquer. Une boite modale ici retenait la liaison des
;  raccourcis et la pose du filtre tant qu'on n'avait pas clique -- a
;  chaque ouverture de session, derriere les autres fenetres. La boite
;  vient une fois tout demarre, et dans la langue de l'interface.
if (!Gamma.ClampLeve())
    SetTimer(AvertirClamp, -2000)

AvertirClamp() {
    MsgBox(I18n.S("clamp_avertissement")
         . "`n`n  HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM`n"
         . "  GdiIcmGammaRange  (REG_DWORD)  =  256`n`n"
         . I18n.S("clamp_install"), "Ocre", 48)
}

;-------------------------------------------------------------- raccourcis ----
RelierTout() {
    global lies, pas, refuses

    for combo in lies
        try Hotkey(combo, "Off")
    lies := []
    refuses := []

    pas := Max(1, Config.LireNombre("pas"))

    Lier(Config.Lire("hk_moins"),  Moins)
    Lier(Config.Lire("hk_plus"),   Plus)
    Lier(Config.Lire("hk_off"),    Alterner)
    Lier(Config.Lire("hk2_moins"), Moins)
    Lier(Config.Lire("hk2_plus"),  Plus)
    Lier(Config.Lire("hk2_off"),   Alterner)
    Lier(Config.Lire("hk_gris"),   BasculerGris)

    ;  La molette, pour un reglage continu.
    ;
    ;  Une intensite se cherche plutot qu'elle ne se saisit : la molette donne
    ;  un reglage progressif qu'aucune touche ne peut offrir. Ctrl+Alt+molette
    ;  par defaut -- Ctrl+molette seul sert au zoom un peu partout, mais y
    ;  ajouter Alt ne rentre en conflit avec rien de connu.
    ;
    ;  La luminosite prend la meme molette, Maj en plus. Un raccourci a
    ;  modificateurs ne se declenche pas si une autre touche de modification
    ;  est enfoncee : les deux jeux ne se marchent pas dessus. Les deux jeux
    ;  de modificateurs se changent dans la fenetre des raccourcis.
    ;  Les modificateurs sont valides avant d'etre lies : une valeur vide
    ;  dans ocre.ini aurait donne "WheelUp" tout court, et la molette ne
    ;  fonctionnait plus nulle part.
    molF := Raccourcis._Molette(Config.Lire("mol_filtre"), Config.DEFAUTS["mol_filtre"])
    molL := Raccourcis._Molette(Config.Lire("mol_lum"), Config.DEFAUTS["mol_lum"])
    if (molL = molF)
        molL := Config.DEFAUTS["mol_lum"] != molF ? Config.DEFAUTS["mol_lum"] : "^+"
    Lier(molF . "WheelUp", PlusMolette)
    Lier(molF . "WheelDown", MoinsMolette)
    Lier(molL . "WheelUp", PlusLum)
    Lier(molL . "WheelDown", MoinsLum)
}

;  Un raccourci refuse par Windows ne doit pas empecher les autres de vivre :
;  selon la machine, certaines combinaisons sont deja prises par le pilote
;  graphique ou reservees par le systeme.
;
;  Mais il ne doit pas non plus disparaitre en silence : un raccourci qu'on
;  croit en place et qui ne repond pas passe pour un programme casse. Le
;  refus est note dans erreurs.log, et la fenetre des reglages le nomme sous
;  les champs (Reglages.refuses).
Lier(combo, action) {
    global lies, refuses
    if (combo = "")
        return
    ;  Une touche de frappe seule -- "Space", "a" -- ecrite a la main dans
    ;  ocre.ini est refusee comme elle l'est a la capture : liee, elle ne
    ;  fonctionnerait plus nulle part ailleurs.
    if (!RegExMatch(combo, "^[\^!+#<>*~$]") && Raccourcis._Frappe(combo)) {
        refuses.Push(combo)
        Raccourcis.refuses := refuses
        Journal("erreurs.log", "raccourci refuse : " . combo . "  --  touche de frappe seule")
        return
    }
    ;  Deja lie a une autre action : Hotkey() remplacerait la premiere par la
    ;  seconde en silence. Le premier venu garde la combinaison.
    for deja in lies {
        if (Raccourcis._Normal(deja) = Raccourcis._Normal(combo)) {
            refuses.Push(combo)
            Raccourcis.refuses := refuses
            Journal("erreurs.log", "raccourci refuse : " . combo . "  --  deja pris par une autre action")
            return
        }
    }
    try {
        Hotkey(combo, action, "On")
        lies.Push(combo)
    } catch as e {
        refuses.Push(combo)
        Raccourcis.refuses := refuses
        Journal("erreurs.log", "raccourci refuse : " . combo . "  --  " . e.Message)
    }
}

;----------------------------------------------------------------- actions ----
;  Sur quel ecran ?
;
;  En mode ensemble la question ne se pose pas : la valeur va partout. En mode
;  separe il faut choisir, et les deux gestes ne designent pas la meme chose :
;  au clavier on regle l'ecran que l'on regarde, c'est-a-dire celui de la
;  fenetre active ; a la molette on regle celui que l'on survole, puisque la
;  main y est deja.
Vise(molette := false) {
    if (!Filtre.separes)
        return 0
    return molette ? Ecrans.SousSouris() : Ecrans.Actif()
}

;  manuel distingue un reglage voulu -- raccourci, molette, curseur -- d'une
;  pose faite par le planificateur ou au demarrage. Seul le premier suspend
;  l'horaire : sinon le planificateur se suspendrait lui-meme des sa premiere
;  minute.
Appliquer(p, avecPastille := true, manuel := true, ecran := 0, grisTaux := 1.0, noirTaux := 1.0) {
    demande := Round(p)

    touche := Filtre.Definir(Max(0, Min(100, demande)), "", ecran, grisTaux, true, noirTaux)
    intensite := Filtre.Lire(touche).i

    if (manuel)
        Horaire.Suspendre()
    PlanifierTray()

    if (avecPastille)
        Pastille(intensite, demande, touche)
}

;  La pastille, separee de la pose : un pas au clavier l'affiche tout de suite
;  avec la valeur d'arrivee, pendant que le fondu, lui, prend un sixieme de
;  seconde a y mener l'ecran.
Pastille(intensite, demande, ecran) {
    if (!ecran)
        ecran := Ecrans.Actif()

    ;  En butee, la valeur ne bouge pas : sans mention explicite, rien ne
    ;  distingue un raccourci mort d'un filtre deja au maximum. C'est ce qui
    ;  a fait croire que Ctrl+F6 ne repondait plus.
    if (demande > 100)
        Osd.Montrer(intensite, I18n.S("maxi"), -1, "", ecran)
    else if (demande < 0)
        Osd.Montrer(intensite, I18n.S("mini"), -1, "", ecran)
    else
        Osd.Montrer(intensite, intensite = 0 ? I18n.S("coupe") : "", -1, "", ecran)
}

;  La luminosite descend d'abord le retroeclairage, puis la rampe une fois
;  celui-ci a son plancher (voir Retro.ahk). La pastille garde la tache a la
;  couleur du filtre -- c'est elle qui identifie l'application -- mais sa barre
;  passe au gris : c'est ce qui dit qu'on ne regle pas la meme chose.
;  persister vaut faux pour un assombrissement passager -- inactivite,
;  batterie, suivi du contenu -- : ce n'est pas un reglage, et l'ecrire
;  dans ocre.ini ferait rouvrir la session suivante au plancher si la
;  machine s'eteint pendant qu'il tient.
AppliquerLum(l, avecPastille := true, ecran := 0, persister := true) {
    demande := Round(l)

    touche := Filtre.Definir("", Max(0, Min(100, demande)), ecran, 1.0, persister)
    apres := Filtre.Lire(touche)

    if (!avecPastille)
        return

    if (demande > 100)
        texte := I18n.S("maxi")
    else if (demande < 0)
        texte := I18n.S("mini")
    else
        texte := apres.l . " %"

    Osd.Montrer(apres.i, texte, apres.l, Theme.TEXTE_BAS, touche)
}

;  Fonctions nommees plutot que lambdas : une fonction imbriquee ne resout pas
;  les globales comme le ferait une expression ecrite au niveau superieur.
;  Elles relisent le pas a chaque appui, donc un changement de reglage prend
;  effet sans avoir a relier les raccourcis.
Plus(*) {
    Ajuster(+PasCourant(), Vise())
}

Moins(*) {
    Ajuster(-PasCourant(), Vise())
}

;  La molette vise l'ecran qu'elle survole, et ne fond pas : le geste est deja
;  continu.
PlusMolette(*) {
    e := Vise(true)
    Appliquer(Filtre.Lire(e).i + PasCourant(), true, true, e)
    Habitudes.Noter("intensite", Filtre.Lire(e).i)
}

MoinsMolette(*) {
    e := Vise(true)
    Appliquer(Filtre.Lire(e).i - PasCourant(), true, true, e)
    Habitudes.Noter("intensite", Filtre.Lire(e).i)
}

PlusLum(*) {
    e := Vise(true)
    AppliquerLum(Filtre.Lire(e).l + PasCourant(), true, e)
    Habitudes.Noter("luminosite", Filtre.Lire(e).l)
}

MoinsLum(*) {
    e := Vise(true)
    AppliquerLum(Filtre.Lire(e).l - PasCourant(), true, e)
    Habitudes.Noter("luminosite", Filtre.Lire(e).l)
}

Alterner(*) {
    Basculer()
}

;  Bascule le gris seul, sans toucher au filtre. C'est le meme reglage que la
;  case des reglages -- "gris" dans ocre.ini -- pris au clavier : l'ecran
;  devient gris tout de suite si le filtre est actif, et le restera aux
;  prochaines coupures tant que la case est cochee.
BasculerGris(*) {
    actif := (Config.Lire("gris") != "1")
    Config.Ecrire("gris", actif ? 1 : 0)
    Filtre.Appliquer()
    Osd.Montrer(Filtre.Lire(Vise()).i
                  , actif ? I18n.S("gris_on") : I18n.S("gris_off")
                  , -1, "", Vise() ? Vise() : Ecrans.Actif())
}

;  La chambre noire : rien que du rouge (voir Compositeur.CHAMBRE, et
;  pourquoi pas l'inversion de f.lux). Un etat de session, sans reglage ni raccourci : on
;  y entre et on en sort par la ligne du panneau, et une session s'ouvre
;  toujours en couleur. La pastille le dit, comme pour le gris.
BasculerChambre(*) {
    Filtre.chambre := !Filtre.chambre
    Filtre.Appliquer()
    Osd.Montrer(Filtre.Lire(Vise()).i
              , Filtre.chambre ? I18n.S("chambre_on") : I18n.S("gris_off")
              , -1, "", Vise() ? Vise() : Ecrans.Actif())
}

PasCourant() {
    global pas
    return Max(1, pas)
}

;  Un pas au clavier passe par le fondu : cinq points d'un coup se voient, les
;  memes cinq points en un sixieme de seconde ne se voient pas.
;
;  Deux details, tous deux appris d'une touche maintenue enfoncee. La
;  repetition automatique envoie un appui toutes les trente millisecondes, et
;  le fondu en prend cent soixante : le suivant arrive donc toujours au milieu
;  du precedent.
;
;  - Le pas se compte depuis la CIBLE du fondu en cours, pas depuis la valeur
;    posee a cet instant. Sinon 100 moins 5 se calcule depuis 97 et donne 92,
;    puis 91, puis 89 : la suite des valeurs n'a plus de sens, et la pastille
;    le montre.
;
;  - On ne pose PAS l'arrivee d'un coup avant de lancer le fondu. Le faire
;    puis repartir du depart pour animer, c'est un aller-retour visible a
;    chaque appui -- l'ecran monte, redescend, remonte. La pastille seule
;    montre l'arrivee tout de suite ; l'ecran, lui, y va en fondu depuis la ou
;    il est, quelle que soit la cible precedente.
;
;  Ainsi une touche maintenue donne 100, 95, 90, 85 a la pastille, et un
;  glissement continu a l'ecran.
Ajuster(delta, ecran := 0) {
    voie := VoieFondu("intensite", ecran)
    base := Fondu.EnCours(voie) ? Fondu.Cible(voie)
                                       : Filtre.Lire(ecran).i
    demande := base + delta
    arrivee := Max(0, Min(100, demande))

    Pastille(arrivee, demande, ecran)
    Fondu.Vers(voie, Filtre.Lire(ecran).i, arrivee
             , (v) => Appliquer(v, false, true, ecran))
    Habitudes.Noter("intensite", arrivee)
}

AjusterLum(delta, ecran := 0) {
    AppliquerLum(Filtre.Lire(ecran).l + delta, true, ecran)
    Habitudes.Noter("luminosite", Filtre.Lire(ecran).l)
}

;  "derniere" n'est mise a jour QUE par la coupure via la bascule : c'est le
;  niveau que "retablir" doit rendre. La renseigner a chaque valeur non nulle
;  reviendrait a retenir le dernier palier traverse en descendant pas a pas.
Basculer() {
    global chambreDerniere

    e := Vise()
    depart := Filtre.Lire(e).i

    ;  L'etat qui compte est celui ou le fondu en cours MENE, pas la valeur
    ;  posee a cet instant. Sinon un second appui au milieu d'une coupure
    ;  90 -> 0 trouvait 40, le prenait pour le niveau a retenir, et relancait
    ;  une coupure : trois appuis rapides ramenaient "derniere" a 5. Depuis
    ;  la cible, le second appui annule le premier -- l'ecran revient a 90 de
    ;  la ou il en est -- et le troisieme coupe a nouveau, sans rien perdre.
    voie := VoieFondu("intensite", e)
    etat := Fondu.EnCours(voie) ? Fondu.Cible(voie) : depart

    ;  La bascule coupe TOUT, chambre noire comprise : c'est le geste "rends-
    ;  moi mon ecran", et il ne doit rien laisser derriere lui. Et elle rend
    ;  tout : la chambre noire revient avec le filtre si elle etait la au
    ;  moment de couper. Si le filtre etait deja coupe, il n'y a qu'elle a
    ;  eteindre -- et le retablissement ramenera les deux.
    if (Filtre.chambre && etat = 0) {
        chambreDerniere := true
        Filtre.chambre := false
        Filtre.Appliquer()
        Pastille(0, 0, e)
        return
    }

    if (etat > 0) {
        EcrireDerniere(e, etat)
        chambreDerniere := Filtre.chambre
        Filtre.chambre := false
        cible := 0
    } else {
        cible := LireDerniere(e)
        Filtre.chambre := chambreDerniere
    }

    ;  Le gris couple au filtre suit le fondu : il vaut la fraction du chemin
    ;  parcouru entre zero et le niveau plein, dans un sens comme dans
    ;  l'autre. Sans cela il tombait d'un bloc au premier point d'intensite.
    ;  "derniere" est dans le lot pour qu'un fondu repris a mi-chemin garde
    ;  le gris la ou il en etait, au lieu de sauter a plein.
    plein := Max(depart, cible, LireDerniere(e), 1)
    Pastille(cible, cible, e)
    Fondu.Vers(voie, depart, cible
             , (v) => Appliquer(v, false, true, e, v / plein, v / plein)
             , Fondu.DureeBascule())
}

;  Le niveau que "retablir" doit rendre, par ecran quand ils sont separes :
;  sous "e<hash>_d" dans ocre.ini, comme leurs valeurs. Sans reglage propre,
;  celui de l'ensemble. En mode ensemble, la cle "derniere" de toujours.
LireDerniere(e := 0) {
    global derniere
    if (e && Filtre.separes) {
        v := Config.LireNombre(Config.CleEcran(e.id) . "_d")
        if (v > 0)
            return v
    }
    return derniere > 0 ? derniere : 60
}

EcrireDerniere(e, v) {
    global derniere
    if (e && Filtre.separes) {
        Config.Ecrire(Config.CleEcran(e.id) . "_d", v)
        return
    }
    derniere := v
    Config.Ecrire("derniere", v)
}

;  Le nom de la voie de fondu d'un ecran : une par ecran quand ils sont
;  separes, sinon un pas au clavier sur l'un reprenait la cible du fondu de
;  l'autre. "lum_<id>" est aussi la voie qu'emploient l'inactivite, la
;  batterie et le suivi du contenu.
VoieFondu(nom, ecran := 0) {
    if (!ecran)
        return nom
    return (nom = "luminosite" ? "lum_" : "intensite_") . ecran.id
}

;  Ce que le panneau relit : la cible du fondu en cours sur l'ecran vise,
;  sinon la valeur posee.
CibleOuNiveau(nom) {
    voie := VoieFondu(nom, Vise())
    if (Fondu.EnCours(voie))
        return Fondu.Cible(voie)
    return nom = "luminosite" ? NiveauLum() : Niveau()
}

;  Un prereglage pose les deux valeurs d'un coup. Il est ecrit "intensite,
;  luminosite" dans le fichier de configuration.
;  L'apercu de la fenetre des prereglages : le couple qu'on regle va a
;  l'ecran vise par le meme fondu court qu'un pas au clavier, sans pastille.
;  Ce qu'on voit en fermant reste -- pas de Valider, pas de retour : c'est
;  donc un reglage a la main comme les curseurs, qui suspend l'horaire et
;  compte pour les habitudes.
ApercuPrereglage(i, l) {
    e := Vise()
    depart := Filtre.Lire(e)
    Fondu.Vers(VoieFondu("intensite", e), depart.i, i, (v) => Appliquer(v, false, true, e))
    Fondu.Vers(VoieFondu("luminosite", e), depart.l, l, (v) => AppliquerLum(v, false, e))
    Habitudes.Noter("intensite", i)
    Habitudes.Noter("luminosite", l)
}

Prereglage(cle) {
    e := Vise()
    ;  Prereglages.Lire valide et retombe sur le defaut de la cle : un
    ;  "pre_nuit=abc" ecrit a la main ne doit pas faire planter un clic.
    v := Prereglages.Lire(cle)
    i := v.i, l := v.l

    Osd.Montrer(i, "", -1, "", e ? e : Ecrans.Actif())
    depart := Filtre.Lire(e)
    Fondu.Vers(VoieFondu("intensite", e), depart.i, i, (v) => Appliquer(v, false, true, e)
             , Fondu.DureeBascule())
    Fondu.Vers(VoieFondu("luminosite", e), depart.l, l, (v) => AppliquerLum(v, false, e)
             , Fondu.DureeBascule())
    Habitudes.Noter("intensite", i)
    Habitudes.Noter("luminosite", l)
}

Niveau() {
    return Filtre.Lire(Vise()).i
}

NiveauLum() {
    return Filtre.Lire(Vise()).l
}

;  Le panneau remplace le menu systeme au clic droit. Les trois commandes de
;  reglage le laissent ouvert, on enchaine volontiers plusieurs paliers.
;
;  Ce que le panneau relit apres une commande, c'est la valeur d'ARRIVEE du
;  fondu qu'elle a lance, pas celle posee a cet instant : "Plus chaud" passe
;  par un fondu, et relire l'ecran tout de suite rendait l'ancienne valeur --
;  le curseur ne bougeait pas.
OuvrirPanneau() {
    v := Filtre.Lire(Vise())
    Panneau.Montrer(v.i, v.l, Map(
        "intensite",  (x) => (Appliquer(x, false, true, Vise()), Habitudes.Noter("intensite", x)),
        "luminosite", (x) => (AppliquerLum(x, false, Vise()), Habitudes.Noter("luminosite", x)),
        "plus",       () => Plus(),
        "moins",      () => Moins(),
        "couper",     () => Basculer(),
        "chambre",    () => BasculerChambre(),
        "lireChambre", () => Filtre.chambre,
        "lire",       () => CibleOuNiveau("intensite"),
        "lireLum",    () => CibleOuNiveau("luminosite"),
        "prereglage", (cle) => Prereglage(cle),
        "reprendre",  () => ReprendreHoraire(),
        "unite",      () => PlanifierTray(),
        "reglages",   () => OuvrirReglages(),
        "quitter",    () => ExitApp()))
}

;  Le planificateur, suspendu par un reglage a la main, reprend sans attendre
;  le basculement : il repose l'intensite de l'heure, et la pastille le dit.
ReprendreHoraire() {
    Horaire.Reprendre()
    Osd.Montrer(Niveau(), I18n.S("horaire_on"), -1, "", Ecrans.Actif())
}

;  Pour "Ocre.exe /horaire" : 1 allume, 0 coupe, 2 bascule. C'est la meme
;  cle que la bascule des reglages, prise depuis la ligne de commande.
DefinirHoraire(v) {
    actif := (v = 2) ? (Config.Lire("horaire") != "1") : (v = 1)
    Config.Ecrire("horaire", actif ? 1 : 0)
    Horaire.Relire()
    PlanifierTray()
    Osd.Montrer(Niveau(), actif ? I18n.S("horaire_on") : I18n.S("horaire_off")
              , -1, "", Ecrans.Actif())
}

;  AutoHotkey remonte les clics sur l'icone par le message 0x404, lParam
;  portant l'evenement souris. En renvoyant 0 on empeche l'affichage du menu
;  systeme, que le panneau remplace. Gauche : les reglages ; droit : le
;  panneau ; milieu : couper ou retablir, le geste de Ctrl+F7 pour qui a la
;  main sur la souris ; la molette regle l'intensite (voir SurIcone).
Icone(wParam, lParam, msg, hwnd) {
    if (lParam = 0x0205) {              ; bouton droit relache
        OuvrirPanneau()
        return 0
    }
    if (lParam = 0x0202) {              ; bouton gauche relache
        OuvrirReglages()
        return 0
    }
    if (lParam = 0x0208) {              ; molette relachee : Ctrl+F7 a la souris
        Basculer()
        return 0
    }
    if (lParam = 0x0201 || lParam = 0x0204 || lParam = 0x0207 || lParam = 0x0203)
        return 0                        ; enfoncements et double-clic
}
OnMessage(0x404, Icone)

OuvrirReglages(*) {
    Reglages.Ouvrir((x, e) => (Appliquer(x, false, true, e), Habitudes.Noter("intensite", x))
                  , (x, e) => (AppliquerLum(x, false, e), Habitudes.Noter("luminosite", x))
                  , () => Enregistres()
                  , () => ConstruireTray())
}

;  Un enregistrement peut avoir change les raccourcis, le pas, les ecrans et
;  l'horaire : on relit tout plutot que de deviner ce qui a bouge.
Enregistres() {
    Filtre.Charger()
    Filtre.Appliquer()
    RelierTout()
    Horaire.Relire()
    Rappel.Relire()
    Inactif.Relire()
    Batterie.Relire()
    Adaptatif.Relire()
    Habitudes.Relire()
    PlanifierTray()
}

;  L'assombrissement a l'inactivite (voir Inactif.ahk) : on releve la
;  luminosite de chaque ecran, on descend au plancher en fondu ; au retour
;  on remonte a ce qui etait releve. En mode separe chaque ecran a sa voie
;  de fondu ; ensemble, une seule suffit.
avantInactif := Map()

AssombrirInactif(duree) {
    global avantInactif
    avantInactif := Map()
    if (!Filtre.separes) {
        avantInactif["*"] := Filtre.Lire().l
        Fondu.Vers("luminosite", Filtre.Lire().l, 0, (v) => AppliquerLum(v, false, 0, false), duree)
        return
    }
    for e in Ecrans.Lister() {
        avantInactif[e.id] := Filtre.Lire(e).l
        Fondu.Vers("lum_" . e.id, Filtre.Lire(e).l, 0, FondreLum.Bind(e), duree)
    }
}

EclaircirInactif(duree) {
    global avantInactif
    for id, l in avantInactif {
        e := (id = "*") ? 0 : Ecrans.ParId(id)
        if (id != "*" && !e)
            continue
        if (duree <= 0)
            AppliquerLum(l, false, e)
        else
            Fondu.Vers(id = "*" ? "luminosite" : "lum_" . id, Filtre.Lire(e).l, l
                     , FondreLum.Bind(e), duree)
    }
    avantInactif := Map()
}

;  L'assombrissement a ete defait par une relecture (reprise de veille,
;  changement d'ecran) alors qu'on est toujours inactif : on le remet, d'un
;  coup et sans toucher a ce qui a ete releve.
TenirInactif() {
    global avantInactif
    for id, l in avantInactif {
        e := (id = "*") ? 0 : Ecrans.ParId(id)
        if (id != "*" && !e)
            continue
        voie := id = "*" ? "luminosite" : "lum_" . id
        if (!Fondu.EnCours(voie) && Filtre.Lire(e).l > 0)
            AppliquerLum(0, false, e, false)
    }
}

;  Une fonction liee plutot qu'une lambda dans la boucle : la lambda
;  capturerait la variable, pas l'ecran.
FondreLum(e, v) {
    AppliquerLum(v, false, e, false)
}

;  Sur batterie (voir Batterie.ahk) : chaque ecran descend de "pourcent"
;  points, et l'on note ce qu'il avait ET ce qu'on lui a pose. Au retour du
;  secteur, un ecran dont la luminosite n'est plus celle qu'on a posee a
;  ete regle a la main entre-temps : on le laisse, comme Retro.Adopter.
BaisserBatterie(pourcent, duree) {
    global avantBatterie
    avantBatterie := Map()
    for e in (Filtre.separes ? Ecrans.Lister() : [0]) {
        id := e ? e.id : "*"
        l := Filtre.Lire(e).l
        cible := Max(0, l - pourcent)
        avantBatterie[id] := { avant: l, pose: cible }
        Fondu.Vers(id = "*" ? "luminosite" : "lum_" . id, l, cible, FondreLum.Bind(e), duree)
    }
}

RemonterBatterie(duree) {
    global avantBatterie
    for id, m in avantBatterie {
        e := (id = "*") ? 0 : Ecrans.ParId(id)
        if (id != "*" && !e)
            continue
        if (Filtre.Lire(e).l != m.pose)
            continue
        if (duree <= 0)
            AppliquerLum(m.avant, false, e)
        else
            Fondu.Vers(id = "*" ? "luminosite" : "lum_" . id, m.pose, m.avant
                     , FondreLum.Bind(e), duree)
    }
    avantBatterie := Map()
}

;  La respiration du rappel des 20-20-20 : la tache de la zone de
;  notification retrecit et regrossit doucement pendant vingt secondes, a
;  la couleur du filtre. -1 rend l'icone normale.
RespirerTray(echelle) {
    if (echelle < 0) {
        RafraichirTray()
        return
    }
    Blob.Tray(Filtre.Lire(Vise()).i, echelle, Horaire.Suspendu())
}

;-------------------------------------------------------------------- tray ----
;  L'icone est redessinee en GDI+ a chaque changement : c'est la partie la plus
;  couteuse d'un cran, et sous la molette il en passe plusieurs dizaines par
;  seconde. On la regroupe donc sur 80 ms -- assez court pour que l'icone suive
;  le geste, assez long pour ne pas la redessiner pour rien.
PlanifierTray() {
    global tray
    if (!tray)
        tray := () => RafraichirTray()
    SetTimer(tray, -80)
}

RafraichirTray() {
    intensite := Filtre.Lire(Vise()).i

    ;  Le point dans le coin dit l'horaire suspendu sans qu'on ait a
    ;  survoler l'icone.
    Blob.Tray(intensite, 1.0, Horaire.Suspendu())
    IconerFenetres(intensite)

    ;  L'infobulle dit aussi quand le planificateur se tait, et jusqu'a
    ;  quand : un horaire suspendu qui ne le dirait pas passerait pour un
    ;  horaire en panne.
    texte := intensite = 0 ? I18n.S("filtre_coupe") : Unite.Texte(intensite)
    if (Horaire.Suspendu())
        texte .= " - " . I18n.S("horaire_suspendu") . Horaire.FinSuspension()
    A_IconTip := "Ocre " . Version() . " - " . texte
}

;  L'icone des fenetres suit celle de la zone de notification.
;
;  Une fenetre porte l'icone de l'exe -- l'orange plein du logo -- tandis que
;  la zone de notification montre la tache a la teinte du filtre : deux
;  couleurs pour le meme logo, cote a cote dans la barre des taches, et
;  c'est la barre qui avait l'air fausse. WM_SETICON pose la notre sur
;  chaque fenetre visible du processus, grande pour la barre des taches,
;  petite pour la barre de titre.
;
;  Les handles nous appartiennent : Windows ne copie pas l'icone qu'on lui
;  passe, elle doit vivre tant qu'une fenetre s'en sert. On ne detruit donc
;  les precedentes qu'une fois les nouvelles posees partout.
IconerFenetres(intensite) {
    global iconeGrande, iconePetite
    grande := Blob.Icone(intensite, 32)
    petite := Blob.Icone(intensite, 16)

    for hwnd in WinGetList("ahk_pid " . ProcessExist()) {
        try {
            SendMessage(0x80, 1, grande, hwnd)      ; WM_SETICON, ICON_BIG
            SendMessage(0x80, 0, petite, hwnd)      ; ICON_SMALL
        }
    }

    if (iconeGrande)
        DllCall("DestroyIcon", "ptr", iconeGrande)
    if (iconePetite)
        DllCall("DestroyIcon", "ptr", iconePetite)
    iconeGrande := grande, iconePetite := petite
}

;  Une fenetre qui vient de s'ouvrir recoit l'icone du moment -- sur sa barre
;  de titre. Le bouton de la barre des taches, lui, garde l'orange de l'exe :
;  Windows 11 ignore l'icone de la fenetre pour ce bouton (voir README).
IconerFenetre(hwnd) {
    global iconeGrande, iconePetite
    if (!iconeGrande)
        return
    try {
        SendMessage(0x80, 1, iconeGrande, hwnd)
        SendMessage(0x80, 0, iconePetite, hwnd)
    }
}

;  Le menu systeme de l'icone n'existe plus : le clic gauche ouvre les
;  reglages, le clic droit le panneau (voir Icone), et AutoHotkey n'affiche
;  le sien que si on le laisse faire. Il ne reste que l'icone et l'infobulle
;  a tenir a jour -- et a retraduire au changement de langue.
ConstruireTray() {
    A_TrayMenu.Delete()
    RafraichirTray()
}

;-------------------------------------------------------- chien de garde ------
;  Windows reinitialise la rampe de lui-meme : sortie de veille, changement de
;  resolution, invite UAC, sortie d'un jeu plein ecran. On la remet en place
;  sans rien afficher.
;
;  Trois de ces quatre cas s'annoncent, et il serait dommage de les attendre :
;
;    WM_DISPLAYCHANGE      resolution, branchement ou debranchement d'un ecran
;    WM_POWERBROADCAST     mise en veille et sortie de veille
;    WM_WTSSESSION_CHANGE  verrouillage, deverrouillage, changement de session
;
;  Les deux premiers sont diffuses a toutes les fenetres de premier plan, dont
;  la fenetre cachee du script ; le troisieme demande un abonnement explicite.
;  La rampe revient donc dans la milliseconde au lieu d'attendre le prochain
;  tour de minuteur.
;
;  Le sondage reste, mais toutes les 10 secondes : il ne couvre plus que ce qui
;  n'envoie aucun message -- une invite UAC, la sortie d'un jeu plein ecran.
Remettre() {
    if (Filtre.Neutre())
        return
    Filtre.Appliquer()
}

;  Le pilote n'a pas toujours fini de reconfigurer l'affichage quand le message
;  arrive : on repose la rampe tout de suite, puis une seconde fois un instant
;  plus tard. Une pose de trop ne coute rien ; une pose trop tot est perdue.
;
;  Les contextes et les moniteurs physiques sont oublies au passage : ceux d'un
;  ecran qui vient d'etre debranche ne valent plus rien, et un ecran qui arrive
;  n'en a pas encore.
;
;  WM_POWERBROADCAST ne dit pas que la veille : PBT_APMPOWERSTATUSCHANGE
;  arrive a chaque pas de trois pour cent de batterie, et une remise en place
;  complete a chaque fois -- ecrans reenumeres, moniteurs physiques rouverts,
;  duplications DXGI refaites -- coutait cher pour rien, et perdait au passage
;  le retroeclairage d'origine. On ne se reveille que sur ce qui touche a
;  l'affichage : la sortie de veille (PBT_APMRESUMEAUTOMATIC 0x12,
;  PBT_APMRESUMESUSPEND 0x7) ; le reste ne va qu'a la batterie. De meme pour
;  la session : seuls le deverrouillage (WTS_SESSION_UNLOCK 0x8), l'ouverture
;  (WTS_SESSION_LOGON 0x5) et la reconnexion (WTS_CONSOLE_CONNECT 0x1,
;  WTS_REMOTE_CONNECT 0x3) comptent.
Reveil(wParam := 0, lParam := 0, msg := 0, hwnd := 0) {
    ;  Le meme message porte le changement d'alimentation : chargeur
    ;  branche ou debranche (voir Batterie.ahk).
    if (msg = 0x0218) {
        Batterie.Message(wParam)
        if (wParam != 0x12 && wParam != 0x7)
            return
    }
    if (msg = 0x02B1 && wParam != 0x8 && wParam != 0x5 && wParam != 0x1 && wParam != 0x3)
        return
    ;  Forcer plutot que remettre : une sortie de veille ou un changement de
    ;  resolution peut aussi avoir bascule le mode couleur (SDR vers HDR, par
    ;  exemple), donc la voie a prendre. Forcer vide la detection et le cache
    ;  du compositeur, que rien d'autre ne remet en cause.
    Filtre.Forcer()
    SetTimer(() => Filtre.Forcer(), -1200)
    ;  Les duplications de bureau tombent avec un changement de mode : on
    ;  les rend, elles seront refaites a la mesure suivante.
    Capture.Oublier()
}

OnMessage(0x007E, Reveil)          ; WM_DISPLAYCHANGE
OnMessage(0x0218, Reveil)          ; WM_POWERBROADCAST

;  NOTIFY_FOR_THIS_SESSION = 0. Si l'abonnement echoue -- service Terminal
;  Services arrete, strategie d'entreprise -- on s'en passe : le minuteur
;  couvre le cas, avec dix secondes de retard.
if (DllCall("wtsapi32\WTSRegisterSessionNotification"
          , "ptr", A_ScriptHwnd, "uint", 0))
    OnMessage(0x02B1, Reveil)      ; WM_WTSSESSION_CHANGE

Surveiller() {
    Ecrans.Verifier()
    AdopterLuminosite()
    if (Filtre.Neutre())
        return
    if (Filtre.Devie())
        Filtre.Appliquer()
}

;  Les touches Fn ou le curseur de Windows ont bouge le retroeclairage :
;  Ocre s'y recale sans rien afficher, au lieu de l'ecraser au geste suivant
;  (voir Retro.Adopter). Sans pastille : ce n'est pas un geste sur Ocre.
;
;  Seulement si quelqu'un a touche au clavier ou a la souris depuis le tour
;  precedent : une touche Fn est une touche, le curseur de Windows se prend
;  a la souris. Une lecture DDC coute trente a cent millisecondes de bus
;  I2C, et certains moniteurs clignotent quand on les interroge sans arret ;
;  une machine qu'on ne touche pas n'a pas de raison d'etre interrogee.
AdopterLuminosite() {
    if (A_TimeIdlePhysical > 2 * 10000)
        return
    for ch in Retro.Adopter() {
        e := Filtre.separes ? Ecrans.ParId(ch.id) : 0
        if (Filtre.separes && !e)
            continue
        AppliquerLum(ch.pourcent, false, e)
    }
}
SetTimer(Surveiller, 10000)

;--------------------------------------------------- la molette sur l'icone ---
;  Rouler la molette avec le curseur sur l'icone de la zone de notification
;  regle l'intensite, sans modificateur : c'est le geste le plus naturel qui
;  manquait, et Twinkle Tray l'a rendu attendu. Les raccourcis molette ne
;  vivent que sous cette condition (HotIf) ; ailleurs la molette est a tout
;  le monde. Le rectangle de l'icone est demande au shell a chaque coup :
;  c'est un appel, et l'icone bouge quand la zone se reorganise.
SurIcone(*) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    ;  NOTIFYICONIDENTIFIER : cbSize, hWnd, uID (1028 : l'icone d'AutoHotkey,
    ;  c'est aussi le numero de son message), guidItem.
    ;  Le handle est aligne sur sa taille : hWnd a 8 et uID a 16 en 64 bits,
    ;  4 et 8 en 32 bits, ou la structure fait 28 octets.
    taille := A_PtrSize = 8 ? 40 : 28
    id := Buffer(taille, 0)
    NumPut("UInt", taille, id, 0)
    NumPut("Ptr", A_ScriptHwnd, id, A_PtrSize)
    NumPut("UInt", 1028, id, 2 * A_PtrSize)
    r := Buffer(16, 0)
    if (DllCall("shell32\Shell_NotifyIconGetRect", "ptr", id, "ptr", r) != 0)
        return false
    return mx >= NumGet(r, 0, "Int") && mx < NumGet(r, 8, "Int")
        && my >= NumGet(r, 4, "Int") && my < NumGet(r, 12, "Int")
}
HotIf(SurIcone)
Hotkey("WheelUp", PlusMolette)
Hotkey("WheelDown", MoinsMolette)
HotIf()

;  A la sortie : arreter les fondus en cours, ecrire ce qui attendait encore,
;  se desabonner, rendre la rampe et le retroeclairage d'origine, puis rendre
;  les contextes.
Sortir(*) {
    Habitudes.Clore()
    Adaptatif.Arreter()
    Inactif.Rendre(0)
    Batterie.Rendre(0)
    Fondu.ArreterTout()
    Config.Vider()
    try DllCall("wtsapi32\WTSUnRegisterSessionNotification", "ptr", A_ScriptHwnd)
    Filtre.Rendre()
    Filtre.Oublier()
}
OnExit(Sortir)

;------------------------------------------------------------------ journaux --
;  Deux journaux dans %APPDATA%\Ocre : demarrage.log et erreurs.log. Ils sont
;  faits pour etre relus a la main apres coup, pas pour grossir : au-dela de
;  max lignes, on ne garde que la seconde moitie.
;
;  Tout est sous try : un journal qu'on ne peut pas ecrire ne doit jamais
;  empecher le filtre de fonctionner.
Journal(fichier, ligne, max := 40) {
    f := Config.DOSSIER . "\" . fichier
    try {
        Config.Init()
        if (FileExist(f)) {
            lignes := StrSplit(FileRead(f, "UTF-8"), "`n")
            if (lignes.Length > max) {
                garde := max // 2
                FileDelete(f)
                Loop garde
                    FileAppend(lignes[lignes.Length - garde - 1 + A_Index] . "`n"
                             , f, "UTF-8")
            }
        }
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") . "  -  " . ligne . "`n"
                 , f, "UTF-8")
    }
}

;  Trace de demarrage. A_TickCount donne les millisecondes ecoulees depuis
;  l'allumage de la machine : la ligne dit donc a quelle seconde apres le
;  demarrage Ocre a reellement pris la main, ce qui distingue une application
;  lente d'une application lancee tard par Windows.
Journal("demarrage.log", Round(A_TickCount / 1000)
                       . " s apres le demarrage de Windows")

ConstruireTray()
RelierTout()
Filtre.Appliquer()

;  Une commande arrivee alors que rien ne tournait s'applique maintenant que
;  tout est en place. /horaire ecrit sa cle avant que le planificateur ne la
;  lise, juste en dessous : rien d'autre a faire.
switch ordre.code {
    case CMD_INTENSITE:      Appliquer(ordre.valeur)
    case CMD_LUMINOSITE:     AppliquerLum(ordre.valeur)
    case CMD_INTENSITE_REL:  Ajuster(ordre.valeur - DECALAGE)
    case CMD_LUMINOSITE_REL: AjusterLum(ordre.valeur - DECALAGE)
    case CMD_PLUS:           Plus()
    case CMD_MOINS:          Moins()
    case CMD_BASCULE:        Basculer()
    case CMD_GRIS:           BasculerGris()
    case CMD_CHAMBRE:        BasculerChambre()
    case CMD_PRESET:         Prereglage(NomPrereglage(ordre.valeur))
    case CMD_RAPPEL:         SetTimer(() => Rappel.Lancer(), -500)
    case CMD_HORAIRE:
        Config.Ecrire("horaire", (ordre.valeur = 2 ? Config.Lire("horaire") != "1"
                                                   : ordre.valeur = 1) ? 1 : 0)
}

;  Le planificateur pose son intensite tout de suite s'il est actif : une
;  machine allumee a 23 h doit ouvrir la session a l'intensite de cette
;  heure-la, pas a celle de la derniere fois qu'on a touche au curseur.
;  Et il previent quand il se suspend ou reprend : l'infobulle suit.
Horaire.surEtat := PlanifierTray
Horaire.Init((v) => Appliquer(v, false, false), () => Niveau())

;  Le rappel des 20-20-20, s'il est demande -- et jamais filtre coupe : c'est
;  le geste qu'on fait pour montrer son ecran a quelqu'un.
Rappel.Init(RespirerTray, () => !Filtre.Coupe())

;  L'assombrissement a l'inactivite, s'il est demande.
Inactif.Init(AssombrirInactif, EclaircirInactif, TenirInactif)
Batterie.Init(BaisserBatterie, RemonterBatterie)

;  La luminosite qui suit le contenu de l'ecran (voir Adaptatif.ahk) : elle
;  se tait quand l'ecran est assombri pour inactivite et tant qu'une fenetre
;  a curseur est ouverte -- on ne dispute pas le curseur a la main qui le
;  tient --, et retire ce que la batterie a retire.
Adaptatif.Init((l, e, duree) => Fondu.Vers(e ? "lum_" . e.id : "luminosite", Filtre.Lire(e).l, l
                                         , FondreLum.Bind(e), duree)
             , () => !Inactif.assombri && !Reglages.gui && !Panneau.Ouvert()
             , () => Batterie.applique ? Batterie.pourcent : 0)

;  Les habitudes (voir Habitudes.ahk) : le modele lit la valeur courante,
;  pose la sienne par le fondu de la bascule avec une pastille qui dit
;  pourquoi, et n'a la main sur une voie que si aucun automate ne l'a --
;  le planificateur pour l'intensite ; le suivi du contenu, l'inactivite et
;  la batterie pour la luminosite.
Habitudes.soleil := SoleilDuJour
Habitudes.presence := () => A_TimeIdlePhysical < 60000
Habitudes.Init(PoserHabitude
             , (voie) => voie = "intensite" ? Niveau() : NiveauLum()
             , AutomateHabitude
             , BloqueHabitude
             , AppDevant
             , ProposerHabitude
             , (texte) => Journal("habitudes.log", texte, 300))
Horaire.decalage := () => Habitudes.Decalage("intensite")
Adaptatif.decalage := () => Habitudes.Decalage("luminosite")

;  L'automate qui tient une voie, et sa valeur brute : le planificateur
;  pour l'intensite, le suivi du contenu pour la luminosite. Les habitudes
;  n'y apprennent que l'ecart, que l'automate ajoute lui-meme (voir
;  Habitudes.Decalage).
AutomateHabitude(voie) {
    if (voie = "intensite")
        return Horaire.actif ? Round(Horaire.Cible(A_Hour * 60 + A_Min).valeur) : ""
    return (Adaptatif.actif && Adaptatif.brute >= 0) ? Adaptatif.brute : ""
}

;  Les etats passagers, ou l'on n'apprend rien et ne pose rien.
BloqueHabitude(voie) {
    return voie = "luminosite" && (Inactif.assombri || Batterie.applique)
}

;  Le soleil d'une date, pour le temps solaire des habitudes : le lieu des
;  reglages, ou celui du fuseau horaire ; rien si l'on ne sait pas.
SoleilDuJour(date) {
    lat := Lieu._Nombre(Config.Lire("lat")), lon := Lieu._Nombre(Config.Lire("lon"))
    if (!Soleil.Valide(lat, lon)) {
        f := Fuseau.Lieu()
        if (!f)
            return 0
        lat := f.lat, lon := f.lon
    }
    try {
        s := Soleil.Jour(Integer(SubStr(date, 1, 4)), Integer(SubStr(date, 5, 2)), Integer(SubStr(date, 7, 2)), lat, lon)
        if (s.lever = Soleil.JAMAIS)
            return 0
        return { lever: s.lever, coucher: s.coucher }
    }
    return 0
}

;  Deux soirs concordants : la pastille propose, un clic accepte.
;  Pastille coupee dans le panneau : pas de proposition non plus -- c'est
;  une pastille, et l'on a demande a ne plus en voir. Le modele attendra
;  d'etre sur de lui pour poser tout seul.
ProposerHabitude(voie, v, cible, accepter) {
    if (!Osd.Permise())
        return
    texte := Format(I18n.S("habitude_proposition"), voie = "intensite" ? Unite.Texte(v) : v . " %")
    Osd.Proposer(voie = "intensite" ? v : Niveau(), texte, accepter, Ecrans.Actif())
}

;  La pastille dit pourquoi : "Habitude - 5 fois", ou le nom de
;  l'application quand c'est elle qui decide. Un pas de rampe, lui, passe
;  sans pastille : il en viendrait une toutes les demi-heures.
PoserHabitude(voie, v, cible) {
    if (voie = "intensite")
        Fondu.Vers("intensite", Niveau(), v, (x) => Appliquer(x, false, false), Fondu.DureeBascule())
    else
        Fondu.Vers("luminosite", NiveauLum(), v, (x) => AppliquerLum(x, false), Fondu.DureeBascule())
    if (cible.rampe)
        return
    texte := cible.contexte != "" ? I18n.S("habitude") . " - " . RegExReplace(cible.contexte, "\.exe\+?$")
                                  : Format(I18n.S("habitude_n"), Round(cible.poids))
    if (voie = "intensite")
        Osd.Montrer(v, texte, -1, "", Ecrans.Actif())
    else
        Osd.Montrer(Niveau(), texte, v, Theme.TEXTE_BAS, Ecrans.Actif())
}

;  L'application au premier plan, pour le contexte des habitudes, avec un
;  "+" quand elle est en plein ecran -- un film et une page ne sont pas le
;  meme contexte. Ocre lui-meme et ses fenetres ne comptent pas.
;
;  Une application du Store vit derriere ApplicationFrameHost.exe, le cadre
;  que Windows lui prete : Netflix et la Calculatrice y auraient le meme nom.
;  Le vrai processus est celui de la fenetre enfant "Windows.UI.Core.CoreWindow".
AppDevant() {
    try {
        hwnd := WinGetID("A")
        nom := StrLower(WinGetProcessName(hwnd))
        if (nom = "applicationframehost.exe") {
            try {
                coeur := ControlGetHwnd("Windows.UI.Core.CoreWindow1", hwnd)
                pid := 0
                DllCall("GetWindowThreadProcessId", "ptr", coeur, "uint*", &pid)
                if (pid)
                    nom := StrLower(ProcessGetName(pid))
            }
        }
        if (nom = "ocre.exe" || nom = "autohotkey64.exe" || nom = "autohotkey32.exe")
            return ""
        return nom . (Inactif._PleinEcran() ? "+" : "")
    }
    return ""
}

Prereglages.Init(ApercuPrereglage)

;  Au premier lancement, Ocre demarre a 0 % et rien ne se passe : quelqu'un
;  qui vient de l'installer ne voit rien. Deux pastilles, une fois pour
;  toutes, disent le geste de base et ou sont les reglages.
if (premierLancement)
    SetTimer(Accueillir, -1500)

Accueillir() {
    Osd.Montrer(0, I18n.S("accueil_1"), -1, "", Ecrans.Actif(), 4000)
    SetTimer(() => Osd.Montrer(0, I18n.S("accueil_2"), -1, "", Ecrans.Actif(), 4000), -4500)
}
