<#
    archive.ps1 -- dist\Ocre-<version>.zip : l'archive sans installateur.

    Ocre.exe, install.ps1, les deux README, la licence et celle de la police
    Inter. install.ps1 se suffit a lui-meme quand l'exe est la : il ne demande
    tools\ que pour construire. La licence de la police accompagne l'exe qui
    l'embarque (l'OFL le demande) ; GeoNames est credite dans les README.

    Une seule liste, pour tools\release.ps1 et pour le workflow GitHub : elles
    ne peuvent pas diverger. Rend le chemin de l'archive.

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\archive.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

if ((Get-Content (Join-Path $Root 'Ocre.ahk') -Raw) -notmatch ';@Ahk2Exe-SetVersion\s+([0-9][0-9.]*)') {
    throw "pas de directive SetVersion dans Ocre.ahk"
}
$Version = $Matches[1]

$Dist = Join-Path $Root 'dist'
New-Item -ItemType Directory -Force $Dist | Out-Null
$zip = Join-Path $Dist "Ocre-$Version.zip"
Remove-Item $zip -ErrorAction SilentlyContinue

$fichiers = @('Ocre.exe', 'install.ps1', 'README.md', 'README.en.md', 'LICENSE', 'lib\Inter-LICENSE.txt') |
    ForEach-Object { Join-Path $Root $_ }
foreach ($f in $fichiers) { if (-not (Test-Path $f)) { throw "$f manque" } }

Compress-Archive -Path $fichiers -DestinationPath $zip -CompressionLevel Optimal
$zip
