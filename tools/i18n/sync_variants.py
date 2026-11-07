"""Reuse reviewed translations for literal casing, spaces and decoration variants.
Only existing Portuguese keys may be reused. Never changes IDs or input values.
"""
import json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2];codes=['en','es','fr','ja','zh_CN','ru']
files={c:root/'data/ui'/(c+'.json') for c in codes};data={c:json.loads(p.read_text()) for c,p in files.items()}
known={k.casefold():k for k in data['en']};literals=set()
for p in (root/'scripts').rglob('*.gd'):
    for line in p.read_text().splitlines():
        if line.lstrip().startswith('#'):continue
        for m in re.finditer(r'"(?:[^"\\]|\\.)*"',line):
            try:literals.add(json.loads(m.group()))
            except ValueError:pass
count=0
for source in sorted(literals):
    if source in data['en']:continue
    m=re.fullmatch(r'([\s▾▸▶+←‹]*)(.*?)([\s*→›…:.]*)',source,flags=re.S)
    if not m:continue
    prefix,core,suffix=m.groups();match=known.get(core.casefold())
    if not match or not core:continue
    for code,d in data.items():
        target=d[match]
        if core.isupper():target=target.upper()
        elif core.islower():target=target.lower()
        d[source]=prefix+target+suffix
    count+=1
if '--check' not in sys.argv:
    for code,p in files.items():p.write_text(json.dumps(data[code],ensure_ascii=False,indent=2)+'\n')
print(f'Localized source variants: {count}')
if '--check' in sys.argv:sys.exit(bool(count))
