"""HTTP integration for the isolated Supabase project only; no admin key.
Run: python3 tests/test_http.py --phase anonymous|authenticated
Runtime credentials are read from .runtime/stage.json and never logged.
"""
import argparse,base64,json,uuid,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CONFIG=ROOT/'.runtime/stage.json'
RESULTS=[]
def check(name,condition):
 RESULTS.append({'test':name,'passed':bool(condition)})
 print(json.dumps(RESULTS[-1]),flush=True)
 if not condition: raise AssertionError(name)
def http(c,path,body=None,token=None,method='POST',extra=None):
 headers={'apikey':c['key'],'Content-Type':'application/json'}
 if token: headers['Authorization']='Bearer '+token
 if extra: headers.update(extra)
 request=urllib.request.Request(c['url']+path,data=None if body is None else json.dumps(body).encode(),headers=headers,method=method)
 try:
  with urllib.request.urlopen(request,timeout=30) as response:
   raw=response.read();return response.status,json.loads(raw) if raw else None
 except urllib.error.HTTPError as error:
  raw=error.read()
  try: data=json.loads(raw)
  except ValueError: data={'http_error':error.code}
  return error.code,data
def rpc(c,name,body=None,token=None):
 return http(c,'/rest/v1/rpc/'+name,body or {},token)
def command(c,token,revision,operation,key=None):
 request={'protocol_version':2,'rules_version':'desert_progression_2.0.0','request_id':key or str(uuid.uuid4()),'expected_revision':revision,'operation':operation}
 return rpc(c,'qse_progression_command',{'p_request':request},token)
def anonymous(c):
 status,settings=http(c,'/auth/v1/settings',method='GET')
 check('auth_email_enabled',status==200 and settings['external']['email'] and not settings['disable_signup'])
 api=json.loads((ROOT/'data/ui/api.json').read_text())
 args={'p_nickname':'QSE Test','p_discoverable':False,'p_public_id':'QSE-'+'0'*32,'p_term':'QSE','p_action':'send','p_target':str(uuid.uuid4()),'p_request_id':str(uuid.uuid4()),'p_before':None,'p_request':{}}
 for name,definition in api['endpoints'].items():
  status,data=rpc(c,name,{key:args[key] for key in definition['parameters']})
  check('anon_denied_'+name,status in (401,403))
def authenticated(c):
 sessions={}
 for label,user in c['users'].items():
  status,data=http(c,'/auth/v1/token?grant_type=password',{'email':user['email'],'password':user['password']})
  check('real_auth_login_'+label,status==200 and 'access_token' in data)
  claims=json.loads(base64.urlsafe_b64decode(data['access_token'].split('.')[1]+'==='))
  check('non_admin_jwt_'+label,claims['role']=='authenticated')
  sessions[label]={'token':data['access_token'],'refresh':data['refresh_token'],'id':data['user']['id']}
 a,b=sessions['a'],sessions['b']
 for label,s in sessions.items():
  status,data=rpc(c,'qse_profile_self',token=s['token'])
  check('profile_identity_'+label,status==200 and data['user_id']==s['id'])
  nickname='QSET05'+label.upper()
  status,data=rpc(c,'qse_profile_update',{'p_nickname':nickname},s['token'])
  check('nickname_persists_'+label,status==200 and data['nickname']==nickname)
  status,data=rpc(c,'qse_wallet',token=s['token'])
  check('wallet_zero_'+label,status==200 and data['coins']=='0' and data['gems']=='0' and data['transactions']==[])
  status,data=rpc(c,'qse_wallet_history',{'p_before':'9223372036854775808'},s['token'])
  check('cursor_overflow_'+label,status==200 and data=={'error':'invalid_cursor'})
 status,data=rpc(c,'qse_t05_rls_probe',{'p_target':a['id'],'p_mode':'read'},a['token'])
 check('rls_own_rows',status==200 and data['role']=='authenticated' and data['subject']==a['id'] and data['wallet_rows']==1 and data['profile_rows']==1 and data['unlock_rows']==7)
 for viewer,target in [(a,b),(b,a)]:
  status,data=rpc(c,'qse_t05_rls_probe',{'p_target':target['id'],'p_mode':'read'},viewer['token'])
  check('rls_other_account_'+viewer['id'],status==200 and data['wallet_rows']==0 and data['profile_rows']==0 and data['unlock_rows']==0)
  status,data=rpc(c,'qse_t05_rls_probe',{'p_target':target['id'],'p_mode':'write'},viewer['token'])
  check('wallet_write_denied_'+viewer['id'],status in (401,403))
 status,data=rpc(c,'qse_t05_rls_probe',{'p_target':a['id'],'p_mode':'write'},a['token'])
 check('own_wallet_arbitrary_write_denied',status in (401,403))
 status,data=http(c,'/rest/v1/wallets?select=*',token=a['token'],method='GET',extra={'Accept-Profile':'qse_v3'})
 check('private_schema_not_exposed',status in (400,404,406))
 status,data=rpc(c,'qse_wallet',{'p_user_id':b['id']},a['token'])
 check('cannot_choose_wallet_owner',status in (400,404))
 status,data=rpc(c,'qse_find_players',{'p_term':'QSET05B'},a['token'])
 check('search_finds_b',status==200 and any(p['user_id']==b['id'] for p in data['players']))
 key=str(uuid.uuid4());body={'p_action':'send','p_target':b['id'],'p_request_id':key}
 status,first=rpc(c,'qse_friend_action',body,a['token'])
 check('friend_request_sent',status==200 and first['status']=='applied')
 status,data=rpc(c,'qse_friend_action',body,a['token'])
 check('friend_request_idempotent',status==200 and data==first)
 status,data=rpc(c,'qse_friend_action',dict(body,p_action='cancel'),a['token'])
 check('friend_request_idempotency_conflict',status==200 and data['error']=='idempotency_conflict')
 status,data=rpc(c,'qse_friend_action',{'p_action':'accept','p_target':a['id'],'p_request_id':str(uuid.uuid4())},b['token'])
 check('friend_accept_by_recipient',status==200 and data['status']=='applied')
 status,data=rpc(c,'qse_friends',token=a['token'])
 check('friends_list_and_skin',status==200 and any(p['user_id']==b['id'] and p['equipped_character_id']=='cowboy' for p in data['friends']))
 status,snapshot=rpc(c,'qse_progression_snapshot',token=a['token'])
 check('initial_campaign_locked',status==200 and snapshot['completed_phase_ids']==[] and len(snapshot['unlocked_character_ids'])==7 and 'el_fuego' not in snapshot['unlocked_character_ids'])
 status,data=command(c,a['token'],snapshot['revision'],{'type':'equip_character','character_id':'lana'})
 check('equip_unlocked',status==200 and data['status']=='applied' and data['snapshot']['equipped_character_id']=='lana')
 revision=data['snapshot']['revision']
 for char in ['el_fuego','cactus','malagueta']:
  status,data=command(c,a['token'],revision,{'type':'equip_character','character_id':char})
  check('equip_denied_'+char,status==200 and data['code']=='locked_character')
 status,data=command(c,a['token'],revision,{'type':'start_phase','phase_id':'desert_phase_01'})
 check('start_first_phase',status==200 and data['status']=='applied')
 revision=data['snapshot']['revision']
 status,data=command(c,a['token'],revision,{'type':'complete_phase','phase_id':'desert_phase_01','attempt_id':str(uuid.uuid4()),'evidence_id':str(uuid.uuid4())})
 check('completion_without_proof_denied',status==200 and data['code']=='verification_unavailable' and data['snapshot']['completed_phase_ids']==[] and 'el_fuego' not in data['snapshot']['unlocked_character_ids'])
 status,data=rpc(c,'qse_wallet',token=a['token'])
 check('wallet_still_zero',status==200 and data['coins']=='0' and data['gems']=='0')
 status,data=http(c,'/auth/v1/token?grant_type=refresh_token',{'refresh_token':a['refresh']})
 check('real_refresh',status==200 and bool(data.get('access_token')))
 token=data['access_token']
 status,data=http(c,'/auth/v1/logout?scope=local',{},token)
 check('real_logout',status in (200,204))
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--phase',choices=['anonymous','authenticated'],required=True)
 args=parser.parse_args();c=json.loads(CONFIG.read_text())
 if c['url']!='https://ifomrkzmxgwwjapoeklo.supabase.co':raise RuntimeError('ISOLATED PROJECT REQUIRED')
 try:
  (anonymous if args.phase=='anonymous' else authenticated)(c)
 finally:
  (ROOT/'tests'/('results_'+args.phase+'.json')).write_text(json.dumps({'project':'ifomrkzmxgwwjapoeklo','phase':args.phase,'results':RESULTS,'note':'Only executed cases are listed; authenticated cases require successful Auth login.'},indent=2))
if __name__=='__main__':main()
