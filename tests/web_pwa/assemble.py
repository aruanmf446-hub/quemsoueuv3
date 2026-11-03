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
# Motor (wasm) igual entre versões, como no jogo real; o pacote (pck) muda a cada versão.
open(os.path.join(out, "index.wasm"), "wb").write(bytes(range(256)) * 16)
open(os.path.join(out, "index.pck"), "wb").write(os.urandom(8192))
for name in os.listdir("web/pwa"):
    if name.startswith("icon-"): shutil.copy(os.path.join("web/pwa", name), os.path.join(out, "pwa", name))
shutil.copy("web/pwa/manifest.webmanifest", os.path.join(out, "manifest.webmanifest"))
import subprocess
subprocess.run([sys.executable, "tools/web/stamp_sw.py", out, build], check=True, stdout=subprocess.DEVNULL)
print("montado", out, build)
