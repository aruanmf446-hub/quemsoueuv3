"""Valida o catálogo aprovado e exporta JSON para o responsável pelo backend.

Sem rede, SQL, alterações no Supabase ou dependências externas.
Uso: python3 tools/decks/repository_catalog.py [--output /tmp/catalogo.json]
"""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
DECK_ID = re.compile(r"repo_[a-f0-9]{24}\Z")
CARD_ID = re.compile(r"card_[0-9]{2}\Z")


def catalog(root=ROOT):
    manifest = json.loads((root / "data/community/approved_decks.json").read_text())
    decks, seen = [], set()
    for row in manifest["decks"]:
        deck_id = row["id"]
        if not DECK_ID.fullmatch(deck_id) or deck_id in seen:
            raise ValueError("ID inválido ou repetido no manifesto")
        seen.add(deck_id)
        folder = root / "assets/duel/decks/community" / deck_id
        info = json.loads((folder / "deck.json").read_text())
        cards = info["cards"]
        if info.get("visibility") != "public" or info.get("price") != 0 or not 5 <= len(cards) <= 30:
            raise ValueError(f"Deck fora do contrato: {deck_id}")
        names = set()
        for key, value in cards.items():
            if not CARD_ID.fullmatch(key) or not (folder / (key + ".webp")).is_file():
                raise ValueError(f"Carta ausente/inválida: {deck_id}/{key}")
            name = value["name"].strip().casefold()
            if not name or name in names:
                raise ValueError(f"Nome vazio/repetido: {deck_id}/{key}")
            names.add(name)
        if info.get("cover") and not (folder / "cover.webp").is_file():
            raise ValueError(f"Capa ausente: {deck_id}")
        decks.append({"id": deck_id, "name": info["name"][:32], "order": 99,
                      "cards": [f"{deck_id}/{key}" for key in sorted(cards)]})
    return {"schema_version": 1, "source": "repository_manual_review", "decks": decks}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        result = catalog()
    except (ValueError, KeyError, OSError, TypeError) as error:
        parser.exit(1, f"Catálogo inválido: {error}\n")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"REPOSITORY_CATALOG decks={len(result['decks'])} failures=0")


if __name__ == "__main__":
    main()
