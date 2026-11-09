extends SceneTree
class FakeMusic extends Node:
 var paused:=false
 var id:="first"
 func available_tracks()->Array:return [{"id":id}]
 func current_track()->Dictionary:return {"id":id,"title":"Fixture music"}
 func track_length()->float:return 100.0
 func playback_position()->float:return 20.0
var checks:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:
  push_error(message);quit(1);assert(ok,message)
func frames()->void:
 for i in 6:await process_frame
func choose(screen:Control,id:String,value:bool)->void:
 var card:=screen.find_child("DeckChoice_"+id,true,false) as Button
 card.toggled.emit(value)
 card.find_child("AcceptSelection",true,false).pressed.emit()
 await frames()
func run()->void:
 root.size=Vector2i(1672,941)
 if OS.get_cmdline_user_args().size():
  var parts:=OS.get_cmdline_user_args()[0].split("x")
  root.size=Vector2i(int(parts[0]),int(parts[1]))
 UIScale.apply_device_profile(root)
 var services:=PlayerServices.new();root.add_child(services)
 var fake:=preload("res://tests/duel_t26/fake_game.gd").new();root.add_child(fake)
 services.duel.client=fake
 services.session.client=fake;fake.access_token="fixture-not-real"
 services.session.user={"id":"00000000-0000-4000-8000-000000000931"}
 services.session._expires_at=Time.get_unix_time_from_system()+3600;services.session.set_process(false)
 var screen:Control=load("res://scenes/player/duel.tscn").instantiate();root.add_child(screen)
 screen.show_screen();await screen._open_form();await frames()
 check(screen._form.decks.is_empty(),"online create starts with zero decks despite server defaults")
 screen._submit_form();await frames()
 check(fake.created.is_empty(),"no room RPC without deck selection")
 check(screen.find_child("DeckTab_Comprados",true,false)==null,"commerce filter hidden")
 var footer:=screen.find_child("FormActions",true,false) as Control
 check(footer.get_parent()==screen.get_node("Margin/Column"),"actions outside scroll")
 var button:=screen.find_child("SubmitRoom",true,false) as Control
 check(button.get_global_rect().end.y<=root.get_visible_rect().size.y,"whole submit button within viewport")
 for tab in ["Favoritos","Bombando","Meus decks"]:
  screen._deck_tab=tab;screen._refresh_deck_grid();await frames()
  var label:=screen.find_child("DeckEmpty",true,false) as Label
  check(label!=null and label.size.x>=250 and label.size.y<=160,"empty message readable: "+tab)
 screen._deck_tab="Todos";screen._refresh_deck_grid();await frames()
 await choose(screen,"lendas_urbanas",true);await choose(screen,"demo_terror",true)
 check(screen._form.decks.size()==2,"multiple decks still supported with per-card confirmation")
 await choose(screen,"lendas_urbanas",false);await choose(screen,"demo_terror",false)
 check(screen._form.decks.is_empty(),"can clear all selections before submit")
 await services.duel.use_local();await screen._open_form();await frames()
 check(screen._form.decks.is_empty(),"local create starts with zero decks")
 screen.queue_free();await frames()
 services.session.user={};fake.access_token=""
 var library:Control=load("res://scenes/player/deck_library.tscn").instantiate();root.add_child(library);library.show_screen();await frames()
 check(library.find_child("GuestDeckPreview",true,false)!=null and library.find_child("GuestDeckTile",true,false)!=null,"guest invitation above and after deck list")
 var grid:=library.find_child("DeckGrid",true,false) as GridContainer
 var teaser:=library.find_child("GuestDeckTile",true,false) as Control
 check(teaser.get_index()==grid.get_child_count()-1,"invitation last after real decks")
 check(is_equal_approx(teaser.custom_minimum_size.x,(grid.get_child(0) as Control).custom_minimum_size.x),"invitation has same tile width")
 for tab:String in ["Populares","Recentes"]:
  library._tab=tab;library._update_results();await frames()
  var title:=library.find_child("ResultsTitle",true,false) as Label
  check(not title.text.contains("("),"heading without quantity: "+tab)
 library.queue_free();await frames()
 var skins:Control=load("res://scripts/skins/skins_panel.gd").new();skins.services=services
 check(not skins._character_visible("lorena"),"Lorena hidden by common gallery/preview predicate")
 check(not services.inventory.entry("lorena").is_empty(),"Lorena model and inventory preserved")
 skins.free()
 var host:=Control.new();root.add_child(host);host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var player:Control=load("res://scripts/audio/now_playing.gd").new();host.add_child(player)
 var music:=FakeMusic.new();root.add_child(music);player._music=music;player._refresh();await frames()
 player.set_duel_notice(true);player.set_mini(true)
 check(not player.visible,"no permanent player when entering duel")
 music.id="next";player._refresh()
 check(player.visible and player._notice_left>0,"new track shows transient notice")
 check(is_equal_approx(player.position.y,host.size.y-player.size.y-24),"notice at bottom-right")
 player._process(5.1)
 check(not player.visible and not music.paused,"notice expires without stopping playback")
 player.set_duel_notice(false)
 check(player.visible and is_equal_approx(player.modulate.a,1.0),"other routes retain visible player")
 check(is_equal_approx(player.position.y,16),"other mini routes keep original placement")
 host.queue_free();music.queue_free();services.queue_free();fake.queue_free()
 await frames()
 await create_timer(0.25).timeout
 print("DUEL_POLISH_BATCH_1 checks=",checks," failures=0");quit(0)
