"""Utilidades de leitura; nenhuma função inicia Godot, Blender ou serviços remotos."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE_COMMIT = "957fce550e8c4d0a71009b47e8f86e73d0780b19"


def load_json(path):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError(f"Chave JSON duplicada: {key}")
            result[key] = value
        return result
    return json.loads(Path(path).read_text(encoding="utf-8"), object_pairs_hook=pairs,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def resource_path(root, value):
    if not isinstance(value, str) or not value.startswith("res://"):
        raise ValueError(f"Caminho res:// inválido: {value!r}")
    relative = value[6:]
    if "\\" in relative or ".." in Path(relative).parts:
        raise ValueError(f"Caminho fora do projeto: {value}")
    target = (Path(root) / relative).resolve()
    if not target.is_relative_to(Path(root).resolve()):
        raise ValueError(f"Caminho fora do projeto: {value}")
    return target


def tracked_files(root=ROOT, revision=None):
    command = ["git", "ls-tree", "-rz", "--name-only", revision] if revision else ["git", "ls-files", "-z"]
    return [p.decode("utf-8") for p in subprocess.check_output(command, cwd=root).split(b"\0") if p]
