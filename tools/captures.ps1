<#
    captures.ps1 -- les illustrations de la documentation, dans les deux langues.

    Rejoue tools\test-ui.ahk -- qui ouvre chaque fenetre d'Ocre avec une
    configuration jetable, la clique et la photographie -- une fois en francais,
    une fois en anglais, puis copie les photos retenues dans docs\img\fr et
    docs\img\en. Ce sont des captures de FENETRES seules, jamais du bureau :
    rien de personnel n'y figure (et l'on regarde avant de les ajouter : les deux
    anciennes captures de bureau, apercu-ui.png et apercu-osd.png, ne sont pas
    versionnees pour cette raison).

    Les fenetres s'ouvrent sur le bureau une quarantaine de secondes par langue :
    ne touchez a rien pendant ce temps, un clic ailleurs fausserait les essais.

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\captures.ps1 [-Langues fr,en]
#>

[CmdletBinding()]
param(
    [string[]]$Langues = @('fr', 'en')
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

$Ahk = @(
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Ahk) { Write-Host "  [X] AutoHotkey v2 introuvable" -ForegroundColor Red; exit 1 }

#  Celles que la documentation montre.
$Photos = @('panneau', 'reglages', 'planificateur-soleil', 'planificateur-fixe', 'prereglages'
            'raccourcis', 'habitudes', 'lieu', 'apropos', 'osd')

foreach ($lang in $Langues) {
    Write-Host "`n== $lang ==" -ForegroundColor Cyan
    $src = Join-Path $env:TEMP ('ocre-test-ui' + $(if ($lang -eq 'fr') { '' } else { "-$lang" }))
    Remove-Item (Join-Path $src '*.png') -ErrorAction SilentlyContinue

    $env:OCRE_TEST_LANGUE = $lang
    try {
        $p = Start-Process $Ahk -ArgumentList '/ErrorStdOut', "`"$(Join-Path $PSScriptRoot 'test-ui.ahk')`"" -Wait -PassThru -NoNewWindow
    } finally {
        Remove-Item Env:OCRE_TEST_LANGUE -ErrorAction SilentlyContinue
    }
    #  Un echec de verification n'empeche pas la photo : en anglais, celles qui
    #  lisent un texte francais n'ont pas de sens (voir test-ui.ahk).
    Write-Host "  test-ui : code $($p.ExitCode)"

    $dest = Join-Path $Root "docs\img\$lang"
    New-Item -ItemType Directory -Force $dest | Out-Null
    foreach ($n in $Photos) {
        $f = Join-Path $src "$n.png"
        if (Test-Path $f) { Copy-Item $f $dest -Force; Write-Host "  [ok] $n.png" -ForegroundColor Green }
        else              { Write-Host "  [!] $n.png manque" -ForegroundColor Yellow }
    }
}
Write-Host "`nRegardez les images avant de les ajouter : une fenetre inattendue peut s'etre glissee dans un cliche." -ForegroundColor Yellow
