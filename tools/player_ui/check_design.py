"""Trava do design aprovado dos menus (sem dependências).

O visual de molduras/placas de imagem azul e dourado (assets/ui/kit e a moldura com brasão
frame_painel_brasao) foi reprovado para as telas de menu: Personagens, Configurações, Amigos,
Música, Duelo, Perfil e demais telas do jogador. Este verificador falha se essas imagens
voltarem a ser referenciadas por scripts ou cenas de menu.

python3 tools/player_ui/check_design.py
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
# Telas do jogador e estilo compartilhado. O menu principal/lobby (scenes/menu, scenes/lobby,
# scripts/menu) é o design aprovado e tem arte própria; não entra aqui.
MENU_PATHS = ["scripts/ui", "scripts/skins", "scenes/player", "scenes/skins"]
FORBIDDEN = [
    (re.compile(r"res://assets/ui/kit/"), "kit de molduras assets/ui/kit (reprovado)"),
    (re.compile(r"frame_painel_brasao"), "moldura com brasão (reprovada)"),
    (re.compile(r"res://assets/ui/Imagem"), "imagem original do kit reprovado (assets/ui)"),
    (re.compile(r"res://assets/processed/textures/"), "textura colorida do kit reprovado"),
    (re.compile(r"StyleBoxTexture|NinePatchRect"), "moldura de imagem em tela de menu"),
]


def violations(root: Path = ROOT) -> list[str]:
    found = []
    for base in MENU_PATHS:
        for path in sorted((root / base).rglob("*")):
            if path.suffix not in {".gd", ".tscn", ".tres"}:
                continue
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                for pattern, reason in FORBIDDEN:
                    if pattern.search(line):
                        found.append(f"{path.relative_to(root)}:{number}: {reason}: {line.strip()}")
    return found


if __name__ == "__main__":
    problems = violations()
    for problem in problems:
        print(problem)
    print("Design dos menus: OK" if not problems else f"{len(problems)} referência(s) ao visual reprovado.")
    sys.exit(1 if problems else 0)
