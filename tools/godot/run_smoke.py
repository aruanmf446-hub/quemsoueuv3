"""Executa Godot real e trata erros do motor como falhas, mesmo com exit code zero."""
import argparse,os,re,subprocess,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',default='godot');p.add_argument('--output',default='/tmp/qse-godot-smoke');a=p.parse_args()
root=Path(__file__).resolve().parents[2];out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=True)
env=os.environ.copy()
for key,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
 path=out/folder;path.mkdir(exist_ok=True);env[key]=str(path)
# No credentials or backend calls are configured by this harness.
results=[]
def run(name,args,timeout):
 try:
  r=subprocess.run([a.godot,'--headless','--path',str(root),'--rendering-method','gl_compatibility',*args],env=env,capture_output=True,text=True,timeout=timeout)
  log=r.stdout+r.stderr;code=r.returncode
 except subprocess.TimeoutExpired as e:
  log=(e.stdout or b'').decode(errors='replace')+(e.stderr or b'').decode(errors='replace');code=124
 (out/(name+'.log')).write_text(log)
 passed=code==0 and not re.search(r'(?:SCRIPT ERROR:|ERROR:|Parse Error:)',log)
 results.append({'test':name,'exit_code':code,'passed':passed});print(name,'PASS' if passed else 'FAIL',flush=True)
 return passed
version=subprocess.run([a.godot,'--version'],env=env,capture_output=True,text=True).stdout.strip()
imported=run('import',['--editor','--import','--quit'],900)
if imported:
 for n in range(1,11):
  run(f'phase_{n:02d}',['--script','res://tools/godot/smoke.gd','--',f'res://scenes/desert/phase_{n:02d}.tscn'],120)
  if n<10:run(f'transition_{n:02d}',['--script','res://tools/godot/smoke.gd','--',f'res://scenes/desert/phase_{n:02d}.tscn','--transition'],120)
 run('functional',['--script','res://tools/godot/functional.gd'],120)
 run('duel_local',['--script','res://tests/duel_local/flow_test.gd'],240)
 run('supabase_connections',['--script','res://tests/supabase_connections/verify.gd'],120)
 run('catalog_remote',['--script','res://tests/catalog_remote/verify.gd'],120)
 run('main_menu',['--script','res://tools/godot/smoke.gd','--','res://scenes/menu/main_menu.tscn'],120)
(out/'results.json').write_text(json.dumps({'engine':version,'headless':True,'visual_tests':False,'tests':results},indent=2))
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
