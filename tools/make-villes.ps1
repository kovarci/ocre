<#
    make-villes.ps1 -- regenere lib/villes.txt depuis GeoNames.

    La table sert au calcul solaire : pouvoir dire "Annecy" et obtenir
    45,91 / 6,13, sans reseau au moment de s'en servir.

    Ce qui est retenu, et pourquoi :

      population >= 20 000   couvre les sous-prefectures francaises et leurs
                             equivalents ailleurs. En dessous, l'ecart de
                             coucher du soleil se compte en secondes contre un
                             fondu de trois heures : c'est la reconnaissance du
                             nom qui compte, pas la precision.

      asciiname              le champ deja translittere de GeoNames. Le fichier
                             produit est en ASCII pur, sans BOM, comme le reste
                             du projet -- des accents y seraient relus en ANSI.

      un seul enregistrement par couple (nom, pays), le plus peuple. Sans cela
      la table porte quatorze Springfield americains que rien ne distingue a
      l'affichage.

      tri par population decroissante. Ce tri EST le classement des resultats :
      taper "par" doit donner Paris avant Paranagua.

    Le format, une ville par ligne, "nom|pays|latitude|longitude", est decrit
    dans l'en-tete de lib/Villes.ahk. Le fichier est embarque dans l'exe en
    ressource (directive AddResource dans Ocre.ahk) et lu a la premiere
    recherche seulement : le demarrage ne le paie pas.

    La table des exonymes ("Geneve" -> "Geneva") n'est PAS regeneree : elle est
    ecrite a la main dans lib/Villes.ahk, le champ alternatenames de GeoNames
    etant trop bruite pour l'automatiser. Voir le commentaire sur place.

    Les donnees sont celles de GeoNames (geonames.org), sous licence
    CC BY 4.0 : l'attribution figure dans le README, section Credits.

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\make-villes.ps1
#>

[CmdletBinding()]
param(
    [int]$Population = 20000,
    [string]$Source = 'https://download.geonames.org/export/dump/cities15000.zip'
)

$ErrorActionPreference = 'Stop'

$Racine = Split-Path $PSScriptRoot -Parent
$Cible  = Join-Path $Racine 'lib\villes.txt'
$Travail = Join-Path ([IO.Path]::GetTempPath()) 'ocre-villes'

function Info ($m) { Write-Host "  $m" }
function Ok   ($m) { Write-Host "  [ok] $m" -ForegroundColor Green }

Write-Host "`nRegeneration de la table des villes" -ForegroundColor Cyan

if (-not (Test-Path $Cible)) {
    throw "lib/villes.txt est introuvable : ce script met a jour la table, il ne cree pas le fichier."
}

#---------------------------------------------------------------- telechargement
New-Item -ItemType Directory -Force $Travail | Out-Null
$Zip = Join-Path $Travail 'cities.zip'
$Txt = Join-Path $Travail 'cities15000.txt'

if (-not (Test-Path $Txt)) {
    Info "telechargement de $Source"
    Invoke-WebRequest -Uri $Source -OutFile $Zip -UseBasicParsing
    Expand-Archive -Path $Zip -DestinationPath $Travail -Force
    Ok "archive decompressee"
} else {
    Info "archive deja presente dans $Travail"
}

#------------------------------------------------------------------- filtrage --
Info "filtrage a partir de $Population habitants"

$vues = @{}
$retenues = New-Object System.Collections.Generic.List[object]

foreach ($ligne in [IO.File]::ReadLines($Txt, [Text.Encoding]::UTF8)) {
    $f = $ligne.Split("`t")
    if ($f.Length -lt 15) { continue }

    $pop = 0
    [void][int]::TryParse($f[14], [ref]$pop)
    if ($pop -lt $Population) { continue }

    $nom = $f[2]
    $cc  = $f[8]
    if (-not $nom -or -not $cc) { continue }

    # ASCII imprimable uniquement, et rien qui perturbe la section de
    # continuation d'AutoHotkey : accent grave, pourcent, point-virgule,
    # guillemet, les deux separateurs, et la parenthese qui la fermerait.
    if ($nom -notmatch '^[ -~]+$') { continue }
    if ($nom -match '[`%;"|~)]')   { continue }

    $cle = "$nom|$cc"
    if ($vues.ContainsKey($cle)) {
        if ($pop -le $vues[$cle].pop) { continue }
        $vues[$cle].pop = $pop
        $vues[$cle].lat = $f[4]
        $vues[$cle].lon = $f[5]
        continue
    }
    $e = [pscustomobject]@{ nom = $nom; cc = $cc; lat = $f[4]; lon = $f[5]; pop = $pop }
    $vues[$cle] = $e
    $retenues.Add($e)
}

$triees = $retenues | Sort-Object -Property pop -Descending
Ok "$($triees.Count) villes retenues"

#------------------------------------------------------------- ecriture -----
#  Un enregistrement par ligne, "nom|pays|lat|lon". Sans BOM, en ASCII
#  strict : un accent qui s'y glisserait serait relu en ANSI.
$sb = New-Object Text.StringBuilder
foreach ($v in $triees) {
    [void]$sb.AppendFormat("{0}|{1}|{2:F2}|{3:F2}`n", $v.nom, $v.cc,
                           [double]$v.lat, [double]$v.lon)
}
[IO.File]::WriteAllText($Cible, $sb.ToString(), (New-Object Text.ASCIIEncoding))

$ko = [math]::Round((Get-Item $Cible).Length / 1KB)
Ok "lib/villes.txt reecrit ($ko Ko)"
Info "verifiez avec : AutoHotkey64.exe tools\test-soleil.ahk"
Write-Host ""
