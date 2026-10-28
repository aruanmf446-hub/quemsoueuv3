"""Gera inventários reproduzíveis da base, sem carregar o projeto no Godot."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re

from common import ROOT, BASE_COMMIT, load_json, resource_path, sha256, tracked_files, write_json
from inspect_assets import inspect_model, external_reference

DIRECTORIES = {
    "cowboy": "Cowboy", "michelly": "Michelly", "rodrigo": "Rodrigo",
    "lorena": "Lorena", "gus": "Gus", "lana": "Lana", "halloween": "Hallowen",
    "el_fuego": "El fuego", "cactus": "cactus", "malagueta": "malagueta",
}


def scan_references(root, files):
    classes, texts, edges, dynamic = {}, {}, [], []
    for name in files:
        if Path(name).suffix not in (".gd", ".tscn", ".json", ".cfg", ".import", ".godot"):
            continue
        text = (root / name).read_text(encoding="utf-8")
        texts[name] = text
        match = re.search(r"^class_name\s+(\w+)", text, re.M)
        if match and name.startswith("scripts/"):
            classes[match[1]] = name
        for match in re.finditer(r'''["'](res://[^"'\r\n]+)["']''', text):
            uri = match[1]
            if uri.startswith("res://.godot/"):
                continue  # Cache gerado pelo importador; sua ausência é esperada fora do editor.
            line = text.count("\n", 0, match.start()) + 1
            if any(c in uri for c in ("%", "{", "*")) or uri.endswith("/"):
                dynamic.append({"source": name, "line": line, "expression": uri})
                continue
            try:
                exists = resource_path(root, uri).exists()
            except ValueError:
                exists = False
            edges.append({"source": name, "line": line, "target": uri[6:], "kind": "resource", "exists": exists})
    for source, text in texts.items():
        if not source.startswith("scripts/"):
            continue
        for class_name, target in classes.items():
            if source != target and re.search(r"\b" + re.escape(class_name) + r"\b", text):
                edges.append({"source": source, "target": target, "kind": "class_reference", "exists": True})
    return {"method": "Referências literais e nomes de classes; não é um parser GDScript nem resolve caminhos de nós em execução.",
            "classes": classes, "edges": edges, "dynamic_references": dynamic,
            "missing_resources": [e for e in edges if not e["exists"] and not e["source"].startswith("addons/")],
            "addon_unresolved_literals": [e for e in edges if not e["exists"] and e["source"].startswith("addons/")],
            "addon_literal_limit": "O plugin contém exemplos, caminhos opcionais e mensagens de validação; seus literais não são declarados dependências obrigatórias do jogo."}


def build_inventory(root, files):
    records = []
    owner_dirs = {f"assets/characters/{directory}": owner for owner, directory in DIRECTORIES.items()}
    for name in files:
        if not name.startswith("assets/") or name.endswith(".import"):
            continue
        path = root / name
        owner = next((owner for directory, owner in owner_dirs.items() if name.startswith(directory + "/")), None)
        record = {"path": "res://" + name, "size_bytes": path.stat().st_size,
                  "sha256": sha256(path), "format": path.suffix.lower().lstrip("."), "character_id": owner}
        if path.suffix.lower() in (".fbx", ".glb", ".obj"):
            try:
                record["inspection"] = inspect_model(path)
                refs = record["inspection"].get("texture_references", []) + record["inspection"].get("material_libraries", []) + record["inspection"].get("external_uris", [])
                record["external_references"] = [external_reference(path, value) for value in refs]
            except (ValueError, IndexError, KeyError, OSError) as error:
                record["inspection_error"] = str(error)
        if path.suffix.lower() == ".mtl":
            references = [line.strip().split(maxsplit=1)[1] for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
                          if line.strip().startswith(("map_Kd ", "map_Ka ", "map_Bump ", "bump "))]
            record["external_references"] = [external_reference(path, value) for value in references]
        records.append(record)
    characters = []
    runtime = load_json(root / "data/characters.json")
    by_id = {entry["id"]: (group, entry) for group in ("playable", "unlockable", "story_villains") for entry in runtime[group]}
    enemy_entries = load_json(root / "data/desert_enemies.json")["enemies"]
    for character_id, directory in DIRECTORIES.items():
        owned = [r for r in records if r["character_id"] == character_id]
        animations = [r for r in owned if r["format"] == "fbx"]
        signatures = sorted({r.get("inspection", {}).get("skeleton_evidence", {}).get("hierarchy_sha256") for r in animations} - {None})
        group, entry = by_id.get(character_id, ("enemy" if character_id in enemy_entries else "boss_asset_only", enemy_entries.get(character_id, {})))
        characters.append({"id": character_id, "name": entry.get("name", "Malagueta"),
                           "runtime_group": group, "directory": "res://assets/characters/" + directory,
                           "models": [r["path"] for r in owned if r["format"] in ("obj", "glb") or r.get("inspection", {}).get("mesh_count", 0) > 0],
                           "fbx_files": [r["path"] for r in animations],
                           "textures": [r["path"] for r in owned if r["format"] in ("png", "jpg", "jpeg", "webp", "ktx2")],
                           "runtime_animation_aliases": entry.get("animations", {}),
                           "bone_hierarchy_signatures": signatures,
                           "idle_verified": entry.get("idle_verified", False),
                           "limit": "Assinatura igual só compara nomes e parentesco; pose de repouso, pesos, importação e aparência ainda exigem validação no motor."})
    return {"baseline_commit": BASE_COMMIT, "method": "Leitura dos arquivos originais; sem conversão, Blender, Godot ou serviços externos.",
            "format_counts": dict(sorted(Counter(r["format"] for r in records).items())),
            "characters": characters, "files": records}


def audit(root, out):
    files = tracked_files(root, BASE_COMMIT)
    absent = [name for name in files if not (root / name).is_file()]
    if absent:
        raise ValueError(f"Checkout incompleto: {len(absent)} arquivos da base ausentes; primeiro: {absent[0]}")
    graph = scan_references(root, files)
    inventory = build_inventory(root, files)
    source = load_json(root / "data/characters.json")
    findings = []
    def finding(code, severity, message, paths):
        findings.append({"id": code, "severity": severity, "status": "open", "message": message, "evidence": paths})
    fuego = next(e for e in source["unlockable"] if e["id"] == "el_fuego")
    if fuego.get("unlock", {}).get("flag") != "desert_campaign_completed":
        finding("unlock_legacy_flag", "high", "El Fuego usa desert_stage_completed; a regra requerida é a conquista desert_campaign_completed após a fase 10. Nenhuma regra ativa foi alterada.", ["data/characters.json", "data/progress_contract.json", "scripts/skins/skins_panel.gd"])
    finding("campaign_not_implemented", "high", "Só a fase 1 tem cena/configuração/script. A conclusão local apenas mostra mensagem; não registra campanha, conquista ou desbloqueio. Não há fases 2–10 nem código de chefe nesta base.", ["scenes/desert/phase_01.tscn", "scripts/desert/phase_01.gd"])
    finding("story_menu_not_connected", "medium", "O menu emite option_selected; o código atual só trata skins. Não foi localizada ligação literal do botão História à fase 1.", ["scripts/menu/main_menu.gd", "scenes/menu/main_menu.tscn"])
    finding("progress_development_only", "high", "Progresso e equipamento ficam em arquivos user:// editáveis e existem botões DEV. Não há autenticação ou validação remota implementada.", ["scripts/progress/player_progress.gd", "scripts/skins/skins_panel.gd", "scripts/lobby/lobby_area.gd"])
    finding("unverified_idle", "medium", "Todos os oito personagens equipáveis usam pose estática de clipe base e idle_verified=false; os arquivos 1–4 não têm semântica de movimento verificada.", ["data/characters.json", "scripts/lobby/character_slot.gd"])
    finding("first_clip_merge", "medium", "CharacterSlot copia o primeiro clipe encontrado, sem selecionar por nome e sem retarget explícito. Compatibilidade dos caminhos de trilhas depende da importação Godot.", ["scripts/lobby/character_slot.gd"])
    mal = [r for r in inventory["files"] if r["character_id"] == "malagueta"]
    if mal:
        finding("malagueta_pending_note_stale", "medium", "Há OBJ/MTL/textura e FBXs de Malagueta, mas pending_assets ainda diz que não foram encontrados. Existência não significa chefe implementado.", ["data/desert_enemies.json", "assets/characters/malagueta"])
    if all(r.get("inspection", {}).get("mesh_count") == 0 for r in mal if r["format"] == "fbx"):
        finding("malagueta_animation_only", "high", "Os FBXs de Malagueta contêm esqueleto/animação sem malha. O OBJ é estático e não armazena rig; falta preparar ou fornecer a malha vinculada ao esqueleto.", [r["path"][6:] for r in mal if r["format"] in ("obj", "fbx")])
    elif any(r.get("inspection", {}).get("mesh_count") == 0 for r in mal if r["format"] == "fbx"):
        finding("malagueta_base_selection", "medium", "ataque de baixo pra cima.fbx tem malha, skin e 65 ossos; os outros quatro FBXs só têm animação/esqueleto. Usar o primeiro como candidato de base e validar as outras trilhas antes de integrar o chefe.", [r["path"][6:] for r in mal if r["format"] == "fbx"])
    for record in inventory["files"]:
        if "inspection_error" in record:
            finding("asset_inspection_" + record["sha256"][:12], "high", record["inspection_error"], [record["path"][6:]])
    if graph["missing_resources"]:
        finding("missing_resource_references", "high", "Existem referências literais a arquivos ausentes; ver dependency_graph.json.", sorted({e["source"] for e in graph["missing_resources"]}))
    finding("environment_placeholder", "medium", "A fase 1 monta caixas e materiais de placeholder; faltam assets de ambientes, obstáculos, checkpoints, áudio e apresentação das outras fases.", ["data/desert_enemies.json", "scripts/desert/phase_01.gd"])
    finding("remote_raw_fbx", "medium", "load() de PackedScene depende dos recursos importados pelo Godot. Baixar um FBX cru do R2 não o transforma em PackedScene disponível no jogo exportado.", ["scripts/lobby/character_slot.gd"])
    snapshot = {"baseline_commit": BASE_COMMIT, "engine_declared": "Godot 4.7 / GDScript 2.0",
                "godot_executed": False, "blender_executed": False,
                "main_scene": "res://scenes/menu/main_menu.tscn", "autoloads": [],
                "counts": {"tracked_files": len(files), "scenes": sum(n.endswith(".tscn") for n in files),
                           "game_scripts": sum(n.startswith("scripts/") and n.endswith(".gd") for n in files),
                           "addon_scripts": sum(n.startswith("addons/") and n.endswith(".gd") for n in files),
                           "initially_playable": len(source["playable"]), "unlockable": len(source["unlockable"])},
                "protected_files": {name: sha256(root / name) for name in files}, "findings": findings}
    write_json(out / "audit_snapshot.json", snapshot)
    write_json(out / "dependency_graph.json", graph)
    write_json(out / "asset_inventory.json", inventory)
    rows = ["# Inventário estrutural dos assets", "", f"Base: `{BASE_COMMIT}`. Gerado por `python3 tools/offline/audit_project.py`.", "",
            "Leitura binária/estrutural; nenhum modelo foi convertido ou alterado. Nomes de clipes e ossos são os nomes na origem, não uma confirmação do resultado do importador Godot.", "",
            "| Personagem / ID | Uso atual | Modelos | FBXs | Texturas locais | Hierarquias distintas |", "| --- | --- | ---: | ---: | ---: | ---: |"]
    for c in inventory["characters"]:
        rows.append(f"| {c['name']} / `{c['id']}` | {c['runtime_group']} | {len(c['models'])} | {len(c['fbx_files'])} | {len(c['textures'])} | {len(c['bone_hierarchy_signatures'])} |")
    for c in inventory["characters"]:
        rows += ["", f"## {c['name']} — `{c['id']}`", "", f"Diretório original: `{c['directory']}`. `idle_verified={str(c['idle_verified']).lower()}`.", "",
                 "| Arquivo de modelo/animação | Estrutura verificável |", "| --- | --- |"]
        for r in inventory["files"]:
            if r["character_id"] != c["id"] or r["format"] not in ("fbx", "obj", "glb"):
                continue
            i = r.get("inspection", {})
            if r["format"] == "fbx":
                skeleton = i.get("skeleton_evidence", {})
                detail = f"{i.get('vertex_count', '?')} vértices, {skeleton.get('limb_nodes', '?')} ossos, {skeleton.get('skin_deformers', '?')} skins, {len(i.get('animation_stacks', []))} pilha(s); FBX {i.get('version', '?')}"
            elif r["format"] == "obj":
                detail = f"{i.get('vertex_count', '?')} vértices; estático, sem esqueleto"
            else:
                detail = f"{i.get('vertex_count', '?')} vértices; {i.get('skeleton_evidence', {}).get('skins', '?')} skins; {len(i.get('animations', []))} animações"
            rows.append(f"| `{Path(r['path']).name}` | {detail} |")
        rows += ["", "Texturas: " + (", ".join(f"`{Path(p).name}`" for p in c["textures"]) or "nenhuma textura separada encontrada"), "",
                 "Compatibilidade: " + ("há mais de uma hierarquia; separar esqueleto-base e animações antes de vincular." if len(c["bone_hierarchy_signatures"]) > 1 else "nomes/parentesco consistentes entre os FBXs inspecionados; pose de repouso e trilhas importadas continuam pendentes.")]
    rows += ["", "## Limites e preparação", "", "- OBJ não leva ossos/pesos/animações. GLB/FBX só podem ser declarados animáveis após inspeção das skins e validação de reprodução.",
             "- Caminhos de autoria ausentes podem ter textura embutida ou candidato pelo nome local: essas situações estão separadas no JSON; candidato não prova resolução pelo importador.",
             "- Manter originais. Conversão, LOD, compressão, materiais, sockets e root motion exigem uma etapa futura de importação e teste no Godot.",
             "- Não há orçamento de polígonos ou memória aprovado para os dispositivos-alvo; este relatório mede os arquivos, sem inventar limites de desempenho.",
             "- Lista completa de arquivos, hashes SHA-256, bytes, curvas, ossos e referências externas: `asset_inventory.json`."]
    (out / "assets.md").write_text("\n".join(rows) + "\n", encoding="utf-8")
    print(json.dumps({"counts": snapshot["counts"], "asset_formats": inventory["format_counts"], "missing_references": len(graph["missing_resources"]), "findings": len(findings)}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--out", type=Path)
    arguments = parser.parse_args()
    audit(arguments.root.resolve(), arguments.out or arguments.root / "docs/offline/generated")
