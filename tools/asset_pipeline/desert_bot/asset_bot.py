#!/usr/bin/env python3
"""Fila de produção: Codex executa image_gen; este bot registra/prepara os resultados."""
import argparse, hashlib, json, re, shutil, subprocess
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[3]
QUEUE = Path(__file__).with_name('queue.json')
COMMON = ('Match the approved attached capital_house.png: polished painterly medieval desert kingdom, '
          'warm sandstone, restrained crimson cloth and gold flame insignia, cool moonlit edges, amber lanterns. '
          'ONE isolated reusable environment asset, entire object visible, true transparent background, '
          'front-facing orthographic elevation compatible with a side-scrolling 2.5D game. '
          'No characters, no text, no UI, no sky, no ground plane, no collage or complete level. ')

def read(): return json.loads(QUEUE.read_text())
def write(q): QUEUE.write_text(json.dumps(q, ensure_ascii=False, indent=2)+'\n')
def find(q,key):
    if not re.fullmatch(r'[a-z][a-z0-9_]+',key): raise ValueError('ID inválido')
    return next(x for x in q['assets'] if x['id']==key)

def main():
    p=argparse.ArgumentParser(description=__doc__);sub=p.add_subparsers(dest='command',required=True)
    n=sub.add_parser('next');n.add_argument('--limit',type=int,default=2);n.add_argument('--large-batch',action='store_true',help='usar somente para lote grande pedido pelo dono')
    r=sub.add_parser('register');r.add_argument('id');r.add_argument('image',type=Path)
    b=sub.add_parser('build');b.add_argument('--godot',required=True)
    sub.add_parser('status');a=p.parse_args();q=read()
    if a.command=='next':
        if not 1<=a.limit<=(12 if a.large_batch else 2): p.error('Padrão1–2; lote grande autorizado exige --large-batch, máximo12')
        for item in [x for x in q['assets'] if x['state']=='pending'][:a.limit]:
            print(json.dumps({'id':item['id'],'tool':'image_gen__imagegen','arguments':{
                'prompt':COMMON+item['brief'],'transparent_background':True,
                'referenced_image_paths':[str(ROOT/q['reference'])]}},ensure_ascii=False))
    elif a.command=='register':
        item=find(q,a.id)
        if item['state']!='pending': p.error('Item já registrado; não sobrescrever fonte')
        with Image.open(a.image) as im:
            if im.format!='PNG' or im.mode!='RGBA' or im.getchannel('A').getextrema()[0]==255:
                p.error('A geração precisa ser PNG RGBA com transparência')
            dimensions=list(im.size)
        dest=ROOT/'assets/desert/modular/source'/f'{a.id}.png'
        if dest.exists(): p.error('Fonte já existe; revisão manual necessária')
        shutil.copyfile(a.image,dest)
        item.update(state='generated',source=str(dest.relative_to(ROOT)),size=dimensions,
                    sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),generated_with='image_gen__imagegen')
        write(q);print(a.id,'registered')
    elif a.command=='build':
        items=[x for x in q['assets'] if x['state']=='generated']
        if not items: print('Nenhum item novo para preparar');return
        for item in items: find(q,item['id'])
        subprocess.run([a.godot,'--headless','--path',str(ROOT),'--script',
                        'res://tools/asset_pipeline/desert_bot/build.gd','--',*[x['id'] for x in items]],check=True)
        catalog=ROOT/'assets/desert/modular/city_assets.json';data=json.loads(catalog.read_text())
        for item in items:
            item.update(state='prepared',texture=f'res://assets/desert/modular/{item["id"]}.res')
            if not any(x['id']==item['id'] for x in data['assets']):
                data['assets'].append({'id':item['id'],'texture':item['texture'],'role':item['label'],
                    'suggested_width_metres':item['width_metres'],'placed_in_game':False})
        catalog.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');write(q)
    else:
        for item in q['assets']: print(item['id'],item['state'])

if __name__=='__main__': main()
