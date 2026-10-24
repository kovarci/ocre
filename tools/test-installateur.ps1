<#
    test-installateur.ps1 -- l'installateur tient-il ses promesses, retour
    arriere compris ?

    Construit la variante d'essai (installer.ps1 -Essai) et la joue, sans
    elevation, sur des cles factices : tout ce qu'elle ecrit est sous
    HKCU\Software\OcreEssai, la tache s'appelle OcreEssai, le menu Demarrer
    OcreEssai -- ni HKLM, ni la vraie tache, ni le vrai Ocre. Quatre scenarios :

      A  Windows vierge : installation, mise a jour par-dessus (l'etat d'origine
         ne doit pas etre ecrase par le notre), puis retrait -- tout doit
         revenir comme avant, dossier compris
      B  machine deja reglee (le cas de install.ps1) : rien n'a ete change, rien
         n'est rendu
      C  une valeur modifiee par un tiers depuis l'installation : le retrait
         n'y touche pas
      D  sans la case des filtres de couleur, Win+Ctrl+C n'est pas touche

    Ce que ce test ne couvre pas, faute d'elevation : l'ecriture dans HKLM
    elle-meme, et l'arret d'un Ocre en marche (/quit).

    Rend le nombre de verifications en echec.

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\test-installateur.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$Dir   = Join-Path $env:TEMP 'ocre-essai'
$App   = Join-Path $Dir 'app'
$Menu  = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\OcreEssai"
$Gk    = 'HKCU:\Software\OcreEssai\ICM'
$Ck    = 'HKCU:\Software\OcreEssai\ColorFiltering'
$Echecs = 0

#------------------------------------------------------------ construction ----
Write-Host "`nConstruction de la variante d'essai"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'installer.ps1') -Essai | Out-Null
$Version = if ((Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'Ocre.ahk') -Raw) -match ';@Ahk2Exe-SetVersion\s+([0-9][0-9.]*)') { $Matches[1] } else { '0.0.0' }
$Setup = Join-Path $Dir "OcreEssai-$Version-setup.exe"
if (-not (Test-Path $Setup)) { Write-Host "  [X] l'installateur d'essai n'a pas ete construit" -ForegroundColor Red; exit 1 }

#--------------------------------------------------------------- outils -------
function Verifier($nom, $cond, $detail = '') {
    if ($cond) { Write-Host "  ok    $nom" -ForegroundColor Green }
    else { Write-Host "  RATE  $nom   -> $detail" -ForegroundColor Red; $script:Echecs++ }
}
function Valeur($cle, $nom) { $v = Get-ItemProperty $cle -Name $nom -ErrorAction SilentlyContinue; if ($v) { $v.$nom } else { 'absent' } }
function Etat { "gamma=$(Valeur $Gk GdiIcmGammaRange) hotkey=$(Valeur $Ck HotkeyEnabled)" }
function TacheExiste { & schtasks.exe /Query /TN OcreEssai 2>&1 | Out-Null; $LASTEXITCODE -eq 0 }
function Installer($taches) {
    $a = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=`"$App`""
    if ($null -ne $taches) { $a += " /TASKS=`"$taches`"" }
    (Start-Process $Setup -ArgumentList $a -Wait -PassThru).ExitCode
}
function Desinstaller {
    $p = Start-Process "$App\unins000.exe" -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -Wait -PassThru
    # le desinstalleur se recopie dans %TEMP% et se supprime en partant
    for ($i = 0; $i -lt 100 -and (Test-Path $App); $i++) { Start-Sleep -Milliseconds 300 }
    $p.ExitCode
}
function Nettoyer {
    Remove-Item 'HKCU:\Software\OcreEssai' -Recurse -Force -ErrorAction SilentlyContinue
    & schtasks.exe /Delete /TN OcreEssai /F 2>&1 | Out-Null
    Remove-Item $App -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $Menu -Recurse -Force -ErrorAction SilentlyContinue
}
function Poser($gamma, $hotkey) {
    New-Item $Gk -Force | Out-Null; New-Item $Ck -Force | Out-Null
    if ($null -ne $gamma)  { New-ItemProperty $Gk -Name GdiIcmGammaRange -Value $gamma  -PropertyType DWord -Force | Out-Null }
    if ($null -ne $hotkey) { New-ItemProperty $Ck -Name HotkeyEnabled    -Value $hotkey -PropertyType DWord -Force | Out-Null }
}

#----------------------------------------------------------------- A ---------
Write-Host "`n== A : Windows vierge, installation, mise a jour, retrait ==" -ForegroundColor Cyan
Nettoyer; Poser $null 1
Verifier "installation" ((Installer 'demarrage,filtres') -eq 0)
Verifier "gamma pose a 256" ((Valeur $Gk GdiIcmGammaRange) -eq 256) (Etat)
Verifier "Win+Ctrl+C desactive" ((Valeur $Ck HotkeyEnabled) -eq 0) (Etat)
Verifier "Ocre.exe installe" (Test-Path "$App\Ocre.exe")
Verifier "la sauvegarde existe (.ini et .reg)" ((Test-Path "$App\sauvegarde\avant-installation.ini") -and (Test-Path "$App\sauvegarde\avant-installation.reg"))
$reg = Get-Content "$App\sauvegarde\avant-installation.reg" -Raw -ErrorAction SilentlyContinue
Verifier "le .reg rend l'etat d'origine (gamma efface, Win+Ctrl+C a 1)" ($reg -match '"GdiIcmGammaRange"=-' -and $reg -match '"HotkeyEnabled"=dword:00000001') $reg
Verifier "tache de demarrage creee" (TacheExiste)
$xml = & schtasks.exe /Query /TN OcreEssai /XML 2>&1 | Out-String
Verifier "... qui vise l'exe installe" ($xml.Contains("$App\Ocre.exe"))
Verifier "... et que la batterie n'arrete pas" ($xml -match '<StopIfGoingOnBatteries>false')
Verifier "menu Demarrer : Ocre, remise a plat, restauration" ((Get-ChildItem $Menu -ErrorAction SilentlyContinue | Measure-Object).Count -eq 3)

Verifier "mise a jour par-dessus" ((Installer $null) -eq 0)
$ini = Get-Content "$App\sauvegarde\avant-installation.ini" -Raw
Verifier "... l'etat d'origine n'est pas ecrase par le notre" ($ini -match 'Avant=absent' -and $ini -match 'Avant=1') $ini
Verifier "... la tache est toujours la" (TacheExiste)

Verifier "retrait" ((Desinstaller) -eq 0)
Verifier "gamma de nouveau absent" ((Valeur $Gk GdiIcmGammaRange) -eq 'absent') (Etat)
Verifier "Win+Ctrl+C de nouveau actif" ((Valeur $Ck HotkeyEnabled) -eq 1) (Etat)
Verifier "tache retiree" (-not (TacheExiste))
Verifier "dossier d'installation disparu" (-not (Test-Path $App))
Verifier "menu Demarrer nettoye" (-not (Test-Path $Menu))

#----------------------------------------------------------------- B ---------
Write-Host "`n== B : machine deja reglee (gamma 256, Win+Ctrl+C a 0) ==" -ForegroundColor Cyan
Nettoyer; Poser 256 0
Verifier "installation" ((Installer 'filtres') -eq 0)
Verifier "rien n'est marque comme change" ((Get-Content "$App\sauvegarde\avant-installation.ini" -Raw) -notmatch 'Pose=1')
Verifier "pas de tache sans la case" (-not (TacheExiste))
Desinstaller | Out-Null
Verifier "les reglages d'avant restent" ((Valeur $Gk GdiIcmGammaRange) -eq 256 -and (Valeur $Ck HotkeyEnabled) -eq 0) (Etat)

#----------------------------------------------------------------- C ---------
Write-Host "`n== C : un tiers a touche au gamma depuis l'installation ==" -ForegroundColor Cyan
Nettoyer; Poser $null 1
Installer 'filtres' | Out-Null
New-ItemProperty $Gk -Name GdiIcmGammaRange -Value 100 -PropertyType DWord -Force | Out-Null
Desinstaller | Out-Null
Verifier "sa valeur n'est pas ecrasee" ((Valeur $Gk GdiIcmGammaRange) -eq 100) (Etat)
Verifier "Win+Ctrl+C est rendu quand meme" ((Valeur $Ck HotkeyEnabled) -eq 1) (Etat)

#----------------------------------------------------------------- D ---------
Write-Host "`n== D : sans la case des filtres de couleur ==" -ForegroundColor Cyan
Nettoyer; Poser $null 1
Installer 'demarrage' | Out-Null
Verifier "Win+Ctrl+C n'est pas touche" ((Valeur $Ck HotkeyEnabled) -eq 1) (Etat)
Verifier "le gamma est pose" ((Valeur $Gk GdiIcmGammaRange) -eq 256) (Etat)
Desinstaller | Out-Null
Verifier "le gamma est retire" ((Valeur $Gk GdiIcmGammaRange) -eq 'absent') (Etat)

Nettoyer
Write-Host ""
if ($Echecs -eq 0) { Write-Host "Tout passe." -ForegroundColor Green }
else { Write-Host "$Echecs verification(s) en echec." -ForegroundColor Red }
exit $Echecs
