"""Janela real, entradas, percurso completo, capturas nativas e regressão das dez fases."""
import argparse, json, os, re, subprocess, tempfile
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--godot',required=True)
p.add_argument('--output',default='/tmp/qse-gameplay-t15d')
p.add_argument('--only',nargs='+',help='Etapas específicas para repetir uma verificação afetada.')
a=p.parse_args()
root=Path(__file__).resolve().parents[2]
out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=True)
engine=[a.godot,'--path',str(root)]
window=['--rendering-method','gl_compatibility','--audio-driver','Dummy']
targets=[
 ('import',engine+['--headless','--editor','--import','--quit']),
 ('extra',engine+window+['--script','res://tests/gameplay_t15d/verify.gd','--',str(out/'extra'),'1920x1080']),
 ('session',engine+window+['--script','res://tests/gameplay_t15d/session_checks.gd']),
 ('journey',engine+window+['--script','res://tests/gameplay_t15d/journey.gd','--',str(out/'journey'),'1920x1080']),
 ('mobile-journey',engine+window+['--script','res://tests/gameplay_t15d/journey.gd','--',str(out/'mobile-journey'),'844x390']),
 ('scenario',engine+window+['--script','res://tools/godot/phase01_scenario.gd','--',str(out/'route'),'1920x1080']),
 ('mobile-scenario',engine+window+['--script','res://tools/godot/phase01_scenario.gd','--',str(out/'mobile-route'),'844x390']),
 ('desktop',engine+window+['--script','res://tests/gameplay_t15d/capture.gd','--',str(out/'desktop'),'1920x1080']),
 ('mobile',engine+window+['--script','res://tests/gameplay_t15d/capture.gd','--',str(out/'mobile'),'844x390']),
 ('smoke',['python3','tools/godot/run_smoke.py','--godot',a.godot,'--output',str(out/'smoke')]),
]
if a.only:
 if set(a.only)-{name for name,cmd in targets}: raise SystemExit('Etapa desconhecida')
 targets=[entry for entry in targets if entry[0] in a.only]
results=[]
for name,cmd in targets:
 with tempfile.TemporaryDirectory(prefix='t15d-user-') as data:
  env=os.environ.copy()
  for variable,folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
   env[variable]=str(Path(data)/folder);Path(env[variable]).mkdir()
  result=subprocess.run(cmd,cwd=root,env=env,capture_output=True,text=True,timeout=360)
 log=result.stdout+result.stderr;(out/(name+'.log')).write_text(log)
 passed=result.returncode==0 and re.search(r'(?:SCRIPT ERROR:|ERROR:|Parse Error:|^FAIL )',log,re.M) is None
 results.append({'test':name,'passed':passed,'exit_code':result.returncode})
 print(name,'PASS' if passed else 'FAIL',flush=True)
 (out/'results.json').write_text(json.dumps(results,indent=2))
 if name=='import' and not passed:break
raise SystemExit(0 if len(results)==len(targets) and all(r['passed'] for r in results) else 1)
