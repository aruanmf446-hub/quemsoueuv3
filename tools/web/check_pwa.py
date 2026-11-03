#!/usr/bin/env python3
"""Verifica a montagem do PWA no build Web: manifest, ícones, um único service worker
versionado, shell com links/metadados e ausência do PWA nativo do Godot (dois workers)."""
import json, os, re, sys

root = sys.argv[1] if len(sys.argv) > 1 else "build/web"
errors = []
manifest = json.load(open(os.path.join(root, "manifest.webmanifest"), encoding="utf-8"))
for key, value in {"display": "standalone", "start_url": "/quemsoueuv3/", "scope": "/quemsoueuv3/", "orientation": "landscape"}.items():
    if manifest.get(key) != value: errors.append(f"manifest.{key} != {value}")
for icon in manifest.get("icons", []):
    if not os.path.exists(os.path.join(root, icon["src"])): errors.append("ícone ausente: " + icon["src"])
if not os.path.exists(os.path.join(root, "pwa/icon-180.png")): errors.append("apple-touch-icon ausente")
sw = open(os.path.join(root, "sw.js"), encoding="utf-8").read()
if "__BUILD__" in sw: errors.append("sw.js sem versão do build")
if "__FILES__" in sw or '"index.wasm"' not in sw: errors.append("sw.js sem hashes dos arquivos")
if "supabase" in sw.lower() and "Supabase" not in sw: errors.append("sw.js referencia supabase")
workers = [f for f in os.listdir(root) if f.endswith(".service.worker.js") or f == "index.service.worker.js"]
if workers: errors.append("service worker extra do Godot: " + ", ".join(workers))
html = open(os.path.join(root, "index.html"), encoding="utf-8").read()
for needle in ['rel="manifest"', "apple-mobile-web-app-capable", 'rel="apple-touch-icon"', 'register("sw.js")', "qseNativeInput"]:
    if needle not in html: errors.append("index.html sem " + needle)
if len(re.findall(r"serviceWorker\.register", html)) != 1: errors.append("index.html deve registrar exatamente 1 service worker")
if errors:
    print("PWA_CHECK FAIL\n- " + "\n- ".join(errors)); sys.exit(1)
print("PWA_CHECK OK (manifest, ícones, sw único versionado, shell iOS)")
