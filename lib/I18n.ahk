;==============================================================================
;  I18n.ahk -- textes de l'interface, francais et anglais.
;
;  Ce fichier est encode en UTF-8 AVEC BOM : sans lui, AutoHotkey lirait les
;  accents en ANSI et afficherait "IntensitÃ©". Les autres fichiers du projet
;  restent en ASCII pur et n'ont pas cette contrainte.
;==============================================================================

#Requires AutoHotkey v2.0

class I18n {

    static langue := "fr"

    static TEXTES := Map(
        "fr", Map(
            "sous_titre",     "Filtre de lumière chaude",
            "intensite",      "INTENSITÉ",
            "ecran",          "ÉCRAN",
            "filtre",         "Filtre",
            "luminosite",     "LUMINOSITÉ",
            "lum_court",      "Luminosité",
            "raccourcis",     "RACCOURCIS",
            "comportement",   "COMPORTEMENT",
            "planificateur",  "PLANIFICATEUR",
            "principal",      "Principal",
            "secours",        "Secours",
            "moins_fort",     "Filtre moins fort",
            "plus_fort",      "Filtre plus fort",
            "couper",         "Couper / rétablir",
            "aide_molette",   "{1} règle le filtre, {2} la luminosité.",
            "aide_touches",   "Cliquez un champ puis appuyez sur la combinaison voulue. "
                            . "Sur beaucoup de portables les touches F1-F12 sont captées "
                            . "par le firmware : le jeu de secours n'en utilise aucune.",
            "reinitialiser",  "Réinitialiser",
            "pas",            "Pas par appui",
            "points",         "points de pourcentage",
            "gris_seul",      "Gris seul",
            "refuses",        "Refusé par Windows : ",
            "refuses_n",      "Refusés par Windows : ",
            "raccourcis_titre", "Raccourcis",
            "raccourcis_clavier", "Raccourcis clavier et molette",
            "molette_filtre", "Molette, filtre",
            "molette_lum",    "Molette, luminosité",
            "tester",         "Tester",
            "aide_tester",    "Écoute 5 s et dit quels raccourcis arrivent jusqu'à Windows.",
            "test_en_cours",  "Appuyez sur chacun de vos raccourcis… (5 s)",
            "test_recu",      "Reçus : ",
            "test_rien",      "Jamais arrivés : ",
            "touche_seule",   "Une touche seule bloquerait la frappe : ajoutez Ctrl, Alt ou Win.",
            "touche_prise",   "{} est déjà pris par un autre champ.",
            "ecran_n",        "Écran {}",
            "demarrage",      "Démarrer avec Windows",
            "clamp_avertissement", "Le garde-fou GdiIcmGammaRange n'est pas levé : le filtre plafonnera.`n`n"
                            . "Posez cette valeur en administrateur, puis rouvrez la session :",
            "clamp_install",  "install.ps1 le fait pour vous.",
            "config_refus",   "Les réglages ne peuvent pas être écrits dans :`n{}`n`nOcre continue de fonctionner, mais rien ne sera retenu. Déplacez-le dans un dossier où vous pouvez écrire, ou supprimez l'ocre.ini posé à côté de l'exécutable (mode portable).",
            "deja_lance",     "Ocre est déjà lancé et ne répond pas — sans doute une instance élevée (administrateur).`n`n"
                            . "Fermez-la depuis son icône près de l'horloge, ou depuis le gestionnaire des tâches, puis relancez.",
            "demarrage_refuse", "Windows a refusé de modifier le démarrage automatique.`n`n"
                            . "Une tâche planifiée posée par un administrateur (une version précédente) "
                            . "ne se remplace qu'avec l'élévation : relancez install.ps1 en administrateur.",
            "suivre_horaire", "Suivre un horaire",
            "nuit_de",        "Nuit à partir de",
            "jour_de",        "Jour à partir de",
            "fondu_court",    "Fondu",
            "minutes",        "minutes",
            "int_nuit",       "Intensité de nuit",
            "aide_horaire",   "Le fondu est long à dessein : sur trois heures, l'intensité monte "
                            . "d'un point toutes les trois minutes et ne se remarque pas. "
                            . "Un réglage à la main tient jusqu'au basculement suivant.",
            "fermer",         "Fermer",
            "appuyez",        "appuyez…",
            "aucun",          "aucun",
            "coupe",          "off",
            "maxi",           "MAX",
            "mini",           "MIN",
            "reglages",       "Réglages…",
            "plus_chaud",     "Plus chaud",
            "moins_chaud",    "Moins chaud",
            "quitter",        "Quitter",
            "filtre_coupe",   "Filtre coupé",

            "configurer",     "Configurer…",
            "planificateur_titre", "Planificateur",
            "mode_manuel",    "Manuel",
            "mode_soleil",    "Soleil",
            "mode_fixe",      "Heures fixes",
            "aide_manuel",    "Rien ne bouge tout seul : l'intensité ne change qu'aux raccourcis, "
                            . "à la molette et au panneau.",
            "lieu",           "Lieu",
            "aucun_lieu",     "non renseigné",
            "lieu_devine",    "{1} (d'après le fuseau horaire)",
            "changer",        "Changer…",
            "decalage",       "Décalage",
            "dec_nuit",       "après le coucher",
            "dec_jour",       "après le lever",
            "aide_soleil",    "Le coucher passe de 17 h en décembre à 22 h en juin : un horaire "
                            . "fixe est donc trop tard la moitié de l'année. Le décalage compte "
                            . "en minutes, et peut être négatif.",
            "lieu_titre",     "Où êtes-vous ?",
            "lieu_aide",      "Tapez une ville — « Lyon », « Lyon, France » — ou entrez vos "
                            . "coordonnées. Rien n'est envoyé sur le réseau.",
            "coordonnees",    "COORDONNÉES",
            "latitude",       "Latitude",
            "longitude",      "Longitude",
            "lieu_vide",      "Aucun lieu : l'horaire restera sur les heures fixes.",
            "lever_court",    "lever",
            "coucher_court",  "coucher",
            "jour_permanent", "Jour permanent aujourd'hui — heures fixes utilisées.",
            "nuit_permanente","Nuit permanente aujourd'hui — heures fixes utilisées.",

            "ecrans",         "ÉCRANS",
            "separer",        "Régler chaque écran séparément",

            "retro",          "Utiliser le rétroéclairage de l'écran",
            "gris",           "Passer l'écran en niveaux de gris avec le filtre",
            "noir",           "Noir OLED avec le filtre, gris sous",
            "noir_unite",     "/ 255 → noir",
            "gris_on",        "GRIS",
            "chambre",        "Chambre noire",
            "chambre_on",     "CHAMBRE NOIRE",
            "gris_off",       "COULEUR",
            "pastille",       "Pastille à l'écran",
            "reappliquer",    "Réappliquer",

            "horaire_suspendu", "horaire suspendu jusqu'à ",
            "reprendre_horaire", "Reprendre l'horaire",
            "aide_unite",     "Cliquer : pour cent ou Kelvin",
            "inactif",        "Assombrir l'écran inactif après",
            "batterie",       "Sur batterie, baisser la luminosité de",
            "adaptatif",      "Suivre le contenu de l'écran, de",
            "habitudes",      "Apprendre mes habitudes",
            "habitudes_titre", "Habitudes",
            "habitudes_aide", "Ocre retient à quel moment du jour (au sens du soleil) et dans quelle application "
                            . "vos réglages à la main mènent à quelle valeur. Deux fois : il propose. Trois fois : "
                            . "il pose la valeur lui-même, en fondu. Une correction pèse double, un silence approuve.",
            "habitudes_compte", "{} observations · {} créneaux sûrs",
            "habitudes_oublier", "Oublier…",
            "habitudes_oublier_confirmer", "Oublier toutes les habitudes apprises ?",
            "habitude",       "Habitude",
            "habitude_n",     "Habitude · {} fois",
            "habitude_proposition", "{} comme hier ?",
            "plein_ecran",    "plein écran",
            "habitudes_vide", "Cliquer une demi-heure pour voir ses observations.",
            "habitudes_correction", "correction",
            "habitudes_implicite", "approuvée",
            "adapt_a",        "à",
            "reset_tout",     "Réinitialiser…",
            "exporter",       "Exporter…",
            "importer",       "Importer…",
            "exporter_titre", "Enregistrer les réglages d'Ocre",
            "importer_titre", "Ouvrir un fichier de réglages d'Ocre",
            "importer_refus", "Ce fichier n'est pas un fichier de réglages d'Ocre.",
            "reset_tout_confirmer", "Remettre tous les réglages d'Ocre à leurs valeurs d'origine ?`n`n"
                            . "Raccourcis, horaire, lieu, préréglages, langue : tout. "
                            . "Le démarrage automatique n'est pas touché.",
            "accueil_1",      "Ctrl+F6 : plus chaud",
            "accueil_2",      "Clic droit sur l'icône",
            "horaire_on",     "HORAIRE",
            "horaire_off",    "SANS HORAIRE",

            "alerte_nl",      "Éclairage nocturne de Windows programmé : les filtres se cumuleront.",
            "alerte_fc",      "Filtre de couleur de Windows actif : l'écran restera gris sans Ocre.",
            "alerte_deux",    "Éclairage nocturne programmé et filtre de couleur de Windows actif.",
            "alerte_app",     "{1} tourne aussi : deux filtres se disputeraient l'écran.",

            "pre_lecture",    "Lecture",
            "pre_film",       "Film",
            "pre_nuit",       "Nuit",
            "prereglages",    "Préréglages du panneau",
            "prereglages_titre", "Préréglages",
            "aide_prereglages", "Lecture, Film, Nuit : les trois boutons du panneau du clic droit. "
                            . "Chacun pose l'intensité et la luminosité d'un coup.",

            "apropos",        "À propos…",
            "version_n",      "Version {1}",
            "apropos_texte",  "Filtre de lumière chaude pour Windows 11, piloté au clavier. "
                            . "Logiciel libre, sous licence MIT. Ocre n'ouvre lui-même aucune "
                            . "connexion réseau : les liens ci-dessous ouvrent votre navigateur.",
            "liens_titre",    "LIENS",
            "lien_depot",     "Projet sur GitHub",
            "lien_versions",  "Notes de version",
            "assistance_titre", "ASSISTANCE",
            "copier_diag",    "Copier le diagnostic",
            "diag_copie",     "Copié : collez-le dans votre signalement.",
            "dossier_reglages", "Dossier des réglages",
            "licences_titre", "LICENCES",
            "licences_texte", "Ocre : licence MIT. Embarqués dans l'exécutable : AutoHotkey v2, "
                            . "l'interpréteur (GNU GPL v2) · Inter, la police de la pastille "
                            . "(SIL OFL 1.1) · GeoNames, la table des villes (CC BY 4.0).",

            "rappel",         "Rappel 20-20-20 : toutes les 20 min, regarder au loin 20 s"),
        "en", Map(
            "sous_titre",     "Warm light filter",
            "intensite",      "INTENSITY",
            "ecran",          "SCREEN",
            "filtre",         "Filter",
            "luminosite",     "BRIGHTNESS",
            "lum_court",      "Brightness",
            "raccourcis",     "SHORTCUTS",
            "comportement",   "BEHAVIOUR",
            "planificateur",  "SCHEDULE",
            "principal",      "Primary",
            "secours",        "Fallback",
            "moins_fort",     "Weaker filter",
            "plus_fort",      "Stronger filter",
            "couper",         "Toggle off / on",
            "aide_molette",   "{1} adjusts the filter, {2} the brightness.",
            "aide_touches",   "Click a field, then press the combination you want. "
                            . "On many laptops F1-F12 are swallowed by the firmware: "
                            . "the fallback set uses none of them.",
            "reinitialiser",  "Reset",
            "pas",            "Step per press",
            "points",         "percentage points",
            "gris_seul",      "Greyscale only",
            "refuses",        "Refused by Windows: ",
            "refuses_n",      "Refused by Windows: ",
            "raccourcis_titre", "Shortcuts",
            "raccourcis_clavier", "Keyboard and wheel shortcuts",
            "molette_filtre", "Wheel, filter",
            "molette_lum",    "Wheel, brightness",
            "tester",         "Test",
            "aide_tester",    "Listens for 5 s and tells which shortcuts reach Windows.",
            "test_en_cours",  "Press each of your shortcuts… (5 s)",
            "test_recu",      "Received: ",
            "test_rien",      "Never arrived: ",
            "touche_seule",   "A bare key would block typing: add Ctrl, Alt or Win.",
            "touche_prise",   "{} is already used by another field.",
            "ecran_n",        "Screen {}",
            "demarrage",      "Start with Windows",
            "clamp_avertissement", "The GdiIcmGammaRange safeguard is not lifted: the filter will be capped.`n`n"
                            . "Set this value as administrator, then sign out and back in:",
            "clamp_install",  "install.ps1 does it for you.",
            "config_refus",   "Settings cannot be written to:`n{}`n`nOcre keeps working, but nothing will be remembered. Move it to a folder you can write to, or remove the ocre.ini next to the executable (portable mode).",
            "deja_lance",     "Ocre is already running and not answering — probably an elevated (administrator) instance.`n`n"
                            . "Close it from its icon next to the clock, or from Task Manager, then start again.",
            "demarrage_refuse", "Windows refused to change the automatic startup.`n`n"
                            . "A scheduled task set by an administrator (a previous version) can only be "
                            . "replaced with elevation: run install.ps1 as administrator.",
            "suivre_horaire", "Follow a schedule",
            "nuit_de",        "Night from",
            "jour_de",        "Day from",
            "fondu_court",    "Fade",
            "minutes",        "minutes",
            "int_nuit",       "Night intensity",
            "aide_horaire",   "The fade is deliberately long: over three hours the intensity rises "
                            . "by one point every three minutes and goes unnoticed. "
                            . "A manual change holds until the next switch.",
            "fermer",         "Close",
            "appuyez",        "press…",
            "aucun",          "none",
            "coupe",          "off",
            "maxi",           "MAX",
            "mini",           "MIN",
            "reglages",       "Settings…",
            "plus_chaud",     "Warmer",
            "moins_chaud",    "Cooler",
            "quitter",        "Quit",
            "filtre_coupe",   "Filter off",

            "configurer",     "Configure…",
            "planificateur_titre", "Schedule",
            "mode_manuel",    "Manual",
            "mode_soleil",    "Sun",
            "mode_fixe",      "Fixed hours",
            "aide_manuel",    "Nothing moves on its own: intensity only changes through the "
                            . "shortcuts, the wheel and the panel.",
            "lieu",           "Location",
            "aucun_lieu",     "not set",
            "lieu_devine",    "{1} (from the time zone)",
            "changer",        "Change…",
            "decalage",       "Offset",
            "dec_nuit",       "after sunset",
            "dec_jour",       "after sunrise",
            "aide_soleil",    "Sunset moves from 5 pm in December to 10 pm in June, so a fixed "
                            . "schedule is late half the year. The offset counts in minutes, "
                            . "and may be negative.",
            "lieu_titre",     "Where are you?",
            "lieu_aide",      "Type a city — “Lyon”, “Lyon, France” — or enter your "
                            . "coordinates. Nothing is sent over the network.",
            "coordonnees",    "COORDINATES",
            "latitude",       "Latitude",
            "longitude",      "Longitude",
            "lieu_vide",      "No location: the schedule will keep its fixed hours.",
            "lever_court",    "sunrise",
            "coucher_court",  "sunset",
            "jour_permanent", "Midnight sun today — fixed hours used instead.",
            "nuit_permanente","Polar night today — fixed hours used instead.",

            "ecrans",         "SCREENS",
            "separer",        "Set each screen separately",

            "retro",          "Use the display backlight",
            "gris",           "Turn the screen greyscale along with the filter",
            "noir",           "OLED black with the filter, greys below",
            "noir_unite",     "/ 255 → black",
            "gris_on",        "GREY",
            "chambre",        "Darkroom",
            "chambre_on",     "DARKROOM",
            "gris_off",       "COLOUR",
            "pastille",       "On-screen badge",
            "reappliquer",    "Reapply",

            "horaire_suspendu", "schedule paused until ",
            "reprendre_horaire", "Resume the schedule",
            "aide_unite",     "Click: percent or Kelvin",
            "inactif",        "Dim the idle screen after",
            "batterie",       "On battery, lower brightness by",
            "adaptatif",      "Follow the screen content, from",
            "habitudes",      "Learn my habits",
            "habitudes_titre", "Habits",
            "habitudes_aide", "Ocre remembers at what moment of the day (relative to the sun) and in which application "
                            . "your manual settings lead to what value. Twice: it suggests. Three times: "
                            . "it sets the value itself, with a fade. A correction counts double, silence approves.",
            "habitudes_compte", "{} observations · {} confident slots",
            "habitudes_oublier", "Forget…",
            "habitudes_oublier_confirmer", "Forget every learned habit?",
            "habitude",       "Habit",
            "habitude_n",     "Habit · {} times",
            "habitude_proposition", "{} like yesterday?",
            "plein_ecran",    "full screen",
            "habitudes_vide", "Click a half-hour to see its observations.",
            "habitudes_correction", "correction",
            "habitudes_implicite", "approved",
            "adapt_a",        "to",
            "reset_tout",     "Reset…",
            "exporter",       "Export…",
            "importer",       "Import…",
            "exporter_titre", "Save Ocre's settings",
            "importer_titre", "Open an Ocre settings file",
            "importer_refus", "This is not an Ocre settings file.",
            "reset_tout_confirmer", "Reset all of Ocre's settings to their original values?`n`n"
                            . "Shortcuts, schedule, location, presets, language: everything. "
                            . "Automatic startup is left as it is.",
            "accueil_1",      "Ctrl+F6: warmer",
            "accueil_2",      "Right-click the icon",
            "horaire_on",     "SCHEDULE",
            "horaire_off",    "NO SCHEDULE",

            "alerte_nl",      "Windows Night Light is scheduled: both filters will add up.",
            "alerte_fc",      "Windows colour filter is on: the screen stays grey without Ocre.",
            "alerte_deux",    "Windows Night Light scheduled and colour filter on.",
            "alerte_app",     "{1} is also running: two filters would fight over the screen.",

            "pre_lecture",    "Reading",
            "pre_film",       "Film",
            "pre_nuit",       "Night",
            "prereglages",    "Panel presets",
            "prereglages_titre", "Presets",
            "aide_prereglages", "Reading, Film, Night: the three buttons of the right-click panel. "
                            . "Each sets intensity and brightness at once.",

            "apropos",        "About…",
            "version_n",      "Version {1}",
            "apropos_texte",  "Warm-light screen filter for Windows 11, driven from the keyboard. "
                            . "Free software under the MIT licence. Ocre itself opens no network "
                            . "connection: the links below open your browser.",
            "liens_titre",    "LINKS",
            "lien_depot",     "Project on GitHub",
            "lien_versions",  "Release notes",
            "assistance_titre", "SUPPORT",
            "copier_diag",    "Copy diagnostic",
            "diag_copie",     "Copied: paste it into your report.",
            "dossier_reglages", "Settings folder",
            "licences_titre", "LICENCES",
            "licences_texte", "Ocre: MIT licence. Embedded in the executable: AutoHotkey v2, "
                            . "the interpreter (GNU GPL v2) · Inter, the badge font "
                            . "(SIL OFL 1.1) · GeoNames, the city table (CC BY 4.0).",

            "rappel",         "20-20-20 reminder: every 20 min, look far away for 20 s"))

    static S(cle) {
        t := I18n.TEXTES[I18n.langue]
        return t.Has(cle) ? t[cle] : cle
    }

    static Definir(langue) {
        langue := StrLower(Trim(langue))            ; "FR" ecrit a la main vaut "fr"
        if (I18n.TEXTES.Has(langue))
            I18n.langue := langue
    }

    ;  Une heure de la journee, a l'affichage : "21:00" en francais, "9:00 PM"
    ;  en anglais -- un Americain lit 19:00 comme une erreur. Ce qui est ecrit
    ;  dans ocre.ini reste en 24 h (voir Horaire.EnTexte) ; ceci ne sert qu'a
    ;  ce qu'on lit.
    static Heure(minutes) {
        minutes := Mod(Mod(Round(minutes), 1440) + 1440, 1440)
        h := minutes // 60, mn := Mod(minutes, 60)
        if (I18n.langue != "en")
            return Format("{:02}:{:02}", h, mn)
        h12 := Mod(h, 12) = 0 ? 12 : Mod(h, 12)
        return Format("{}:{:02} {}", h12, mn, h < 12 ? "AM" : "PM")
    }
}
