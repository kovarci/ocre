<#
    release.ps1 -- une archive prete a donner.

      1. construit Ocre.exe (install.ps1 -Build, sans lancer ni inscrire au demarrage)
      2. lance la suite de tests (tools\test.ps1) ; un echec arrete tout
      3. verifie que l'exe embarque bien la table des villes et la police
      4. range Ocre.exe, install.ps1, les deux README, la licence et celle
         de la police Inter dans Ocre-<version>.zip -- install.ps1 se suffit
         a lui-meme quand l'exe est la : il ne demande tools\ que pour
         construire
      5. construit l'installateur Ocre-<version>-setup.exe (tools\installer.ps1)

    La version est lue dans la directive SetVersion de Ocre.ahk. L'archive
    et l'installateur sont ecrits dans dist\, qui est cree au besoin et n'est
    pas versionne.

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\release.ps1 [-SansTests]
#>

[CmdletBinding()]
param(
    [switch]$SansTests
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = Join-Path $Root 'Ocre.exe'
$Dist = Join-Path $Root 'dist'

function Ok   ($m) { Write-Host "  [ok] $m" -ForegroundColor Green }
function Fail ($m) { Write-Host "  [X] $m"  -ForegroundColor Red }
function Info ($m) { Write-Host "  $m" }

#----------------------------------------------------------------- version --
$src = Get-Content (Join-Path $Root 'Ocre.ahk') -Raw
if ($src -notmatch ';@Ahk2Exe-SetVersion\s+([0-9][0-9.]*)') {
    Fail "pas de directive SetVersion dans Ocre.ahk"; exit 1
}
$Version = $Matches[1]
Write-Host "`nOcre $Version" -ForegroundColor Cyan

#------------------------------------------------------------- 1. build ------
#  La construction arrete l'Ocre en place (il tient l'exe) : on le relance a
#  la fin s'il tournait, sinon la release laissait l'ecran sans filtre.
$tournait = [bool](Get-Process Ocre -ErrorAction SilentlyContinue)
Write-Host "`n[1/5] Construction"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'install.ps1') -Build -NoStart -NoStartup -NoRegistry | Out-Null
if (-not (Test-Path $Exe)) { Fail "Ocre.exe n'a pas ete construit"; exit 1 }
$fv = (Get-Item $Exe).VersionInfo.FileVersion
if ($fv -notlike "$Version*") { Fail "l'exe dit la version '$fv', le source dit '$Version'"; exit 1 }
Ok "Ocre.exe $fv ($([math]::Round((Get-Item $Exe).Length/1MB,2)) Mo)"

#------------------------------------------------------------- 2. tests ------
Write-Host "`n[2/5] Tests"
if ($SansTests) {
    Info "ignores (-SansTests)"
} else {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'test.ps1') | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "$LASTEXITCODE test(s) en echec : pas d'archive"; exit 1 }
    Ok "la suite passe"
}

#--------------------------------------------------------- 3. ressources -----
#  Les deux ressources que l'exe doit embarquer (directives AddResource dans
#  Ocre.ahk et Police.ahk) : sans elles, il tourne mais cherche une ville en
#  vain et ecrit la pastille en Segoe UI. On les cherche dans les octets de
#  l'exe : un nom de ressource y est en UTF-16, sans compression.
Write-Host "`n[3/5] Ressources embarquees"
$bytes = [IO.File]::ReadAllBytes($Exe)
$texte = [Text.Encoding]::Unicode.GetString($bytes)
foreach ($nom in @('VILLES', 'INTER')) {
    if ($texte.IndexOf($nom) -lt 0) { Fail "ressource $nom absente de l'exe"; exit 1 }
    Ok "ressource $nom"
}

#-------------------------------------------------------------- 4. archive ---
Write-Host "`n[4/5] Archive"
New-Item -ItemType Directory -Force $Dist | Out-Null
$zip = Join-Path $Dist "Ocre-$Version.zip"
Remove-Item $zip -ErrorAction SilentlyContinue
#  La licence de la police Inter accompagne l'exe qui l'embarque : l'OFL le
#  demande, et GeoNames est credite dans les README.
$fichiers = @('Ocre.exe', 'install.ps1', 'README.md', 'README.en.md', 'LICENSE', 'lib\Inter-LICENSE.txt') | ForEach-Object { Join-Path $Root $_ }
foreach ($f in $fichiers) { if (-not (Test-Path $f)) { Fail "$f manque"; exit 1 } }
Compress-Archive -Path $fichiers -DestinationPath $zip -CompressionLevel Optimal
Ok "$zip ($([math]::Round((Get-Item $zip).Length/1MB,2)) Mo)"

#------------------------------------------------------- 5. installateur -------
#  Le .exe avec assistant (installer\Ocre.iss), pour qui ne veut ni PowerShell
#  ni dossier decompresse. C'est lui qu'on met en avant sur la page de la release.
Write-Host "`n[5/5] Installateur"
if (-not $SansTests) {
    #  Sans elevation, sur des cles factices : voir tools\test-installateur.ps1.
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'test-installateur.ps1') | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "$LASTEXITCODE verification(s) de l'installateur en echec : pas de release"; exit 1 }
    Ok "installation, mise a jour et retour arriere jouent"
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'installer.ps1') | Out-Null
$setup = Join-Path $Dist "Ocre-$Version-setup.exe"
if (-not (Test-Path $setup)) { Fail "l'installateur n'a pas ete construit (lancez tools\installer.ps1 pour voir pourquoi)"; exit 1 }
Ok "$setup ($([math]::Round((Get-Item $setup).Length/1MB,2)) Mo)"

if ($tournait) { Start-Process $Exe -WorkingDirectory $Root; Ok "Ocre relance" }
Write-Host "`nPret." -ForegroundColor Green
