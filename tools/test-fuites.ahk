;  test-fuites.ahk -- ce qui se dessine mille fois ne doit rien laisser.
;
;  Ocre redessine son icone a chaque cran de molette, a chaque respiration,
;  a chaque survol d'un bouton. Un handle GDI oublie par redessin, c'est
;  trente mille handles au bout d'une semaine -- et Windows tue le processus
;  a dix mille. Une application de zone de notification vit des mois : ce
;  test fait en quelques secondes ce qu'un mois ferait, et compte.
;
;  On chauffe d'abord -- les caches de GDI+ et les polices se remplissent
;  a la premiere passe --, puis on mesure sur la seconde : objets GDI,
;  objets USER, memoire privee. Les compteurs viennent de GetGuiResources et
;  de GetProcessMemoryInfo, ceux du gestionnaire des taches.
;
;  Les fenetres s'ouvrent et se ferment sur le bureau pendant l'essai, avec
;  une configuration jetable ; aucune rampe n'est posee.
;
;  Le rapport part sur la sortie standard et dans fuites-out.txt ; le code
;  de retour vaut 0 ou 1.

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\lib\Filtre.ahk
#Include %A_LineFile%\..\..\lib\Reglages.ahk
#Include %A_LineFile%\..\..\lib\Panneau.ahk
#Include %A_LineFile%\..\..\lib\Osd.ahk
#Include %A_LineFile%\..\..\lib\Prereglages.ahk
#Include %A_LineFile%\..\..\lib\Blob.ahk

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
    f := A_ScriptDir . "\fuites-out.txt"
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
Config.DOSSIER := A_Temp . "\ocre-test-fuites"
Config.FICHIER := Config.DOSSIER . "\essai.ini"
try DirCreate(Config.DOSSIER)
try FileDelete(Config.FICHIER)
Config.Ecrire("langue", "fr")
Config.Ecrire("intensite", 58)
Config.Ecrire("luminosite", 80)
I18n.Definir("fr")
Filtre.Charger()
Prereglages.Init((i, l) => 0, () => { i: 58, l: 80 })

;  Les compteurs du gestionnaire des taches. GR_GDIOBJECTS = 0, GR_USEROBJECTS = 1.
Mesure() {
    gdi := DllCall("GetGuiResources", "ptr", -1, "uint", 0, "uint")
    user := DllCall("GetGuiResources", "ptr", -1, "uint", 1, "uint")
    ;  PROCESS_MEMORY_COUNTERS_EX, 80 octets en 64 bits : PrivateUsage a 72.
    pmc := Buffer(80, 0)
    NumPut("UInt", 80, pmc, 0)
    DllCall("psapi\GetProcessMemoryInfo", "ptr", -1, "ptr", pmc, "uint", 80)
    return { gdi: gdi, user: user, mo: NumGet(pmc, 72, "UPtr") / 1048576.0 }
}

Ecart(a, b) {
    return Format("GDI {:+d}, USER {:+d}, {:+.1f} Mo", b.gdi - a.gdi, b.user - a.user, b.mo - a.mo)
}

;  Un tour de tout ce qui se redessine, dans les proportions d'une journee
;  de molette. Rend le nombre d'operations.
Tour() {
    n := 0
    ;  l'icone de la zone de notification, teinte et point qui changent
    Loop 400 {
        Blob.Tray(Mod(A_Index * 7, 101), 1.0, Mod(A_Index, 2))
        n += 1
    }
    ;  la respiration : des echelles differentes
    Loop 100 {
        Blob.Tray(60, 0.65 + Mod(A_Index, 48) / 100.0)
        n += 1
    }
    ;  une icone qu'on detruit soi-meme, comme les fenetres le font
    Loop 200 {
        h := Blob.Icone(Mod(A_Index * 13, 101), 24)
        DllCall("DestroyIcon", "ptr", h)
        n += 1
    }
    ;  la pastille
    Loop 60 {
        Osd.Montrer(Mod(A_Index * 11, 101), "", -1, "", 0)
        n += 1
    }
    Osd.Cacher()
    ;  le panneau, ouvert et ferme, avec un glissement du curseur
    Loop 20 {
        Panneau.Montrer(58, 80, Map("lire", () => 58, "lireLum", () => 80
                                  , "lireChambre", () => false, "unite", () => 0))
        Sleep(30)
        Loop 10
            Panneau._Glisser(Panneau.ctrls, Mod(A_Index * 9, 101))
        Panneau.Fermer()
        n += 1
    }
    ;  la fenetre des reglages, la plus lourde : tout est peint
    Loop 8 {
        Reglages.Ouvrir((x, e) => 0, (x, e) => 0, () => 0, () => 0)
        Sleep(60)
        ;  le logo qui suit le curseur, par son rendez-vous differe
        Loop 5 {
            Reglages._Teinter(Mod(A_Index * 19, 101))
            Sleep(70)
        }
        Reglages.Fermer()
        n += 1
    }
    ;  les prereglages, et leurs compteurs qui se repeignent
    Loop 8 {
        Prereglages.Ouvrir()
        Sleep(40)
        Loop 10
            Compteur._Clic(Prereglages.c["pre_lecture_i"])
        Prereglages.Fermer()
        n += 1
    }
    ;  la fenetre A propos : logo peint, boutons, et le retour de la copie
    Apropos.Init(() => "1.0.0", () => "diagnostic")
    Apropos.copier := (t) => 0
    Loop 8 {
        Apropos.Ouvrir()
        Sleep(40)
        Apropos._Copier()
        Apropos.Fermer()
        n += 1
    }
    return n
}

Dire("")
Dire("Ocre -- fuites de ressources")
Dire("")

depart := Mesure()
Dire(Format("  au depart : {} objets GDI, {} objets USER, {:.1f} Mo", depart.gdi, depart.user, depart.mo))

n := Tour()
chaud := Mesure()
Dire(Format("  apres la chauffe ({} operations) : {}", n, Ecart(depart, chaud)))

n := Tour()
Sleep(500)
fin := Mesure()
Dire(Format("  apres la mesure ({} operations) : {}", n, Ecart(chaud, fin)))
Dire("")

;  Les seuils : une poignee d'objets pour les caches qui se remplissent
;  encore, pas une par operation. Mille operations qui fuient un objet
;  chacune, c'est mille de plus, pas dix.
Verifier("les objets GDI ne s'accumulent pas", fin.gdi - chaud.gdi <= 10, fin.gdi - chaud.gdi)
Verifier("les objets USER ne s'accumulent pas", fin.user - chaud.user <= 10, fin.user - chaud.user)
Verifier("la memoire privee ne grimpe pas", fin.mo - chaud.mo <= 4.0, Format("{:.1f} Mo", fin.mo - chaud.mo))
Verifier("le processus reste loin de la limite de 10 000 objets GDI", fin.gdi < 2000, fin.gdi)

try FileDelete(Config.FICHIER)
try DirDelete(Config.DOSSIER)

Dire("")
Dire(rates = 0
   ? Format("  {} verifications, aucune erreur.", total)
   : Format("  {} verifications, {} ERREURS.", total, rates))
Dire("")

Ecrire()
ExitApp(rates = 0 ? 0 : 1)
