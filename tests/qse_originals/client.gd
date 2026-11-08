extends SceneTree
const Catalog = preload("res://scripts/decks/deck_library_catalog.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  push_error(text)
func run() -> void:
 var services := PlayerServices.new();root.add_child(services)
 TranslationServer.set_locale("pt_BR")
 var deck := Catalog.find_deck("lado_sombrio")
 check(not deck.is_empty() and deck.official and deck.qse_original,"new deck official and curated Original")
 check(deck.count==10,"ten uploaded cards")
 var info: Dictionary=PlayerContracts.read_json("res://assets/duel/decks/oficial/lado_sombrio/deck.json")
 for card: Dictionary in deck.cards:
  var key: String=card.id.get_slice("/",1)
  check(info.cards.has(key) and key==key.to_upper(),"UUID preserved: "+key)
  check(card.name==info.cards[key].name and card.description==info.cards[key].description,"supplied metadata preserved: "+key)
  check(DuelService.card_name(card.id)==card.name,"duel card name: "+key)
 for legacy: String in ["lendas_urbanas","diva_pop","pinturas","nostalgia_web","sol_nascente"]:
  check(not Catalog.find_deck(legacy).qse_original,"legacy deck is not Original: "+legacy)
 # This metadata test opens the native gallery with an explicit test-only receipt.
 services.session.user={"id":"00000000-0000-4000-8000-000000000091"}
 services.client.access_token="fixture-not-real"
 services.session._expires_at=Time.get_unix_time_from_system()+86400
 services.session.set_process(false)
 services.rewards.state="success"
 services.rewards.offers=[{"kind":"deck","item_id":"lado_sombrio","claimed":true,"auto_grant":false}]
 var screen: Control=load("res://scenes/player/deck_library.tscn").instantiate();root.add_child(screen)
 screen._render_deck(deck)
 for i in 3: await process_frame
 check(screen.find_child("QSEOriginalsBadge",true,false)!=null,"native Original badge shown")
 screen._render_deck(Catalog.find_deck("pinturas"))
 for i in 3: await process_frame
 check(screen.find_child("QSEOriginalsBadge",true,false)==null,"native Original badge absent on legacy deck")
 screen.queue_free()
 var server := LocalDuelServer.new();root.add_child(server)
 server.official_deck_access=Catalog.can_access
 var local_decks: Array=server.decks().filter(func(item:Dictionary)->bool:return item.id=="lado_sombrio")
 check(local_decks.size()==1 and local_decks[0].cards.size()==10,"local game accepts UUID-backed deck")
 var room := server.call_rpc("qse_duel_create",{"p_name":"Original","p_public":false,"p_settings":{"deck_ids":["lado_sombrio"],"cards_per_player":3}})
 check(room.ok,"new local room accepts deck")
 server.call_rpc("qse_duel_add_bot",{"p_room":room.data.room.id})
 var started := server.call_rpc("qse_duel_start",{"p_room":room.data.room.id})
 check(started.ok and started.data.match.pool.size()==10,"match has ten real cards")
 var fake := preload("res://tests/commerce/fake_game.gd").new();root.add_child(fake);fake.access_token="fixture-not-real"
 services.session.client=fake;services.session.user={"id":"00000000-0000-4000-8000-000000000091"};services.session._expires_at=Time.get_unix_time_from_system()+86400;services.session.set_process(false)
 services.progression.state="success";services.progression.data={"unlocked_character_ids":PlayerContracts.initial_ids(),"equipped_character_id":"cowboy"}
 var panel: Control=load("res://scenes/skins/skins_panel.tscn").instantiate();root.add_child(panel);panel._generating=true;panel.show_screen()
 check(not panel._cards.has("el_fuego"),"locked El Fuego absent from gallery")
 check(not panel._collection_ids(panel._collections[0]).has("el_fuego"),"locked reward absent from visible counts")
 panel._search="El Fuego";panel._rebuild_gallery();check(panel._cards.is_empty(),"search cannot reveal locked reward")
 panel._select("el_fuego");check(panel._selected!="el_fuego","direct preview cannot reveal locked reward")
 services.progression.data.unlocked_character_ids.append("el_fuego");panel._search="";panel.render()
 check(panel._cards.has("el_fuego"),"campaign-unlocked El Fuego appears")
 panel._select("el_fuego");check(panel._selected=="el_fuego","unlocked reward selectable")
 services.progression.data.unlocked_character_ids.erase("el_fuego");panel.render()
 check(not panel._cards.has("el_fuego") and panel._selected!="el_fuego","account relock does not retain reward preview")
 check(not services.inventory.entry("el_fuego").is_empty(),"original model remains in registry")
 print("QSE_ORIGINALS checks=",checks," failures=",failures)
 quit(1 if failures else 0)
