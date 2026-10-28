# Gera PNGs antialias 128x128 dos ícones de interface em res://assets/icons/png/.
# Usado quando o importador de SVG do editor não está disponível. Os SVGs de
# origem permanecem em assets/icons/vector/.

Add-Type -AssemblyName System.Drawing

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$out = Join-Path $root 'assets\icons\png'
New-Item -ItemType Directory -Force -Path $out | Out-Null

function New-Canvas {
    $bmp = New-Object System.Drawing.Bitmap 128, 128, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    return @{ bmp = $bmp; g = $g }
}

function Save-Canvas($canvas, $name) {
    $path = Join-Path $out $name
    $canvas.bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.g.Dispose()
    $canvas.bmp.Dispose()
    Write-Output "gerado $name"
}

# Engrenagem: disco com dentes, furo central e cor azul clara.
$c = New-Canvas
$g = $c.g
$ink = [System.Drawing.Color]::FromArgb(255, 10, 22, 48)
$fill = [System.Drawing.Color]::FromArgb(255, 156, 201, 255)
$pen = New-Object System.Drawing.Pen $ink, 5
$brushFill = New-Object System.Drawing.SolidBrush $fill
$brushInk = New-Object System.Drawing.SolidBrush $ink
for ($i = 0; $i -lt 8; $i++) {
    $state = $g.Save()
    $g.TranslateTransform(64, 64)
    $g.RotateTransform($i * 45)
    $g.FillRectangle($brushInk, -11, -58, 22, 26)
    $g.DrawRectangle($pen, -11, -58, 22, 26)
    $g.Restore($state)
}
$g.FillEllipse($brushFill, 28, 28, 72, 72)
$g.DrawEllipse($pen, 28, 28, 72, 72)
$g.FillEllipse($brushInk, 50, 50, 28, 28)
Save-Canvas $c 'icon_settings.png'

# Moeda: disco dourado com gradiente radial, anel interno e estrela.
$c = New-Canvas
$g = $c.g
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddEllipse(6, 6, 116, 116)
$grad = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
$grad.CenterPoint = New-Object System.Drawing.PointF 50, 44
$grad.CenterColor = [System.Drawing.Color]::FromArgb(255, 255, 246, 176)
$grad.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(255, 184, 116, 10))
$g.FillEllipse($grad, 6, 6, 116, 116)
$rim = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 90, 51, 0)), 6
$g.DrawEllipse($rim, 6, 6, 116, 116)
$inner = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 138, 90, 0)), 4
$g.DrawEllipse($inner, 26, 26, 76, 76)
$star = [System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF 64, 36), (New-Object System.Drawing.PointF 71, 56),
    (New-Object System.Drawing.PointF 92, 56), (New-Object System.Drawing.PointF 75, 69),
    (New-Object System.Drawing.PointF 82, 90), (New-Object System.Drawing.PointF 64, 77),
    (New-Object System.Drawing.PointF 46, 90), (New-Object System.Drawing.PointF 53, 69),
    (New-Object System.Drawing.PointF 36, 56), (New-Object System.Drawing.PointF 57, 56))
$g.FillPolygon((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 243, 176))), $star)
Save-Canvas $c 'icon_coin.png'

# Gema: losango facetado azul com brilho.
$c = New-Canvas
$g = $c.g
$outline = [System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF 36, 14), (New-Object System.Drawing.PointF 92, 14),
    (New-Object System.Drawing.PointF 116, 46), (New-Object System.Drawing.PointF 64, 116),
    (New-Object System.Drawing.PointF 12, 46))
$gem = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.PointF 0, 0), (New-Object System.Drawing.PointF 0, 128), ([System.Drawing.Color]::FromArgb(255, 184, 240, 255)), ([System.Drawing.Color]::FromArgb(255, 11, 60, 158))
$g.FillPolygon($gem, $outline)
$edge = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 6, 36, 79)), 5
$g.DrawPolygon($edge, $outline)
$facet = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(230, 216, 246, 255)), 3
$g.DrawLine($facet, 12, 46, 116, 46)
$g.DrawLine($facet, 36, 14, 52, 46)
$g.DrawLine($facet, 92, 14, 76, 46)
$g.DrawLine($facet, 52, 46, 64, 116)
$g.DrawLine($facet, 76, 46, 64, 116)
Save-Canvas $c 'icon_gem.png'
