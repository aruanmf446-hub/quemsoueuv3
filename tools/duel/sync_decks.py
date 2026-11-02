"""Gera supabase/seed/duel_decks.sql a partir das pastas de cartas do Duelo.

Cada deck é uma pasta em assets/duel/decks/oficial/<deck>/ com as cartas em PNG. O nome do arquivo
é o identificador da carta ("<deck>/<arquivo sem .png>"). Um deck.json opcional na pasta
define o nome exibido e a ordem: {"name": "Lendas", "order": 1}.

Uso: python tools/duel/sync_decks.py   (depois aplique o .sql gerado no Supabase)
"""
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
DECKS = ROOT / "assets/duel/decks" / "oficial"
OUTPUT = ROOT / "supabase/seed/duel_decks.sql"
VALID = re.compile(r"^[a-z0-9_]{2,32}$")


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def scan():
    decks, problems = [], []
    for folder in sorted(p for p in DECKS.iterdir() if p.is_dir()) if DECKS.is_dir() else []:
        if not VALID.match(folder.name):
            problems.append(f"pasta '{folder.name}': use só letras minúsculas, números e _ (2 a 32)")
            continue
        info = {}
        if (folder / "deck.json").is_file():
            info = json.loads((folder / "deck.json").read_text(encoding="utf-8"))
        cards = []
        for image in sorted(folder.glob("*.png")):
            if not VALID.match(image.stem):
                problems.append(f"carta '{folder.name}/{image.name}': renomeie com letras minúsculas, números e _")
                continue
            cards.append(f"{folder.name}/{image.stem}")
        if len(cards) < 2:
            problems.append(f"deck '{folder.name}': precisa de pelo menos 2 cartas .png")
            continue
        decks.append({"id": folder.name, "name": str(info.get("name", folder.name.replace("_", " ").title()))[:32],
                      "order": int(info.get("order", 99)), "cards": cards})
    return decks, problems


def main():
    decks, problems = scan()
    for problem in problems:
        print("AVISO:", problem)
    lines = ["-- Gerado por tools/duel/sync_decks.py a partir de assets/duel/decks. Não edite à mão.",
             "begin;"]
    for deck in decks:
        cards = "array[" + ",".join(literal(c) for c in deck["cards"]) + "]::text[]"
        lines.append(f"insert into qse_v3.duel_decks(id,name,card_ids,sort_order) values({literal(deck['id'])},"
                     f"{literal(deck['name'])},{cards},{deck['order']}) on conflict (id) do update set "
                     "name = excluded.name, card_ids = excluded.card_ids, sort_order = excluded.sort_order;")
    # UPSERT apenas; não apagar decks existentes por ausência de arquivos locais.
    if not decks:
        print("AVISO: nenhum deck válido em assets/duel/decks/oficial; o SQL não altera decks existentes.")
    lines.append("commit;")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(decks)} deck(s), {sum(len(d['cards']) for d in decks)} carta(s) -> {OUTPUT.relative_to(ROOT)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
