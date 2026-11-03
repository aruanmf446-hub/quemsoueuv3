"""Importação segura do pacote único Diva Pop do celular para o GitHub."""
from pathlib import Path
import json
import hashlib
import shutil
import struct
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/duel/decks/oficial/diva_pop"
ZIP = DEST / "UPLOAD_DIVA_POP.zip"
EXPECTED = {f"carta_{i:02d}.png" for i in range(1, 11)}
SIGNATURE = bytes.fromhex("89504e470d0a1a0a")
HASHES = {
    "carta_01.png": "f9798d8e370ecb82c87ccef38953fe2e0f7a4a84ee315ab0124e9e7e8b9ab6a2",
    "carta_02.png": "d453b25c9db49892ba9458a885ae907a07f658aab8de6f091c79ea6e909165ed",
    "carta_03.png": "207a7954bea2c5fa980321b62f90d337cb093031c1fb28850a4e5ab26b9a6d60",
    "carta_04.png": "73cbb87ba6568445c388c5ed5f07f16cd458f543262e914d7312033975e4b00c",
    "carta_05.png": "21fbbfb233a2b2354f04481485e0d1c4c996602459082f3433da97cb269d51a1",
    "carta_06.png": "c6a119fbaed4ba4e96766947a0e2e55a04f5fd1422f6ecbcee9ddf42ea008a13",
    "carta_07.png": "ff374ea3730f362b33be81ed4f5ebd0a755da4439fc739adca0ac7a84ee144dd",
    "carta_08.png": "29f0da28a8c5a9c020090f10dc4ab239eb1ef7d2f08c515057e1fa67f2b49d42",
    "carta_09.png": "6ca5ad226bece3e07757debeb03f3ebe57ce7d5199faf3da8195ca91a3909608",
    "carta_10.png": "81f6eeca8b62692f1d9eee6c3e7dee6f050336a53042d10a455b1d44348d35b1",
}

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
                if hashlib.sha256(data).hexdigest() != HASHES[filename]:
                    raise SystemExit(f"Imagem inesperada para {filename}; use o ZIP enviado pelo ChatGPT.")
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
