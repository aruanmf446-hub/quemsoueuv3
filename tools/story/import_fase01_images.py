#!/usr/bin/env python3
"""Importa os 8 quadros WebP da Fase 01 com verificação e limpeza da pasta temporária.

Uso: python3 tools/story/import_fase01_images.py /caminho/el_fuego_abertura_fase01_8_cenas.zip
Execute a partir de qualquer diretório, desde que este script esteja no clone do projeto.
Somente os oito arquivos fase01_MM.webp serão alterados no destino.
"""
from __future__ import annotations

import hashlib
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets" / "story"

EXPECTED = {
    "fase01_01.webp": "daaf4a22aee7736c0e9b9e0973f30644ce9fa721e289d75c7952cc1674aef8d7",
    "fase01_02.webp": "862e4c68b3d302ca2ad9146c76feb9b89206fd09c546de4fdd88e541f504a3aa",
    "fase01_03.webp": "19d99b762be20ef72eb652aba8ac4f2df0db37de83b3c1b63a718bcfc10f93f5",
    "fase01_04.webp": "20e34bd5c9c1984f29f056818f258b70b97c162f3735435e6edaa478129905d7",
    "fase01_05.webp": "fbadb6cbc97443e8522ba603469e9cf21379593265dbeaf7804319d97cbdf40d",
    "fase01_06.webp": "be486ebdc1b368f1a6270049ce9b5853558c1de0195d45c852453c9fdfed4cf4",
    "fase01_07.webp": "a5b336da84558bd2e03a8c1125ceb209c1f1dea1afdf7373d43e4a7958b3837d",
    "fase01_08.webp": "df53dd28dc54939f58f2b0efd65b76e3c45f04baa50fe54d3fa0cc2e8ebee4e8",
}


def checksum(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def verify(name: str, data: bytes) -> None:
    if len(data) < 16 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise ValueError(f"{name}: não é WebP válido")
    if not checksum(data) != EXPECTED[name]:
        raise ValueError(f"{name}: SHA-256 não confere com as imagens aprovadas")


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    source = Path(sys.argv[1]).expanduser().resolve()
    if not source.is_file() or not zipfile.is_zipfile(source):
        raise FileNotFoundError(f"ZIP inexistente ou inválido: {source}")

    # Leia somente nomes conhecidos. Não extraia caminhos arbitrários de ZIP.
    with zipfile.ZipFile(source) as archive:
        data = {}
        for name in EXPECTED:
            matching = [info for info in archive.infolist() if Path(info.filename).name == name and not info.is_dir()]
            if len(matching) != 1:
                raise ValueError(f"{name}: esperado uma vez no ZIP; encontrados {len(matching)}")
            payload = archive.read(matching[0])
            verify(name, payload)
            data[name] = payload

    # Diretório temporário exclusivo, removido automaticamente ao terminar.
    # Backup em memória para restaurar os arquivos se qualquer operação falhar.
    previous = {name: (DEST / name).read_bytes() if (DEST / name).exists() else None for name in EXPECTED}
    installed = []
    with tempfile.TemporaryDirectory(prefix=".temp_fase01_", dir=ROOT) as staging_name:
        stage = Path(staging_name)
        for name, payload in data.items():
            (stage / name).write_bytes(payload)
            verify(name, (stage / name).read_bytes())
        try:
            DEST.mkdir(parents=True, exist_ok=True)
            for name in EXPECTED:
                shutil.copyfile(stage / name, DEST / name)
                installed.append(name)
                verify(name, (DEST / name).read_bytes())
        except Exception:
            for name in installed:
                old = previous[name]
                if old is None:
                    (DEST / name).unlink(missing_ok=True)
                else:
                    (DEST / name).write_bytes(old)
            raise

    for name in EXPECTED:
        verify(name, (DEST / name).read_bytes())
    print("OK: 8 imagens copiadas e conferidas em assets/story/.")
    print("OK: pasta temporária de importação removida; fontes originais preservadas.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
