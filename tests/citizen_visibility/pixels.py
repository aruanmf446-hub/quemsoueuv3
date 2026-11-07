"""Compara capturas reais com/sem um figurante: posição na árvore não prova pixels visíveis."""
import json,sys
from PIL import Image,ImageChops
first=Image.open(sys.argv[1]).convert('RGB');second=Image.open(sys.argv[2]).convert('RGB')
x0,y0,x1,y1=json.loads(sys.argv[3]);box=tuple(round(x) for x in [x0,y0,x1,y1])
a=first.crop(box);b=second.crop(box);difference=ImageChops.difference(a,b)
w,h=difference.size
changed=feet=0;foot_start=int(h*0.8)
for y in range(h):
 for x in range(w):
  if max(difference.getpixel((x,y)))>24:
   changed+=1
   if y>=foot_start:feet+=1
result={'body_ratio':changed/max(w*h,1),'feet_ratio':feet/max(w*(h-foot_start),1),'rect':box}
print(json.dumps(result))
raise SystemExit(0 if result['body_ratio']>0.12 and result['feet_ratio']>0.06 else 1)
