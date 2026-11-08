extends Node
## Offline fixture: real library UI and bundled art, never backend calls.
class OfflineSession extends SessionService:
 func _ready() -> void:set_process(false)
 func authenticated() -> bool:return false
var ui: Control
var callback: JavaScriptObject
func _ready() -> void:
 var services=preload("res://tests/story_continuity/account_merge.gd").TestServices.new()
 add_child(services);PlayerServices.current=services
 services.session=OfflineSession.new();services.add_child(services.session)
 ui=load("res://scenes/player/deck_library.tscn").instantiate()
 add_child(ui)
 ui._stats_state="ok";ui._stats_at=Time.get_ticks_msec()/1000.0
 # Distinct metrics deliberately give different winners, including a community deck.
 ui._stats={"creator:fixture":{"score":90,"favorites":3,"downloads":20},"official:lendas_urbanas":{"score":10,"favorites":12,"downloads":0}}
 ui._demo_entries.assign([{"id":"fixture","ref":"creator:fixture","name":"[TESTE] Comunidade","creator":"Criador de teste","origin":"community","category":"Fantasia","count":9,"cover":"res://assets/duel/decks/oficial/lendas_urbanas/momo.png","images":["res://assets/duel/decks/oficial/lendas_urbanas/momo.png"]}])
 ui._render_library()
 for i in 30:await get_tree().process_frame
 assert(ui.find_child("OpenManualReview",true,false)==null)
 var banner: Control=ui.find_child("FeaturedBanner",true,false)
 var filters: Control=ui.find_child("FilterPanel",true,false)
 assert(banner!=null and filters.get_global_rect().position.y>=banner.get_global_rect().end.y)
 var entries: Array[Dictionary]=[{"ref":"creator:fixture","name":"Comunidade"},{"ref":"official:lendas_urbanas","name":"Oficial"}]
 ui._sort="saved";assert(ui._sorted(entries.duplicate())[0].name=="Oficial")
 ui._sort="downloads";assert(ui._sorted(entries.duplicate())[0].name=="Comunidade")
 ui._sort="popular";assert(ui._sorted(entries.duplicate())[0].name=="Comunidade")
 ui._tab="Populares"
 assert(ui._sort_options().any(func(option:Array)->bool:return option[0]=="downloads"))
 ui._stats["creator:fixture"].erase("downloads");ui._stats["official:lendas_urbanas"].erase("downloads")
 assert(not ui._sort_options().any(func(option:Array)->bool:return option[0]=="downloads"))
 ui._tab="Descobrir";ui._sort=""
 print("PASS banner, filtros, ranking comunidade, favoritos e compatibilidade sem downloads")
 if OS.has_feature("web"):
  callback=JavaScriptBridge.create_callback(_command)
  JavaScriptBridge.get_interface("window").qseLibraryCommand=callback
  JavaScriptBridge.eval("window.qseLibraryReady=true")
func _command(args: Array) -> void:
 ui._select_tab(str(args[0]))
