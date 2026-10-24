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

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\installer.ps1 [-RepoUrl https://github.com/qui/ocre]
#>

[CmdletBinding()]
param(
    [string]$RepoUrl
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
#  Pas de depot, pas d'adresse : l'installateur se construit tout aussi bien
#  sans (git ecrit sur stderr, que 'Stop' ferait passer pour une erreur).
if (-not $RepoUrl -and (Test-Path (Join-Path $Root '.git')) -and (Get-Command git -ErrorAction SilentlyContinue)) {
    $o = & git -C $Root remote get-url origin 2>$null
    if ($LASTEXITCODE -eq 0 -and $o) { $RepoUrl = ($o -replace '\.git$', '').Trim() }
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
$Args2 += (Join-Path $Root 'installer\Ocre.iss')

& $Iscc @Args2
if ($LASTEXITCODE -ne 0) { Fail "ISCC a echoue (code $LASTEXITCODE)"; exit 1 }

$Setup = Join-Path $Root "dist\Ocre-$Version-setup.exe"
if (-not (Test-Path $Setup)) { Fail "$Setup n'a pas ete ecrit"; exit 1 }
Ok "$Setup ($([math]::Round((Get-Item $Setup).Length/1MB,2)) Mo)"

#----------------------------------------------------------------- signature --
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'sign.ps1') -Fichier $Setup
if ($LASTEXITCODE -eq 2) { Info "non signe : SmartScreen avertira au premier lancement (voir README, 'SmartScreen')" }
