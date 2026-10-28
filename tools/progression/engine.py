"""Redutor puro de referência; não autoriza contas online nem altera arquivos."""
from copy import deepcopy

from .codec import VERSION, RULES_VERSION, require


def validate_state(rules, state):
    rules.contracts.validate("state", state)
    completed = state["completed_phase_ids"]
    require(completed == list(rules.phase_ids[:len(completed)]), "phase_sequence", "Conclusões devem formar prefixo sequencial sem duplicações")
    achievements, unlocked = rules.grants(completed)
    require(state["achievement_ids"] == achievements and state["unlocked_character_ids"] == unlocked, "invalid_entitlements", "Conquista/desbloqueios não correspondem às dez conclusões")
    require(state["equipped_character_id"] in unlocked, "character_locked", "Personagem equipado bloqueado ou não jogável")
    if state["active_phase_id"] is not None:
        require(state["active_phase_id"] in _available_phases(rules, state), "phase_locked", "Fase ativa sem pré-requisitos")
    checkpoint = state["checkpoint"]
    if checkpoint is not None:
        require(checkpoint["phase_id"] == state["active_phase_id"], "checkpoint_phase_mismatch", "Checkpoint pertence a outra fase")
        require(checkpoint["checkpoint_id"] in rules.phase_by_id[checkpoint["phase_id"]].checkpoint_ids, "unknown_checkpoint", "Checkpoint não planejado")
    return state


def new_state(rules, player_id):
    require(bool(rules.initial_characters), "empty_initial_catalog", "Não há herói inicial")
    state = {"schema_version": VERSION, "rules_version": RULES_VERSION, "player_id": player_id, "revision": 0,
             "completed_phase_ids": [], "active_phase_id": None, "checkpoint": None,
             "achievement_ids": [], "unlocked_character_ids": list(rules.initial_characters),
             "equipped_character_id": rules.initial_characters[0]}
    return validate_state(rules, state)


def _available_phases(rules, state):
    return list(rules.phase_ids[:min(len(state["completed_phase_ids"]) + 1, len(rules.phase_ids))])


def available_phases(rules, state):
    validate_state(rules, state)
    return _available_phases(rules, state)


def can_start_phase(rules, state, phase_id):
    validate_state(rules, state)
    return phase_id in _available_phases(rules, state)


def can_use_campaign_character(rules, state, phase_id, character_id):
    validate_state(rules, state)
    return character_id == rules.protagonist_id and can_start_phase(rules, state, phase_id)


def can_equip(rules, state, character_id):
    validate_state(rules, state)
    character = rules.characters.get(character_id) if isinstance(character_id, str) else None
    return bool(character and character.classification in ("playable_hero", "unlockable_hero") and character.scope != "campaign_only" and character_id in state["unlocked_character_ids"])


def _changed(rules, before, after):
    if after == before:
        return deepcopy(before)
    after["revision"] = before["revision"] + 1
    return validate_state(rules, after)


def start_phase(rules, state, phase_id):
    validate_state(rules, state)
    require(isinstance(phase_id, str) and phase_id in rules.phase_by_id, "unknown_phase", "Fase desconhecida")
    require(can_start_phase(rules, state, phase_id), "phase_locked", "Não é permitido pular fases")
    after = deepcopy(state)
    if after["active_phase_id"] != phase_id:
        after["active_phase_id"], after["checkpoint"] = phase_id, None
    return _changed(rules, state, after)


def record_checkpoint(rules, state, phase_id, checkpoint_id):
    validate_state(rules, state)
    require(isinstance(phase_id, str) and phase_id in rules.phase_by_id, "unknown_phase", "Fase desconhecida")
    require(phase_id == state["active_phase_id"], "phase_not_active", "Inicie a fase antes de registrar checkpoint")
    require(checkpoint_id in rules.phase_by_id[phase_id].checkpoint_ids, "unknown_checkpoint", "Checkpoint não planejado para esta fase")
    after = deepcopy(state)
    after["checkpoint"] = {"phase_id": phase_id, "checkpoint_id": checkpoint_id}
    return _changed(rules, state, after)


def complete_phase(rules, state, phase_id, *, defeated_boss_id=None):
    validate_state(rules, state)
    require(isinstance(phase_id, str) and phase_id in rules.phase_by_id, "unknown_phase", "Fase desconhecida")
    if phase_id in state["completed_phase_ids"]:
        return deepcopy(state)  # Não duplica conclusão, conquista ou desbloqueio.
    require(phase_id == rules.phase_ids[len(state["completed_phase_ids"])] and phase_id == state["active_phase_id"], "phase_sequence", "Só a próxima fase iniciada pode ser concluída")
    require(defeated_boss_id == rules.phase_by_id[phase_id].boss_id, "boss_evidence_required", "A fase 10 exige derrota de Malagueta; fases anteriores não concedem essa condição")
    after = deepcopy(state)
    after["completed_phase_ids"].append(phase_id)
    after["active_phase_id"], after["checkpoint"] = None, None
    after["achievement_ids"], after["unlocked_character_ids"] = rules.grants(after["completed_phase_ids"])
    return _changed(rules, state, after)


def equip_character(rules, state, character_id):
    require(can_equip(rules, state, character_id), "character_locked", "Personagem bloqueado ou não equipável no lobby")
    after = deepcopy(state)
    after["equipped_character_id"] = character_id
    return _changed(rules, state, after)
