"""QA da campanha noturna: isolamento de user://, percursos físicos completos e janelas reais.

Percursos headless usam --fixed-fps60 com physics_ticks_per_second60 e time_scale1.
Isso acelera somente o relógio de execução, sem aumentar delta nem teletransportar atores.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

parser=argparse.ArgumentParser()
parser.add_argument('--godot',required=True)
parser.add_argument('--output',default='/tmp/desert-night-validation')
parser.add_argument('--display',default=':104')
parser.add_argument('--only',nargs='+')
parser.add_argument('--orders',nargs='+',type=int,default=list(range(1,10)))
parser.add_argument('--timeout',type=int,default=1200)
a=parser.parse_args()
root=Path(__file__).resolve().parents[2]
out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=True)
engine=[a.godot,'--path',str(root)]
window=['--rendering-method','gl_compatibility','--audio-driver','Dummy']
headless=['--headless','--fixed-fps','60']
targets=[
 ('import',engine+['--headless','--editor','--import','--quit']),
 ('layout',engine+headless+['--script','res://tests/desert_night/layout_test.gd']),
 ('legacy10',engine+headless+['--script','res://tests/desert_night/legacy10_test.gd']),
 ('progress',engine+headless+['--script','res://tests/desert_night/progress_test.gd']),
 ('rules-desktop',engine+window+['--script','res://tests/desert_night/rules.gd','--',str(out/'rules-desktop'),'1920x1080']),
 ('rules-mobile',engine+window+['--script','res://tests/desert_night/rules.gd','--',str(out/'rules-mobile'),'844x390']),
 ('navigation-desktop',engine+window+['--script','res://tests/desert_night/navigation.gd','--',str(out/'navigation-desktop'),'1920x1080']),
 ('feel-01',engine+headless+['--script','res://tests/desert_night/feel_test.gd','--','1']),
 ('feel-05',engine+headless+['--script','res://tests/desert_night/feel_test.gd','--','5']),
 ('feel-09',engine+headless+['--script','res://tests/desert_night/feel_test.gd','--','9']),
 ('navigation-mobile',engine+window+['--script','res://tests/desert_night/navigation.gd','--',str(out/'navigation-mobile'),'844x390']),
]
for order in a.orders:
 targets.append((f'route-{order:02}',engine+headless+['--script','res://tests/desert_night/route.gd','--',str(out/f'route-{order:02}'),str(order),'1920x1080','no-captures']))
targets.extend([
 ('window-route',engine+window+['--script','res://tests/desert_night/route.gd','--',str(out/'window-route'),'1','1920x1080','captures']),
 ('mobile-route',engine+window+['--script','res://tests/desert_night/route.gd','--',str(out/'mobile-route'),'1','844x390','captures']),
])
if a.only:
 unknown=set(a.only)-{name for name,_ in targets}
 if unknown: raise SystemExit('Etapas desconhecidas: '+str(unknown))
 targets=[target for target in targets if target[0] in a.only]
results=[]
for name,command in targets:
 started=time.monotonic()
 with tempfile.TemporaryDirectory(prefix='night-qa-user-') as folder:
  env=os.environ.copy();env['DISPLAY']=a.display
  for variable,leaf in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
   path=Path(folder)/leaf;path.mkdir();env[variable]=str(path)
  try:
   process=subprocess.run(command,cwd=root,env=env,capture_output=True,text=True,timeout=a.timeout)
   log=process.stdout+process.stderr;code=process.returncode
  except subprocess.TimeoutExpired as error:
   stdout=error.stdout or b'';stderr=error.stderr or b''
   if isinstance(stdout,bytes):stdout=stdout.decode(errors='replace')
   if isinstance(stderr,bytes):stderr=stderr.decode(errors='replace')
   log=stdout+stderr+'\nTIMEOUT after '+str(a.timeout)+'s';code=124
 passed=code==0 and re.search(r'(?:SCRIPT ERROR:|ERROR:|Parse Error:|^FAIL |TIMEOUT)',log,re.M) is None
 (out/(name+'.log')).write_text(log)
 result={'test':name,'passed':passed,'exit_code':code,'wall_seconds':round(time.monotonic()-started,2),'graphical':name in ['rules-desktop','rules-mobile','navigation-desktop','navigation-mobile','window-route','mobile-route'],'fixed_physics_step':name.startswith('route-')}
 results.append(result)
 (out/'results.json').write_text(json.dumps(results,indent=2))
 print(name,'PASS' if passed else 'FAIL',result['wall_seconds'],flush=True)
 if name=='import' and not passed:break
raise SystemExit(0 if len(results)==len(targets) and all(test['passed'] for test in results) else 1)
