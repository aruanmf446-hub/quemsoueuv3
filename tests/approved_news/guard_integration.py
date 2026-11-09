"""Real git trees: an AI cannot silently rebaseline approved files in its commit."""
import json,os,subprocess,tempfile
from pathlib import Path
script=Path(__file__).resolve().parents[2]/'tools/governance/check_approved.py'
def run(*args,**kwargs):return subprocess.check_output(args,text=True,stderr=subprocess.DEVNULL,**kwargs).strip()
with tempfile.TemporaryDirectory() as directory:
 root=Path(directory)
 def git(*args):return run('git',*args,cwd=root)
 git('init','-q');git('config','user.name','Scope guard test');git('config','user.email','fixture@example.invalid')
 (root/'friends').mkdir();(root/'friends/a').write_text('approved')
 (root/'docs/governance').mkdir(parents=True)
 policy={'areas':{'amizades':['friends/*']},'blobs':{'friends/a':git('hash-object','friends/a')},'controls':['docs/governance/approved_scope.json']}
 (root/'docs/governance/approved_scope.json').write_text(json.dumps(policy));git('add','.');git('commit','-qm','baseline');base=git('rev-parse','HEAD')
 def check(env=None):return subprocess.run(['python3',str(script),'--base',base],cwd=root,capture_output=True,text=True,env=env).returncode
 assert check()==0
 (root/'friends/a').write_text('unauthorized');policy['blobs']['friends/a']=git('hash-object','friends/a')
 (root/'docs/governance/approved_scope.json').write_text(json.dumps(policy));git('add','.');git('commit','-qm','attempted rebaseline')
 assert check()==1, 'untrusted policy rewrite must not bypass trusted base'
 env=dict(os.environ,QSE_APPROVED_CHANGE=json.dumps({'sha':git('rev-parse','HEAD'),'areas':['amizades','protecao'],'reason':'Owner explicitly confirmed this exact change'}))
 assert check(env)==0, 'exact one-commit exception should work'
 env['QSE_APPROVED_CHANGE']=json.dumps({'sha':base,'areas':['amizades','protecao'],'reason':'Old confirmation'})
 assert check(env)==1, 'stale confirmation must not be reused'
 print('GUARD_GIT_INTEGRATION PASS: clean, blocked self-rebaseline, exact authorization, stale authorization')
