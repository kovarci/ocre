;==============================================================================
;  Config.ahk -- reglages persistes et demarrage automatique.
;
;  Les reglages vivent dans %APPDATA%\Ocre\ocre.ini plutot qu'a cote du
;  programme : l'application reste ainsi fonctionnelle meme installee dans un
;  dossier ou l'utilisateur n'a pas le droit d'ecrire.
;
;  Sauf en mode portable : un ocre.ini pose A COTE de l'executable prend le
;  pas, et les journaux le rejoignent. C'est ce qui permet d'emporter Ocre et
;  ses reglages sur une cle USB ou dans un dossier synchronise. Le fichier
;  doit exister -- meme vide -- pour que le mode s'active : c'est un choix
;  qu'on fait en le creant, pas un comportement qui se declenche tout seul.
;==============================================================================

#Requires AutoHotkey v2.0

class Config {

    static DOSSIER := A_AppData . "\Ocre"
    static FICHIER := A_AppData . "\Ocre\ocre.ini"
    static portable := false

    static __New() {
        f := A_ScriptDir . "\ocre.ini"
        if (FileExist(f)) {
            Config.DOSSIER := A_ScriptDir
            Config.FICHIER := f
            Config.portable := true
        }
    }

    static DELAI := 200       ; regroupement des ecritures, en millisecondes

    ;  La langue de Windows decide de celle du premier lancement : francais
    ;  si l'interface est en francais, anglais pour tout le reste. Le
    ;  drapeau des reglages fait le choix suivant. LANGID : les dix bits bas
    ;  disent la langue, 0x0C est le francais, quel que soit le pays.
    static LangueSysteme() {
        try {
            id := DllCall("GetUserDefaultUILanguage", "ushort")
            return (id & 0x3FF) = 0x0C ? "fr" : "en"
        }
        return "en"
    }

    static DEFAUTS := Map(
        "intensite",   "0",       ; intensite courante, 0-100
        "derniere",    "60",      ; valeur retablie par la bascule
        "luminosite",  "100",     ; luminosite, 0-100, materiel puis rampe
        "pas",         "5",       ; points de pourcentage par appui
        "fondu_bascule", "1000",  ; duree du fondu de la bascule, en ms (160 = coup sec)
        "hk_moins",    "^F5",
        "hk_plus",     "^F6",
        "hk_off",      "^F7",
        "hk2_moins",   "^!BS",
        "hk2_plus",    "^!Enter",
        "hk2_off",     "^!Space",
        "mol_filtre",  "^!",      ; modificateurs de la molette qui regle le filtre
        "mol_lum",     "^!+",     ; ... et de celle qui regle la luminosite
        "langue",      Config.LangueSysteme(),   ; fr si Windows est en francais, en sinon
        "unite",       "pct",     ; pct | k : l'intensite s'affiche en % ou en Kelvin
        "retro",       "1",       ; se servir du retroeclairage materiel
        "gris",        "0",       ; niveaux de gris couples au filtre
        "noir",        "0",       ; noir profond (OLED) : seuil 0-64 sous lequel un gris devient noir, 0 = rien
        "noir_seuil",  "28",      ; le seuil choisi, garde quand le noir profond est coupe
        "hk_gris",     "",        ; raccourci qui bascule le gris seul
        "voie",        "auto",    ; auto | gamma | compositeur (HDR)
        "separes",     "0",       ; un reglage par ecran
        "horaire",     "0",       ; planificateur, coupe par defaut
        "h_soleil",    "0",       ; caler l'horaire sur le soleil
        "lat",         "",        ; latitude, en degres decimaux
        "lon",         "",        ; longitude, positive vers l'est
        "lieu",        "",        ; libelle du lieu, pour l'affichage
        "h_debut",     "21:00",   ; debut de la montee vers l'intensite de nuit
        "h_fin",       "07:00",   ; debut de la descente vers celle de jour
        "h_dec_nuit",  "0",       ; decalage sur le coucher, en minutes
        "h_dec_jour",  "0",       ; decalage sur le lever, en minutes
        "h_fondu",     "180",     ; duree d'un fondu, en minutes
        "h_nuit",      "60",      ; intensite visee la nuit
        "h_jour",      "0",       ; intensite visee le jour
        ;  Prereglages du panneau, "intensite,luminosite". Ils se reglent dans
        ;  leur propre fenetre (Prereglages.ahk), ouverte depuis les reglages.
        "pre_lecture", "35,85",
        "pre_film",    "15,70",
        "pre_nuit",    "75,40",
        ;  La regle des 20-20-20 (voir Rappel.ahk), coupee par defaut.
        "rappel",      "0",
        "rappel_minutes", "20",
        ;  Assombrir l'ecran qu'on ne regarde plus (voir Inactif.ahk).
        "inactif",     "0",
        "inactif_minutes", "10",
        ;  La luminosite qui suit le contenu de l'ecran (voir Adaptatif.ahk),
        ;  entre deux bornes.
        "adaptatif",   "0",
        "adapt_mini",  "30",
        "adapt_maxi",  "100",
        "adapt_periode", "150",   ; ms entre deux mesures de l'ecran
        "adapt_fondu", "600",     ; ms du mouvement vers la nouvelle luminosite
        "adapt_lissage", "0.6",   ; part de la mesure neuve dans la moyenne glissante
        ;  Baisser la luminosite sur batterie (voir Batterie.ahk).
        "batterie",    "0",
        "batterie_pourcent", "20",
        ;  La taille de chaque fenetre, "largeur,hauteur" en points, retenue
        ;  quand on la tire par ses bords (voir Cadre.ahk) : taille_reglages,
        ;  taille_planificateur, taille_raccourcis, taille_prereglages,
        ;  taille_lieu. Absentes, la fenetre prend la hauteur de son contenu.
        ;  Apprendre les reglages faits a la main (voir Habitudes.ahk).
        "habitudes",   "0",
        ;  La pastille a l'ecran, a chaque geste. Se coupe dans le panneau
        ;  du clic droit ; les pastilles d'accueil ne l'ecoutent pas.
        "pastille",    "1")

    ;  Ecritures en attente. Une valeur qui vient d'etre posee doit pouvoir
    ;  etre relue tout de suite : sans ce tampon, une lecture pendant les
    ;  200 ms de regroupement renverrait l'ancienne valeur du fichier.
    static attente := Map()
    static tic := 0

    static Init() {
        if (!DirExist(Config.DOSSIER))
            DirCreate(Config.DOSSIER)
    }

    ;  Ce qui a deja ete lu, pour ne pas rouvrir le fichier a chaque appel :
    ;  pendant un fondu, "voie", "gris" et "pastille" etaient relus soixante
    ;  fois par seconde. Le cache tombe des que le fichier change de date --
    ;  verifiee au plus une fois par seconde --, ce qui garde vivante une
    ;  edition a la main d'ocre.ini, et a chaque ecriture, import ou reset.
    static cache := Map()
    static dateVue := ""
    static verifie := 0

    static Lire(cle) {
        if (Config.attente.Has(cle))
            return Config.attente[cle]
        Config._Surveiller()
        if (Config.cache.Has(cle))
            return Config.cache[cle]
        Config.Init()
        defaut := Config.DEFAUTS.Has(cle) ? Config.DEFAUTS[cle] : ""
        return Config.cache[cle] := IniRead(Config.FICHIER, "ocre", cle, defaut)
    }

    static _Surveiller() {
        if (A_TickCount - Config.verifie < 1000)
            return
        Config.verifie := A_TickCount
        date := ""
        try date := FileGetTime(Config.FICHIER, "M")
        if (date != Config.dateVue) {
            Config.dateVue := date
            Config.cache := Map()
        }
    }

    ;  Apres une ecriture de notre main, la date change sans que le cache
    ;  ait a tomber : on prend la nouvelle pour reference.
    static _Datee() {
        try Config.dateVue := FileGetTime(Config.FICHIER, "M")
        Config.verifie := A_TickCount
    }

    static Oublier() {
        Config.cache := Map()
        Config.dateVue := ""
        Config.verifie := 0
    }

    ;  Ecrit la valeur par defaut d'une cle si elle est absente du fichier.
    ;  Une cle qui n'a pas de commande dans les reglages ne se decouvre qu'en
    ;  ouvrant ocre.ini : encore faut-il qu'elle y soit.
    static Reveler(cle) {
        Config.Init()
        if (IniRead(Config.FICHIER, "ocre", cle, "<absent>") = "<absent>")
            Config.Ecrire(cle, Config.DEFAUTS[cle])
    }

    static LireNombre(cle) {
        v := Config.Lire(cle)
        return IsNumber(v) ? Integer(v) : 0
    }

    ;  Une ecriture immediate annule l'ecriture differee qui attendait sur la
    ;  meme cle, sans quoi l'ancienne valeur reviendrait 200 ms plus tard.
    ;
    ;  Le Has n'est pas une precaution de style : Map.Delete leve si la cle est
    ;  absente, et elle l'est presque toujours.
    static Ecrire(cle, valeur) {
        Config.Init()
        if (Config.attente.Has(cle))
            Config.attente.Delete(cle)
        Config._Poser(cle, valeur)
        Config.cache[cle] := "" . valeur
        Config._Datee()
    }

    ;  Le fichier est cree en UTF-16 avec sa marque d'ordre : IniWrite le
    ;  respecte ensuite, et les accents d'un libelle -- "Geneve, Suisse",
    ;  "Emirats arabes unis" -- survivent a n'importe quelle page de codes,
    ;  japonaise ou russe comprise, et d'une machine a l'autre. Cree en ANSI
    ;  par IniWrite, ils devenaient des points d'interrogation.
    static _Creer() {
        if (!FileExist(Config.FICHIER))
            try FileAppend("[ocre]`r`n", Config.FICHIER, "UTF-16")
    }

    ;  Une ecriture refusee -- mode portable dans un dossier qu'on ne peut
    ;  pas ecrire, Program Files par exemple -- ne doit pas faire lever une
    ;  boite d'erreur a chaque geste : on le note une fois, on previent une
    ;  fois (surRefus), et l'application continue avec ses valeurs en
    ;  memoire.
    static refusee := false
    static surRefus := 0

    static _Poser(cle, valeur) {
        Config._Creer()
        try {
            IniWrite(valeur, Config.FICHIER, "ocre", cle)
        } catch as e {
            if (Config.refusee)
                return
            Config.refusee := true
            if (Config.surRefus)
                try (Config.surRefus)(e.Message)
        }
    }

    ;--------------------------------------------------------------------------
    ;  Ecriture differee.
    ;
    ;  L'intensite et la luminosite changent en continu sous la molette et sous
    ;  le curseur : une ecriture par cran, c'est plusieurs dizaines d'acces
    ;  disque par seconde pour une valeur dont seule la derniere compte. On les
    ;  regroupe donc, et le minuteur repart a chaque nouveau cran -- le fichier
    ;  n'est touche qu'une fois le geste termine.
    ;
    ;  Le delai est court a dessein : c'est aussi la fenetre pendant laquelle
    ;  une coupure de courant perdrait le reglage.
    ;--------------------------------------------------------------------------
    static EcrireDiffere(cle, valeur) {
        Config.attente[cle] := "" . valeur
        if (!Config.tic)
            Config.tic := () => Config.Vider()
        SetTimer(Config.tic, -Config.DELAI)
    }

    ;--------------------------------------------------------------------------
    ;  La cle sous laquelle sont ranges les reglages d'un ecran.
    ;
    ;  Un identifiant d'ecran ressemble a
    ;  MONITOR\SDC41B5\{4d36e96e-...}\0001 : des barres obliques, des accolades
    ;  et soixante caracteres, dont un fichier INI ne veut pas comme nom de
    ;  cle. On le replie donc sur huit chiffres hexadecimaux.
    ;
    ;  C'est un FNV-1a tronque a 32 bits. Deux ecrans differents tomberaient
    ;  sur la meme cle une fois sur quatre milliards ; on n'en branche pas
    ;  tant.
    ;--------------------------------------------------------------------------
    static CleEcran(id) {
        h := 2166136261
        Loop Parse id {
            h := (h ^ Ord(A_LoopField)) & 0xFFFFFFFF
            h := (h * 16777619) & 0xFFFFFFFF
        }
        return "e" . Format("{:08x}", h)
    }

    ;  Une copie du fichier, ce qui attendait encore compris. C'est tout
    ;  l'export : les reglages tiennent dans ocre.ini, et une copie du
    ;  fichier les emporte -- raccourcis, lieu, prereglages, langue.
    static Exporter(chemin) {
        Config.Init()
        Config.Vider()
        Config._Creer()
        FileCopy(Config.FICHIER, chemin, true)
    }

    ;  L'inverse. Un fichier sans section [ocre] est refuse : IniRead sans
    ;  cle rend les cles de la section, et une section absente en rend zero.
    ;  Ce qui attendait d'etre ecrit est abandonne : le fichier importe fait
    ;  foi. Rend vrai si le fichier a ete pris.
    static Importer(chemin) {
        try cles := IniRead(chemin, "ocre")
        catch
            return false
        if (Trim(cles, "`r`n ") = "")
            return false
        if (Config.tic)
            SetTimer(Config.tic, 0)
        Config.attente := Map()
        Config.Init()
        FileCopy(chemin, Config.FICHIER, true)
        Config.Oublier()
        return true
    }

    static Vider() {
        if (Config.tic)
            SetTimer(Config.tic, 0)
        if (!Config.attente.Count)
            return
        Config.Init()
        for cle, valeur in Config.attente.Clone() {
            Config._Poser(cle, valeur)
            Config.cache[cle] := "" . valeur
        }
        Config.attente := Map()
        Config._Datee()
    }
}

;==============================================================================
;  Demarrage automatique, par raccourci dans le dossier Demarrage.
;
;  On vise l'executable compile quand il y en a un, sinon l'interpreteur avec
;  le script en argument. C'est ce qui determine le nom affiche par le
;  gestionnaire des taches : "Ocre.exe" dans le premier cas, "AutoHotkey64.exe"
;  dans le second.
;==============================================================================
class Demarrage {

    static LIEN := A_Startup . "\Ocre.lnk"
    static TACHE := "Ocre"

    static Actif() {
        return (Demarrage.TacheExiste() || FileExist(Demarrage.LIEN)) ? true : false
    }

    ;--------------------------------------------------------------------------
    ;  La question "la tache existe-t-elle ?" est posee a chaque ouverture des
    ;  reglages, pour placer la bascule. Y repondre par schtasks.exe demanderait
    ;  de lancer un processus et de l'attendre, dans la boucle de construction
    ;  de la fenetre. Le service du planificateur repond a la meme question sans
    ;  quitter le processus.
    ;
    ;  GetTask leve si la tache n'existe pas : c'est le try qui repond non. Il
    ;  repond non aussi si le service est inaccessible -- l'utilisateur verra
    ;  alors une bascule eteinte, et la reactiver reecrira la tache, ce qui est
    ;  sans consequence.
    ;--------------------------------------------------------------------------
    static TacheExiste() {
        try {
            service := ComObject("Schedule.Service")
            service.Connect()
            service.GetFolder("\").GetTask(Demarrage.TACHE)
            return true
        }
        return false
    }

    ;--------------------------------------------------------------------------
    ;  Deux mecanismes possibles, et ils ne se valent pas.
    ;
    ;  Un raccourci dans le dossier Demarrage est lance par l'explorateur une
    ;  fois le shell pret, derriere tous les autres elements de la file : mesure
    ;  faite sur un portable charge en services constructeur, 46 secondes apres
    ;  l'allumage, alors que l'application s'initialise en 0,35 s.
    ;
    ;  Une tache planifiee a l'ouverture de session echappe a cette file. C'est
    ;  donc le mecanisme prefere, avec repli sur le raccourci si le
    ;  planificateur refuse -- certaines strategies d'entreprise l'interdisent.
    ;
    ;  Un seul des deux est actif a la fois, sinon l'application se lancerait
    ;  deux fois.
    ;--------------------------------------------------------------------------
    ;  Renvoie faux si l'etat demande n'a pas ete obtenu. Creer ou supprimer une
    ;  tache a l'ouverture de session demande des droits administrateur : sans
    ;  eux, schtasks echoue en silence. Une bascule qui revient toute seule sans
    ;  un mot laisse croire a un programme casse -- on verifie donc, et
    ;  l'appelant a de quoi le dire.
    static Definir(actif) {
        if (!actif) {
            Demarrage.SupprimerTache()
            try FileDelete(Demarrage.LIEN)
            return !Demarrage.Actif()
        }

        if (A_IsCompiled && Demarrage.CreerTache()) {
            try FileDelete(Demarrage.LIEN)
            return true
        }
        return Demarrage.CreerLien()
    }

    ;  Par le service du planificateur plutot que par schtasks.exe : ce
    ;  dernier pose ses defauts, et ils sont faits pour une tache de fond,
    ;  pas pour une application -- "ne pas demarrer sur batterie", "arreter
    ;  si l'on passe sur batterie", "arreter au bout de trois jours". Sur un
    ;  portable, debrancher le chargeur tuait Ocre net, rampe chaude laissee
    ;  a l'ecran. Ici tout cela est dit explicitement.
    ;
    ;  Creer la tache ne demande pas l'elevation (verifie) ; remplacer une
    ;  tache posee par un administrateur, si : RegisterTaskDefinition leve
    ;  alors, et l'appelant le dit.
    static CreerTache() {
        try {
            service := ComObject("Schedule.Service")
            service.Connect()
            def := service.NewTask(0)
            def.RegistrationInfo.Description := "Ocre - filtre de lumiere chaude"

            s := def.Settings
            s.DisallowStartIfOnBatteries := false
            s.StopIfGoingOnBatteries := false
            s.ExecutionTimeLimit := "PT0S"           ; jamais arrete pour duree
            s.MultipleInstancesPolicy := 2           ; TASK_INSTANCES_IGNORE_NEW
            s.StartWhenAvailable := true
            s.IdleSettings.StopOnIdleEnd := false

            trig := def.Triggers.Create(9)           ; TASK_TRIGGER_LOGON
            trig.UserId := EnvGet("USERDOMAIN") . "\" . A_UserName

            act := def.Actions.Create(0)             ; TASK_ACTION_EXEC
            act.Path := A_ScriptFullPath

            def.Principal.LogonType := 3             ; TASK_LOGON_INTERACTIVE_TOKEN
            def.Principal.RunLevel := 0              ; TASK_RUNLEVEL_LUA : sans elevation

            service.GetFolder("\").RegisterTaskDefinition(Demarrage.TACHE, def
                , 6, "", "", 3)                      ; TASK_CREATE_OR_UPDATE, TASK_LOGON_INTERACTIVE_TOKEN
            return Demarrage.TacheExiste()
        }
        return false
    }

    static SupprimerTache() {
        try {
            service := ComObject("Schedule.Service")
            service.Connect()
            service.GetFolder("\").DeleteTask(Demarrage.TACHE, 0)
        }
    }

    static CreerLien() {
        if (A_IsCompiled) {
            cible := A_ScriptFullPath
            args := ""
            icone := A_ScriptFullPath
        } else {
            cible := A_AhkPath
            args := '"' . A_ScriptFullPath . '"'
            ico := A_ScriptDir . "\Ocre.ico"
            icone := FileExist(ico) ? ico : A_AhkPath
        }
        try {
            FileCreateShortcut(cible, Demarrage.LIEN, A_ScriptDir, args
                             , "Ocre - filtre de lumiere chaude", icone)
            return true
        }
        return false
    }
}

