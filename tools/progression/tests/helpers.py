"""Dublês somente de teste; não representam autenticação ou prova de gameplay real."""
from copy import deepcopy
from functools import lru_cache
from uuid import UUID

from tools.progression import Rules
from tools.progression.codec import canonical, VERSION, RULES_VERSION

PLAYER = "00000000-0000-4000-8000-000000000001"
OTHER = "00000000-0000-4000-8000-000000000002"


def uid(number):
    return str(UUID(int=number, version=4))


@lru_cache(maxsize=1)
def rules():
    return Rules()


def request(server, number, operation, *, revision=None):
    return {"protocol_version": VERSION, "rules_version": RULES_VERSION, "request_id": uid(number),
            "expected_revision": server.snapshot()["revision"] if revision is None else revision, "operation": operation}


def verified_fixture(request, state):
    """SIMULA verificação já feita pelo servidor; nunca é default da implementação."""
    from tools.progression.server_reference import VerifiedCompletion
    op = request["operation"]
    return VerifiedCompletion(state["player_id"], op["phase_id"], op["attempt_id"], op["evidence_id"],
                              "malagueta" if op["phase_id"] == "desert_phase_10" else None, True)


class FixtureChannel:
    """Aceita apenas documentos previamente publicados pelo teste, sem rede/chaves."""
    def __init__(self):
        self.responses = {}

    def publish(self, document, identity=PLAYER):
        body = canonical(document)
        self.responses[body] = (identity, deepcopy(document))
        return body

    def decode(self, body):
        return deepcopy(self.responses[body])
