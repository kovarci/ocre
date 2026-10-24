;==============================================================================
;  sonde-ecrans.ahk -- ce qu'Ocre voit de vos ecrans.
;
;  Repond a trois questions qu'aucune fenetre de reglages ne devrait avoir a
;  poser :
;
;    - combien d'ecrans, ou, et sous quel identifiant persistant ;
;    - lesquels acceptent une rampe gamma ;
;    - lesquels ont un retroeclairage pilotable, et par quelle voie.
;
;  Rien n'est modifie : la sonde lit, releve, et rend la main. C'est ce qui
;  permet de la lancer sans precaution avant de toucher aux reglages.
;
;  Usage : AutoHotkey64.exe tools\sonde-ecrans.ahk
;==============================================================================

#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\..\lib\Ecrans.ahk
#Include %A_LineFile%\..\..\lib\Retro.ahk
#Include %A_LineFile%\..\..\lib\Gamma.ahk

liste := Ecrans.Lister()

r := "Ocre -- sonde des ecrans`n"
r .= "SM_CMONITORS : " . SysGet(80) . "     enumeres : " . liste.Length . "`n`n"

for i, e in liste {
    r .= "--- ecran " . i . (e.principal ? "  (principal)" : "") . " ---`n"
    r .= "  nom          " . e.nom . "`n"
    r .= "  identifiant  " . e.id . "`n"
    r .= "  position     " . e.x . "," . e.y . "  " . e.w . " x " . e.h . "`n"
    r .= "  hmonitor     " . e.hmon . "`n"

    ;--- rampe gamma ---------------------------------------------------------
    ;  On relit la rampe en place sans jamais en poser : un ecran qui rend sa
    ;  table sait aussi en recevoir une.
    buf := Buffer(3 * 256 * 2, 0)
    lisible := DllCall("gdi32\GetDeviceGammaRamp", "ptr", e.hdc, "ptr", buf)
    r .= "  rampe gamma  " . (lisible ? "lisible" : "REFUSEE") . "`n"

    ;--- retroeclairage ------------------------------------------------------
    etat := Retro._Etat(e)
    if (etat.voie = "ddc") {
        r .= "  retroeclair. DDC/CI     course " . etat.mini . " a " . etat.maxi
           . ", actuellement " . etat.origine . "`n"
    } else if (etat.voie = "wmi") {
        r .= "  retroeclair. WMI        actuellement " . etat.origine . " %`n"
    } else {
        r .= "  retroeclair. aucun -- la rampe assombrira seule`n"
    }

    ;--- ce que donnerait le curseur ----------------------------------------
    r .= "  curseur      "
    for lum in [100, 75, 50, 25, 10, 0] {
        p := Retro.Repartir(e, lum, Gamma.PLANCHER_LUM)
        r .= lum . "%>" . (p.materiel < 0 ? "-" : p.materiel . "%")
           . "/" . Round(p.gamma, 2) . "  "
    }
    r .= "`n`n"
}

r .= "Lecture : curseur > materiel / facteur gamma.`n"
r .= "Rien n'a ete modifie.`n"

;  Les moniteurs physiques ouverts par la sonde sont refermes sans rien
;  rendre : aucune valeur n'a ete ecrite.
Retro.Oublier()
Ecrans.Oublier()

try FileAppend(r, "*")
catch
    MsgBox(r, "Ocre -- sonde des ecrans")
ExitApp(0)
