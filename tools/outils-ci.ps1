<#
    outils-ci.ps1 -- la chaine de construction, sur une machine vierge.

    Pose AutoHotkey v2, son compilateur Ahk2Exe et Inno Setup a l'endroit ou
    install.ps1 et tools\installer.ps1 les cherchent, SANS winget (absent des
    executeurs GitHub) et surtout SANS prendre "la derniere version" : chaque
    outil est epingle a une version et a une empreinte SHA-256, verifiee avant
    toute extraction ou execution. Un binaire signe doit sortir d'une chaine
    qu'on peut redire octet pour octet ; "latest" ne le permet pas.

    Changer de version, c'est changer les trois lignes d'une entree ci-dessous,
    empreinte comprise (l'API GitHub la donne : champ "digest" de l'asset).

      -Racine   ou poser AutoHotkey (defaut : %LOCALAPPDATA%\Programs\AutoHotkey,
                ce que cherche install.ps1)

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\outils-ci.ps1
#>

[CmdletBinding()]
param(
    [string]$Racine = (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'     # Invoke-WebRequest, sans sa barre : dix fois plus vite

function Ok   ($m) { Write-Host "  [ok] $m" -ForegroundColor Green }
function Info ($m) { Write-Host "  $m" }

#  Telecharge, verifie l'empreinte, et ne rend le chemin qu'a ce prix.
function Telecharger ($url, $sha256) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("ocre-ci-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $dir | Out-Null
    $f = Join-Path $dir ([IO.Path]::GetFileName($url))
    Invoke-WebRequest $url -OutFile $f -UseBasicParsing
    $h = (Get-FileHash $f -Algorithm SHA256).Hash
    if ($h -ne $sha256.ToUpper()) {
        throw "empreinte inattendue pour $url`n  attendue : $sha256`n  obtenue  : $h"
    }
    $f
}

#------------------------------------------------------------- AutoHotkey v2 --
$Ahk = Join-Path $Racine 'v2\AutoHotkey64.exe'
if (Test-Path $Ahk) {
    Ok "AutoHotkey deja la : $Ahk"
} else {
    $zip = Telecharger 'https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.30/AutoHotkey_2.0.30.zip' `
                       '1E0ECE7ECB2D5646E55758150472677996A57F9DB5C83D2996D8B47B9E2F31A4'
    Expand-Archive $zip -DestinationPath (Join-Path $Racine 'v2') -Force
    if (-not (Test-Path $Ahk)) { throw "AutoHotkey64.exe absent apres extraction" }
    Ok "AutoHotkey 2.0.30"
}

#---------------------------------------------------------------- Ahk2Exe -----
#  install.ps1 cherche le compilateur dans <Racine>\Compiler\Ahk2Exe.exe.
$A2e = Join-Path $Racine 'Compiler\Ahk2Exe.exe'
if (Test-Path $A2e) {
    Ok "Ahk2Exe deja la : $A2e"
} else {
    $zip = Telecharger 'https://github.com/AutoHotkey/Ahk2Exe/releases/download/Ahk2Exe1.1.37.02a2/Ahk2Exe1.1.37.02a2.zip' `
                       'C29B8C3A5124850D79FC9E66E2CA79677C377D7F31631AD3022BA159C5D9E3BE'
    Expand-Archive $zip -DestinationPath (Join-Path $Racine 'Compiler') -Force
    if (-not (Test-Path $A2e)) { throw "Ahk2Exe.exe absent apres extraction" }
    Ok "Ahk2Exe 1.1.37.02a2"
}

#------------------------------------------------------------- Inno Setup ------
#  Installe pour l'utilisateur courant (/CURRENTUSER) : pas d'elevation, et
#  c'est l'un des endroits que tools\installer.ps1 regarde.
$Iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($Iscc) {
    Ok "Inno Setup deja la : $Iscc"
} else {
    $exe = Telecharger 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-6.7.3.exe' `
                       '9C73C3BAE7ED48D44112A0F48E66742C00090BDB5BEF71D9D3C056C66E97B732'
    $p = Start-Process $exe -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER' -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "l'installation d'Inno Setup a echoue (code $($p.ExitCode))" }
    Ok "Inno Setup 6.7.3"
}
