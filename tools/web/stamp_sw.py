#!/usr/bin/env python3
"""Gera build/web/sw.js a partir de web/pwa/sw.js com a versão do build e o hash de cada arquivo.

Uso: python3 tools/web/stamp_sw.py <pasta_web> <build>
O cache do service worker é guardado por conteúdo: um arquivo que não mudou entre versões
(ex.: index.wasm, o motor) não é baixado de novo.
"""
import hashlib, json, os, sys, shutil

CORE = ["pwa/update.js","index.html", "index.js", "index.wasm", "index.pck", "index.audio.worklet.js",
        "index.audio.position.worklet.js", "voice/bridge.js", "manifest.webmanifest", "pwa/icon-180.png",
        "pwa/icon-192.png", "pwa/icon-512.png"]

out, build = sys.argv[1], sys.argv[2]
os.makedirs(os.path.join(out, "pwa"), exist_ok=True)
shutil.copyfile(os.path.join(os.path.dirname(__file__), "../../web/pwa/update.js"), os.path.join(out, "pwa/update.js"))
# Tiny network-only marker, deliberately excluded from the worker cache.
with open(os.path.join(out, "version.json"), "w", encoding="utf-8") as version:
    json.dump({"schema": 1, "build": build}, version)
# Versão da página (mostrada no diagnóstico): gravada ANTES de calcular os hashes.
page = os.path.join(out, "index.html")
if os.path.isfile(page):
    html = open(page, encoding="utf-8").read()
    open(page, "w", encoding="utf-8").write(html.replace("__PAGE_BUILD__", build))
files = {}
for path in CORE:
    full = os.path.join(out, path)
    if os.path.isfile(full):
        files[path] = hashlib.sha256(open(full, "rb").read()).hexdigest()[:16]
src = open(os.path.join(os.path.dirname(__file__), "..", "..", "web", "pwa", "sw.js")).read()
src = src.replace("__BUILD__", build).replace('"__FILES__"', json.dumps(files, sort_keys=True))
open(os.path.join(out, "sw.js"), "w").write(src)
print("sw.js:", build, ", ".join(f"{k}={v}" for k, v in files.items()))
