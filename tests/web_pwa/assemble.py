#!/usr/bin/env python3
"""Monta um build Web de TESTE (sem motor): shell real com placeholders do Godot substituídos,
arquivos do jogo falsos e os arquivos do PWA como no deploy. Uso: assemble.py <pasta> <build>"""
import os, shutil, sys
out, build = sys.argv[1], sys.argv[2]
os.makedirs(os.path.join(out, "pwa"), exist_ok=True)
shell = open("web/shell.html", encoding="utf-8").read()
for key, value in {"$GODOT_PROJECT_NAME": "Quem Sou Eu", "$GODOT_HEAD_INCLUDE": "", "$GODOT_URL": "index.js",
                   "$GODOT_CONFIG": '{"executable":"index"}', "$GODOT_THREADS_ENABLED": "false"}.items():
    shell = shell.replace(key, value)
open(os.path.join(out, "index.html"), "w", encoding="utf-8").write(shell)
# Motor falso: só o suficiente para o shell não quebrar.
open(os.path.join(out, "index.js"), "w").write("window.Engine=function(){};Engine.getMissingFeatures=function(){return ['motor de teste']};Engine.prototype.startGame=function(){return new Promise(function(){})};")
for name, size in (("index.wasm", 4096), ("index.pck", 8192)):
    open(os.path.join(out, name), "wb").write(os.urandom(size))
for name in os.listdir("web/pwa"):
    if name.startswith("icon-"): shutil.copy(os.path.join("web/pwa", name), os.path.join(out, "pwa", name))
shutil.copy("web/pwa/manifest.webmanifest", os.path.join(out, "manifest.webmanifest"))
open(os.path.join(out, "sw.js"), "w").write(open("web/pwa/sw.js").read().replace("__BUILD__", build))
print("montado", out, build)
