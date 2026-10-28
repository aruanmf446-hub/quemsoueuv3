"""Envelope local versionado; cache de servidor persistido nunca autentica uma sessão."""
from copy import deepcopy

from .codec import VERSION, RULES_VERSION, loads, seal, verify_integrity, require
from .engine import new_state, validate_state


def new_save(rules, player_id, mode="offline_reference"):
    value = {"schema_version": VERSION, "kind": "local_save", "rules_version": RULES_VERSION,
             "player_id": player_id, "mode": mode, "local_revision": 0,
             "local_state": new_state(rules, player_id), "server_cache": None,
             "outbox": [], "migration_receipt": None}
    return validate_save(rules, seal(value))


def validate_save(rules, value):
    verify_integrity(value)
    rules.contracts.validate("save", value)
    validate_state(rules, value["local_state"])
    require(value["local_state"]["player_id"] == value["player_id"], "player_mismatch", "Estado local pertence a outro jogador")
    if value["server_cache"] is not None:
        validate_state(rules, value["server_cache"])
        require(value["server_cache"]["player_id"] == value["player_id"], "player_mismatch", "Cache pertence a outro jogador")
    ids = [entry["request"]["request_id"] for entry in value["outbox"]]
    require(len(ids) == len(set(ids)), "duplicate_request", "Requisição repetida na fila")
    for entry in value["outbox"]:
        require((entry["status"] == "superseded") == (entry["superseded_by"] is not None), "invalid_outbox", "Estado de substituição inconsistente")
        if entry["superseded_by"] is not None:
            require(entry["superseded_by"] in ids and entry["superseded_by"] != entry["request"]["request_id"], "invalid_outbox", "Substituição sem requisição correspondente")
    links = {e["request"]["request_id"]: e["superseded_by"] for e in value["outbox"]}
    for start in links:
        visited = set()
        cursor = start
        while cursor is not None:
            require(cursor not in visited, "invalid_outbox", "Ciclo de substituições na fila")
            visited.add(cursor)
            cursor = links[cursor]
    receipt = value["migration_receipt"]
    if receipt is not None:
        require(set(receipt["claimed_flags"]) <= {"desert_stage_completed", "desert_campaign_completed"}, "invalid_migration_receipt", "Flag de migração desconhecida")
    return value


def load_save(rules, data):
    value = loads(data)
    require(isinstance(value, dict) and value.get("schema_version") == VERSION, "unsupported_save_version", "Save exige migração ou é de versão futura")
    return validate_save(rules, value)


def update_local_reference(rules, save, next_state):
    validate_save(rules, save)
    validate_state(rules, next_state)
    require(save["mode"] == "offline_reference", "online_authority_required", "Progresso online não pode ser concedido pelo redutor local")
    require(next_state["player_id"] == save["player_id"], "player_mismatch", "Outro jogador")
    before = save["local_state"]
    require(set(before["completed_phase_ids"]) <= set(next_state["completed_phase_ids"]) and next_state["revision"] >= before["revision"], "local_progress_rollback", "Não substituir progresso por estado anterior")
    if before == next_state:
        return deepcopy(save)
    require(next_state["revision"] > before["revision"], "revision_conflict", "Mudança de conteúdo sem nova revisão")
    result = deepcopy(save)
    result["local_state"] = deepcopy(next_state)
    result["local_revision"] += 1
    return validate_save(rules, seal(result))
