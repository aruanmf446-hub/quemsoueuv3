extends "res://tests/i18n_expanded/fake_game.gd"
## Test transport only: receipts are isolated per synthetic account, never production.
var receipts := {}
var seen_accounts := {}
var fail_claim := false
var fail_feed := false
var claims := 0
func call_rpc(rpc: String, params: Dictionary = {}) -> Dictionary:
 var owned := bool(receipts.get(user, false))
 var offer := {"id":"deck_lado_sombrio","campaign_id":"lado_sombrio_2026","kind":"deck","item_id":"lado_sombrio","title":"Lado Sombrio","description":"10 personagens QSE Originals. Disponível após o resgate.","claimed":owned,"claim_enabled":true,"price":0,"auto_grant":false}
 match rpc:
  "qse_rewards_feed":
   if fail_feed: return ServiceResult.failure("network_error")
   return ServiceResult.success({"ok":true,"campaign":{"id":"lado_sombrio_2026","title":"QSE ORIGINALS — LADO SOMBRIO","description":"Resgate gratuitamente o Lado Sombrio para liberar as 10 cartas na sua Biblioteca e no Mata-Mata."},"seen":seen_accounts.get(user,false),"revealed":false,"offers":[offer]})
  "qse_rewards_inventory": return ServiceResult.success({"ok":true,"offers":[offer] if owned else []})
  "qse_rewards_mark_seen":
   seen_accounts[user]=true
   return ServiceResult.success({"ok":true})
  "qse_rewards_claim":
   claims+=1
   if fail_claim: return ServiceResult.failure("network_error")
   receipts[user]=true
   return ServiceResult.success({"ok":true,"status":"already_claimed" if owned else "claimed"})
 return await super.call_rpc(rpc,params)
