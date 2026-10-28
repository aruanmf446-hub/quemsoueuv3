"""Reconciliação de referência. Nenhum HTTP, Supabase, token ou upload neste módulo."""
from copy import deepcopy

from .codec import VERSION, RULES_VERSION, digest, require, seal
from .engine import validate_state, start_phase, record_checkpoint, equip_character, can_equip, can_use_campaign_character
from .saves import validate_save


class ClientSession:
    def __init__(self, rules, save, *, authenticated_decoder=None):
        self.rules = rules
        self._save = deepcopy(validate_save(rules, save))
        # Callback do futuro transporte autenticado; NÃO é serializado em save.
        self._decoder = authenticated_decoder
        self._trusted_snapshot = None

    def export_save(self):
        return deepcopy(self._save)

    def effective_state(self):
        if self._save["mode"] == "offline_reference":
            return deepcopy(self._save["local_state"])
        require(self._trusted_snapshot is not None, "online_confirmation_required", "Cache local não autentica desbloqueios online")
        return deepcopy(self._trusted_snapshot)

    def can_equip(self, character_id):
        return can_equip(self.rules, self.effective_state(), character_id)

    def can_use_protagonist(self, phase_id):
        return can_use_campaign_character(self.rules, self.effective_state(), phase_id, self.rules.protagonist_id)

    def _authenticate(self, payload):
        require(self._decoder is not None, "authenticated_transport_required", "Resposta exige adaptador de transporte autenticado")
        try:
            identity, document = self._decoder(payload)
        except Exception as error:
            from .codec import ProgressionError
            raise ProgressionError("unauthenticated_response", "Transporte não confirmou a resposta") from error
        require(identity == self._save["player_id"], "player_mismatch", "Resposta de outro jogador")
        return deepcopy(document)

    def _reconcile(self, snapshot):
        validate_state(self.rules, snapshot)
        require(snapshot["player_id"] == self._save["player_id"], "player_mismatch", "Estado recebido pertence a outro jogador")
        old = self._trusted_snapshot
        if old is not None:
            if snapshot["revision"] < old["revision"]:
                return "stale_ignored", deepcopy(old)
            if snapshot["revision"] == old["revision"]:
                require(digest(snapshot) == digest(old), "same_revision_conflict", "Mesma revisão com conteúdos diferentes")
                return "unchanged", deepcopy(old)
            require(set(old["completed_phase_ids"]) <= set(snapshot["completed_phase_ids"]), "remote_progress_rollback", "Rollback de progresso exige outro protocolo/versionamento")
        return "server_accepted", deepcopy(snapshot)

    def _commit(self, save, trusted):
        if save != self._save:
            save["local_revision"] += 1
            save = seal(save)
        validate_save(self.rules, save)
        self._save, self._trusted_snapshot = save, deepcopy(trusted)

    def accept_snapshot(self, payload):
        """Chamar só com bytes/resposta que o adaptador autenticado validará."""
        snapshot = self._authenticate(payload)
        resolution, trusted = self._reconcile(snapshot)
        save = deepcopy(self._save)
        save["server_cache"] = deepcopy(trusted)
        self._commit(save, trusted)
        return resolution

    def queue_operation(self, operation, request_id):
        save = deepcopy(self._save)
        snapshot = self._trusted_snapshot or save["server_cache"]
        request = {"protocol_version": VERSION, "rules_version": RULES_VERSION, "request_id": request_id,
                   "expected_revision": snapshot["revision"] if snapshot else 0, "operation": deepcopy(operation)}
        self.rules.contracts.validate("request", request)
        require(all(e["request"]["request_id"] != request_id for e in save["outbox"]), "duplicate_request", "ID de requisição já usado")
        save["outbox"].append({"request": request, "status": "pending", "last_response_code": None, "superseded_by": None})
        self._commit(save, self._trusted_snapshot)
        return deepcopy(request)

    def receive_response(self, payload):
        response = self._authenticate(payload)
        self.rules.contracts.validate("response", response)
        save = deepcopy(self._save)
        entry = next((e for e in save["outbox"] if e["request"]["request_id"] == response["request_id"]), None)
        require(entry is not None, "unknown_response", "Resposta não corresponde à fila persistida")
        resolution, trusted = self._reconcile(response["snapshot"])
        if entry["status"] != "superseded":
            terminal = entry["status"] in ("applied", "noop", "rejected")
            require(not terminal or entry["status"] == response["status"] and entry["last_response_code"] == response["code"], "response_conflict", "Resultado idempotente contraditório")
            entry["status"], entry["last_response_code"] = response["status"], response["code"]
        save["server_cache"] = deepcopy(trusted)
        self._commit(save, trusted)
        return {"resolution": resolution, "request_status": entry["status"], "requires_rebase": entry["status"] == "conflict"}

    def rebase_request(self, old_request_id, new_request_id):
        """Rebase explícito: conserva o original e usa outro ID; não reescreve retries."""
        require(self._trusted_snapshot is not None, "online_confirmation_required", "Obtenha estado autenticado antes de resolver conflito")
        save = deepcopy(self._save)
        entry = next((e for e in save["outbox"] if e["request"]["request_id"] == old_request_id), None)
        require(entry is not None and entry["status"] == "conflict", "request_not_rebasable", "Somente conflito pode ser rebaseado")
        require(all(e["request"]["request_id"] != new_request_id for e in save["outbox"]), "duplicate_request", "Novo ID precisa ser inédito")
        operation = entry["request"]["operation"]
        state = self._trusted_snapshot
        if operation["type"] == "start_phase":
            start_phase(self.rules, state, operation["phase_id"])
        elif operation["type"] == "record_checkpoint":
            record_checkpoint(self.rules, state, operation["phase_id"], operation["checkpoint_id"])
        elif operation["type"] == "equip_character":
            equip_character(self.rules, state, operation["character_id"])
        else:
            phase_id = operation["phase_id"]
            require(phase_id in state["completed_phase_ids"] or phase_id == self.rules.phase_ids[len(state["completed_phase_ids"])] and phase_id == state["active_phase_id"], "phase_sequence", "Conclusão pendente não pode ser rebaseada nesta fase")
        request = deepcopy(entry["request"])
        request["request_id"], request["expected_revision"] = new_request_id, state["revision"]
        self.rules.contracts.validate("request", request)
        entry["status"], entry["superseded_by"] = "superseded", new_request_id
        save["outbox"].append({"request": request, "status": "pending", "last_response_code": None, "superseded_by": None})
        self._commit(save, state)
        return deepcopy(request)
