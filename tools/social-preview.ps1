<#
    social-preview.ps1 -- l'image qu'affichent les liens vers le depot (1280 x 640).

    GitHub ne la prend pas dans le depot : elle se televerse a la main, dans
    Settings > General > Social preview. Ce script la fabrique, a partir du logo
    (tools\apercu-logo.png) et de la police Inter du projet, dans
    docs\img\social-preview.png -- pour que le fichier soit versionne, et
    qu'on puisse le refaire sans y repenser.

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\social-preview.ps1
#>

[CmdletBinding()]
param(
    [string]$Titre    = 'Ocre',
    [string]$Slogan   = 'A keyboard-driven warm light filter for Windows 11',
    [string]$Adresse  = 'github.com/kovarci/ocre'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName System.Drawing

# le fond du logo, relu dans l'image : le cadre du logo ne doit pas se voir
$logo = [System.Drawing.Bitmap]::FromFile((Join-Path $Root 'tools\apercu-logo.png'))
$Fond = $logo.GetPixel(2, 2)
$Ocre = [System.Drawing.Color]::FromArgb(214, 130, 58)
$Clair = [System.Drawing.Color]::FromArgb(238, 238, 240)
$Gris = [System.Drawing.Color]::FromArgb(150, 150, 158)

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile((Join-Path $Root 'lib\Inter-Medium.ttf'))
$inter = $pfc.Families[0]

$bmp = New-Object System.Drawing.Bitmap 1280, 640
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear($Fond)

# un filet d'ocre en haut : la seule couleur de la page
$g.FillRectangle((New-Object System.Drawing.SolidBrush $Ocre), 0, 0, 1280, 8)

$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = 'Center'

$f1 = New-Object System.Drawing.Font $inter, 108, ([System.Drawing.FontStyle]::Regular), 'Pixel'
$f2 = New-Object System.Drawing.Font $inter, 36, ([System.Drawing.FontStyle]::Regular), 'Pixel'
$f3 = New-Object System.Drawing.Font $inter, 26, ([System.Drawing.FontStyle]::Regular), 'Pixel'
$g.DrawString($Titre, $f1, (New-Object System.Drawing.SolidBrush $Clair), (New-Object System.Drawing.RectangleF 0, 70, 1280, 150), $fmt)
$g.DrawString($Slogan, $f2, (New-Object System.Drawing.SolidBrush $Gris), (New-Object System.Drawing.RectangleF 0, 215, 1280, 60), $fmt)

# le logo aux cinq intensites, tel quel
$w = 1040
$h = [int]($logo.Height * $w / $logo.Width)
$g.DrawImage($logo, [int]((1280 - $w) / 2), 300, $w, $h)

$g.DrawString($Adresse, $f3, (New-Object System.Drawing.SolidBrush $Ocre), (New-Object System.Drawing.RectangleF 0, 555, 1280, 50), $fmt)

$dest = Join-Path $Root 'docs\img\social-preview.png'
New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
$bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $logo.Dispose(); $pfc.Dispose()
Write-Host "  [ok] $dest ($([math]::Round((Get-Item $dest).Length/1KB)) Ko)" -ForegroundColor Green
