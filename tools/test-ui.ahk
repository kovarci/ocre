;  test-ui.ahk -- chaque fenetre d'Ocre, ouverte, cliquee, photographiee.
;
;  Les deux tests de calcul ne voient pas les fenetres, et c'est la que se
;  cachent les erreurs qui ne se lisent pas : un bouton dont la fermeture a
;  capture la mauvaise variable, deux noms qui ne different que par la casse
;  et qu'AutoHotkey confond, un controle place sous un autre. Ce script
;  construit chaque fenetre avec une configuration jetable, y clique ce qui
;  se clique, verifie ce qui devait suivre, et la photographie dans
;  %TEMP%\ocre-test-ui pour qui veut regarder.
;
;  Aucune rampe n'est posee : les rappels vers Ocre sont remplaces par des
;  fonctions qui notent ce qu'on leur demande. Une dizaine de secondes de
;  fenetres sur le bureau, c'est tout ce qu'il coute.
;
;  Le rapport part sur la sortie standard et dans ui-out.txt ; le code de
;  retour vaut 0 ou 1.

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\lib\Filtre.ahk
#Include %A_LineFile%\..\..\lib\Reglages.ahk
#Include %A_LineFile%\..\..\lib\Panneau.ahk
#Include %A_LineFile%\..\..\lib\Osd.ahk
#Include %A_LineFile%\..\..\lib\Horaire.ahk
#Include %A_LineFile%\..\..\lib\Prereglages.ahk
#Include %A_LineFile%\..\..\lib\Planificateur.ahk
#Include %A_LineFile%\..\..\lib\Raccourcis.ahk
#Include %A_LineFile%\..\..\lib\Lieu.ahk
#Include %A_LineFile%\..\..\lib\Apprentissage.ahk

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
    f := A_ScriptDir . "\ui-out.txt"
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

;  La barre de titre des fenetres reprend l'icone du script : sans cette ligne,
;  les photos montrent le "H" vert de l'interpreteur, pas celle d'Ocre. Elles
;  servent d'illustrations (docs\img) : autant qu'elles soient a l'image de
;  l'application telle qu'on la lance.
try TraySetIcon(A_ScriptDir . "\..\Ocre.ico")

;  Jamais la vraie configuration. Le dossier garde aussi les photos.
DOSSIER := A_Temp . "\ocre-test-ui"
Config.DOSSIER := DOSSIER
Config.FICHIER := DOSSIER . "\essai.ini"
try DirCreate(DOSSIER)
try FileDelete(Config.FICHIER)
Config.Ecrire("langue", "fr")
Config.Ecrire("intensite", 58)
Config.Ecrire("luminosite", 80)
Config.Ecrire("unite", "k")
Config.Ecrire("hk_gris", "^!G")
Config.Ecrire("lat", "45.75"), Config.Ecrire("lon", "4.85")

I18n.Definir("fr")
Filtre.Charger()
Raccourcis.refuses := ["^F7"]

Dire("")
Dire("Ocre -- les fenetres")
Dire("")

;  Un clic sur un controle, a une fraction de sa largeur. Nos controles sont
;  des images peintes qui lisent la position de la souris pour savoir ou l'on
;  a clique : on y amene le curseur, puis on poste l'enfoncement et le
;  relachement au controle lui-meme. Un clic envoye par SendInput, lui, se
;  perd des qu'un autre processus tient un hook souris -- Ocre en tient un
;  pour la molette sur son icone.
Cliquer(ctrl, fraction := 0.5) {
    r := Buffer(16, 0)
    DllCall("GetWindowRect", "ptr", ctrl.Hwnd, "ptr", r)
    x := NumGet(r, 0, "Int"), y := NumGet(r, 4, "Int")
    w := NumGet(r, 8, "Int") - x, h := NumGet(r, 12, "Int") - y
    CoordMode("Mouse", "Screen")
    MouseMove(x + Round(w * fraction), y + h // 2, 0)
    Sleep(60)
    lp := Round(w * fraction) | ((h // 2) << 16)
    PostMessage(0x0201, 1, lp, ctrl.Hwnd)       ; WM_LBUTTONDOWN
    PostMessage(0x0202, 0, lp, ctrl.Hwnd)       ; WM_LBUTTONUP
    Sleep(250)
}

;------------------------------------------------------------- reglages ----
poses := []
posesLum := []
Reglages.Ouvrir((x, e) => poses.Push(x), (x, e) => posesLum.Push(x), () => 0, () => 0)
Sleep(500)
Verifier("la fenetre des reglages s'ouvre", Reglages.gui != 0)
Photo(Reglages.gui.Hwnd, DOSSIER . "\reglages.png")

;  Le clavier : la fenetre s'ouvre avec le curseur d'intensite vise, deux
;  fleches le descendent de deux pas ; Tab passe a la luminosite. Au niveau
;  1, pour que nos propres raccourcis voient les touches ; en mode Event,
;  parce que SendInput ne passe pas quand un autre script tient un hook ; et
;  une touche a la fois, parce qu'une fleche envoyee dans la foulee d'une
;  tabulation arrive avant que le curseur soit pris.
;  Les raccourcis n'existent que fenetre active : si quelqu'un clique
;  ailleurs pendant le test, on le dit et l'on passe, plutot que d'accuser
;  le clavier.
Loop 3 {
    WinActivate("ahk_id " . Reglages.gui.Hwnd)
    Sleep(300)
    if (WinActive("ahk_id " . Reglages.gui.Hwnd))
        break
}
if (WinActive("ahk_id " . Reglages.gui.Hwnd)) {
    SendLevel(1)
    SendMode("Event")
    Send("{Left}")
    Sleep(200)
    Send("{Left}")
    Sleep(300)
    ;  "Au moins deux" et non "deux" : une touche pressee par quelqu'un
    ;  pendant le test arrive aussi a la fenetre active.
    Verifier("les fleches font bouger le curseur d'intensite", poses.Length >= 2
           , poses.Length . " pose(s)")
    Verifier("chaque fleche vaut un pas de cinq", poses.Length >= 2 && Mod(58 - poses[poses.Length], 5) = 0
           , poses.Length ? poses[poses.Length] : "")
    Send("{Tab}")
    Sleep(200)
    Send("{Right}")
    Sleep(300)
    Verifier("Tab passe a la luminosite", posesLum.Length >= 1 && posesLum[1] = 85
           , posesLum.Length ? posesLum[1] : "rien")
} else {
    Dire("  (la fenetre n'a pas pu etre activee : le clavier n'est pas essaye)")
}
;  Le cadre (voir Cadre.ahk) : plus petit que le contenu, il montre un
;  ascenseur et fait defiler ; plus large, il centre.
porteur := Reglages.porteur
hauteurContenu := porteur.hauteur
Reglages.gui.Show("w600 h400")
Sleep(300)
style := DllCall("GetWindowLongPtr", "ptr", Reglages.gui.Hwnd, "int", -16, "ptr")
Verifier("reduite, la fenetre montre un ascenseur", style & 0x00200000)
porteur.contenu.GetPos(&cx, &cy, &cw)
Verifier("elargie, le contenu est centre", cx > 20, cx)
PostMessage(0x0115, 1, 0, Reglages.gui.Hwnd)         ; WM_VSCROLL, SB_LINEDOWN
Sleep(200)
porteur.contenu.GetPos(&cx, &cy)
Verifier("un cran d'ascenseur fait defiler le contenu", cy < 0, cy)
PostMessage(0x0115, 7, 0, Reglages.gui.Hwnd)         ; SB_BOTTOM
Sleep(200)
;  GetPos d'une fenetre enfant rend des pixels physiques ; le reste est en
;  points.
porteur.contenu.GetPos(&cx, &cy)
cy := Round(cy * 96 / A_ScreenDPI)
Reglages.gui.GetClientPos(, , , &ch)
Verifier("en bas, le bas du contenu affleure le bas du cadre", Abs(cy + hauteurContenu - ch) <= 1
       , cy . "+" . hauteurContenu . " vs " . ch)
Photo(Reglages.gui.Hwnd, DOSSIER . "\reglages-reduite.png")
Reglages.gui.Show("w" . Reglages.L . " h" . (hauteurContenu + 100))
Sleep(300)
style := DllCall("GetWindowLongPtr", "ptr", Reglages.gui.Hwnd, "int", -16, "ptr")
porteur.contenu.GetPos(&cx, &cy)
Verifier("assez haute, plus d'ascenseur et le contenu revient en haut"
       , !(style & 0x00200000) && cy = 0, cy)
Verifier("la taille est retenue", Config.Lire("taille_reglages") != "", Config.Lire("taille_reglages"))
Config.Ecrire("taille_reglages", "")

Reglages.Fermer()
Verifier("la fenetre des reglages se ferme", Reglages.gui = 0)

;-------------------------------------------------------------- panneau ----
MouseMove(A_ScreenWidth // 2, A_ScreenHeight - 120)
Panneau.Montrer(58, 80, Map(
    "lire", () => 58, "lireLum", () => 80, "lireChambre", () => false
  , "reprendre", () => 0, "unite", () => 0))
Sleep(500)
Verifier("le panneau s'ouvre", Panneau.gui != 0)
Photo(Panneau.gui.Hwnd, DOSSIER . "\panneau.png")

;  Le panneau se ferme des qu'il perd le focus : si quelqu'un clique
;  ailleurs pendant le test, on le dit et l'on passe.
Loop 3 {
    if (WinActive("ahk_id " . Panneau.gui.Hwnd))
        break
    try WinActivate("ahk_id " . Panneau.gui.Hwnd)
    Sleep(300)
}
if (Panneau.gui && WinActive("ahk_id " . Panneau.gui.Hwnd)) {
    ;  Clic sur la valeur : bascule K -> %
    Verifier("la valeur s'affiche en Kelvin", InStr(Panneau.ctrls["pct"].Text, "K")
           , Panneau.ctrls["pct"].Text)
    Cliquer(Panneau.ctrls["pct"])
    Verifier("un clic sur la valeur passe en pour cent", InStr(Panneau.ctrls["pct"].Text, "%")
           , Panneau.ctrls["pct"].Text)

    ;  La ligne de la pastille : cochee, puis decochee au clic, sans fermer.
    Verifier("la pastille est cochee au depart", InStr(Panneau.ctrls["pastille"].texte, Chr(0x2713)))
    Cliquer(Panneau.ctrls["pastille"].ctrl)
    Verifier("un clic la decoche et l'ecrit", !InStr(Panneau.ctrls["pastille"].texte, Chr(0x2713))
           && Config.Lire("pastille") = "0")
    Verifier("le panneau reste ouvert", Panneau.gui != 0)
    Photo(Panneau.gui.Hwnd, DOSSIER . "\panneau-pastille.png")
    Cliquer(Panneau.ctrls["pastille"].ctrl)
    Verifier("un second clic la recoche", Config.Lire("pastille") = "1")
} else {
    Dire("  (le panneau n'a pas pu etre active : ses clics ne sont pas essayes)")
}
Config.Ecrire("pastille", 1)
Panneau.Fermer()

;-------------------------------------------------------- planificateur ----
;  Les trois boutons de mode : chacun ecrit sa paire de cles et rebatit.
attendu := Map("manuel", "0,0", "soleil", "1,1", "fixe", "1,0")
for m in ["manuel", "soleil", "fixe"] {
    Config.Ecrire("horaire", 1), Config.Ecrire("h_soleil", 0)
    Planificateur.Ouvrir()
    Sleep(400)
    Planificateur._Mode(m)
    Sleep(300)
    Verifier("le mode " . m . " ecrit horaire,h_soleil = " . attendu[m]
           , Config.Lire("horaire") . "," . Config.Lire("h_soleil") = attendu[m]
           , Config.Lire("horaire") . "," . Config.Lire("h_soleil"))
    Verifier("le planificateur se rebatit en mode " . m, Planificateur.gui != 0
           && Planificateur.ModeCourant() = m, Planificateur.ModeCourant())
    Photo(Planificateur.gui.Hwnd, DOSSIER . "\planificateur-" . m . ".png")
    Planificateur.Fermer()
}

;---------------------------------------------------------- prereglages ----
;  L'apercu : un clic sur un compteur pose la rangee, fermer rend le depart.
apercus := []
Prereglages.Init((i, l) => apercus.Push(i . "," . l), () => { i: 58, l: 80 })
Prereglages.Ouvrir()
Sleep(500)
Verifier("la fenetre des prereglages s'ouvre", Prereglages.gui != 0)
Photo(Prereglages.gui.Hwnd, DOSSIER . "\prereglages.png")
lecture := Prereglages.Lire("pre_lecture")
Cliquer(Prereglages.c["pre_lecture_i"].ctrl, 0.92)     ; le bouton "+"
Verifier("un clic sur + pose la rangee, cinq points plus haut"
       , apercus.Length = 1 && apercus[1] = (lecture.i + 5) . "," . lecture.l
       , apercus.Length ? apercus[apercus.Length] : "rien")
Cliquer(Prereglages.c["pre_lecture_l"].ctrl, 0.08)     ; le bouton "-"
Verifier("un clic sur - de la luminosite pose la meme rangee"
       , apercus.Length = 2 && apercus[2] = (lecture.i + 5) . "," . (lecture.l - 5)
       , apercus.Length ? apercus[apercus.Length] : "rien")
Prereglages.Fermer()
Verifier("fermer garde ce qui est a l'ecran (pas de retour en arriere)", apercus.Length = 2
       , apercus.Length)
Verifier("la valeur est ecrite au clic, sans bouton", Prereglages.Lire("pre_lecture").i = lecture.i + 5
       , Prereglages.Lire("pre_lecture").i)

;------------------------------------------------------------- a propos ----
;  Les trois effets de bord -- une adresse, le presse-papiers, le dossier --
;  sont remplaces : le test ne lance pas de navigateur et laisse intact le
;  presse-papiers de qui le lance.
lances := [], copies := [], dossiers := []
Apropos.Init(() => "9.8.7", () => "diagnostic d'essai")
Apropos.lancer := (cible) => lances.Push(cible)
Apropos.copier := (texte) => copies.Push(texte)
Apropos.dossier := () => dossiers.Push(1)
Apropos.Ouvrir()
Sleep(500)
Verifier("la fenetre A propos s'ouvre", Apropos.gui != 0)
Verifier("elle dit la version", InStr(Apropos.c["version"].Text, "9.8.7"), Apropos.c["version"].Text)
Photo(Apropos.gui.Hwnd, DOSSIER . "\apropos.png")
Cliquer(Apropos.c["depot"].ctrl)
Verifier("le bouton du projet ouvre le depot", lances.Length = 1 && lances[1] = Apropos.DEPOT
       , lances.Length ? lances[1] : "rien")
Cliquer(Apropos.c["versions"].ctrl)
Verifier("... et celui des versions, la page des releases", lances.Length = 2 && lances[2] = Apropos.VERSIONS
       , lances.Length ? lances[lances.Length] : "rien")
Verifier("les deux adresses sont celles du depot public"
       , InStr(Apropos.DEPOT, "https://github.com/") = 1 && InStr(Apropos.VERSIONS, Apropos.DEPOT) = 1)
Cliquer(Apropos.c["diag"].ctrl)
Verifier("copier le diagnostic le met dans le presse-papiers", copies.Length = 1 && copies[1] = "diagnostic d'essai"
       , copies.Length ? copies[1] : "rien")
Verifier("... et le dit", Apropos.c["etat"].Text != "", Apropos.c["etat"].Text)
Cliquer(Apropos.c["dossier"].ctrl)
Verifier("le bouton du dossier des reglages l'ouvre", dossiers.Length = 1, dossiers.Length)
Apropos.Fermer()
Verifier("la fenetre A propos se ferme", Apropos.gui = 0)
;  En anglais aussi : pas de cle qui s'affiche telle quelle.
I18n.Definir("en")
Apropos.Ouvrir()
Sleep(400)
Photo(Apropos.gui.Hwnd, DOSSIER . "\apropos-en.png")
Verifier("en anglais, la version s'ecrit Version 9.8.7", InStr(Apropos.c["version"].Text, "Version 9.8.7") = 1
       , Apropos.c["version"].Text)
Apropos.Fermer()
I18n.Definir("fr")

;----------------------------------------------------------- raccourcis ----
Raccourcis.Ouvrir()
Sleep(500)
Verifier("la fenetre des raccourcis s'ouvre", Raccourcis.gui != 0)
Photo(Raccourcis.gui.Hwnd, DOSSIER . "\raccourcis.png")
Raccourcis.Fermer()

;------------------------------------------------------------ habitudes ----
;  Quelques observations fabriquees, pour que les courbes aient quelque
;  chose a montrer.
Habitudes.Oublier()
Loop 5 {
    Habitudes.Observer("intensite", 75 + Mod(A_Index, 3), { minutes: 21 * 60, date: "2026090" . A_Index, we: 0 })
    Habitudes.Observer("luminosite", 40, { minutes: 9 * 60, date: "2026090" . A_Index, we: 0 })
}
Habitudes.Observer("luminosite", 90, { minutes: 14 * 60, date: "20260901", we: 0 })
Apprentissage.Ouvrir()
Sleep(500)
Verifier("la fenetre des habitudes s'ouvre", Apprentissage.gui != 0)
Verifier("elle compte les observations", InStr(Apprentissage.c["compte_intensite"].Text, "5 ")
       , Apprentissage.c["compte_intensite"].Text)
Photo(Apprentissage.gui.Hwnd, DOSSIER . "\habitudes.png")
Apprentissage.Fermer()
Verifier("la fenetre des habitudes se ferme", Apprentissage.gui = 0)
Habitudes.Oublier()

;----------------------------------------------------------------- lieu ----
Lieu.Ouvrir((lat, lon, libelle) => 0)
Sleep(500)
Verifier("la fenetre du lieu s'ouvre", Lieu.gui != 0)
Verifier("le champ de recherche a le focus"
       , ControlGetFocus("ahk_id " . Lieu.gui.Hwnd) = Lieu.c["q"].Hwnd)
Photo(Lieu.gui.Hwnd, DOSSIER . "\lieu.png")
Lieu.Fermer()
Verifier("la fenetre du lieu se ferme", Lieu.gui = 0)

;--------------------------------------------------------------- heures ----
I18n.Definir("en")
Verifier("en anglais, 21:00 s'affiche 9:00 PM", I18n.Heure(21 * 60) = "9:00 PM", I18n.Heure(21 * 60))
Verifier("... et minuit 12:00 AM", I18n.Heure(0) = "12:00 AM", I18n.Heure(0))
Verifier("... et midi 12:00 PM", I18n.Heure(12 * 60) = "12:00 PM", I18n.Heure(12 * 60))
I18n.Definir("fr")
Verifier("en francais, 21:00 reste 21:00", I18n.Heure(21 * 60) = "21:00", I18n.Heure(21 * 60))
Verifier("'9:00 PM' se lit 1260", Horaire.EnMinutes("9:00 PM", -1) = 1260, Horaire.EnMinutes("9:00 PM", -1))
Verifier("'12 am' se lit 0", Horaire.EnMinutes("12 am", -1) = 0, Horaire.EnMinutes("12 am", -1))
Verifier("'21h' se lit 1260", Horaire.EnMinutes("21h", -1) = 1260, Horaire.EnMinutes("21h", -1))
Verifier("'21:00' se lit 1260", Horaire.EnMinutes("21:00", -1) = 1260)
Verifier("'25:00' et 'abc' retombent sur le defaut"
       , Horaire.EnMinutes("25:00", -1) = -1 && Horaire.EnMinutes("abc", -1) = -1 && Horaire.EnMinutes("13 pm", -1) = -1)
Verifier("ce qui s'ecrit reste en 24 h", Horaire.EnTexte(1260) = "21:00")

;------------------------------------------------------------- pastille ----
Osd.Montrer(58, "", -1, "", 0)
Sleep(300)
Verifier("la pastille s'affiche", Osd.gui != 0 && WinExist("ahk_id " . Osd.gui.Hwnd))
Photo(Osd.gui.Hwnd, DOSSIER . "\osd.png")
Osd.Cacher()

;  La proposition des habitudes : une pastille qu'un clic accepte.
accepte := { n: 0 }
Osd.Proposer(58, "80 comme hier ?", () => accepte.n++, 0)
Sleep(300)
Verifier("la proposition s'affiche", WinExist("ahk_id " . Osd.gui.Hwnd) && Osd.action != 0)
Photo(Osd.gui.Hwnd, DOSSIER . "\proposition.png")
Cliquer(Osd.mot)
Verifier("un clic sur la pastille accepte, et la ferme", accepte.n = 1 && Osd.action = 0, accepte.n)

;----------------------------------------------------- l'autre langue ----
Config.Ecrire("langue", "en")
I18n.Definir("en")
Reglages.Ouvrir((x, e) => 0, (x, e) => 0, () => 0, () => 0)
Sleep(400)
Verifier("les reglages s'ouvrent aussi en anglais", Reglages.gui != 0)
Photo(Reglages.gui.Hwnd, DOSSIER . "\reglages-en.png")
Reglages.Fermer()

Config.Vider()
try FileDelete(Config.FICHIER)

Dire("")
Dire(rates = 0
   ? Format("  {} verifications, aucune erreur.", total)
   : Format("  {} verifications, {} ERREURS.", total, rates))
Dire("  photos : " . DOSSIER)
Dire("")

Ecrire()
ExitApp(rates = 0 ? 0 : 1)

;  Photographie une fenetre avec PrintWindow, via GDI+.
Photo(hwnd, fichier) {
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
        hdcS := DllCall("GetDC", "ptr", 0, "ptr")
        hdcM := DllCall("CreateCompatibleDC", "ptr", hdcS, "ptr")
        hbm := DllCall("CreateCompatibleBitmap", "ptr", hdcS, "int", w, "int", h, "ptr")
        old := DllCall("SelectObject", "ptr", hdcM, "ptr", hbm, "ptr")
        ;  PrintWindow plutot que BitBlt : la fenetre peut etre sous une autre.
        if (!DllCall("PrintWindow", "ptr", hwnd, "ptr", hdcM, "uint", 2))
            DllCall("BitBlt", "ptr", hdcM, "int", 0, "int", 0, "int", w, "int", h
                  , "ptr", hdcS, "int", x, "int", y, "uint", 0x00CC0020)
        DllCall("SelectObject", "ptr", hdcM, "ptr", old)
        DllCall("DeleteDC", "ptr", hdcM)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hdcS)

        Blob.Init()
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &pBmp := 0)
        clsid := Buffer(16)                ; l'encodeur PNG
        DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsid)
        try FileDelete(fichier)
        DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBmp, "wstr", fichier, "ptr", clsid, "ptr", 0)
        DllCall("gdiplus\GdipDisposeImage", "ptr", pBmp)
        DllCall("DeleteObject", "ptr", hbm)
    }
}
