from pathlib import Path
import shutil,subprocess,sys,re
repo=Path(__file__).resolve().parents[2]
stage,out,godot=Path(sys.argv[1]),Path(sys.argv[2]),sys.argv[3]
assert stage.resolve()!=repo and (stage/'.iphone_web_fixture_stage').exists()
for part in ['scripts','scenes','data','web','tests']:
    shutil.copytree(repo/part,stage/part,dirs_exist_ok=True)
project=(repo/'project.godot').read_text()
project=re.sub(r'run/main_scene=.*','run/main_scene="res://tests/duel_stage_layout/web_fixture.tscn"',project)
(stage/'project.godot').write_text(project)
preset=(repo/'export_presets.cfg').read_text().replace('tests/*,','').replace('custom_features=""','custom_features="iphone_layout_fixture"',1)
(stage/'export_presets.cfg').write_text(preset)
out.mkdir(parents=True,exist_ok=True)
for args in [['--editor','--import','--quit'],['--export-release','Web',str(out/'index.html')]]:
    subprocess.run([godot,'--headless','--path',str(stage),*args],check=True)
(out/'loading').mkdir(exist_ok=True)
(out/'loading/list.json').write_text('[]')
