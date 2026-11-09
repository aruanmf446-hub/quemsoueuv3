"""Fail closed on changes to approved areas; CI loads this script from its base commit."""
import argparse, fnmatch, json, os, subprocess, sys
from pathlib import Path
POLICY='docs/governance/approved_scope.json'
def git(*args): return subprocess.check_output(['git','-c','core.quotepath=false',*args],text=True).strip()
def tree(ref):
    result={}
    lines=git('ls-files','--stage').splitlines() if ref=='INDEX' else git('ls-tree','-r',ref).splitlines()
    for line in lines:
        meta,path=line.split('\t',1); fields=meta.split()
        result[path]=fields[1] if ref=='INDEX' else fields[2]
    return result
def areas(path, policy):
    return [area for area,patterns in policy['areas'].items() if any(fnmatch.fnmatchcase(path,p) for p in patterns)]
def evaluate(policy,current,changed_controls=(),authorization=None,sha=''):
    failed=[]; authorization=authorization or {}
    allowed=set(authorization.get('areas',[])) if authorization.get('sha')==sha and authorization.get('reason','').strip() else set()
    for path in set(policy['blobs'])|set(current):
        scope=areas(path,policy)
        if scope and current.get(path)!=policy['blobs'].get(path) and not set(scope).issubset(allowed): failed.append(path)
    if 'protecao' not in allowed: failed.extend(changed_controls)
    return sorted(set(failed))
def main():
    p=argparse.ArgumentParser();p.add_argument('--base',default='');p.add_argument('--ref',default='HEAD');args=p.parse_args()
    current=tree(args.ref); head=git('rev-parse','HEAD'); path=Path(POLICY)
    if not path.exists(): raise SystemExit('Missing approved-scope policy')
    proposed=json.loads(path.read_text()); controls=[]; policy=proposed
    if args.base and set(args.base)!={'0'}:
        try: raw=subprocess.check_output(['git','show',args.base+':'+POLICY],text=True,stderr=subprocess.DEVNULL).strip()
        except subprocess.CalledProcessError: raw=''
        if raw:
            policy=json.loads(raw);before=tree(args.base)
            controls=[x for x in policy['controls'] if before.get(x)!=current.get(x)]
    auth=json.loads(os.environ.get('QSE_APPROVED_CHANGE','{}') or '{}')
    failed=evaluate(policy,current,controls,auth,head)
    # The proposed baseline itself must match the actual release, not arbitrary hashes.
    for file in set(proposed['blobs'])|set(current):
        if areas(file,proposed) and proposed['blobs'].get(file)!=current.get(file): failed.append(file)
    if failed:
        print('BLOCKED: área aprovada alterada sem confirmação específica do dono:')
        print('\n'.join(sorted(set(failed))));return 1
    print('APPROVED_SCOPE_GUARD PASS');return 0
if __name__=='__main__':sys.exit(main())
