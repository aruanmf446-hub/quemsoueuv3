#!/usr/bin/env python3
"""Gera os ícones do PWA a partir do logo oficial embutido na tela de carregamento (web/shell.html).
Fundo escuro com o degradê da identidade; logo centralizado sem distorção."""
import base64, io, re, sys
from PIL import Image, ImageDraw

shell = open("web/shell.html", encoding="utf-8").read()
data = re.search(r'src="data:image/webp;base64,([^"]+)"', shell).group(1)
logo = Image.open(io.BytesIO(base64.b64decode(data))).convert("RGBA")

def icon(size, pad, out):
    canvas = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(canvas)
    for y in range(size):  # degradê vertical #1b2a4a → #05080f
        t = y / max(size - 1, 1)
        c = tuple(int(a + (b - a) * t) for a, b in zip((27, 42, 74), (5, 8, 15)))
        draw.line([(0, y), (size, y)], fill=c + (255,))
    room = int(size * (1 - 2 * pad))
    scale = min(room / logo.width, room / logo.height)
    art = logo.resize((max(1, int(logo.width * scale)), max(1, int(logo.height * scale))), Image.LANCZOS)
    canvas.alpha_composite(art, ((size - art.width) // 2, (size - art.height) // 2))
    canvas.convert("RGB").save(out, optimize=True)

for size in (180, 192, 512):
    icon(size, 0.03, f"web/pwa/icon-{size}.png")
icon(512, 0.2, "web/pwa/icon-maskable-512.png")  # área segura para ícones mascarados
print("ok")
