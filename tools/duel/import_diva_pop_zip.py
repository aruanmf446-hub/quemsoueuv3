"""Importação segura do pacote único Diva Pop do celular para o GitHub."""
from pathlib import Path
import json
import shutil
import struct
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/duel/decks/oficial/diva_pop"
ZIP = DEST / "UPLOAD_DIVA_POP.zip"
EXPECTED = {f"carta_{i:02d}.png" for i in range(1, 11)}
SIGNATURE = bytes.fromhex("89504e470d0a1a0a")

def main() -> None:
    if not ZIP.exists():
        raise SystemExit("Faça o upload do arquivo UPLOAD_DIVA_POP.zip na pasta diva_pop.")
    deck = json.loads((DEST / "deck.json").read_text(encoding="utf-8"))
    if set(deck["cards"]) != {name[:-4] for name in EXPECTED}:
        raise SystemExit("deck.json não corresponde às dez cartas esperadas.")
    with zipfile.ZipFile(ZIP, "r") as bundle:
        names = bundle.namelist()
        if len(names) != len(set(names)):
            raise SystemExit("Arquivo ZIP contém nomes duplicados.")
        if set(names) not in (EXPECTED, EXPECTED | {"deck.json"}):
            raise SystemExit("ZIP deve conter somente carta_01.png a carta_10.png, além de deck.json opcional.")
        with tempfile.TemporaryDirectory() as temporary:
            temp = Path(temporary)
            for filename in sorted(EXPECTED):
                info = bundle.getinfo(filename)
                if info.file_size < 1000 or info.file_size > 5_000_000:
                    raise SystemExit(f"Arquivo fora do tamanho permitido: {filename}")
                data = bundle.read(filename)
                if not data.startswith(SIGNATURE) or data[12:16] != b"IHDR":
                    raise SystemExit(f"PNG inválido: {filename}")
                width, height = struct.unpack(">II", data[16:24])
                if not (512 <= width <= 4096 and 768 <= height <= 8192):
                    raise SystemExit(f"Dimensão inválida {filename}: {width}x{height}")
                (temp / filename).write_bytes(data)
            for filename in sorted(EXPECTED):
                shutil.copyfile(temp / filename, DEST / filename)
    ZIP.unlink()
    print("Diva Pop: dez imagens PNG validadas e importadas em", DEST.relative_to(ROOT))

if __name__ == "__main__":
    main()
