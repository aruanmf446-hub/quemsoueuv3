"""Validate catalogs and prevent formatting regressions. No external dependencies."""
import json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
codes=['en','es','fr','ja','zh_CN','ru']
catalogs={c:json.loads((root/'data/ui'/(c+'.json')).read_text()) for c in codes}
base=catalogs['en'];errors=[];token=re.compile(r'%(?:[-+0-9.#]*)([sdifoxX])')
required=['Confirmar cartas','Configurações da sala','Nome da carta','Motivo da reprovação','Você não tem moedas suficientes.','Seu primeiro ataque','Começa em %d','Recargas guardadas: %s','INSTALAR NO IPHONE','há %d dias','Escolha suas cartas, selecione suas skins e entre no duelo.']
for code,data in catalogs.items():
    if set(data)!=set(base):errors.append(f'{code}: catalog keys differ')
    for key,value in data.items():
        if not isinstance(value,str) or not value:errors.append(f'{code}: empty translation: {key}')
        elif token.findall(key)!=token.findall(value):errors.append(f'{code}: format tokens: {key}')
    for key in required:
        if key not in data:errors.append(f'{code}: missing core flow: {key}')
print(json.dumps({'messages_per_language':{k:len(v) for k,v in catalogs.items()},'errors':errors},ensure_ascii=False,indent=2))
sys.exit(bool(errors))
