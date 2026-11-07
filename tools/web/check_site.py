#!/usr/bin/env python3
"""Verifica a página inicial (web/site ou a raiz do build): SEO, caminhos relativos e
que ela NÃO carrega o motor do jogo. Uso: check_site.py <pasta>"""
import os, re, sys
root = sys.argv[1] if len(sys.argv) > 1 else "web/site"
html = open(os.path.join(root, "index.html"), encoding="utf-8").read()
errors = []
need = ['<html lang="pt-BR"', '<link rel="canonical" href="https://quemsoueu.cards/">', 'name="description"',
        'property="og:image"', 'name="twitter:card"', '"@type":"VideoGame"', 'href="jogar/"', 'name="viewport"']
for n in need:
    if n not in html: errors.append("index.html sem " + n)
if len(re.findall(r"<h1\b", html)) != 1: errors.append("deve haver exatamente um <h1>")
for bad in ["index.js", "index.wasm", "index.pck", "serviceWorker", "Engine(", "manifest.webmanifest"]:
    if bad in html: errors.append("a página inicial não pode carregar o jogo: " + bad)
for ref in re.findall(r'(?:src|href|srcset)="([^"#]+)"', html):
    if ref.startswith(("http", "mailto:", "data:")): continue
    if ref.startswith("/"): errors.append("caminho absoluto quebra no GitHub Pages: " + ref)
    elif ref not in ("./", "jogar/") and not os.path.exists(os.path.join(root, ref)): errors.append("arquivo ausente: " + ref)
for f in ["robots.txt", "sitemap.xml", "site.css", "img/og.jpg"]:
    if not os.path.exists(os.path.join(root, f)): errors.append("ausente: " + f)
if os.path.exists(os.path.join(root, "jogar", "index.html")):
    if not os.path.exists(os.path.join(root, "jogar", "index.wasm")): errors.append("jogar/ sem o motor")
if errors: print("SITE_CHECK FAIL\n- " + "\n- ".join(errors)); sys.exit(1)
print("SITE_CHECK OK (SEO, caminhos relativos, página inicial sem motor)")
