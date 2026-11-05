"""Instala fixture temporária, importa no Godot e valida Biblioteca/duelo local.

Uso: python3 tests/deck_repository/with_published_fixture.py /caminho/godot
Não publicar nem exportar o jogo durante esta execução. Restaura manifesto e
remove somente a pasta temporária criada por este script, inclusive se falhar.
"""
import base64
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
ID = "repo_" + "f" * 24
IMAGE = 'UklGRioAAABXRUJQVlA4TB0AAAAvP8FvAAdQwWpVtf8BAUnS//9hRP8z/vOf//xfAAA='


def main():
    engine = sys.argv[1]
    manifest = ROOT / "data/community/approved_decks.json"
    original = manifest.read_bytes()
    data = json.loads(original)
    folder = ROOT / "assets/duel/decks/community" / ID
    if folder.exists() or any(row["id"] == ID for row in data["decks"]):
        raise RuntimeError("Fixture já existe; não sobrescrever arquivos existentes.")
    folder.mkdir(parents=True)
    try:
        cards = {}
        for i in range(1, 6):
            key = f"card_{i:02}"
            (folder / (key + ".webp")).write_bytes(base64.b64decode(IMAGE))
            cards[key] = {"name": f"Carta {i}", "crops": {"library": {"x": .5, "y": .4}, "duel": {"x": .5, "y": .35}}}
        (folder / "cover.webp").write_bytes(base64.b64decode(IMAGE))
        (folder / "deck.json").write_text(json.dumps({"name": "Fixture não publicada", "creator": "Fixture local", "visibility": "public", "price": 0, "cover": True, "cards": cards}))
        data["decks"].append({"id": ID})
        manifest.write_text(json.dumps(data))
        subprocess.run([sys.executable, str(ROOT / "tools/decks/repository_catalog.py")], check=True)
        subprocess.run([engine, "--headless", "--path", str(ROOT), "--editor", "--import", "--quit"], check=True)
        subprocess.run([engine, "--headless", "--path", str(ROOT), "--script", "res://tests/deck_repository/published_flow.gd"], check=True)
    finally:
        manifest.write_bytes(original)
        shutil.rmtree(folder)


if __name__ == "__main__":
    main()
