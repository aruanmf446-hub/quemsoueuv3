"""GAME commerce switches. Default is read-only status. No Stripe secrets are printed.

Enable only after the owner confirms final prices and a real Stripe Sandbox test.
Examples are inactive database quotes, not approval to charge them.
"""
import argparse,json
from deploy_stripe import call

STATUS="""select jsonb_build_object('payments',(select to_jsonb(s) from qse_v3.coin_store_settings s),
'commerce',(select to_jsonb(s) from qse_v3.commerce_settings s),
'packages',(select jsonb_agg(to_jsonb(p) order by p.price_brl_cents,p.id) from qse_v3.coin_packages p),
'active_cosmetics',(select count(*) from qse_v3.cosmetic_products where active),
'active_emotes',(select count(*) from qse_v3.emote_products where active),
'ability_refills',(select to_jsonb(s) from qse_v3.ability_refill_settings s));"""

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--disable',action='store_true',help='Disable payments/new purchases and restore free deck creation; preserve balances/ownership')
 # Activation is intentionally not a blind switch: it needs the actual catalogue approved by the owner.
 a=p.parse_args()
 if a.disable:
  sql="""begin;
update qse_v3.coin_store_settings set enabled=false,live_mode=false;
update qse_v3.commerce_settings set cosmetics_enabled=false,deck_credits_required=false;
update qse_v3.coin_packages set active=false;
update qse_v3.cosmetic_products set active=false;
update qse_v3.emote_products set active=false;
update qse_v3.ability_refill_settings set active=false;
commit;"""
  call('/database/query','POST',json.dumps({'query':sql,'read_only':False}).encode())
 result=call('/database/query','POST',json.dumps({'query':STATUS,'read_only':True}).encode())
 names={s['name'] for s in call('/secrets')}
 print(json.dumps({'game':result,'stripe_secret_configured':'STRIPE_SECRET_KEY' in names,'webhook_secret_configured':'STRIPE_WEBHOOK_SECRET' in names},indent=2))
if __name__=='__main__':main()
