"""Update an existing isolated iPhone staging copy and export the real Web engine.
Usage: python3 .../export_fixture.py <stage> <output> <godot>
No backend calls; tests are included only in this staging preset.
"""
from pathlib import Path
import json, shutil, subprocess, sys
root = Path(__file__).resolve().parents[2]
stage, output, godot = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
assert stage.resolve() != root and (stage / '.iphone_web_fixture_stage').exists()
for name in ['scripts','scenes','data','web','tests']:
    shutil.copytree(root / name, stage / name, dirs_exist_ok=True)
if (root/'assets/emotes').exists():
    shutil.copytree(root/'assets/emotes',stage/'assets/emotes',dirs_exist_ok=True)
project=(root/'project.godot').read_text()
import re
project=re.sub(r'run/main_scene=.*', 'run/main_scene="res://tests/iphone_deck/web_fixture.tscn"',project)
(stage/'project.godot').write_text(project)
preset=(root/'export_presets.cfg').read_text().replace('custom_features=""','custom_features="iphone_layout_fixture"',1).replace('tests/*,','')
(stage/'export_presets.cfg').write_text(preset)
output.mkdir(parents=True,exist_ok=True)
for args in [['--editor','--import','--quit'],['--script','res://tests/iphone_deck/make_fixture.gd'],['--export-release','Web',str(output/'index.html')]]:
    subprocess.run([godot,'--headless','--path',str(stage),*args],check=True)
(output/'loading').mkdir(exist_ok=True)
(output/'loading/list.json').write_text('[]')
shutil.copytree(root/'web/pwa',output/'pwa',dirs_exist_ok=True)
shutil.copy2(root/'web/pwa/manifest.webmanifest',output/'manifest.webmanifest')
subprocess.run([sys.executable,str(root/'tools/web/stamp_sw.py'),str(output),'input-fixture'],check=True)
