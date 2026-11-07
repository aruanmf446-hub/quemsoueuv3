extends Control
var stages: Array[LobbyStage]=[]
var callback: JavaScriptObject
var names: Array[String]=[]
func _ready() -> void: run.call_deferred()
func run() -> void:
 print("SAMBA_SETUP_START")
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 PlayerUI.apply_theme(self)
 var bg := ColorRect.new();bg.color=PlayerUI.INTERIOR_BG;add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var margin := MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
 var column := VBoxContainer.new();column.add_theme_constant_override("separation",12);margin.add_child(column)
 column.add_child(PlayerUI.label("SAMBA · O MESMO FBX EM PERSONAGENS DIFERENTES",30,PlayerUI.GOLD))
 column.add_child(PlayerUI.label("TESTE DE MOVIMENTO · modelos originais · sem compra ou publicação",20,PlayerUI.MUTED))
 var row := HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(row)
 var group_value := str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('group') || '1'")) if OS.has_feature("web") else OS.get_environment("QSE_SAMBA_GROUP")
 var ids: Array=["cowboy","el_fuego","halloween","lana"]
 if group_value=="2": ids=["michelly","rodrigo","lorena","gus"]
 var entries := CharacterCatalog.load_entries()
 for id in ids:
  print("SAMBA_MODEL ",id)
  var entry: Dictionary=entries[CharacterCatalog.index_of(entries,id)]
  var cell := VBoxContainer.new();cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(cell)
  var title := PlayerUI.label(str(entry.name),28);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cell.add_child(title)
  var stage: LobbyStage=load("res://scenes/lobby/lobby_stage.tscn").instantiate()
  stage.set_script(load("res://scripts/skins/showcase_stage.gd"))
  stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
  cell.add_child(stage);stage.call("prepare_showcase");stage.apply_profile("baixo");stage.show_character(entry)
  stage.get_node("Viewport").msaa_3d=Viewport.MSAA_2X
  stage.static_preview=true
  var player: AnimationPlayer=stage.character.get("_anim_player")
  var clip: Animation=load("res://tests/fbx_dance/generated/"+id+".res")
  player.get_animation_library(&"").add_animation(&"fbx_samba_test",clip)
  stages.append(stage);names.append(str(entry.name))
 print("SAMBA_LAYOUT")
 for i in 6: await get_tree().process_frame
 var report := PlayerContracts.read_json("res://tests/fbx_dance/generated/report.json")
 for stage in stages:
  var id := str(stage.character.character_id)
  for entry: Dictionary in report.avatars:
   if str(entry.id)!=id:continue
   var low := Vector3(entry.bounds_min[0],entry.bounds_min[1],entry.bounds_min[2])
   var high := Vector3(entry.bounds_max[0],entry.bounds_max[1],entry.bounds_max[2])
   stage._target_y=(low.y+high.y)*0.5
   var aspect := maxf(stage.size.x/stage.size.y,0.3)
   var height := maxf((high.y-low.y)*1.12,(high.x-low.x)*1.12/aspect)
   stage._base_distance=height/(2.0*tan(deg_to_rad(LobbyStage.CAMERA_FOV*0.5)))
   stage.set_zoom(1.0)
   for attempt in 20:
    var fits := true
    var pixels: Vector2=stage.get_node("Viewport").size
    for point in 16:
     var angle := TAU*float(point)/16.0
     var projected := stage._camera.unproject_position(Vector3(0.8*cos(angle),0.0,0.8*sin(angle)))
     if projected.x<8 or projected.x>pixels.x-8 or projected.y<8 or projected.y>pixels.y-8:fits=false
    if fits: break
    stage._base_distance*=1.05
    stage.set_zoom(1.0)
 print("SAMBA_READY")
 if not OS.has_feature("web"):
  set_meta("ready",true)
  return
 callback=JavaScriptBridge.create_callback(sample)
 JavaScriptBridge.get_interface("window").qseSambaSample=callback
 JavaScriptBridge.eval("window.qseSambaReady=true")
 sample([0.0])
func sample(args: Array) -> void:
 var time := float(args[0])
 for stage in stages:
  stage.character.set_pose(&"fbx_samba_test",time)
  stage.get_node("Viewport").render_target_update_mode=SubViewport.UPDATE_ALWAYS
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 for stage in stages: stage.get_node("Viewport").render_target_update_mode=SubViewport.UPDATE_DISABLED
 if OS.has_feature("web"): JavaScriptBridge.eval("window.qseSambaFrame="+JSON.stringify({"time":time,"characters":names}))
