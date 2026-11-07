extends SceneTree
## Fixtures de posição para revisão visual; não simulam uma travessia completa.
const Layout=preload("res://scripts/desert/t15d/campaign_layout.gd")
var failures:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
 if DisplayServer.get_name()=="headless":push_error("Precisa de renderização real");quit(1);return
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 var args:=OS.get_cmdline_user_args()
 var output:=args[0]
 var size:=args[1].split("x")
 root.size=Vector2i(int(size[0]),int(size[1]))
 DirAccess.make_dir_recursive_absolute(output)
 var selected: Array=[]
 for arg in args:
  if arg.begins_with("--phases="):
   for value in arg.trim_prefix("--phases=").split(","):selected.append(int(value))
 for order in range(1,10):
  if not selected.is_empty() and not selected.has(order):continue
  var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
  root.add_child(phase)
  current_scene=phase
  phase.set_physics_process(false)
  for sample in [35.0,740.0,1390.0]:
   var floor:=Layout.floor_at(phase._phase,sample)
   var x: float=sample
   if floor.is_empty() or floor.get("task_void",false):
    floor=phase._phase.surfaces.filter(func(s: Dictionary) -> bool:return not s.get("task_void",false) and float(s.left)>sample)[0]
    x=float(floor.left)+3.0
   elif sample!=35.0:x=float(floor.left)+3.0
   phase._player.set_physics_process(false)
   phase._player.position=Vector3(x,float(floor.height)+0.04,0)
   phase._player.velocity=Vector3.ZERO
   phase._player._invulnerable=999
   phase._stream_world(x,true)
   for i in 2400:
    if phase._build_queue.is_empty():break
    phase._process(0)
   for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
   phase._player.set_physics_process(true)
   for i in 16:await physics_frame
   if not phase._player.is_on_floor():failures+=1
   phase._player.set_physics_process(false)
   phase._player._model.show()
   for i in 3:phase._follow_camera(1.0)
   phase._scenery.follow(phase._camera,phase._player.position.x)
   await process_frame
   await RenderingServer.frame_post_draw
   var file:=output+"/fase_%02d_x%04d.jpg" % [order,int(sample)]
   var error:=root.get_texture().get_image().save_jpg(file,0.94)
   if error!=OK:failures+=1
   print("REVISION_CAPTURE ",file," world_x=",phase._player.position.x," grounded=",phase._player.is_on_floor()," result=",error)
  phase.free()
  current_scene=null
  await process_frame
 print("REVISION_CAPTURE failures=",failures)
 quit(1 if failures else 0)
