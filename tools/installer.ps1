<#
    installer.ps1 -- construit l'installateur : dist\Ocre-<version>-setup.exe

    Un seul .exe, avec assistant, entree dans Parametres > Applications et
    desinstallation -- ce que l'archive .zip et install.ps1 ne sont pas. Il est
    ecrit avec Inno Setup 6 (installer\Ocre.iss), que ce script recupere par
    winget s'il manque, comme install.ps1 le fait d'AutoHotkey.

    Ocre.exe doit deja etre construit (install.ps1 -Build) : tools\release.ps1
    s'en charge, puis appelle ce script. L'installateur est signe avec le meme
    certificat que l'exe, s'il y en a un (tools\sign.ps1).

    La version est lue dans la directive SetVersion de Ocre.ahk. L'adresse du
    depot, si -RepoUrl n'est pas donne, est celle du remote "origin".

    -Essai construit la VARIANTE D'ESSAI (voir l'en-tete de installer\Ocre.iss) :
    un OcreEssai-<version>-setup.exe dans %TEMP%\ocre-essai, qui ne touche ni
    HKLM, ni la vraie tache, ni le vrai Ocre, et ne demande pas l'elevation.
    C'est celui que tools\test-installateur.ps1 joue ; il ne se signe pas et
    ne se publie pas.

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\installer.ps1 [-RepoUrl https://github.com/qui/ocre] [-Essai]
#>

[CmdletBinding()]
param(
    [string]$RepoUrl,
    [switch]$Essai
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

function Ok   ($m) { Write-Host "  [ok] $m" -ForegroundColor Green }
function Fail ($m) { Write-Host "  [X] $m"  -ForegroundColor Red }
function Info ($m) { Write-Host "  $m" }

#----------------------------------------------------------------- version --
$src = Get-Content (Join-Path $Root 'Ocre.ahk') -Raw
if ($src -notmatch ';@Ahk2Exe-SetVersion\s+([0-9][0-9.]*)') {
    Fail "pas de directive SetVersion dans Ocre.ahk"; exit 1
}
$Version = $Matches[1]

if (-not (Test-Path (Join-Path $Root 'Ocre.exe'))) { Fail "Ocre.exe manque : install.ps1 -Build le construit"; exit 1 }
if (-not (Test-Path (Join-Path $Root 'Ocre.ico'))) { Fail "Ocre.ico manque : install.ps1 -Build le genere"; exit 1 }

#------------------------------------------------------------------ depot -----
#  Pas de depot, ou pas de remote : pas d'adresse, et l'installateur se
#  construit tout aussi bien. git ecrit sa plainte sur stderr, que 'Stop'
#  ferait passer pour une erreur : on le laisse parler le temps de la question.
if (-not $RepoUrl -and (Test-Path (Join-Path $Root '.git')) -and (Get-Command git -ErrorAction SilentlyContinue)) {
    $ea = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & git -C $Root remote get-url origin 2>$null
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $ea
    if ($rc -eq 0 -and $o) { $RepoUrl = ($o -replace '\.git$', '').Trim() }
}

#------------------------------------------------------------------ ISCC ------
$Candidats = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)
$Iscc = $Candidats | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Iscc) {
    Info "Inno Setup 6 absent, installation via winget..."
    & winget install --id JRSoftware.InnoSetup -e --accept-package-agreements --accept-source-agreements --silent | Out-Null
    $Iscc = $Candidats | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $Iscc) { Fail "Inno Setup 6 introuvable"; exit 1 }
Ok "Inno Setup : $Iscc"

#--------------------------------------------------------------- compilation --
$Args2 = @("/DAppVersion=$Version", '/Qp')
if ($RepoUrl) { $Args2 += "/DRepoUrl=$RepoUrl" }
if ($Essai) {
    $Sortie = Join-Path $env:TEMP 'ocre-essai'
    $Args2 += '/DESSAI', "/O$Sortie"
    $Setup = Join-Path $Sortie "OcreEssai-$Version-setup.exe"
} else {
    $Setup = Join-Path $Root "dist\Ocre-$Version-setup.exe"
}
$Args2 += (Join-Path $Root 'installer\Ocre.iss')

& $Iscc @Args2
if ($LASTEXITCODE -ne 0) { Fail "ISCC a echoue (code $LASTEXITCODE)"; exit 1 }

if (-not (Test-Path $Setup)) { Fail "$Setup n'a pas ete ecrit"; exit 1 }
Ok "$Setup ($([math]::Round((Get-Item $Setup).Length/1MB,2)) Mo)"

#----------------------------------------------------------------- signature --
if (-not $Essai) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'sign.ps1') -Fichier $Setup
    if ($LASTEXITCODE -eq 2) { Info "non signe : SmartScreen avertira au premier lancement (voir README, 'SmartScreen')" }
}
