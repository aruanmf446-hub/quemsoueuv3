"""Migração conservadora: originais e alegações são preservados; flags não concedem skins."""
from copy import deepcopy
from dataclasses import dataclass
import hashlib
from pathlib import Path
import re

from jsonschema import Draft202012Validator, FormatChecker

from .codec import VERSION, ProgressionError, loads, digest, require, seal
from .saves import load_save, new_save, validate_save

MIGRATION_VERSION = "legacy_to_local_save_2.0.0"


@dataclass(frozen=True)
class MigrationResult:
    save: dict | None
    report: dict


def _without_comment(line):
    quoted, escaped = False, False
    result = []
    for char in line:
        if char in (";", "#") and not quoted:
            break
        result.append(char)
        if char == '"' and not escaped:
            quoted = not quoted
        escaped = char == "\\" and not escaped
    require(not quoted, "corrupt_legacy_cfg", "String de configuração não terminada")
    return "".join(result).strip()


def parse_legacy_cfg(raw):
    try:
        lines = raw.decode("utf-8-sig").splitlines()
    except UnicodeError as error:
        raise ProgressionError("corrupt_legacy_cfg", "Configuração não está em UTF-8") from error
    result, section = {}, None
    for line in lines:
        line = _without_comment(line)
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            require(bool(section), "corrupt_legacy_cfg", "Seção vazia")
            continue
        require(section is not None and "=" in line, "corrupt_legacy_cfg", "Linha de configuração inválida")
        key, value = (piece.strip() for piece in line.split("=", 1))
        require(bool(key), "corrupt_legacy_cfg", "Chave vazia")
        name = (section, key)
        require(name not in result, "duplicate_legacy_key", "Chave legada repetida")
        result[name] = value  # Valores desconhecidos não são executados nem descartados dos backups.
    return result


def migrate_sources(rules, sources, player_id, *, root=None):
    """sources é {nome_lógico: bytes}; não lê/escreve arquivos e nunca autentica dados."""
    require(bool(sources), "missing_source", "Forneça pelo menos um save")
    require(all(isinstance(name, str) and name and Path(name).name == name and name not in (".", "..") and "\\" not in name and isinstance(raw, bytes) for name, raw in sources.items()), "invalid_source", "Nomes simples e bytes são obrigatórios")
    source_hashes = {name: hashlib.sha256(raw).hexdigest() for name, raw in sorted(sources.items())}
    migration_id = digest({"migration_version": MIGRATION_VERSION, "player_id": player_id, "sources": source_hashes})
    report = {"migration_id": migration_id, "target_save_version": VERSION, "source_sha256": source_hashes,
              "status": "quarantined", "requires_server_review": True, "errors": [], "warnings": []}
    try:
        result = new_save(rules, player_id)
        claimed_flags, claimed_phases, prior_equipped, formats = {}, None, None, []
        extra_claims = False
        for name, raw in sorted(sources.items()):
            if name.lower().endswith(".cfg"):
                formats.append("godot_cfg_v0")
                cfg = parse_legacy_cfg(raw)
                for flag in ("desert_stage_completed", "desert_campaign_completed"):
                    key = ("flags", flag)
                    if key in cfg:
                        require(cfg[key] in ("true", "false"), "invalid_legacy_flag", "Flag legada deve ser booleana literal")
                        require(flag not in claimed_flags or claimed_flags[flag] == (cfg[key] == "true"), "conflicting_legacy_sources", "Fontes discordam da mesma flag")
                        claimed_flags[flag] = cfg[key] == "true"
                key = ("lobby", "character_id")
                if key in cfg:
                    equipped = loads(cfg[key])
                    require(isinstance(equipped, str) and re.fullmatch(r"[a-z][a-z0-9_]*", equipped) is not None, "invalid_legacy_equipment", "ID de equipamento legado inválido")
                    require(prior_equipped in (None, equipped), "conflicting_legacy_sources", "Equipamentos legados conflitantes")
                    prior_equipped = equipped
                continue
            old = loads(raw)
            require(isinstance(old, dict), "invalid_save", "Raiz do save não é objeto")
            version = old.get("schema_version")
            require(type(version) is int, "unsupported_save_version", "Versão de save ausente ou inválida")
            if version == VERSION:
                require(len(sources) == 1, "mixed_current_and_legacy", "Não combinar automaticamente save atual e legado")
                current = load_save(rules, raw)
                require(current["player_id"] == player_id, "player_mismatch", "Save atual pertence a outro jogador")
                report.update(status="already_current", requires_server_review=bool(current["migration_receipt"] and current["migration_receipt"]["review_required"]))
                return MigrationResult(deepcopy(current), report)
            require(version == 1, "unsupported_save_version", "Versão futura/desconhecida: não redefinir o save")
            base_root = Path(root) if root is not None else Path(__file__).resolve().parents[2]
            schema = loads((base_root / "data/contracts/player_state.schema.json").read_bytes())
            require(not list(Draft202012Validator(schema, format_checker=FormatChecker()).iter_errors(old)), "invalid_legacy_v1", "Save v1 não corresponde ao contrato anterior")
            require(old["profile"]["user_id"] == player_id, "player_mismatch", "Save v1 pertence a outro jogador")
            claims = [entry["phase_id"] for entry in old["phase_completions"]]
            require(claims == list(rules.phase_ids[:len(claims)]), "invalid_legacy_sequence", "Conclusões legadas incompletas, duplicadas ou fora de ordem")
            if old["campaigns"]:
                require(len(old["campaigns"]) == 1 and old["campaigns"][0]["completed_phase_ids"] == claims, "invalid_legacy_sequence", "Progresso e conclusões legadas discordam")
            require(claimed_phases is None or claimed_phases == claims, "conflicting_legacy_sources", "Fontes discordam das conclusões")
            claimed_phases = claims
            achievement_claim = any(a["id"] == rules.achievement_id for a in old["achievements"])
            if achievement_claim:
                require(claimed_flags.get(rules.achievement_id, True) is True, "conflicting_legacy_sources", "Conquista alegada contradiz flag legada")
                claimed_flags[rules.achievement_id] = True
            extra_claims |= bool(old["achievements"]) or any(u["character_id"] not in rules.initial_characters for u in old["character_unlocks"])
            require(prior_equipped in (None, old["equipped_character_id"]), "conflicting_legacy_sources", "Equipamentos conflitantes")
            prior_equipped = old["equipped_character_id"]
            formats.append("player_state_v1_untrusted_file")
        if prior_equipped in rules.initial_characters:
            result["local_state"]["equipped_character_id"] = prior_equipped
        elif prior_equipped is not None:
            report["warnings"].append("prior_equipment_requires_entitlement_review")
        review = bool(extra_claims or any(claimed_flags.values()) or claimed_phases or prior_equipped is not None and prior_equipped not in rules.initial_characters)
        receipt = {"migration_version": MIGRATION_VERSION, "migration_id": migration_id, "source_sha256": source_hashes,
                   "source_formats": sorted(set(formats)), "claimed_flags": claimed_flags,
                   "claimed_completed_phase_ids": claimed_phases or [], "prior_equipped_character_id": prior_equipped,
                   "review_required": review, "disposition": "unverified_local_import"}
        result["migration_receipt"] = receipt
        result = validate_save(rules, seal(result))
        report.update(status="migrated_unverified", requires_server_review=review)
        return MigrationResult(result, report)
    except (ProgressionError, OSError) as error:
        report["errors"].append(getattr(error, "code", "legacy_schema_unavailable"))
        return MigrationResult(None, report)
