<#
    test.ps1 -- lance les tests d'Ocre et compte les echecs.

      test-courbe   la courbe, le planificateur, la configuration (pur calcul)
      test-soleil   le calcul solaire contre des references independantes
      test-cli      Kelvin, unite, rappel, raccourcis, et la ligne de commande
      test-ui       chaque fenetre, ouverte, cliquee, photographiee
      test-fuites   ce qui se dessine mille fois ne laisse-t-il rien ?
      test-perf     le demarrage est-il rapide, le repos silencieux ?
      test-clamp    Windows applique-t-il la rampe telle quelle ? (-Clamp)

    Les trois premiers ne touchent a rien et tournent n'importe ou. Les deux
    suivants ouvrent les fenetres d'Ocre sur le bureau une vingtaine de
    secondes, sans poser de rampe ; test-perf chronometre et mesure une
    quinzaine de secondes. Le dernier POSE une rampe extreme sur vos ecrans
    pendant une demi-seconde, puis la retire : il n'est lance que sur
    demande.

    Chaque test rend 0 ou 1 ; ce script rend le nombre de tests en echec.

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\test.ps1 [-Clamp]
            .\install.ps1 -Test
#>

[CmdletBinding()]
param(
    [switch]$Clamp
)

$ErrorActionPreference = 'Stop'

$AhkCandidates = @(
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey32.exe"
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
)
$Ahk = $AhkCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Ahk) {
    Write-Host "  [X] AutoHotkey v2 introuvable : les tests demandent l'interpreteur." -ForegroundColor Red
    exit 1
}

$Tests = @('test-courbe', 'test-soleil', 'test-cli', 'test-ui', 'test-fuites', 'test-perf')
if ($Clamp) { $Tests += 'test-clamp' }

$Echecs = 0
foreach ($t in $Tests) {
    Write-Host "`n== $t ==" -ForegroundColor Cyan
    $script = Join-Path $PSScriptRoot "$t.ahk"

    # Les tests ecrivent sur la sortie standard heritee de cette console, et
    # certains aussi dans <nom>-out.txt, pour qui les lance par double-clic.
    $p = Start-Process -FilePath $Ahk -ArgumentList "`"$script`"" -Wait -PassThru -NoNewWindow

    if ($p.ExitCode -eq 0) {
        Write-Host "  [ok] $t" -ForegroundColor Green
    } else {
        Write-Host "  [X] $t (code $($p.ExitCode))" -ForegroundColor Red
        $Echecs += 1
    }
}

Write-Host ""
if ($Echecs -eq 0) {
    Write-Host "Tous les tests passent." -ForegroundColor Green
} else {
    Write-Host "$Echecs test(s) en echec." -ForegroundColor Red
}
exit $Echecs
