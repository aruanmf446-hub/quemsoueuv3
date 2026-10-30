"""Temporário: sonda os três projetos só com as chaves publicáveis do client.json.
Imprime status, nomes de rotas/tabelas e contagens. Nunca imprime chaves."""
import json, urllib.request, urllib.error
c = json.load(open("data/backend/client.json"))
targets = {"game": (c["url"], c["publishable_key"]),
           "chat": (c["connections"]["chat"]["url"], c["connections"]["chat"]["publishable_key"]),
           "catalog": (c["connections"]["catalog"]["url"], c["connections"]["catalog"]["publishable_key"])}
def get(url, key, path, method="GET", body=None, accept="application/json"):
    req = urllib.request.Request(url + path, method=method, data=json.dumps(body).encode() if body is not None else None,
        headers={"apikey": key, "Accept": accept, "Content-Type": "application/json"})
    try:
        r = urllib.request.urlopen(req, timeout=20); return r.status, r.read()
    except urllib.error.HTTPError as e: return e.code, e.read()
    except Exception as e: return "ERR", str(e).encode()
for name, (url, key) in targets.items():
    s, b = get(url, key, "/auth/v1/health"); print(name, "auth/health", s)
    s, b = get(url, key, "/auth/v1/settings"); print(name, "auth/settings", s)
    s, b = get(url, key, "/rest/v1/", accept="application/openapi+json")
    paths = []
    try:
        d = json.loads(b); paths = sorted(k for k in d.get("paths", {}) if k != "/")
        defs = d.get("definitions", {})
        for t in paths:
            if not t.startswith("/rpc/"):
                print(name, "table", t, "cols:", ",".join(defs.get(t.strip("/"), {}).get("properties", {}).keys()))
        print(name, "rpcs", [p for p in paths if p.startswith("/rpc/")])
    except Exception: print(name, "openapi", s, b[:160])
    for t in [p for p in paths if not p.startswith("/rpc/")]:
        s, b = get(url, key, "/rest/v1" + t + "?select=*&limit=50")
        try:
            rows = json.loads(b); print(name, "read", t, s, (len(rows) if isinstance(rows, list) else rows))
            if name == "catalog" and isinstance(rows, list): print(json.dumps(rows, ensure_ascii=False)[:3000])
        except Exception: print(name, "read", t, s, b[:160])
s, b = get(targets["game"][0], targets["game"][1], "/rest/v1/rpc/qse_duel_decks", "POST", {})
print("game rpc qse_duel_decks anon", s, b[:200])
