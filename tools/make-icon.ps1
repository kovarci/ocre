<#
    make-icon.ps1 -- genere Ocre.ico, l'icone du fichier executable.

    La forme est la meme que celle dessinee a chaud par lib/Blob.ahk : une
    tache organique definie par des rayons polaires, lissee par une courbe
    fermee. Seule la couleur differe, figee ici sur une ocre chaude.

      -Out <chemin>      destination (defaut : Ocre.ico a la racine du projet)
      -Intensite <0..1>  teinte, de froid a ocre brulee
      -Apercu            ecrit aussi tools\apercu-logo.png, la tache aux
                         cinq intensites sur fond sombre

    Usage : powershell -ExecutionPolicy Bypass -File .\tools\make-icon.ps1
#>

[CmdletBinding()]
param(
    [string]$Out,
    [double]$Intensite = 0.78,
    [switch]$Apercu
)

if (-not $Out) { $Out = Join-Path (Split-Path -Parent $PSScriptRoot) 'Ocre.ico' }

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Rayons polaires de la tache, en fraction du rayon max. Volontairement
# irreguliers : c'est ce qui lui donne son aspect vivant plutot que geometrique.
# lib/Blob.ahk utilise exactement la meme table.
$Rayons = @(1.00, 0.74, 0.93, 0.66, 0.90, 0.80, 0.99, 0.70, 0.86)

function Get-Teinte {
    # 0 = froid (filtre coupe), 1 = ocre brulee (filtre a fond)
    param([double]$p)
    $froid = @(136, 146, 160)   # gris bleute
    $moyen = @(227, 163,  60)   # ambre
    $chaud = @(200,  90,  30)   # ocre brulee

    if ($p -lt 0.5) { $a = $froid; $b = $moyen; $t = $p / 0.5 }
    else            { $a = $moyen; $b = $chaud; $t = ($p - 0.5) / 0.5 }

    $r  = [int]($a[0] + ($b[0] - $a[0]) * $t)
    $g  = [int]($a[1] + ($b[1] - $a[1]) * $t)
    $bl = [int]($a[2] + ($b[2] - $a[2]) * $t)
    return , @($r, $g, $bl)
}

function New-BlobBitmap {
    param([int]$Taille, [double]$p)

    $bmp = New-Object System.Drawing.Bitmap($Taille, $Taille,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $cx = $Taille / 2.0
    $cy = $Taille / 2.0
    $rMax = $Taille * 0.44          # marge : la tache respire dans son carre

    $pts = New-Object 'System.Drawing.PointF[]' $Rayons.Count
    for ($i = 0; $i -lt $Rayons.Count; $i++) {
        $ang = 2.0 * [Math]::PI * $i / $Rayons.Count
        $r = $rMax * $Rayons[$i]
        $pts[$i] = New-Object System.Drawing.PointF(
            [float]($cx + $r * [Math]::Cos($ang)),
            [float]($cy + $r * [Math]::Sin($ang)))
    }

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddClosedCurve($pts, 0.9)

    $c = Get-Teinte $p
    $clair = [System.Drawing.Color]::FromArgb(255,
        [Math]::Min(255, $c[0] + 38), [Math]::Min(255, $c[1] + 32), [Math]::Min(255, $c[2] + 24))
    $sombre = [System.Drawing.Color]::FromArgb(255,
        [Math]::Max(0, $c[0] - 42), [Math]::Max(0, $c[1] - 46), [Math]::Max(0, $c[2] - 40))

    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(0, 0)),
        (New-Object System.Drawing.PointF([float]$Taille, [float]$Taille)),
        $clair, $sombre)

    $g.FillPath($brush, $path)
    $brush.Dispose(); $path.Dispose(); $g.Dispose()
    return , $bmp
}

function ConvertTo-Png {
    param([System.Drawing.Bitmap]$Bmp)
    $ms = New-Object System.IO.MemoryStream
    $Bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    # La virgule est indispensable : sans elle PowerShell deroule le tableau
    # d'octets en autant d'objets Byte et l'appelant recoit un Object[].
    return , $ms.ToArray()
}

function ConvertTo-Dib {
    <#
        Entree d'icone au format DIB non compresse. System.Drawing refuse de
        relire les entrees PNG en dessous de 256 px, et certains outils de
        ressources aussi : le DIB reste le format le plus surement accepte.

        BITMAPINFOHEADER, puis les pixels BGRA de bas en haut, puis un masque
        AND de 1 bit par pixel. Le masque est laisse a zero : l'alpha des
        pixels suffit sur toutes les versions de Windows visees.
    #>
    param([System.Drawing.Bitmap]$Bmp)

    $n = $Bmp.Width
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)

    $bw.Write([UInt32]40)          # biSize
    $bw.Write([Int32]$n)           # biWidth
    $bw.Write([Int32]($n * 2))     # biHeight : XOR + AND empiles
    $bw.Write([UInt16]1)           # biPlanes
    $bw.Write([UInt16]32)          # biBitCount
    $bw.Write([UInt32]0)           # biCompression = BI_RGB
    $bw.Write([UInt32]0)           # biSizeImage
    $bw.Write([Int32]0); $bw.Write([Int32]0)
    $bw.Write([UInt32]0); $bw.Write([UInt32]0)

    $rect = New-Object System.Drawing.Rectangle(0, 0, $n, $n)
    $data = $Bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                          [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $stride = $data.Stride
        $buf = New-Object byte[] ($stride * $n)
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buf, 0, $buf.Length)
        for ($y = $n - 1; $y -ge 0; $y--) {
            $bw.Write($buf, $y * $stride, $n * 4)
        }
    } finally {
        $Bmp.UnlockBits($data)
    }

    $ligne = [int]([Math]::Floor(($n + 31) / 32)) * 4    # lignes alignees sur 4 octets
    $bw.Write((New-Object byte[] ($ligne * $n)), 0, $ligne * $n)

    $bw.Flush()
    $r = $ms.ToArray()
    $bw.Dispose(); $ms.Dispose()
    return , $r
}

# --- assemblage du fichier .ico -------------------------------------------
$Tailles = @(16, 20, 24, 32, 48, 64, 128, 256)
$Images = @()
foreach ($t in $Tailles) {
    $bmp = New-BlobBitmap -Taille $t -p $Intensite
    if ($t -ge 128) { $blob = [byte[]](ConvertTo-Png -Bmp $bmp) }
    else            { $blob = [byte[]](ConvertTo-Dib -Bmp $bmp) }
    $bmp.Dispose()
    if ($blob.Length -lt 64) { throw "entree vide pour la taille $t" }
    $Images += , $blob
}

$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)

$bw.Write([UInt16]0)                  # reserve
$bw.Write([UInt16]1)                  # type : 1 = icone
$bw.Write([UInt16]$Tailles.Count)

$offset = 6 + 16 * $Tailles.Count
for ($i = 0; $i -lt $Tailles.Count; $i++) {
    $t = $Tailles[$i]
    if ($t -ge 256) { $dim = 0 } else { $dim = $t }
    $bw.Write([Byte]$dim)             # largeur (0 signifie 256)
    $bw.Write([Byte]$dim)             # hauteur
    $bw.Write([Byte]0)                # palette
    $bw.Write([Byte]0)                # reserve
    $bw.Write([UInt16]1)              # plans
    $bw.Write([UInt16]32)             # bits par pixel
    $bw.Write([UInt32]$Images[$i].Length)
    $bw.Write([UInt32]$offset)
    $offset += $Images[$i].Length
}
foreach ($img in $Images) { $bw.Write($img) }

$bw.Flush()
[System.IO.File]::WriteAllBytes($Out, $ms.ToArray())
$bw.Dispose(); $ms.Dispose()

Write-Host "Icone ecrite : $Out ($([math]::Round((Get-Item $Out).Length/1KB,1)) Ko, $($Tailles.Count) tailles)"

# --- controle de relecture -------------------------------------------------
$ctrl = New-Object System.Drawing.Icon($Out, 32, 32)
$b = $ctrl.ToBitmap()
Write-Host "Relecture 32 px : $($b.Width)x$($b.Height) -- OK"
$b.Dispose(); $ctrl.Dispose()

# --- planche d'apercu ------------------------------------------------------
if ($Apercu) {
    $cases = @(0.0, 0.25, 0.5, 0.75, 1.0)
    $board = New-Object System.Drawing.Bitmap(($cases.Count * 150), 172)
    $g = [System.Drawing.Graphics]::FromImage($board)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 28, 28, 30))
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $font = New-Object System.Drawing.Font("Segoe UI", 11)
    $k = 0
    foreach ($p in $cases) {
        $b2 = New-BlobBitmap -Taille 128 -p $p
        $g.DrawImage($b2, (150 * $k + 11), 12, 128, 128)
        $g.DrawString("$([int]($p * 100)) %", $font,
            [System.Drawing.Brushes]::Gainsboro, (150 * $k + 55), 146)
        $b2.Dispose(); $k++
    }
    $g.Dispose()
    $dest = Join-Path $PSScriptRoot 'apercu-logo.png'
    $board.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $board.Dispose()
    Write-Host "Apercu ecrit : $dest"
}
