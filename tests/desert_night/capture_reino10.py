"""Capturas reais de três perfis; o painel usa as capturas, nunca conceitos gerados."""
import argparse, json, os, subprocess, tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--output',required=True);p.add_argument('--panel-only',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parents[2];out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=True);results=json.loads((out/'results.json').read_text()) if a.panel_only else []
for name,size,iphone in ([] if a.panel_only else [('desktop','1672x941',False),('iphone','844x390',True),('standard_small','640x360',False)]):
 target=out/name;target.mkdir(exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='reino10-capture-') as folder:
  env=os.environ.copy();env['LP_NUM_THREADS']='2'
  for key,leaf in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
   path=Path(folder)/leaf;path.mkdir();env[key]=str(path)
  if iphone:env['QSE_TEST_IPHONE']='1'
  else:env.pop('QSE_TEST_IPHONE',None)
  cmd=[a.godot,'--path',str(root),'--audio-driver','Dummy','--max-fps','30','--script','res://tests/desert_night/reino_v3_gallery.gd','--',str(target),size]
  if iphone:cmd.append('--iphone')
  with (target/'engine.log').open('w') as log:run=subprocess.run(cmd,env=env,cwd=root,stdout=log,stderr=subprocess.STDOUT,timeout=900)
 text=(target/'engine.log').read_text();passed=run.returncode==0 and 'REINO_GALLERY failures=0' in text and not any(t in text for t in ['ERROR:','SCRIPT ERROR:','Parse Error:'])
 results.append({'profile':name,'size':size,'iphone':iphone,'passed':passed,'exit_code':run.returncode,'captures':len(list(target.glob('*.png')))})
 (out/'results.json').write_text(json.dumps(results,indent=2));print(name,passed,flush=True)
 for image in target.glob('*.png'):Image.open(image).convert('RGB').save(target/(image.stem+'.jpg'),quality=92)
# Mantém proporção e todo o quadro; legendas ficam fora das capturas.
labels=['Portões da Capital','Telhados da Capital','Bazar da Cidade','Aqueduto do Deserto','Jardins do Oásis','Ruínas Enterradas','Estrada da Mineração','Posto de Controle','Entrada da Mineradora','Interior da Mineração']
panel=Image.new('RGB',(1280,5*390),(8,16,28));draw=ImageDraw.Draw(panel)
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16)
for index,label in enumerate(labels):
 name=f'fase_{index+1:02d}_distrito05_fixture.jpg'
 if index==0:name='fase_01.jpg'
 if index==8:name='fase_09_portal_final_fixture.jpg'
 image=Image.open(out/'desktop'/name);image.thumbnail((640,360))
 x=(index%2)*640;y=(index//2)*390
 draw.text((x+10,y+8),f'{index+1:02d}  {label}',fill=(243,209,139),font=font)
 panel.paste(image,(x+(640-image.width)//2,y+30+(360-image.height)//2))
panel.save(out/'painel_10_fases.jpg',quality=92)
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
