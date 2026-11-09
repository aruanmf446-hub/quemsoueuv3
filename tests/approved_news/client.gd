extends SceneTree
class Overlay extends NewsOverlay:
 func _load()->void:pass
var checks:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:
  push_error(message);quit(1);assert(ok,message)
func run()->void:
 var services:=PlayerServices.new();root.add_child(services)
 var fake:=preload("res://tests/lado_sombrio_claim/fake_game.gd").new();root.add_child(fake)
 fake.user="00000000-0000-4000-8000-000000000093";fake.access_token="fixture-not-real"
 services.session.client=fake;services.rewards.client=fake;services.session.user={"id":fake.user}
 services.session._expires_at=Time.get_unix_time_from_system()+3600;services.session.set_process(false)
 await services.rewards.refresh();await services.rewards.claim("deck_lado_sombrio")
 fake.fail_feed=true
 var result:=await services.rewards.refresh()
 check(not result.ok and services.rewards.state=="error","feed failure reproduced")
 check(services.rewards.inventory_state=="success" and services.rewards.is_deck_claimed("lado_sombrio"),"real receipt independent of campaign feed")
 var overlay:=Overlay.new();overlay._history=true;root.add_child(overlay)
 for i in 3:await process_frame
 check(overlay.find_child("Offer_deck_lado_sombrio",true,false)!=null,"history shows server receipt despite feed failure")
 check(overlay.find_child("RefreshRewardHistory",true,false)!=null,"history can be refreshed manually")
 services.rewards.campaign={"id":"current"};services.rewards.revealed=false
 var granted:Dictionary={"id":"granted","kind":"deck","item_id":"pinturas","claimed":true,"auto_grant":true,"campaign_id":"current","revealed":false}
 services.rewards.offers.append(granted);overlay._render()
 check(overlay._visible_offers(services.rewards).any(func(o:Dictionary)->bool:return o.id=="granted"),"unrevealed server receipt is not hidden from history")
 services.rewards.offers.append({"id":"not_claimed","kind":"deck","claimed":false})
 check(not overlay._visible_offers(services.rewards).any(func(o:Dictionary)->bool:return o.id=="not_claimed"),"pending item never pretends to be claimed")
 await services.rewards.refresh_inventory()
 check(services.rewards.is_deck_claimed("lado_sombrio"),"manual history refresh keeps actual receipt")
 overlay.queue_free();services.session.user={};fake.access_token="";services.rewards.clear()
 var library:Control=load("res://scenes/player/deck_library.tscn").instantiate();root.add_child(library);library.show_screen()
 for i in 4:await process_frame
 check(library.find_child("GuestDeckPreview",true,false)!=null,"guest sees generic invitation")
 check(library.find_child("GuestDeckBlur",true,false).texture.resource_path=="res://assets/ui/battle/private_back.svg","preview uses generic back, not locked card art")
 check(library.find_child("Deck_lado_sombrio",true,false)==null,"locked pack stays hidden from guests")
 check(not services.duel.local_server.decks().any(func(d:Dictionary)->bool:return d.id=="lado_sombrio"),"visitor cannot play protected pack")
 var route:={"value":""};library.navigate_requested.connect(func(id:String,_params:Dictionary)->void:route.value=id)
 library.find_child("GuestDeckLogin",true,false).pressed.emit()
 check(route.value=="account","invitation opens existing account route")
 print("APPROVED_NEWS checks=",checks," failures=0");quit(0)
