"""Servidor de referência em memória, sem rede. Não é um serviço implantado.

Somente o adaptador servidor pode fornecer identidade autenticada e CompletionVerifier.
Nenhum campo do comando do cliente declara confiança ou concede recompensas.
"""
from copy import deepcopy
from dataclasses import dataclass
from threading import RLock

from .codec import VERSION, RULES_VERSION, ProgressionError, digest, require, seal, verify_integrity
from .engine import new_state, validate_state, start_phase, record_checkpoint, complete_phase, equip_character


@dataclass(frozen=True)
class VerifiedCompletion:
    player_id: str
    phase_id: str
    attempt_id: str
    evidence_id: str
    defeated_boss_id: str | None = None
    exit_reached: bool = False


class ServerReference:
    def __init__(self, rules, player_id, *, completion_verifier=None):
        self.rules = rules
        self.player_id = player_id
        self._state = new_state(rules, player_id)
        self._journal = {}
        self._evidence = []
        self._verifier = completion_verifier
        self._lock = RLock()

    def snapshot(self):
        with self._lock:
            return deepcopy(self._state)

    def _response(self, request, status, code=None, *, snapshot=None):
        result = {"protocol_version": VERSION, "rules_version": RULES_VERSION,
                  "request_id": request["request_id"], "status": status, "code": code,
                  "snapshot": deepcopy(self._state if snapshot is None else snapshot)}
        self.rules.contracts.validate("response", result)
        return result

    def handle(self, authenticated_player_id, request):
        # Falha antes de devolver qualquer snapshot de outro dono.
        require(authenticated_player_id == self.player_id, "player_mismatch", "Identidade autenticada não corresponde ao jogador")
        request = deepcopy(request)
        self.rules.contracts.validate("request", request)
        with self._lock:
            request_id, request_digest = request["request_id"], digest(request)
            previous = self._journal.get(request_id)
            if previous:
                if previous["request_digest"] != request_digest:
                    return self._response(request, "rejected", "idempotency_conflict")
                return deepcopy(previous["response"])
            if request["expected_revision"] != self._state["revision"]:
                result = self._response(request, "conflict", "revision_conflict")
            else:
                try:
                    operation = request["operation"]
                    kind = operation["type"]
                    evidence = None
                    if kind == "start_phase":
                        next_state = start_phase(self.rules, self._state, operation["phase_id"])
                    elif kind == "record_checkpoint":
                        next_state = record_checkpoint(self.rules, self._state, operation["phase_id"], operation["checkpoint_id"])
                    elif kind == "equip_character":
                        next_state = equip_character(self.rules, self._state, operation["character_id"])
                    else:
                        phase_id = operation["phase_id"]
                        if phase_id in self._state["completed_phase_ids"]:
                            next_state = deepcopy(self._state)
                        else:
                            require(phase_id == self.rules.phase_ids[len(self._state["completed_phase_ids"])] and phase_id == self._state["active_phase_id"], "phase_sequence", "Conclusão fora de ordem ou sem início")
                            require(self._verifier is not None, "verification_required", "Verificador servidor não configurado; negar conclusão")
                            try:
                                proof = self._verifier(deepcopy(request), deepcopy(self._state))
                            except Exception as error:
                                raise ProgressionError("verification_failed", "Verificação externa indisponível ou rejeitada") from error
                            require(isinstance(proof, VerifiedCompletion), "verification_required", "Resposta não verificada")
                            require(proof.exit_reached is True, "exit_evidence_required", "Evidência não confirma a saída/conclusão da fase")
                            require((proof.player_id, proof.phase_id, proof.attempt_id, proof.evidence_id) == (self.player_id, phase_id, operation["attempt_id"], operation["evidence_id"]), "proof_mismatch", "Evidência pertence a outro jogador/fase/tentativa")
                            require(all(e["evidence_id"] != proof.evidence_id and e["attempt_id"] != proof.attempt_id for e in self._evidence), "evidence_reused", "Evidência/tentativa já consumida")
                            next_state = complete_phase(self.rules, self._state, phase_id, defeated_boss_id=proof.defeated_boss_id)
                            evidence = {"phase_id": phase_id, "attempt_id": proof.attempt_id,
                                        "evidence_id": proof.evidence_id, "request_id": request_id}
                    validate_state(self.rules, next_state)
                    changed = next_state != self._state
                    result = self._response(request, "applied" if changed else "noop", snapshot=next_state)
                    # Mudança de estado e concessões são uma única transição sob o lock.
                    self._state = next_state
                    if evidence:
                        self._evidence.append(evidence)
                except ProgressionError as error:
                    result = self._response(request, "rejected", error.code)
            self._journal[request_id] = {"request": deepcopy(request), "request_digest": request_digest, "response": deepcopy(result)}
            return deepcopy(result)

    def export_store(self):
        """Só para armazenamento controlado pelo servidor/adaptador, nunca endpoint cliente."""
        with self._lock:
            value = {"schema_version": VERSION, "kind": "server_reference_store", "rules_version": RULES_VERSION,
                     "player_id": self.player_id, "state": deepcopy(self._state),
                     "journal": deepcopy(list(self._journal.values())), "evidence_ledger": deepcopy(self._evidence)}
            result = seal(value)
            self.rules.contracts.validate("server_store", result)
            return result

    @classmethod
    def from_store(cls, rules, value, *, completion_verifier=None):
        verify_integrity(value)
        rules.contracts.validate("server_store", value)
        validate_state(rules, value["state"])
        require(value["state"]["player_id"] == value["player_id"], "player_mismatch", "Armazenamento pertence a outro jogador")
        ids = [j["request"]["request_id"] for j in value["journal"]]
        require(len(ids) == len(set(ids)), "duplicate_request", "Journal duplicado")
        journal = {}
        for entry in value["journal"]:
            validate_state(rules, entry["response"]["snapshot"])
            require(entry["request_digest"] == digest(entry["request"]) and entry["request"]["request_id"] == entry["response"]["request_id"], "corrupt_journal", "Journal inconsistente")
            snapshot = entry["response"]["snapshot"]
            require(snapshot["player_id"] == value["player_id"] and snapshot["revision"] <= value["state"]["revision"], "corrupt_journal", "Snapshot incompatível com armazenamento")
            journal[entry["request"]["request_id"]] = deepcopy(entry)
        ledger = value["evidence_ledger"]
        require([e["phase_id"] for e in ledger] == value["state"]["completed_phase_ids"], "corrupt_evidence_ledger", "Conclusão sem evidência registrada")
        for key in ("attempt_id", "evidence_id", "request_id"):
            require(len({e[key] for e in ledger}) == len(ledger), "evidence_reused", "Evidências repetidas no armazenamento")
        for evidence in ledger:
            entry = journal.get(evidence["request_id"])
            require(entry is not None and entry["response"]["status"] == "applied", "corrupt_evidence_ledger", "Evidência sem transação aplicada")
            operation = entry["request"]["operation"]
            require(operation["type"] == "complete_phase" and all(operation[k] == evidence[k] for k in ("phase_id", "attempt_id", "evidence_id")), "corrupt_evidence_ledger", "Evidência não corresponde ao comando")
        result = cls(rules, value["player_id"], completion_verifier=completion_verifier)
        result._state, result._journal, result._evidence = deepcopy(value["state"]), journal, deepcopy(ledger)
        return result
