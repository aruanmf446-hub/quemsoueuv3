"""T20: nomeia a pilha do 'null function' comparando o index.wasm de produção (sem nomes)
com um template 4.7.2 compilado com --profiling-funcs. Só confia no nome se o corpo da
função for idêntico nos dois binários."""
import hashlib, sys, json
def leb(b, i):
    r = s = 0
    while True:
        x = b[i]; i += 1; r |= (x & 0x7f) << s; s += 7
        if x < 0x80: return r, i
def sections(b):
    i = 8
    while i < len(b):
        sid = b[i]; size, j = leb(b, i + 1); yield sid, j, j + size, b; i = j + size
def imported_funcs(b):
    for sid, s, e, _ in sections(b):
        if sid == 2:
            n, i = leb(b, s); count = 0
            for _ in range(n):
                l, i = leb(b, i); i += l; l, i = leb(b, i); i += l; kind = b[i]; i += 1
                if kind == 0: _, i = leb(b, i); count += 1
                elif kind == 1: i += 1; f, i = leb(b, i); _, i = leb(b, i); i = leb(b, i)[1] if f & 1 else i
                elif kind == 2: f, i = leb(b, i); _, i = leb(b, i); i = leb(b, i)[1] if f & 1 else i
                elif kind == 3: i += 2
                elif kind == 4: i += 1; _, i = leb(b, i)
            return count
    return 0
def bodies(b):
    imp = imported_funcs(b); out = {}
    for sid, s, e, _ in sections(b):
        if sid == 10:
            n, i = leb(b, s)
            for k in range(n):
                size, j = leb(b, i); out[imp + k] = (j, j + size, hashlib.sha1(b[j:j + size]).hexdigest()); i = j + size
    return out
def names(b):
    for sid, s, e, _ in sections(b):
        if sid == 0:
            l, i = leb(b, s)
            if b[i:i + l] != b'name': continue
            i += l
            while i < e:
                sub = b[i]; size, i = leb(b, i + 1); end = i + size
                if sub == 1:
                    n, i = leb(b, i); m = {}
                    for _ in range(n):
                        idx, i = leb(b, i); l, i = leb(b, i); m[idx] = b[i:i + l].decode('utf-8', 'replace'); i += l
                    return m
                i = end
    return {}
prod = open(sys.argv[1], 'rb').read(); sym = open(sys.argv[2], 'rb').read()
stack = [int(x) for x in sys.argv[3].split(',')]
pb, sb, nm = bodies(prod), bodies(sym), names(sym)
print('funções prod', len(pb), 'símbolos', len(sb), 'nomes', len(nm))
same = sum(1 for k, v in pb.items() if k in sb and sb[k][2] == v[2])
print('corpos idênticos por índice', same, 'de', len(pb))
byhash = {}
for k, v in sb.items(): byhash.setdefault(v[2], []).append(k)
res = []
for f in stack:
    p = pb.get(f); entry = {'func': f}
    if p:
        entry['prod_range'] = [hex(p[0]), hex(p[1])]
        if f in sb and sb[f][2] == p[2]: entry['name'] = nm.get(f); entry['match'] = 'mesmo índice e corpo'
        elif p[2] in byhash: entry['name'] = [nm.get(k) for k in byhash[p[2]]]; entry['match'] = 'corpo idêntico em outro índice'
        else: entry['match'] = 'sem corpo idêntico'; entry['name_at_index'] = nm.get(f)
    res.append(entry)
print(json.dumps(res, indent=1, ensure_ascii=False))
