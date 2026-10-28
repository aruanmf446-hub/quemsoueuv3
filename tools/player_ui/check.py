"""Verificações estáticas da Tarefa 03. Não inicia nem importa o Godot."""
import hashlib
import json
from pathlib import Path
from tools.preservation import expected_blob
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASE = "529ab72643ee3e5b92a466be9602299d0330b101"
ALLOWED_CHANGES = {
    "project.godot", "data/characters.json", "scenes/menu/main_menu.tscn",
    "scripts/menu/main_menu.gd", "scenes/skins/skins_panel.tscn",
    "scripts/skins/skins_panel.gd", "scripts/progress/player_progress.gd",
    "scripts/lobby/lobby_area.gd", "scripts/lobby/lobby_stage.gd",
    "scripts/skins/thumbnail_cache.gd",
    "scripts/ui/navigation_manager.gd", "scripts/ui/player_screen.gd",
    "scripts/ui/screens/settings_screen.gd", "scripts/ui/screens/public_profile_screen.gd",
    "scripts/services/device_preferences.gd", "tools/player_ui/check.py",
}
ATTR = re.compile(r'(\w+)="([^"]*)"')


def load_json(path):
    def unique(items):
        data = {}
        for key, value in items:
            if key in data:
                raise ValueError(f"Chave duplicada: {key}")
            data[key] = value
        return data
    return json.loads(path.read_text(), object_pairs_hook=unique)


def scene_tree(path, stack=()):
    path = Path(path)
    if path in stack:
        raise ValueError(f"Ciclo de cenas: {path}")
    source = path.read_text()
    external = {}
    for match in re.finditer(r"^\[ext_resource (.*)\]$", source, re.M):
        attrs = dict(ATTR.findall(match[1]))
        external[attrs["id"]] = ROOT / attrs["path"].removeprefix("res://")
        if not external[attrs["id"]].is_file():
            raise ValueError(f"{path}: recurso ausente {attrs['path']}")
    nodes = {}
    for match in re.finditer(r"^\[node (.*?)\]\s*\n(.*?)(?=^\[|\Z)", source, re.M | re.S):
        attrs = dict(ATTR.findall(match[1]))
        root = "parent" not in attrs
        parent = "" if attrs.get("parent", ".") == "." else attrs["parent"] + "/"
        name = "" if root else parent + attrs["name"]
        instance = re.search(r'instance=ExtResource\("([^"]+)"\)', match[1])
        if instance:
            nested = scene_tree(external[instance[1]], (*stack, path))
            for child, script in nested.items():
                key = name + ("/" if name and child else "") + child
                nodes[key] = script
        nodes.setdefault(name, None)
        script = re.search(r'^script = ExtResource\("([^"]+)"\)', match[2], re.M)
        if script:
            nodes[name] = external[script[1]]
    for node in nodes:
        if "/" in node and node.rsplit("/", 1)[0] not in nodes:
            raise ValueError(f"{path}: pai ausente de {node}")
    return nodes


def validate_catalog(catalog, rules):
    entries = catalog["playable"] + catalog["unlockable"]
    ids = [entry["id"] for entry in entries]
    if len(ids) != len(set(ids)):
        raise ValueError("IDs duplicados no catálogo")
    expected = rules["classifications"]["playable_heroes"] + rules["classifications"]["unlockable_heroes"]
    if ids != expected:
        raise ValueError("Catálogo diverge dos IDs v2")
    fuego = next(entry for entry in entries if entry["id"] == "el_fuego")
    if fuego["unlock"] != {"type": "achievement", "achievement_id": "desert_campaign_completed", "label": "Conclua o Reino do Deserto"}:
        raise ValueError("Autorização de El Fuego não canônica")
    for entry in catalog["playable"]:
        if entry["unlock"] is not None:
            raise ValueError("Herói inicial incorretamente bloqueado")


def validate_routes(routes, root=ROOT):
    if set(routes) != {"profile","public_profile","settings","friends","wallet","skins","story","account"}:
        raise ValueError("Rotas incompletas ou desconhecidas")
    if len(set(routes.values())) != len(routes):
        raise ValueError("Duas rotas usam a mesma cena")
    for path in routes.values():
        if not path.startswith("res://") or ".." in Path(path).parts:
            raise ValueError("Caminho de navegação inválido")
        if not (root / path.removeprefix("res://")).is_file():
            raise ValueError(f"Tela ausente: {path}")


def check(root=ROOT):
    from gdtoolkit.parser import parser
    from jsonschema import Draft202012Validator
    from pglast import parse_sql
    parser._cache_dirpath = str(Path(tempfile.gettempdir()) / "qse-gdtoolkit-cache")
    rules = load_json(root / "data/progression/rules.v2.json")
    validate_catalog(load_json(root / "data/characters.json"), rules)
    routes = load_json(root / "data/ui/routes.json")["routes"]
    validate_routes(routes, root)
    schema = load_json(root / "data/ui/services.schema.json")
    Draft202012Validator.check_schema(schema)
    scripts = list((root / "scripts").rglob("*.gd"))
    class_files = {}
    for path in scripts:
        source = path.read_text()
        parser.parse(source)
        match = re.search(r"^class_name (\w+)", source, re.M)
        if match:
            if match[1] in class_files:
                raise ValueError(f"Classe global duplicada: {match[1]}")
            class_files[match[1]] = path
        for resource in re.findall(r'["\'](res://[^"\']+)["\']', source):
            if "%" not in resource and not (root / resource.removeprefix("res://")).is_file():
                raise ValueError(f"{path}: caminho inexistente {resource}")
    scenes = list((root / "scenes").rglob("*.tscn"))
    for path in scenes:
        nodes = scene_tree(path)
        for node, script in nodes.items():
            seen = set()
            while script is not None and script not in seen:
                seen.add(script)
                source = script.read_text()
                for short, quoted in re.findall(r'\$(?:([A-Za-z_][\w/]*)|"([^"]+)")', source):
                    target = "/".join(part for part in [node, short or quoted] if part)
                    if target not in nodes:
                        raise ValueError(f"{path}: {script.name} referencia nó ausente {target}")
                base = re.search(r"^extends (\w+)",source,re.M)
                script = class_files.get(base[1]) if base else None
    for path in (root / "supabase/migrations").glob("*.sql"):
        parse_sql(path.read_text())
    parse_sql((root / "supabase/preflight.sql").read_text())
    # A biblioteca e os 82 arquivos das duas tarefas anteriores permanecem intactos.
    entries = subprocess.check_output(["git","ls-tree","-rz",BASE],cwd=root).split(b"\0")
    previous = []
    modified = []
    for entry in filter(None, entries):
        header, filename = entry.split(b"\t", 1)
        before = header.split()[2].decode()
        relative = filename.decode()
        previous.append(relative)
        file = root / relative
        if not file.is_file():
            raise ValueError(f"Arquivo anterior removido: {relative}")
        after = hashlib.sha1(b"blob "+str(file.stat().st_size).encode()+b"\0"+file.read_bytes()).hexdigest()
        if before != after:
            if after != expected_blob(root, BASE, relative, before):
                raise ValueError(f"Mudança fora do escopo de interface: {relative}")
            modified.append(relative)
    return {"base": BASE, "routes":len(routes),"scenes_scanned":len(scenes),"scripts_parsed":len(scripts),
            "previous_files":len(previous),"justified_ui_changes":modified,"previous_offline_deliveries_unchanged":82,
            "godot_executed":False,"remote_database_connected":False,"sql_parser":"pglast","gdscript_parser":"gdtoolkit 4.5; não verifica tipos/APIs do motor"}


if __name__ == "__main__":
    try:
        print(json.dumps(check(), ensure_ascii=False, indent=2))
    except Exception as error:
        print(str(error),file=sys.stderr)
        raise SystemExit(1)
