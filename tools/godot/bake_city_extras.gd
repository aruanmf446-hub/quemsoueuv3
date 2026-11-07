extends SceneTree
## Renderiza os modelos oficiais em sprites completos para figurantes do fundo.
## Nenhum modelo/skeleton extra é instanciado durante o jogo.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 if DisplayServer.get_name()=="headless":quit(1);return
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(256,384)
 viewport.transparent_bg=true
 viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var environment:=WorldEnvironment.new()
 environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color(0,0,0,0)
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("#e7e3d9")
 environment.environment.ambient_light_energy=0.7
 viewport.add_child(environment)
 var key:=DirectionalLight3D.new()
 key.rotation_degrees=Vector3(-28,-32,0)
 key.light_energy=1.5
 viewport.add_child(key)
 var camera:=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=2.15
 camera.position=Vector3(0,0.98,6)
 viewport.add_child(camera)
 camera.look_at(Vector3(0,0.98,0))
 camera.current=true
 var entries: Array=CharacterCatalog.load_entries()
 var cactus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/desert_enemies.json")).enemies.cactus
 entries=entries.filter(func(e: Dictionary) -> bool:return e.id in ["michelly","rodrigo","lana"])
 entries.append(cactus)
 DirAccess.make_dir_recursive_absolute("res://assets/desert/city_people")
 for entry: Dictionary in entries:
  var model:=preload("res://scripts/desert/t15d/actor_slot.gd").new()
  viewport.add_child(model)
  var minimal:=entry.duplicate(true)
  minimal.animations={"base":entry.animations.base}
  model.load_entry(minimal)
  model.rotation.y=PI*0.5 if entry.id=="cactus" else PI*0.12
  for i in 3:await process_frame
  var frames:=4 if entry.id=="cactus" else 1
  var atlas:=Image.create(256*frames,384,false,Image.FORMAT_RGBA8)
  atlas.fill(Color.TRANSPARENT)
  for frame in frames:
   model.set_pose("base",float(frame)*0.18 if entry.id=="cactus" else 0.0)
   await process_frame
   await RenderingServer.frame_post_draw
   var picture:=viewport.get_texture().get_image()
   atlas.blit_rect(picture,Rect2i(0,0,256,384),Vector2i(frame*256,0))
  var path:="res://assets/desert/city_people/"+str(entry.id)+".png"
  var result:=atlas.save_png(path)
  print("CITY_PEOPLE_BAKE ",entry.id," frames=",frames," result=",result)
  model.free()
 viewport.free()
 quit(0)
