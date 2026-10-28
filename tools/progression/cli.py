"""CLI local para inspeção, simulação e migração; nunca acessa serviços remotos."""
import argparse
from copy import deepcopy
import json
from pathlib import Path
import subprocess
import sys

from .codec import ROOT, ProgressionError, canonical, loads, require
from .rules import Rules
from .engine import new_state, start_phase, complete_phase
from .saves import new_save, load_save, update_local_reference
from .migration import migrate_sources, MIGRATION_VERSION
from .storage import write_migration_bundle, inspect_migration_bundle

BASE_COMMIT = "943c890519111c83aab3c5bdf85bcb120dc02f72"


def check_reference(root=ROOT):
    rules = Rules(root)
    root = Path(root)
    policy = loads((root / "data/progression/migration_policy.v2.json").read_bytes())
    rules.contracts.validate("migration_policy", policy)
    required_policy = {"migration_version": MIGRATION_VERSION, "target_save_version": 2,
                       "supported_json_versions": [1, 2], "flags_are_completion_evidence": False,
                       "legacy_equipment_is_entitlement": False, "server_cache_trusted_on_load": False,
                       "unknown_future_version": "quarantine_without_overwrite",
                       "corrupt_save": "quarantine_original_bytes_without_creating_progress"}
    require(all(policy.get(key) == value for key, value in required_policy.items()), "migration_policy_mismatch", "Contrato de migração contradiz implementação")
    original = [p.decode() for p in subprocess.check_output(["git", "ls-tree", "-rz", "--name-only", BASE_COMMIT], cwd=root).split(b"\0") if p]
    require(subprocess.run(["git", "diff", "--quiet", BASE_COMMIT, "--", *original], cwd=root).returncode == 0, "previous_files_changed", "Um arquivo anterior da base foi alterado")
    examples = sorted((root / "data/progression/examples").glob("*.save.json"))
    for path in examples:
        load_save(rules, path.read_bytes())
    return {"status": "ok", "rules_version": "desert_progression_2.0.0", "preserved_files": len(original),
            "preserved_previous_delivery_files": 49, "phases": len(rules.phases), "characters": len(rules.characters),
            "validated_save_examples": len(examples), "godot_executed": False, "remote_services_accessed": False,
            "runtime_migration_applied": False}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("check", help="Verificar contratos, exemplos e preservação dos arquivos anteriores")
    demo = commands.add_parser("demo", help="Simular dez fases, sem gameplay")
    demo.add_argument("--player-id", default="00000000-0000-4000-8000-000000000001")
    create = commands.add_parser("new", help="Emitir save inicial na saída padrão; não cria arquivos")
    create.add_argument("--player-id", required=True)
    status = commands.add_parser("inspect", help="Inspecionar save v2, sem confiar em cache online")
    status.add_argument("save", type=Path)
    bundle = commands.add_parser("inspect-bundle", help="Conferir backups, marcador de conclusão e save de um bundle")
    bundle.add_argument("directory", type=Path)
    migrate = commands.add_parser("migrate", help="Planejar migração; --out cria bundle novo com backups")
    migrate.add_argument("--player-id", required=True)
    migrate.add_argument("--source", type=Path, action="append", required=True)
    migrate.add_argument("--out", type=Path)
    args = parser.parse_args(argv)
    try:
        rules = Rules()
        if args.command == "check":
            result = check_reference()
        elif args.command == "new":
            result = new_save(rules, args.player_id)
        elif args.command == "demo":
            state = new_state(rules, args.player_id)
            rows = []
            for phase in rules.phases:
                state = start_phase(rules, state, phase.id)
                state = complete_phase(rules, state, phase.id, defeated_boss_id=phase.boss_id)
                rows.append({"phase_id": phase.id, "provisional_achievement_ids": deepcopy(state["achievement_ids"]), "el_fuego_provisionally_unlocked": "el_fuego" in state["unlocked_character_ids"]})
            result = {"simulation_only": True, "definitive_online_unlocks_granted": False, "phases": rows}
        elif args.command == "inspect-bundle":
            result = inspect_migration_bundle(rules, args.directory)
        elif args.command == "inspect":
            save = load_save(rules, args.save.read_bytes())
            result = {"mode": save["mode"], "local_revision": save["local_revision"], "local_completed_phase_ids": save["local_state"]["completed_phase_ids"],
                      "local_entitlements_are_provisional": True, "server_cache_trusted": False, "requires_server_review": bool(save["migration_receipt"] and save["migration_receipt"]["review_required"])}
        else:
            require(len({path.name for path in args.source}) == len(args.source), "duplicate_source_name", "Arquivos de origem precisam de nomes lógicos distintos")
            sources = {path.name: path.read_bytes() for path in args.source}
            migration = migrate_sources(rules, sources, args.player_id)
            if args.out is not None:
                write_migration_bundle(rules, sources, migration, args.out)
            result = migration.report
            print(json.dumps(result, ensure_ascii=False, indent=2))
            return 0 if migration.save is not None else 2
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (ProgressionError, OSError) as error:
        print(json.dumps({"status": "error", "code": getattr(error, "code", "filesystem_error"), "message": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
