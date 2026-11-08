extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  push_error(message)
func run() -> void:
 var services := PlayerServices.new();root.add_child(services)
 var fake := preload("res://tests/commerce/fake_game.gd").new();root.add_child(fake)
 fake.access_token="fixture-not-real"
 services.session.client=fake
 services.session.user={"id":"00000000-0000-4000-8000-000000000091"}
 services.session._expires_at=Time.get_unix_time_from_system()+86400;services.session.set_process(false)
 for service in [services.cosmetic_shop,services.coin_store,services.emote_shop,services.ability_refills]: service.client=fake
 await services.cosmetic_shop.refresh()
 services.cosmetic_shop.data.enabled=true
 var item := services.cosmetic_shop.product("cowboy","style_1")
 item.available=true
 check((await services.cosmetic_shop.buy(item)).code=="sales_disabled","local free release blocks a remotely enabled cosmetic")
 await services.coin_store.refresh()
 services.coin_store.data.enabled=true
 services.coin_store.data.packages[0].available=true
 check((await services.coin_store.create_checkout(services.coin_store.data.packages[0])).code=="payments_unavailable","local free release blocks remotely enabled checkout")
 check((await services.emote_shop.buy("samba",50)).code=="sales_disabled","emote purchase inactive")
 check((await services.ability_refills.buy(10)).code=="sales_disabled","refill purchase inactive")
 check(fake.checkout_calls.is_empty() and fake.purchase_calls.is_empty() and fake.coins==250,"no checkout, purchase or debit")
 var panel: Control=load("res://scenes/skins/skins_panel.tscn").instantiate();root.add_child(panel)
 panel._generating=true
 panel.show_screen({"cosmetic_mode":"shop"})
 for i in 8: await process_frame
 check(panel._cosmetic_mode=="skins","old emote route opens normal skins")
 for mode: String in ["emotes","shop"]:
  panel._choose_cosmetic_mode(mode)
  check(panel._cosmetic_mode=="skins","old preview mode stays inactive: "+mode)
 for control: Control in panel.find_children("*","Control",true,false):
  if str(control.name).begins_with("CosmeticTab_") or control.name in ["SkinVariantPicker","VariationPurchase","EmoteShopActions","BuySkin"]:
   check(not control.is_visible_in_tree(),"hidden cosmetic control: "+str(control.name))
 check(panel.find_child("SkinEquipButton",true,false).is_visible_in_tree(),"original equip flow stays visible")
 panel.queue_free()
 for i in 3: await process_frame
 var deck: Control=load("res://scenes/player/deck_library.tscn").instantiate();root.add_child(deck)
 deck._create_deck()
 for i in 3: await process_frame
 check(not deck.find_child("DeckCreationCredits",true,false).is_visible_in_tree(),"deck editor hides creation credits and purchase link")
 check(deck.find_child("DeckName",true,false).is_visible_in_tree(),"deck creation stays available")
 check(not services.cosmetic_shop.data.deck_credits_required,"backend fixture keeps creation free")
 deck.queue_free()
 for i in 3: await process_frame
 print("FREE_RELEASE checks=",checks," failures=",failures)
 quit(1 if failures else 0)
