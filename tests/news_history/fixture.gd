extends Node
## Offline UI fixture: ownership below is synthetic, never a real grant.
class OfflineSession extends SessionService:
 func _ready() -> void:set_process(false)
 func authenticated() -> bool:return true
class Overlay extends NewsOverlay:
 func _load() -> void:pass
var services: PlayerServices
var overlay: NewsOverlay
var callback: JavaScriptObject
func _ready() -> void:
 services=preload("res://tests/story_continuity/account_merge.gd").TestServices.new()
 add_child(services);PlayerServices.current=services
 services.session=OfflineSession.new();services.add_child(services.session)
 services.rewards=OfficialRewardsService.new();services.add_child(services.rewards)
 var rewards:=services.rewards
 rewards.state="success";rewards.inventory_state="success";rewards.seen=true;rewards.revealed=true
 rewards.campaign={}
 rewards.offers.assign([
  {"id":"old-deck","kind":"deck","item_id":"lado_sombrio","title":"Lado Sombrio","description":"Presente oficial da equipe Quem Sou Eu.","claimed":true,"claimed_at":"2026-11-08T15:30:00Z","campaign_id":"past-campaign","revealed":true},
  {"id":"old-skin","kind":"skin","item_id":"cowboy","title":"Cowboy","description":"Skin recebida em uma campanha anterior.","claimed":true,"claimed_at":"2026-10-20T12:00:00Z","campaign_id":"past-campaign","revealed":true},
  {"id":"pending-deck","kind":"deck","item_id":"lendas_urbanas","title":"Lendas Urbanas","claimed":false,"auto_grant":false}
 ])
 overlay=Overlay.new();add_child(overlay)
 for i in 8:await get_tree().process_frame
 assert(overlay.find_child("Claim_old-deck",true,false)==null)
 (overlay.find_child("MoreNews",true,false) as Button).pressed.emit()
 for i in 8:await get_tree().process_frame
 assert(overlay.find_child("Offer_old-deck",true,false)!=null)
 assert(overlay.find_child("Claim_pending-deck",true,false)==null)
 assert(overlay.find_child("RedeemGiftBundle",true,false)==null)
 assert(overlay.find_child("ClaimedDate",true,false).text=="08/11/2026")
 overlay._switch("skin")
 assert(overlay.find_child("Offer_old-skin",true,false)!=null)
 overlay._switch("deck")
 var button:=Button.new();PlayerUI.style_hero_button(button)
 for state in ["normal","hover","pressed","hover_pressed","disabled"]:
  assert((button.get_theme_stylebox(state) as StyleBoxFlat).bg_color.a==0.0)
 assert((button.get_theme_stylebox("focus") as StyleBoxFlat).border_width_left>0)
 button.free()
 var sort: OptionButton=overlay.find_child("RewardSort",true,false)
 assert(sort!=null and (sort.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.a==0.0)
 var saved:=rewards.offers.duplicate(true)
 rewards.offers.clear();rewards.inventory_state="error";overlay._render()
 assert(overlay.find_child("NewsMessage",true,false)!=null)
 assert(overlay.find_child("Offer_old-deck",true,false)==null)
 rewards.offers.assign(saved);rewards.inventory_state="success";overlay._render()
 get_tree().set_meta("news_history_passed",true)
 print("PASS histórico sem campanha ativa, recibos e datas, pendências separadas, erro sem posse falsa, botões transparentes com foco")
 if OS.has_feature("web"):
  callback=JavaScriptBridge.create_callback(_command)
  JavaScriptBridge.get_interface("window").qseNewsCommand=callback
  JavaScriptBridge.eval("window.qseNewsReady=true")
func _command(args:Array)->void:
 var mode:=str(args[0])
 if mode=="history" or mode=="available":
  if overlay._history!=(mode=="history"):overlay._legacy_news()
 elif mode=="skin" or mode=="deck":overlay._switch(mode)
