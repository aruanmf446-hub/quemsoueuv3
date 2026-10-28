"""JSON estrito, contrato e checksum. SHA-256 detecta corrupção; não autentica saves."""
from copy import deepcopy
import hashlib
import hmac
import json
import math
import re
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[2]
RULES_VERSION = "desert_progression_2.0.0"
VERSION = 2


class ProgressionError(ValueError):
    def __init__(self, code, message):
        self.code = code
        super().__init__(message)


def require(condition, code, message):
    if not condition:
        raise ProgressionError(code, message)


def loads(data):
    def pairs(items):
        value = {}
        for key, item in items:
            require(key not in value, "duplicate_json_key", "Chave JSON repetida")
            value[key] = item
        return value
    def nonfinite(_):
        raise ProgressionError("invalid_json", "Número JSON não finito")
    try:
        text = data.decode("utf-8-sig") if isinstance(data, bytes) else data
        return json.loads(text, object_pairs_hook=pairs, parse_constant=nonfinite)
    except (UnicodeError, json.JSONDecodeError, RecursionError, TypeError) as error:
        raise ProgressionError("invalid_json", "JSON inválido ou truncado") from error


def canonical(value):
    def normalize(item):
        if isinstance(item, dict):
            require(all(isinstance(key, str) for key in item), "invalid_json", "Chaves JSON devem ser strings")
            return {key: normalize(value) for key, value in item.items()}
        if isinstance(item, list):
            return [normalize(value) for value in item]
        if isinstance(item, float):
            require(math.isfinite(item) and item.is_integer() and abs(item) <= 9007199254740991, "invalid_json", "Progressão não admite números fracionários/não finitos")
            return int(item)
        return item
    try:
        return json.dumps(normalize(value), ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")
    except (TypeError, ValueError, RecursionError, UnicodeError) as error:
        raise ProgressionError("invalid_json", "Objeto não serializável como JSON") from error


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def seal(value):
    body = deepcopy(value)
    body.pop("integrity", None)
    body["integrity"] = {"algorithm": "sha256", "digest": digest(body)}
    return body


def verify_integrity(value):
    require(isinstance(value, dict), "invalid_save", "Envelope deve ser objeto")
    body = deepcopy(value)
    checksum = body.pop("integrity", None)
    require(isinstance(checksum, dict) and checksum.get("algorithm") == "sha256" and isinstance(checksum.get("digest"), str), "invalid_integrity", "Checksum ausente ou desconhecido")
    require(re.fullmatch(r"[a-f0-9]{64}", checksum["digest"]) is not None, "invalid_integrity", "Formato do checksum inválido")
    require(hmac.compare_digest(checksum["digest"], digest(body)), "checksum_mismatch", "Checksum não confere; não redefinir progresso silenciosamente")


class Contracts:
    def __init__(self, root=ROOT):
        self.document = loads((Path(root) / "data/progression/contract.v2.schema.json").read_bytes())
        Draft202012Validator.check_schema(self.document)
        self.validators = {name: Draft202012Validator({"$defs": self.document["$defs"], "$ref": "#/$defs/" + name}, format_checker=FormatChecker()) for name in self.document["$defs"]}

    def validate(self, kind, value):
        errors = list(self.validators[kind].iter_errors(value))
        if errors:
            # Não imprimir conteúdo do save/credenciais no diagnóstico.
            path = "/".join(str(p) for p in errors[0].path)
            raise ProgressionError("invalid_contract", f"Contrato {kind} inválido em /{path}")
