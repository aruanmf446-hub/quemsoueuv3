"""Falha se o .wasm não tiver a seção 'name' com nomes de funções (T20)."""
import sys

def leb(b, i):
    r = s = 0
    while True:
        x = b[i]; i += 1; r |= (x & 0x7f) << s; s += 7
        if x < 0x80: return r, i

b = open(sys.argv[1], 'rb').read()
i, count = 8, 0
while i < len(b):
    sid = b[i]; size, i = leb(b, i + 1); end = i + size
    if sid == 0:
        l, j = leb(b, i)
        if b[j:j + l] == b'name':
            j += l
            while j < end:
                sub = b[j]; ssz, j = leb(b, j + 1)
                if sub == 1: count, _ = leb(b, j)
                j += ssz
    i = end
print('funções nomeadas:', count)
sys.exit(0 if count > 1000 else 1)
