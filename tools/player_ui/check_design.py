"""Confere o modelo das telas do jogador (sem dependências).

Painéis, botões e cartões das telas do jogador (Personagens, Configurações, Amigos, Música,
Duelo, Perfil e demais) são StyleBoxFlat do PlayerUI, seguindo
docs/referencias/personagens/REFERENCIA_APROVADA.png. Falha se uma dessas telas usar imagem
como moldura.

python3 tools/player_ui/check_design.py
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
# Telas do jogador e estilo compartilhado. O menu principal/lobby (scenes/menu, scenes/lobby,
# scripts/menu) é o design aprovado e tem arte própria; não entra aqui.
MENU_PATHS = ["scripts/decks", "scripts/ui", "scripts/skins", "scenes/player", "scenes/skins"]
FORBIDDEN = [
    (re.compile(r"StyleBoxTexture|NinePatchRect"), "imagem como moldura em tela do jogador"),
    (re.compile(r"res://assets/processed/(frames|textures)/"), "moldura/textura de imagem em tela do jogador"),
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
    print("Design dos menus: OK" if not problems else f"{len(problems)} tela(s) fora do modelo.")
    sys.exit(1 if problems else 0)
