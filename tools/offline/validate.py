"""Valida propostas e preservação da base; não valida o jogo executável."""
import argparse
from collections import Counter
import json
from pathlib import Path
import sys
import subprocess

try:
    from jsonschema import Draft202012Validator, FormatChecker
    from jsonschema.exceptions import SchemaError
except ImportError:
    raise SystemExit("Instale as dependências de ferramentas: python3 -m pip install -r tools/offline/requirements.txt")

from common import ROOT, BASE_COMMIT, load_json, resource_path, sha256, tracked_files, write_json
from audit_project import scan_references

PHASE_IDS = [f"desert_phase_{i:02d}" for i in range(1, 11)]
ACHIEVEMENT = "desert_campaign_completed"


class Report:
    def __init__(self):
        self.errors = []
        self.warnings = []

    def require(self, condition, code, message):
        if not condition:
            self.errors.append({"code": code, "message": message})

    def warn(self, code, message):
        self.warnings.append({"code": code, "message": message})

    def unique(self, values, label):
        duplicates = [value for value, count in Counter(values).items() if count > 1]
        self.require(not duplicates, "duplicate_id", f"{label}: IDs duplicados {duplicates}")


def validate_schema(document, schema, label, report):
    Draft202012Validator.check_schema(schema)
    errors = sorted(Draft202012Validator(schema, format_checker=FormatChecker()).iter_errors(document), key=lambda e: str(list(e.path)))
    for error in errors:
        report.require(False, "schema", f"{label} /{'/'.join(map(str, error.path))}: {error.message}")
    return not errors


def check_file_references(root, value, report, label):
    if isinstance(value, dict):
        for key, item in value.items():
            check_file_references(root, item, report, f"{label}.{key}")
    elif isinstance(value, list):
        for i, item in enumerate(value):
            check_file_references(root, item, report, f"{label}[{i}]")
    elif isinstance(value, str) and value.startswith("res://"):
        try:
            path = resource_path(root, value)
            report.require(path.exists(), "missing_file", f"{label}: {value}")
        except ValueError as error:
            report.require(False, "invalid_path", str(error))


def check_protected_files(root, snapshot, report):
    for file, digest in snapshot["protected_files"].items():
        path = root / file
        report.require(path.is_file(), "protected_missing", file)
        if path.is_file():
            report.require(sha256(path) == digest, "protected_changed", file)


def check_story(registry, campaign, phases, runtime, enemies, resources, dependencies, report):
    entries = registry["entries"]
    report.unique([e["id"] for e in entries], "Catálogo complementar")
    index = {entry["id"]: entry for entry in entries}
    runtime_entries = [e for group in ("playable", "unlockable", "story_villains") for e in runtime[group]]
    report.unique([e["id"] for e in runtime_entries], "data/characters.json")
    report.require(set(index) == {e["id"] for e in runtime_entries} | set(enemies["enemies"]) | {"malagueta"}, "registry_coverage", "Preservar o inventário existente sem inventar personagens")
    for id, role in [("cactus", "enemy"), ("malagueta", "boss")]:
        entry = index.get(id, {})
        report.require(role in entry.get("roles", []) and entry.get("story", {}).get("role") == role and not entry.get("lobby", {}).get("equippable", True), "hostile_role", id)
    for group in ("playable", "unlockable"):
        for source in runtime[group]:
            entry = index.get(source["id"])
            report.require(entry is not None, "catalog_compatibility", source["id"] + " ausente da proposta")
            if entry:
                report.require(entry["name"] == source["name"] and entry["runtime_group"] == group, "catalog_compatibility", source["id"] + ": nome ou grupo alterado")
                report.require(entry["model_candidate"] == source["model"], "catalog_compatibility", source["id"] + ": modelo ativo substituído")
                report.require(entry["lobby"]["initially_unlocked"] == (group == "playable"), "initial_unlock", source["id"])
    for key, enemy in enemies["enemies"].items():
        report.require(enemy["id"] == key and key in index, "enemy_id", key)
    for entry in entries:
        hostile = bool(set(entry["roles"]) & {"enemy", "boss"})
        if hostile:
            report.require(not entry["lobby"]["equippable"] and not entry["lobby"]["initially_unlocked"] and entry["lobby"]["unlock_achievement"] is None, "hostile_playable", entry["id"])
            report.require(not set(entry["roles"]) & {"lobby_playable", "unlockable"}, "hostile_playable", entry["id"])
        if entry["story"]["exclusive_to_story"]:
            report.require(not entry["lobby"]["equippable"], "story_exclusive", entry["id"])
    fuego = index.get("el_fuego", {})
    report.require(fuego.get("lobby", {}).get("unlock_achievement") == ACHIEVEMENT and not fuego.get("lobby", {}).get("initially_unlocked", True), "fuego_unlock", "El Fuego deve iniciar bloqueado no lobby")
    report.require(fuego.get("story", {}).get("available_before_lobby_unlock") is True and fuego.get("story", {}).get("role") == "protagonist", "fuego_story", "Bloqueio do lobby não pode impedir campanha")
    report.require(campaign["phase_ids"] == PHASE_IDS and campaign["phase_count"] == 10, "phase_order", "Campanha deve listar dez IDs estáveis em ordem")
    report.require(campaign["protagonist_id"] == "el_fuego", "wrong_protagonist", "Campanha")
    report.unique([p["id"] for p in phases], "Fases")
    report.require([p["id"] for p in phases] == PHASE_IDS, "phase_order", "Arquivos/ordem das fases")
    completion = campaign["completion"]
    report.require(completion["required_phase_ids"] == PHASE_IDS and completion["final_phase_id"] == PHASE_IDS[-1], "campaign_completion", "Conclusão requer todas as dez fases")
    report.require(completion["achievement_id"] == ACHIEVEMENT and completion["unlocks_character_id"] == "el_fuego" and completion["required_boss_id"] == "malagueta", "campaign_completion", "Conquista, protagonista ou chefe final divergente")
    report.require(campaign["legacy_compatibility"]["automatic_legacy_grant"] is False, "unsafe_legacy_grant", "Flag legada não é prova de conclusão")
    report.unique([r["id"] for r in resources["resources"]], "Recursos")
    report.unique([d["id"] for d in dependencies["dependencies"]], "Dependências")
    resource_ids = {r["id"] for r in resources["resources"]}
    dependency_ids = {d["id"] for d in dependencies["dependencies"]}
    for resource in resources["resources"]:
        report.require(bool(resource["existing_files"]) == (resource["availability"] == "available_unverified"), "resource_availability", resource["id"])
    checkpoints = []
    for i, phase in enumerate(phases, 1):
        id = phase["id"]
        report.require(phase["order"] == i and phase["difficulty"]["progression_rank"] == i, "phase_order", id)
        report.require(phase["protagonist_id"] == "el_fuego", "wrong_protagonist", id)
        report.require(phase["prerequisite_phase_ids"] == ([] if i == 1 else [PHASE_IDS[i - 2]]), "phase_prerequisites", id)
        report.require(all(e["character_id"] == "cactus" for e in phase["enemies_planned"]), "wrong_enemy", id)
        report.require(set(phase["resources_required"]) <= resource_ids, "unknown_resource", id)
        report.require(set(phase["implementation_dependencies"]) <= dependency_ids, "unknown_dependency", id)
        checkpoints.extend(c["id"] for c in phase["checkpoints_planned"])
        report.require(all(c["id"].startswith(id + "_checkpoint_") for c in phase["checkpoints_planned"]), "checkpoint_id", id)
        report.require(phase["completion"]["checkpoint_is_completion"] is False, "checkpoint_completion", id)
        rewards = [(r["type"], r["target_id"]) for r in phase["future_rewards"]]
        expected = [("phase_completion", id)]
        if i == 10:
            expected += [("achievement", ACHIEVEMENT), ("character_unlock", "el_fuego")]
            report.require(phase["boss_id"] == "malagueta" and phase["completion"]["required_boss_id"] == "malagueta" and phase["completion"]["type"] == "defeat_boss_then_reach_exit", "final_boss", id)
        else:
            expected += [("next_phase_access", PHASE_IDS[i])]
            report.require(phase["boss_id"] is None and phase["completion"]["required_boss_id"] is None and phase["completion"]["type"] == "reach_exit", "premature_boss", id)
        report.require(rewards == expected, "reward_rule", id + ": recompensa antecipada ou contraditória")
        existing = phase["existing_runtime"]
        report.require(existing == ({"scene": "res://scenes/desert/phase_01.tscn", "config": "res://data/desert/phase_01.json", "status": "prototype_preserved"} if i == 1 else {"scene": None, "config": None, "status": "not_implemented"}), "runtime_claim", id)
    report.unique(checkpoints, "Checkpoints")


def check_player_state(state, registry, report):
    index = {e["id"]: e for e in registry["entries"]}
    unlocks, achievements = state["character_unlocks"], state["achievements"]
    report.unique([e["character_id"] for e in unlocks], "Unlocks do jogador")
    report.unique([a["id"] for a in achievements], "Conquistas do jogador")
    report.unique([c["phase_id"] for c in state["phase_completions"]], "Fases concluídas")
    report.unique([c["completion_id"] for c in state["phase_completions"]], "IDs de conclusão")
    report.unique([c["campaign_id"] for c in state["campaigns"]], "Progresso por campanha")
    achievement_ids = {a["id"] for a in achievements}
    completed = {p["phase_id"] for p in state["phase_completions"]}
    report.require(completed <= set(PHASE_IDS), "unknown_completed_phase", str(completed))
    # A campanha é sequencial: não aceitar fase 10 isolada como uma campanha completa.
    report.require(completed == set(PHASE_IDS[:len(completed)]), "completion_gap", "Há fase concluída sem pré-requisitos")
    for c in state["campaigns"]:
        report.unique(c["completed_phase_ids"], "Progresso da campanha")
        report.require(set(c["completed_phase_ids"]) == completed, "progress_inconsistent", c["campaign_id"])
        all_done = completed == set(PHASE_IDS)
        report.require((c["status"] == "completed") == all_done, "campaign_status", c["campaign_id"])
        report.require((c["completed_at"] is not None) == all_done, "campaign_timestamp", c["campaign_id"])
        if c["current_phase_id"] is not None:
            report.require(not all_done and c["current_phase_id"] == PHASE_IDS[len(completed)], "current_phase", c["campaign_id"])
        if c["status"] == "not_started":
            report.require(not completed and c["current_phase_id"] is None, "campaign_status", "Campanha não iniciada tem progresso")
    report.require(not completed or bool(state["campaigns"]), "progress_inconsistent", "Conclusões sem campanha")
    report.require((ACHIEVEMENT in achievement_ids) == (completed == set(PHASE_IDS)), "achievement_evidence", "Conquista exige dez conclusões verificadas e deve constar na conclusão completa")
    for a in achievements:
        report.require(a["id"] == ACHIEVEMENT and a["source_campaign_id"] == "desert_campaign", "achievement_source", a["id"])
    for u in unlocks:
        entry = index.get(u["character_id"])
        report.require(bool(entry) and entry["lobby"]["equippable"], "hostile_unlock", u["character_id"])
        if not entry:
            continue
        required = entry["lobby"]["unlock_achievement"]
        if required:
            report.require(u["source"] == "achievement" and u["source_achievement_id"] == required and required in achievement_ids, "unlock_evidence", u["character_id"])
        else:
            report.require(u["source"] == "initial_catalog" and u["source_achievement_id"] is None and entry["lobby"]["initially_unlocked"], "unlock_source", u["character_id"])
    owned = {u["character_id"] for u in unlocks}
    expected = {e["id"] for e in registry["entries"] if e["lobby"]["initially_unlocked"]}
    if ACHIEVEMENT in achievement_ids:
        expected.add("el_fuego")
    report.require(owned == expected, "unlock_set", "Estado deve preservar personagens iniciais e conceder El Fuego somente com a conquista")
    report.require(state["equipped_character_id"] in owned, "equipped_locked", state["equipped_character_id"])


def check_manifest(root, manifest, inventory, report):
    assets = manifest["assets"]
    report.unique([a["asset_id"] for a in assets], "Manifesto asset_id")
    report.unique([a["source_path"] for a in assets], "Manifesto source_path")
    report.unique([a["proposed_object_key"] for a in assets], "Manifesto object key")
    indexed = {f["path"]: f for f in inventory["files"]}
    report.require({a["source_path"] for a in assets} == set(indexed), "manifest_coverage", "Manifesto deve cobrir os 130 assets originais inventariados")
    for a in assets:
        report.require(a["asset_id"] == "source:" + a["source_path"][6:] and a["format"] == Path(a["source_path"]).suffix[1:], "asset_identity", a["source_path"])
        try:
            path = resource_path(root, a["source_path"])
        except ValueError as error:
            report.require(False, "invalid_path", str(error))
            continue
        report.require(path.is_file(), "missing_file", a["source_path"])
        if path.is_file():
            report.require(path.stat().st_size == a["size_bytes"] and sha256(path) == a["sha256"], "asset_integrity", a["source_path"])
        source = indexed.get(a["source_path"])
        if source:
            report.require(a["character_id"] == source["character_id"] and a["sha256"] == source["sha256"], "manifest_owner", a["source_path"])
        key = a["proposed_object_key"]
        report.require(key.startswith("sources/v1/") and a["sha256"] in key.split("/") and ".." not in key.split("/") and ":" not in key and "\\" not in key, "object_key", key)
        expected_realm = "desert" if a["character_id"] in ("el_fuego", "cactus", "malagueta") else None
        report.require(a["realm_id"] == expected_realm, "asset_realm", a["source_path"])
        report.require(a["publication_status"] == "not_uploaded" and a["runtime_ready"] is False, "false_publication", a["source_path"])


def validate(root=ROOT, strict_runtime=False):
    root = Path(root).resolve()
    report = Report()
    plans, contracts = root / "data/planning", root / "data/contracts"
    schemas = {}
    try:
        for path in sorted(contracts.glob("*.schema.json")):
            schema = load_json(path)
            Draft202012Validator.check_schema(schema)
            schemas[path.name] = schema
        documents = {}
        for path in sorted(plans.rglob("*.json")):
            d = load_json(path)
            documents[path.relative_to(plans).as_posix()] = d
            schema_name = ("desert_phase" if path.parent.name == "desert" else "asset_manifest" if path.name == "asset_manifest.local.json" else path.stem) + ".schema.json"
            report.require(schema_name in schemas, "missing_schema", str(path))
            if schema_name in schemas:
                validate_schema(d, schemas[schema_name], str(path.relative_to(root)), report)
            check_file_references(root, d, report, str(path.relative_to(root)))
        for path in sorted((contracts / "examples").glob("*.json")):
            state = load_json(path)
            if validate_schema(state, schemas["player_state.schema.json"], path.name, report):
                check_player_state(state, documents["character_registry.json"], report)
        service = load_json(contracts / "progress_service.proposal.json")
        validate_schema(service, schemas["progress_service.schema.json"], "progress_service.proposal", report)
        check_file_references(root, service, report, "progress_service.proposal")
        report.require(service["status"] == "proposal_only_not_deployed" and service["credentials_included"] is False, "service_scope", "Contrato não pode afirmar deploy nem incluir credenciais")
        report.unique([t["name"] for t in service["tables_proposed"]], "Tabelas propostas")
        report.unique([o["name"] for o in service["operations_proposed"]], "Operações propostas")
        report.require(service["completion_policy"]["required_phase_ids"] == PHASE_IDS and service["completion_policy"]["achievement_id"] == ACHIEVEMENT and service["completion_policy"]["legacy_flag_is_proof"] is False, "service_completion", "Política do serviço contradiz campanha")
        runtime, enemies = load_json(root / "data/characters.json"), load_json(root / "data/desert_enemies.json")
        check_file_references(root, runtime, report, "data/characters.json")
        check_file_references(root, enemies, report, "data/desert_enemies.json")
        if not any(e["code"] == "schema" for e in report.errors):
            phases = [documents[f"desert/phase_{i:02d}.json"] for i in range(1, 11)]
            check_story(documents["character_registry.json"], documents["desert_campaign.json"], phases, runtime, enemies, documents["resource_requirements.json"], documents["implementation_dependencies.json"], report)
            snapshot = load_json(root / "docs/offline/generated/audit_snapshot.json")
            report.require(snapshot["baseline_commit"] == BASE_COMMIT, "baseline_commit", "Base de preservação incorreta")
            original_files = tracked_files(root, BASE_COMMIT)
            report.require(set(snapshot["protected_files"]) == set(original_files), "baseline_coverage", "O snapshot deve proteger todos os arquivos da base")
            report.require(subprocess.run(["git", "diff", "--quiet", BASE_COMMIT, "--", *original_files], cwd=root).returncode == 0, "baseline_git_changed", "Arquivos originais diferem do commit auditado")
            check_protected_files(root, snapshot, report)
            graph = scan_references(root, list(snapshot["protected_files"]))
            for missing in graph["missing_resources"]:
                report.require(False, "missing_file", f"{missing['source']}:{missing['line']} -> {missing['target']}")
            inventory = load_json(root / "docs/offline/generated/asset_inventory.json")
            check_manifest(root, documents["asset_manifest.local.json"], inventory, report)
        fuego = next(e for e in runtime["unlockable"] if e["id"] == "el_fuego")
        if fuego["unlock"]["flag"] != ACHIEVEMENT:
            message = "Runtime preservado usa desert_stage_completed; a migração para desert_campaign_completed/fase 10 NÃO está aplicada."
            if strict_runtime:
                report.require(False, "runtime_unlock_contradiction", message)
            else:
                report.warn("runtime_unlock_contradiction", message)
        report.warn("runtime_not_executed", "Godot/Blender não executados: importação, sintaxe GDScript, gameplay, retarget e desempenho permanecem sem validação de execução.")
    except (ValueError, KeyError, IndexError, OSError, TypeError, StopIteration, SchemaError) as error:
        report.require(False, "incomplete_or_invalid_data", f"{type(error).__name__}: {error}")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--strict-runtime", action="store_true", help="Também reprovar a divergência legada de desbloqueio, preservada nesta tarefa")
    parser.add_argument("--report", type=Path, help="Salvar relatório JSON no caminho informado")
    args = parser.parse_args()
    result = validate(args.root, args.strict_runtime)
    payload = {"scope": "offline_proposals_and_baseline", "errors": result.errors, "warnings": result.warnings,
               "godot_executed": False, "blender_executed": False, "remote_services_modified": False}
    if args.report:
        write_json(args.report, payload)
    for error in result.errors:
        print(f"ERRO [{error['code']}] {error['message']}")
    for warning in result.warnings:
        print(f"AVISO [{warning['code']}] {warning['message']}")
    print(f"{'FALHOU' if result.errors else 'OK'}: {len(result.errors)} erros; {len(result.warnings)} avisos. Aprovação estática não equivale a validação no Godot.")
    sys.exit(1 if result.errors else 0)
