<#
    liens.ps1 -- les liens des fichiers Markdown du depot mènent-ils quelque part ?

    Pour chaque [texte](cible) hors blocs de code : un fichier relatif existe-t-il,
    et une ancre (#titre) correspond-elle a un titre du fichier vise, calcule comme
    le fait GitHub (minuscules, sans ponctuation, espaces en tirets, doublons
    suffixes -1, -2...) ? Les adresses http(s) ne sont pas suivies : on ne parle
    pas au reseau pour verifier une documentation.

    Rend le nombre de liens casses. Appele par la CI (ci.yml) : une page deplacee
    ou un titre renomme, et le lien qui y menait se voit tout de suite.

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\liens.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

#  Ni les archives construites, ni .git, ni ce qui n'est pas a nous.
$Fichiers = Get-ChildItem $Root -Recurse -File -Filter *.md |
    Where-Object { $_.FullName -notmatch '\\(dist|\.git|node_modules)\\' }

function Slug([string]$titre) {
    $t = $titre -replace '`', ''
    $t = [regex]::Replace($t, '\[([^\]]*)\]\([^)]*\)', '$1')
    $t = $t.Replace('*', '').Trim().ToLowerInvariant()
    $sb = New-Object Text.StringBuilder
    foreach ($c in $t.ToCharArray()) {
        if ([char]::IsLetterOrDigit($c) -or $c -eq ' ' -or $c -eq '-' -or $c -eq '_') { [void]$sb.Append($c) }
    }
    $sb.ToString().Replace(' ', '-')
}

#  Les ancres de chaque fichier, une fois.
$Ancres = @{}
function AncresDe([string]$chemin) {
    if ($Ancres.ContainsKey($chemin)) { return $Ancres[$chemin] }
    $vues = @{}
    $liste = New-Object Collections.Generic.HashSet[string]
    $fence = $false
    foreach ($l in [IO.File]::ReadAllLines($chemin)) {
        if ($l -match '^\s*```') { $fence = -not $fence; continue }
        if ($fence) { continue }
        if ($l -match '^(#{1,6})\s+(.*?)\s*$') {
            $s = Slug $Matches[2]
            if ($vues.ContainsKey($s)) { $vues[$s]++; $s = "$s-$($vues[$s])" } else { $vues[$s] = 0 }
            [void]$liste.Add($s)
        }
        # <a name="x"> et id="x" : des ancres aussi
        foreach ($m in [regex]::Matches($l, '(?:name|id)="([^"]+)"')) { [void]$liste.Add($m.Groups[1].Value) }
    }
    $Ancres[$chemin] = $liste
    $liste
}

$Casses = 0
$Total = 0
foreach ($f in $Fichiers) {
    $dir = Split-Path $f.FullName -Parent
    $rel = $f.FullName.Substring($Root.Length + 1)
    $fence = $false
    $n = 0
    foreach ($l in [IO.File]::ReadAllLines($f.FullName)) {
        $n++
        if ($l -match '^\s*```') { $fence = -not $fence; continue }
        if ($fence) { continue }
        # on ote le code en ligne : `[x](y)` n'est pas un lien
        $ligne = [regex]::Replace($l, '`[^`]*`', '')
        # liens [t](c) et images ![t](c) ; attributs src= et href= des balises HTML
        $cibles = @()
        foreach ($m in [regex]::Matches($ligne, '\]\(([^)\s]+)(?:\s+"[^"]*")?\)')) { $cibles += $m.Groups[1].Value }
        foreach ($m in [regex]::Matches($ligne, '(?:src|href)="([^"]+)"')) { $cibles += $m.Groups[1].Value }
        foreach ($c in $cibles) {
            if ($c -match '^(https?:|mailto:)') { continue }
            $Total++
            $c = $c.Trim('<', '>')
            $chemin, $frag = $c -split '#', 2
            if ($chemin) {
                $cible = Join-Path $dir ([uri]::UnescapeDataString($chemin))
                $existe = Test-Path -LiteralPath $cible
            } else {
                $cible = $f.FullName
                $existe = $true
            }
            if (-not $existe) {
                Write-Host "  [X] ${rel}:${n}  fichier introuvable : $c" -ForegroundColor Red
                $Casses++
                continue
            }
            if ($frag -and (Test-Path -LiteralPath $cible -PathType Leaf) -and $cible -match '\.md$') {
                if (-not (AncresDe $cible).Contains($frag.ToLowerInvariant())) {
                    Write-Host "  [X] ${rel}:${n}  ancre introuvable : $c" -ForegroundColor Red
                    $Casses++
                }
            }
        }
    }
}

if ($Casses -eq 0) { Write-Host "$Total liens relatifs, tous bons." -ForegroundColor Green }
else { Write-Host "$Casses lien(s) casse(s) sur $Total." -ForegroundColor Red }
exit $Casses
