# Legado: frames/buttons/textures gerados aqui foram reprovados para menus.
# Consulte docs/design/MENUS.md; não reaplicar o kit às telas do jogador.
# Gera cópias processadas dos PNGs de UI em res://assets/processed/.
# Os originais em assets/ permanecem intactos.
#  - Recorta a área com conteúdo (alfa >= 24), com 4 px de margem.
#  - Zera o alfa residual (< 24) para remover halos coloridos da geração.
#  - Imagens opacas (24 bpp) são copiadas sem alteração de pixels.

Add-Type -AssemblyName System.Drawing

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$out = Join-Path $root 'assets\processed'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$map = @(
    @{ src = 'backgrounds\Imagem do ChatGPT 28 de out. de 2026, 00_55_14.png'; dst = 'backgrounds\bg_lobby_fantasia.png'; crop = $false },
    @{ src = 'logos\Imagem do ChatGPT 28 de out. de 2026, 00_55_54.png';       dst = 'logos\logo_menu_principal.png'; crop = $true },
    @{ src = 'icons\Imagem do ChatGPT 28 de out. de 2026, 00_56_26.png';       dst = 'buttons\btn_modo_historia.png'; crop = $true },
    @{ src = 'icons\Imagem do ChatGPT 28 de out. de 2026, 00_56_32.png';       dst = 'buttons\btn_modo_duelo.png'; crop = $true },
    @{ src = 'icons\Imagem do ChatGPT 28 de out. de 2026, 00_56_35.png';       dst = 'buttons\btn_skins.png'; crop = $true },
    @{ src = 'icons\Imagem do ChatGPT 28 de out. de 2026, 00_56_39.png';       dst = 'buttons\btn_amizades.png'; crop = $true },
    @{ src = 'icons\Imagem do ChatGPT 28 de out. de 2026, 00_56_43.png';       dst = 'buttons\btn_configuracoes.png'; crop = $true },
    @{ src = 'ui\Imagem do ChatGPT 28 de out. de 2026, 01_05_02-1.png';        dst = 'frames\frame_painel_amizades.png'; crop = $true },
    @{ src = 'ui\Imagem do ChatGPT 28 de out. de 2026, 01_05_03-2.png';        dst = 'frames\frame_card_perfil.png'; crop = $true },
    @{ src = 'ui\Imagem do ChatGPT 28 de out. de 2026, 01_05_04-3.png';        dst = 'frames\frame_botao_cabecalho.png'; crop = $true },
    @{ src = 'ui\Imagem do ChatGPT 28 de out. de 2026, 01_05_04-4.png';        dst = 'frames\frame_avatar_anel.png'; crop = $true },
    @{ src = 'ui\Imagem do ChatGPT 28 de out. de 2026, 01_05_05-5.png';        dst = 'frames\frame_painel_brasao.png'; crop = $true },
    @{ src = 'ui\Imagem do ChatGPT 28 de out. de 2026, 01_05_06-6.png';        dst = 'textures\textura_azul.png'; crop = $false },
    @{ src = 'ui\Imagem do ChatGPT 28 de out. de 2026, 01_05_06-7.png';        dst = 'textures\textura_dourada.png'; crop = $false },
    @{ src = 'ui\Imagem do ChatGPT 28 de out. de 2026, 01_05_07-8.png';        dst = 'textures\textura_vermelha.png'; crop = $false },
    @{ src = 'ui\Imagem do ChatGPT 28 de out. de 2026, 01_05_08-9.png';        dst = 'textures\textura_roxa.png'; crop = $false },
    @{ src = 'ui\Imagem do ChatGPT 28 de out. de 2026, 01_05_08-10.png';       dst = 'textures\textura_verde.png'; crop = $false }
)

$alphaThreshold = 24
$pad = 4

foreach ($item in $map) {
    $srcPath = Join-Path $root ('assets\' + $item.src)
    $dstPath = Join-Path $out $item.dst
    New-Item -ItemType Directory -Force -Path (Split-Path $dstPath) | Out-Null

    $bmp = [System.Drawing.Bitmap]::FromFile($srcPath)
    try {
        if (-not $item.crop) {
            $bmp.Save($dstPath, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Output ("copiado  {0} ({1}x{2})" -f $item.dst, $bmp.Width, $bmp.Height)
            continue
        }

        $minX = $bmp.Width; $minY = $bmp.Height; $maxX = -1; $maxY = -1
        for ($y = 0; $y -lt $bmp.Height; $y++) {
            for ($x = 0; $x -lt $bmp.Width; $x++) {
                if ($bmp.GetPixel($x, $y).A -ge $alphaThreshold) {
                    if ($x -lt $minX) { $minX = $x }
                    if ($x -gt $maxX) { $maxX = $x }
                    if ($y -lt $minY) { $minY = $y }
                    if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }

        $left = [math]::Max(0, $minX - $pad)
        $top = [math]::Max(0, $minY - $pad)
        $right = [math]::Min($bmp.Width - 1, $maxX + $pad)
        $bottom = [math]::Min($bmp.Height - 1, $maxY + $pad)
        $w = $right - $left + 1
        $h = $bottom - $top + 1

        $result = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        for ($y = 0; $y -lt $h; $y++) {
            for ($x = 0; $x -lt $w; $x++) {
                $c = $bmp.GetPixel($left + $x, $top + $y)
                if ($c.A -lt $alphaThreshold) {
                    $result.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, $c.R, $c.G, $c.B))
                } else {
                    $result.SetPixel($x, $y, $c)
                }
            }
        }
        $result.Save($dstPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $result.Dispose()
        Write-Output ("recortado {0} ({1}x{2} de {3}x{4})" -f $item.dst, $w, $h, $bmp.Width, $bmp.Height)
    } finally {
        $bmp.Dispose()
    }
}
