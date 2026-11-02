#!/usr/bin/env python3
"""Teste ponta a ponta da Comunidade (T24) contra o GAME real, com 3 contas de TESTE.

Etapas (workflow_dispatch, uma por vez; entre elas o administrador age por SQL):
  publish   – conta OWNER cria deck [E2E] (5 cartas + capa) e pede publicação.
  community – depois da aprovação: READER lê vitrine/prévias, original bloqueado;
              READER e R1 denunciam; OWNER não pode; denúncia repetida recusada.
  finish    – depois da 3ª denúncia (SQL): confere volta à revisão, despublica e apaga tudo.

Credenciais só por variáveis de ambiente (GitHub Secrets). Nada sensível é impresso.
"""
import json, os, struct, sys, uuid, zlib, urllib.request, urllib.error

CLIENT = json.load(open(os.path.join(os.path.dirname(__file__), "..", "..", "data", "backend", "client.json")))
URL = CLIENT["url"].rstrip("/")
KEY = CLIENT["publishable_key"]
BUCKET = "qse-deck-originals"
RESULTS = []


def log(ok, text):
    RESULTS.append((ok, text))
    print(("PASS " if ok else "FAIL ") + text, flush=True)


def call(method, path, token=None, body=None, raw=None, ctype="application/json", extra=None):
    headers = {"apikey": KEY, "Authorization": "Bearer " + (token or KEY)}
    data = None
    if raw is not None:
        data, headers["Content-Type"] = raw, ctype
    elif body is not None:
        data, headers["Content-Type"] = json.dumps(body).encode(), "application/json"
    headers.update(extra or {})
    req = urllib.request.Request(URL + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            payload = r.read()
            return r.status, (json.loads(payload) if payload and "json" in r.headers.get("Content-Type", "") else payload)
    except urllib.error.HTTPError as e:
        payload = e.read()
        try: payload = json.loads(payload)
        except Exception: pass
        return e.code, payload


def login(role):
    email, password = os.environ.get(f"QSE_TEST_{role}_EMAIL", ""), os.environ.get(f"QSE_TEST_{role}_PASSWORD", "")
    if not email or not password: sys.exit(f"secret ausente: QSE_TEST_{role}_*")
    status, data = call("POST", "/auth/v1/token?grant_type=password", body={"email": email, "password": password})
    if status != 200: sys.exit(f"login {role} falhou: HTTP {status} {data.get('error_code', '') if isinstance(data, dict) else ''}")
    return data["access_token"], data["user"]["id"]


def rpc(token, name, params):
    return call("POST", f"/rest/v1/rpc/{name}", token, params)


def png(width, height, rgb):
    row = b"\x00" + bytes(rgb) * width
    raw = zlib.compress(row * height)
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")


def upload(token, path, data):
    return call("POST", f"/storage/v1/object/{BUCKET}/{path}", token, raw=data, ctype="image/png", extra={"x-upsert": "true"})


def summary(text):
    target = os.environ.get("GITHUB_STEP_SUMMARY")
    if target:
        with open(target, "a") as f: f.write(text + "\n")
    print(text)


def stage_publish():
    token, uid = login("OWNER")
    deck = str(uuid.uuid4())
    status, data = call("POST", "/rest/v1/qse_creator_decks", token, [{"id": deck, "owner_id": uid, "name": "[E2E] Comunidade",
        "description": "Deck de teste automático (será apagado).", "category": "Outros", "requested_visibility": "public"}], extra={"Prefer": "return=minimal"})
    log(status in (200, 201, 204), f"deck criado ({status})")
    cards, paths = [], []
    for i in range(5):
        card = str(uuid.uuid4())
        color = [(40 + i * 40) % 255, 90, 160]
        for suffix, size in (("original.png", (120, 168)), ("library.png", (100, 140)), ("duel.png", (160, 50))):
            path = f"{uid}/{deck}/{card}_{suffix}"
            st, _ = upload(token, path, png(*size, color))
            paths.append(path)
            log(st in (200, 201), f"upload carta {i + 1} {suffix} ({st})")
        cards.append({"id": card, "deck_id": deck, "position": i, "name": f"E2E Carta {i + 1}", "description": "",
            "portrait_center_x": 0.5, "portrait_center_y": 0.5, "portrait_zoom": 0.6 if i == 0 else 1.0,
            "duel_center_x": 0.5, "duel_center_y": 0.5, "duel_zoom": 1.0, "image_original_path": f"{uid}/{deck}/{card}_original.png"})
    st, data = call("POST", "/rest/v1/qse_creator_cards?on_conflict=id", token, cards, extra={"Prefer": "resolution=merge-duplicates,return=minimal"})
    log(st in (200, 201, 204), f"5 cartas gravadas, uma com zoom 0.6 ({st} {data if st >= 300 else ''})")
    cover = f"{uid}/{deck}/deck_cover.png"
    st, _ = upload(token, cover, png(160, 100, [200, 150, 60]))
    log(st in (200, 201), f"capa enviada ({st})")
    st, data = call("PATCH", f"/rest/v1/qse_creator_decks?id=eq.{deck}", token, {"cover_mode": "upload", "cover_image_path": cover}, extra={"Prefer": "return=minimal"})
    log(st in (200, 204), f"capa registrada no deck ({st} {data if st >= 300 else ''})")
    st, data = rpc(token, "qse_deck_publish_request", {"p_deck": deck})
    log(st == 200 and isinstance(data, dict) and data.get("status") == "pending_review", f"pedido de publicação → {data}")
    summary(f"\n**DECK_ID:** `{deck}`\n\nSQL para o administrador aprovar:\n```sql\nupdate public.qse_creator_decks set status='published', review_note=null where id='{deck}' and status='pending_review';\n```")


def stage_community(deck):
    reader, reader_id = login("READER")
    r1, _ = login("R1")
    owner, _ = login("OWNER")
    st, data = rpc(reader, "qse_community_decks", {"p_query": "[E2E]", "p_theme": None, "p_sort": "recent", "p_limit": 24, "p_cursor": None})
    item = next((i for i in (data.get("items", []) if isinstance(data, dict) else []) if i.get("id") == deck), None)
    log(item is not None, "deck aparece na vitrine para outra conta")
    if item:
        log(str(item.get("cover_path", "")).endswith("deck_cover.png"), f"cover_path da capa enviada → {item.get('cover_path')}")
        log("owner_id" not in item and set(item.get("creator", {}).keys()) <= {"public_id", "nickname", "equipped_character_id", "level"}, "só perfil público do criador")
    st, data = rpc(reader, "qse_community_deck", {"p_deck": deck})
    cards = data.get("cards", []) if isinstance(data, dict) else []
    log(len(cards) == 5 and all("image_original_path" not in c for c in cards), f"detalhe com 5 cartas e sem original ({len(cards)})")
    if cards:
        prev = cards[0].get("preview_library_path", "")
        st, _ = call("GET", f"/storage/v1/object/authenticated/{BUCKET}/{prev}", reader)
        log(st == 200, f"prévia legível por outra conta ({st})")
        original = prev.replace("_library.png", "_original.png")
        st, _ = call("GET", f"/storage/v1/object/authenticated/{BUCKET}/{original}", reader)
        log(st >= 400, f"original bloqueado para outra conta ({st})")
        log(abs(float(cards[0].get("crops", {}).get("library", {}).get("zoom", 1)) - 0.6) < 0.01 or any(abs(float(c.get("crops", {}).get("library", {}).get("zoom", 1)) - 0.6) < 0.01 for c in cards), "zoom reduzido preservado")
    st, data = rpc(reader, "qse_deck_report", {"p_deck": deck, "p_reason": "Teste automático E2E"})
    log(isinstance(data, dict) and data.get("report_count") == 1, f"1ª denúncia (READER) → {data}")
    st, data = rpc(r1, "qse_deck_report", {"p_deck": deck, "p_reason": "Teste automático E2E"})
    log(isinstance(data, dict) and data.get("report_count") == 2 and data.get("status") == "published", f"2ª denúncia (R1) → {data}")
    st, data = rpc(owner, "qse_deck_report", {"p_deck": deck, "p_reason": "Teste"})
    log(isinstance(data, dict) and data.get("error") == "cannot_report_own", f"dono não denuncia o próprio → {data}")
    st, data = rpc(reader, "qse_deck_report", {"p_deck": deck, "p_reason": "De novo"})
    log(isinstance(data, dict) and data.get("error") == "already_reported", f"denúncia repetida recusada → {data}")
    summary(f"\nSQL para o administrador registrar a 3ª denúncia (deve devolver o deck para revisão):\n```sql\n-- usar a função/tabela de denúncias do GAME com um usuário distinto do dono, do READER ({reader_id}) e do R1\n```")


def stage_finish(deck):
    owner, uid = login("OWNER")
    reader, _ = login("READER")
    st, data = call("GET", f"/rest/v1/qse_creator_decks?id=eq.{deck}&select=status", owner)
    status = data[0]["status"] if isinstance(data, list) and data else None
    log(status == "pending_review", f"após a 3ª denúncia o deck voltou para revisão ({status})")
    st, data = rpc(reader, "qse_community_deck", {"p_deck": deck})
    log(isinstance(data, dict) and data.get("error") == "deck_not_found", f"saiu da vitrine → {data}")
    st, data = rpc(owner, "qse_deck_unpublish", {"p_deck": deck})
    log(isinstance(data, dict) and data.get("status") == "draft", f"despublicar → {data}")
    st, cards = call("GET", f"/rest/v1/qse_creator_cards?deck_id=eq.{deck}&select=id", owner)
    prefixes = [f"{uid}/{deck}/deck_cover.png"]
    for card in cards if isinstance(cards, list) else []:
        prefixes += [f"{uid}/{deck}/{card['id']}_{s}" for s in ("original.png", "library.png", "duel.png")]
    st1, _ = call("DELETE", f"/storage/v1/object/{BUCKET}", owner, {"prefixes": prefixes})
    st2, _ = call("DELETE", f"/rest/v1/qse_creator_cards?deck_id=eq.{deck}", owner)
    st3, _ = call("DELETE", f"/rest/v1/qse_creator_decks?id=eq.{deck}", owner)
    log(st1 in (200, 204) and st2 in (200, 204) and st3 in (200, 204), f"limpeza: arquivos {st1}, cartas {st2}, deck {st3}")


if __name__ == "__main__":
    stage = sys.argv[1]
    deck = sys.argv[2] if len(sys.argv) > 2 else ""
    {"publish": lambda: stage_publish(), "community": lambda: stage_community(deck), "finish": lambda: stage_finish(deck)}[stage]()
    failed = [t for ok, t in RESULTS if not ok]
    summary(f"\n**{stage}: {len(RESULTS) - len(failed)}/{len(RESULTS)} PASS**" + ("".join(f"\n- FAIL {t}" for t in failed)))
    sys.exit(1 if failed else 0)
