"""Temporário: descobre tabelas públicas do CATALOG por nomes candidatos (só leitura)."""
import json, urllib.request, urllib.error
c = json.load(open("data/backend/client.json"))
url, key = c["connections"]["catalog"]["url"], c["connections"]["catalog"]["publishable_key"]
names = ["characters","character","catalog_characters","skins","catalog_skins","decks","deck","catalog_decks","duel_decks",
 "cards","card","catalog_cards","deck_cards","duel_cards","personagens","cartas","items","catalog_items","catalog"]
for schema in ["public","catalog","qse_catalog","qse_v3"]:
    for n in names:
        req = urllib.request.Request(f"{url}/rest/v1/{n}?select=*&limit=20", headers={"apikey": key, "Accept-Profile": schema})
        try:
            r = urllib.request.urlopen(req, timeout=20); rows = json.loads(r.read())
            print("FOUND", schema, n, len(rows)); print(json.dumps(rows, ensure_ascii=False)[:2500])
        except urllib.error.HTTPError as e:
            body = e.read()[:120]
            if e.code != 404 and b"PGRST205" not in body and b"PGRST106" not in body: print(schema, n, e.code, body)
        except Exception as e: print(schema, n, "ERR", e)
print("done")
