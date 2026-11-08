extends SceneTree
const Catalog=preload("res://scripts/decks/deck_library_catalog.gd")
var checks:=0
func _initialize()->void: run.call_deferred()
func check(ok:bool, message:String)->void:
 checks+=1
 if not ok:
  push_error(message)
  quit(1)
  assert(ok,message)
func frames()->void:
 for i in 3: await process_frame
func run()->void:
 var services:=PlayerServices.new();root.add_child(services)
 var fake:=preload("res://tests/lado_sombrio_claim/fake_game.gd").new();root.add_child(fake)
 fake.user="00000000-0000-4000-8000-000000000091";fake.access_token="fixture-not-real"
 services.session.client=fake;services.rewards.client=fake
 services.session.user={"id":fake.user};services.session._expires_at=Time.get_unix_time_from_system()+3600;services.session.set_process(false)
 await services.rewards.refresh()
 check(not Catalog.can_access("lado_sombrio"),"no receipt, no access")
 check(Catalog.can_access("pinturas"),"legacy access unchanged")
 check(services.rewards.pending_count()==1,"one manual offer pending")
 var server:=services.duel.local_server
 check(not server.decks().any(func(d:Dictionary)->bool:return d.id=="lado_sombrio"),"local deck hidden")
 var room:=server.call_rpc("qse_duel_create",{"p_name":"Claim test","p_settings":{"deck_ids":["lado_sombrio"],"cards_per_player":3}})
 check(not room.ok,"direct local settings blocked")
 var screen:Control=load("res://scenes/player/deck_library.tscn").instantiate();root.add_child(screen)
 screen._render_deck(Catalog.find_deck("lado_sombrio"));await frames()
 check(screen._deck.is_empty() and screen.find_child("QSEOriginalsBadge",true,false)==null,"direct library route blocked")
 screen.queue_free()
 var host:=preload("res://tests/i18n_expanded/hero_host.gd").new();root.add_child(host)
 host.hero.set_pending_rewards(services.rewards.pending_count());await frames()
 var badge:=host.hero.find_child("HeroNewsPending",true,false) as Control
 check(badge!=null and badge.visible and badge.get_child(0).text=="+1","actual hero shows +1")
 var overlay:=NewsOverlay.new();root.add_child(overlay);await frames()
 check(overlay.find_child("Claim_deck_lado_sombrio",true,false)!=null,"manual claim button shown")
 check(overlay.find_child("RewardCover",true,false).texture!=null,"real pack art preview shown before claiming")
 services.rewards.offers.append({"id":"old_auto","campaign_id":"old_campaign","kind":"skin","claimed":true,"auto_grant":true})
 services.rewards.changed.emit();await frames()
 check(overlay.find_child("RedeemGiftBundle",true,false)==null,"manual offer has no fake bundle confirmation")
 await services.rewards.mark_seen();overlay._close_top();await frames()
 check(services.rewards.pending_count()==1,"opening and ignoring preserve count")
 await services.rewards.refresh()
 check(not Catalog.can_access("lado_sombrio") and services.rewards.pending_count()==1,"refresh preserves pending")
 fake.fail_claim=true
 var result:=await services.rewards.claim("deck_lado_sombrio")
 check(not result.ok and not Catalog.can_access("lado_sombrio") and services.rewards.pending_count()==1,"failed claim cannot grant")
 fake.fail_claim=false
 result=await services.rewards.claim("deck_lado_sombrio")
 check(result.ok and Catalog.can_access("lado_sombrio"),"explicit server receipt unlocks")
 check(services.rewards.pending_count()==0,"manual claim clears badge without reveal")
 host.hero.set_pending_rewards(services.rewards.pending_count())
 check(not badge.visible,"hero badge hides after successful claim")
 check(server.decks().any(func(d:Dictionary)->bool:return d.id=="lado_sombrio"),"cached local catalog unlocks after claim")
 room=server.call_rpc("qse_duel_create",{"p_name":"Claim test","p_settings":{"deck_ids":["lado_sombrio"],"cards_per_player":3}})
 check(room.ok,"claimed pack playable locally")
 var before:=fake.claims
 await services.rewards.claim("deck_lado_sombrio")
 check(fake.claims==before,"client does not resend owned claim")
 await services.rewards.refresh()
 check(Catalog.can_access("lado_sombrio") and services.rewards.pending_count()==0,"server receipt survives refresh")
 fake.user="00000000-0000-4000-8000-000000000092";services.session.user={"id":fake.user};services.rewards.clear()
 check(not Catalog.can_access("lado_sombrio"),"account switch immediately revokes previous preview")
 await services.rewards.refresh()
 check(not Catalog.can_access("lado_sombrio") and services.rewards.pending_count()==1,"other account must redeem independently")
 services.rewards.offers.append({"id":"other_manual","kind":"deck","claimed":false,"auto_grant":false})
 check(services.rewards.pending_count()==2,"multiple pending offers count +2")
 services.session.user={}
 check(not Catalog.can_access("lado_sombrio"),"anonymous cannot use another account receipt")
 print("MANUAL_CLAIM checks=",checks," failures=0")
 quit(0)
