"""Additional no-session checks. No signup, login, browser or SQL writes."""
import json,urllib.request,urllib.error
from pathlib import Path
URL="https://ifomrkzmxgwwjapoeklo.supabase.co"
KEY="sb_publishable_zaj_ZrtAaM-HEGPsxnUxDQ_TyhVwSB5"
def request(path,headers,body=None):
 req=urllib.request.Request(URL+path,headers={"apikey":KEY,**headers},data=body)
 try:
  with urllib.request.urlopen(req,timeout=25) as r:return r.status,json.loads(r.read())
 except urllib.error.HTTPError as e:
  return e.code,json.loads(e.read())
cases=[
 ("malformed_jwt_rejected","/rest/v1/rpc/qse_wallet",{"Authorization":"Bearer invalid.jwt.signature","Content-Type":"application/json"},b"{}",(401,403),None),
 ("private_schema_not_exposed","/rest/v1/wallets?select=user_id",{"Accept-Profile":"qse_v3"},None,(406,),"PGRST106"),
 ("private_ledger_not_public_rpc","/rest/v1/rpc/post_wallet_entry",{"Content-Type":"application/json"},b"{}",(404,),"PGRST202"),
]
results=[]
for name,path,headers,body,statuses,code in cases:
 status,data=request(path,headers,body)
 passed=status in statuses and (code is None or data.get("code")==code)
 row={"test":name,"http_status":status,"error_code":data.get("code"),"passed":passed}
 results.append(row); print(json.dumps(row),flush=True)
out={"project":"ifomrkzmxgwwjapoeklo","scope":"additional_no_session","results":results,"signup_attempted":False,"login_attempted":False,"database_writes":False}
Path(__file__).with_name("results_no_session_extra.json").write_text(json.dumps(out,indent=2))
if not all(r["passed"] for r in results):raise SystemExit(1)
