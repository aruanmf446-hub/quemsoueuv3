extends SceneTree
class Slow extends "res://tests/ability_refills/fake_game.gd":
 var refill_hold:=true
 func call_rpc(rpc:String,params:Dictionary={}) -> Dictionary:
  if rpc=="qse_ability_refills":
   while refill_hold:await get_tree().process_frame
  return await super.call_rpc(rpc,params)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var services:=PlayerServices.new();root.add_child(services)
 var fake:=Slow.new();root.add_child(fake);fake.access_token="fixture"
 services.session.client=fake;services.ability_refills.client=fake
 services.session.user={"id":"00000000-0000-4000-8000-000000000089"};services.session._expires_at=Time.get_unix_time_from_system()+86400;services.session.set_process(false)
 var ui:=preload("res://tests/ability_refills/visual.gd").new();root.add_child(ui)
 ui._session.show_settings();ui._session.show_refills()
 for i in 4:await process_frame
 if services.ability_refills.state!="loading":quit(1);return
 ui._session.show_settings()
 fake.refill_hold=false
 for i in 8:await process_frame
 if services.ability_refills.state!="success" or ui._session._page!="settings" or not paused:quit(1);return
 ui._resume();ui.queue_free();services.queue_free();fake.queue_free()
 for i in 3:await process_frame
 print("ABILITY_REFILLS_LIFECYCLE PASS");quit()
