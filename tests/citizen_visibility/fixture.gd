extends Node
## Offline, export exclusivo de teste. Mesma fase, física, câmera e fila normais.
var phase: Node3D
var callback: JavaScriptObject
var start_x:=-8.0
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 if OS.has_feature("web") and OS.has_feature("citizen_visibility_fixture"):
  callback=JavaScriptBridge.create_callback(probe)
  JavaScriptBridge.get_interface("window").qseCitizenProbe=callback
 open_phase(1)
func open_phase(order: int,checkpoint:=-1) -> void:
 if is_instance_valid(phase):phase.free()
 var run=preload("res://scripts/desert/t15d/campaign_run.gd")
 var saved: Dictionary=run.fresh(order)
 if checkpoint>=0:
  var stage: Dictionary=preload("res://scripts/desert/t15d/campaign_layout.gd").build(order)
  saved.checkpoint=checkpoint
  saved.position=[stage.checkpoints[checkpoint].pos[0],stage.checkpoints[checkpoint].pos[1]]
 start_x=float(saved.position[0])
 run.save("",saved,"start")
 phase=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
 add_child(phase)
func state() -> Dictionary:
 var result:={"tick":Engine.get_physics_frames(),"order":phase._order,"start_x":start_x,"checkpoint":phase._checkpoint_index,"x":phase._player.position.x,"queue":phase._build_queue.size(),"active":phase.is_physics_processing(),"paused":get_tree().paused,"citizens":[]}
 var size:=get_viewport().get_visible_rect().size
 for group in get_tree().get_nodes_in_group("campaign_background_people"):
  for sprite in group.get_children():
   if not sprite is Sprite3D:continue
   var pos: Vector3=sprite.global_position
   var screen: Vector2=phase._camera.unproject_position(pos)
   var w: float=sprite.texture.get_width()/float(sprite.hframes)*sprite.pixel_size
   var h: float=sprite.texture.get_height()/float(sprite.vframes)*sprite.pixel_size
   var corner_a: Vector2=phase._camera.unproject_position(pos+Vector3(-w*0.5,h*0.5,0))
   var corner_b: Vector2=phase._camera.unproject_position(pos+Vector3(w*0.5,-h*0.5,0))
   result.citizens.append({"id":sprite.get_instance_id(),"rect":[corner_a.x/size.x,corner_a.y/size.y,corner_b.x/size.x,corner_b.y/size.y],"species":sprite.get_meta("species"),"x":pos.x,"y":pos.y,"z":pos.z,"screen":[screen.x/size.x,screen.y/size.y],"frustum":phase._camera.is_position_in_frustum(pos),"visible":sprite.is_visible_in_tree()})
 return result
func probe(args: Array) -> void:
 var command:=str(args[0]) if args.size()>0 else "state"
 if command=="photo-freeze":get_tree().paused=true
 if command=="photo-resume":get_tree().paused=false
 if command.begins_with("hide:") or command.begins_with("show:"):
  var sprite:=instance_from_id(command.get_slice(":",1).to_int()) as Sprite3D
  if is_instance_valid(sprite):sprite.visible=command.begins_with("show:")
 if command.begins_with("resume:"):
  var values:=command.split(":")
  open_phase(clampi(values[1].to_int(),1,10),clampi(values[2].to_int(),0,6))
 if command.begins_with("phase:"):open_phase(clampi(command.trim_prefix("phase:").to_int(),1,10))
 JavaScriptBridge.eval("window.qseCitizenState="+JSON.stringify(state()))
