#!/usr/bin/env python3
"""Real GAME/LiveKit voice authorization E2E with three pre-existing test users.

Never print bearer tokens, passwords, email addresses, room invite codes, or JWTs.
Test rooms are short-lived; every membership is removed in finally.
"""
import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
CONFIG = json.loads((ROOT / "data/backend/client.json").read_text())
BASE = CONFIG["url"].rstrip("/")
KEY = CONFIG["publishable_key"]
FUNCTION = "/functions/v1/qse-voice-token"
CHECKS = 0


def check(value, label):
    global CHECKS
    CHECKS += 1
    print(("PASS " if value else "FAIL ") + label, flush=True)
    if not value:
        raise AssertionError(label)


def http(method, path, token=None, body=None):
    """Only bounded HTTP statuses and parsed JSON are returned; never print secrets."""
    headers = {"apikey": KEY, "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(
        BASE + path,
        method=method,
        headers=headers,
        data=json.dumps(body).encode("utf-8") if body is not None else None,
    )
    try:
        with urllib.request.urlopen(req, timeout=35) as response:
            data = response.read(262144)
            return response.status, json.loads(data) if data else {}
    except urllib.error.HTTPError as error:
        data = error.read(262144)
        try:
            payload = json.loads(data)
        except (ValueError, UnicodeError):
            payload = {}
        return error.code, payload


def authenticate(role):
    email = os.environ.get("QSE_TEST_" + role + "_EMAIL", "")
    password = os.environ.get("QSE_TEST_" + role + "_PASSWORD", "")
    if not email or not password:
        raise AssertionError("GitHub Secrets de teste ausentes para " + role)
    status, payload = http("POST", "/auth/v1/token?grant_type=password", body={
        "email": email, "password": password,
    })
    check(status == 200 and bool(payload.get("access_token")), "login GAME " + role)
    return payload["access_token"]


def rpc(token, name, args):
    return http("POST", "/rest/v1/rpc/" + name, token, args)


def access(token, room_id, action="token"):
    return http("POST", FUNCTION, token, {"room_id": room_id, "action": action})


def decode_claims(token):
    parts = token.split(".")
    if len(parts) != 3:
        raise AssertionError("LiveKit JWT invalido")
    payload = parts[1] + "=" * ((4 - len(parts[1]) % 4) % 4)
    return json.loads(base64.urlsafe_b64decode(payload))


def expect_token(status, payload, label, room_name=None):
    check(status == 200 and isinstance(payload, dict) and
          isinstance(payload.get("participant_token"), str) and
          isinstance(payload.get("server_url"), str) and
          isinstance(payload.get("room"), str), label)
    claims = decode_claims(payload["participant_token"])
    permissions = claims.get("video", {})
    check(
        permissions.get("roomJoin") is True and
        permissions.get("roomAdmin") is not True and
        permissions.get("canPublish") is True and
        permissions.get("canSubscribe") is True and
        permissions.get("canPublishData") is False and
        permissions.get("canPublishSources") == ["microphone"],
        label + ": apenas microfone",
    )
    check(claims.get("video", {}).get("room") == payload["room"], label + ": sala assinada")
    if room_name:
        check(payload["room"] == room_name, label + ": mesma sala")
    check(payload["server_url"].startswith("wss://"), label + ": conexao segura")
    return claims


def safe_leave(token, room_id):
    try:
        rpc(token, "qse_duel_leave", {"p_room": room_id})
    except Exception:
        print("WARN limpeza da sala indisponivel (verificar sala de teste)", flush=True)


def main():
    owner = reader = r1 = None
    owner_room = r1_room = None
    try:
        owner = authenticate("OWNER")
        reader = authenticate("READER")
        r1 = authenticate("R1")

        # The endpoint must reject access before it ever looks up room membership.
        st, _ = http("POST", FUNCTION, body={
            "room_id": "00000000-0000-4000-8000-000000000032",
            "action": "token",
        })
        check(st == 401, "sem Authorization: 401")

        st, decks = rpc(owner, "qse_duel_decks", {})
        check(st == 200 and isinstance(decks, dict) and
              isinstance(decks.get("defaults"), dict), "configuracao do Mata-Mata")
        settings = decks["defaults"]

        st, created = rpc(owner, "qse_duel_create", {
            "p_name": "T32 Teste Voz Temporario",
            "p_public": False,
            "p_settings": settings,
        })
        check(st == 200 and isinstance(created, dict) and
              isinstance(created.get("room"), dict) and
              isinstance(created["room"].get("id"), str) and
              isinstance(created["room"].get("code"), str),
              "criar sala privada temporaria")
        owner_room = created["room"]["id"]
        invite_code = created["room"]["code"]

        st, _ = access(reader, owner_room)
        check(st == 403, "READER fora da sala nao recebe token")
        st, _ = access(r1, owner_room)
        check(st == 403, "R1 fora da sala nao recebe token")

        st, owner_voice = access(owner, owner_room)
        owner_claims = expect_token(st, owner_voice, "OWNER autorizado")

        st, joined = rpc(reader, "qse_duel_join", {"p_code": invite_code})
        check(st == 200 and isinstance(joined, dict) and
              joined.get("room", {}).get("id") == owner_room,
              "READER entrou na mesma sala")

        st, reader_voice = access(reader, owner_room)
        reader_claims = expect_token(st, reader_voice, "READER autorizado", owner_voice["room"])
        check(owner_claims.get("sub") != reader_claims.get("sub"),
              "identidades de voz isoladas por usuario")

        st, roster = access(owner, owner_room, "sync")
        check(st == 200 and roster.get("ok") is True and
              isinstance(roster.get("participants"), list) and
              len(roster["participants"]) >= 2,
              "sincronizacao autoriza apenas membros")

        st, separate = rpc(r1, "qse_duel_create", {
            "p_name": "T32 Outra Sala Temporaria",
            "p_public": False,
            "p_settings": settings,
        })
        check(st == 200 and isinstance(separate, dict) and
              isinstance(separate.get("room"), dict) and
              isinstance(separate["room"].get("id"), str),
              "R1 cria segunda sala privada")
        r1_room = separate["room"]["id"]

        st, r1_voice = access(r1, r1_room)
        r1_claims = expect_token(st, r1_voice, "R1 autorizado na segunda sala")
        check(r1_voice["room"] != owner_voice["room"] and
              r1_claims.get("sub") != owner_claims.get("sub"),
              "salas LiveKit e identidades diferentes")
        st, _ = access(owner, r1_room)
        check(st == 403, "OWNER nao acessa segunda sala")
        st, _ = access(r1, owner_room)
        check(st == 403, "R1 nao acessa primeira sala")

        # Actual LiveKit WebRTC in Chrome with fake mic. No audio is recorded.
        if os.environ.get("QSE_RUN_VOICE_BROWSER", "") == "1":
            env = os.environ.copy()
            env.update({
                "QSE_VOICE_URL": owner_voice["server_url"],
                "QSE_VOICE_OWNER_TOKEN": owner_voice["participant_token"],
                "QSE_VOICE_READER_TOKEN": reader_voice["participant_token"],
            })
            browser = subprocess.run(
                ["node", str(ROOT / "tools/e2e/voice_browser_e2e.cjs")],
                env=env, cwd=str(ROOT), timeout=85,
                capture_output=True, text=True,
            )
            # Browser logs are deliberately limited to fixed PASS/FAIL labels.
            for line in (browser.stdout + "\n" + browser.stderr).splitlines():
                if line.startswith("PASS ") or line.startswith("FAIL "):
                    print(line, flush=True)
            check(browser.returncode == 0, "LiveKit WebRTC navegador com 2 contas")

        st, _ = access(reader, owner_room, "disconnect")
        check(st == 200, "READER solicita saida da voz")
        st, _ = access(owner, owner_room, "disconnect")
        check(st == 200, "OWNER solicita saida da voz")

        # Verify revocation after a participant leaves the GAME room.
        st, _ = rpc(reader, "qse_duel_leave", {"p_room": owner_room})
        check(st == 200, "READER saiu da sala GAME")
        st, _ = access(reader, owner_room)
        check(st == 403, "READER saiu: novo token bloqueado")

        print("PASS voz E2E concluido, checks=%d" % CHECKS, flush=True)
    finally:
        if reader and owner_room:
            safe_leave(reader, owner_room)
        if owner and owner_room:
            safe_leave(owner, owner_room)
        if r1 and r1_room:
            safe_leave(r1, r1_room)
        print("INFO limpeza de salas de teste solicitada", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, TimeoutError) as error:
        # Error text contains only authored test labels, never external payloads.
        print("FAIL " + str(error), flush=True)
        sys.exit(1)
    except Exception:
        print("FAIL erro de rede ou resposta inesperada no E2E (detalhes privados omitidos)", flush=True)
        sys.exit(1)
