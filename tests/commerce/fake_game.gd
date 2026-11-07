extends "res://tests/coin_store/fake_game.gd"
## UI fixture only, never exported with the production preset.
func _init() -> void:
 enabled=false
 packages=[{"id":"coins_100","name":"100 moedas","coins":"100","price_brl_cents":1000,"reward_kind":"coins","available":false},
 {"id":"coins_250","name":"250 moedas","coins":"250","price_brl_cents":2000,"reward_kind":"coins","available":false},
 {"id":"coins_400","name":"400 moedas","coins":"400","price_brl_cents":3000,"reward_kind":"coins","available":false},
 {"id":"deck_credit","name":"1 crédito de deck","coins":"1","price_brl_cents":1000,"reward_kind":"deck_credits","available":false}]
func call_rpc(rpc: String,params: Dictionary={}) -> Dictionary:
 if rpc=="qse_cosmetic_shop":
  await get_tree().process_frame
  return ServiceResult.success({"enabled":false,"deck_credits_required":false,"deck_credits":"0","equipped":{},"items":[{"id":"cowboy_style_1","name":"Cowboy · Variação 1","kind":"variation","character_id":"cowboy","style_id":"style_1","price_coins":"100","available":false,"owned":false}]})
 if rpc=="qse_emote_shop":
  await get_tree().process_frame
  return ServiceResult.success({"coins":"250","items":[{"id":"samba","name":"Samba","price_coins":"50","animation_key":"emote_samba","available":false,"owned":false}]})
 return await super.call_rpc(rpc,params)
