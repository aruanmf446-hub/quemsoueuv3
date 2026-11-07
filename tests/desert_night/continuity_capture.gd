extends SceneTree
## Capturas de posições explícitas. O apoio é assentado pela física; não prova percurso.
var phase: Node3D
var output: String
func _initialize() -> void:call_deferred("run")
func shot(label: String) -> void:
 phase._player._model.show()
 for i in 3:phase._follow_camera(1.0)
 phase._scenery.follow(phase._camera,phase._player.position.x)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_jpg(output+"/"+label+".jpg",0.94)
 print("CONTINUITY_CAPTURE ",label," grounded=",phase._player.is_on_floor())
func run() -> void:
 if DisplayServer.get_name()=="headless":quit(1);return
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 var args:=OS.get_cmdline_user_args()
 output=args[0]
 DirAccess.make_dir_recursive_absolute(output)
 var size:=args[1].split("x")
 root.size=Vector2i(int(size[0]),int(size[1]))
 for order in [1,5,6,7,9]:
  phase=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
  root.add_child(phase)
  phase.set_physics_process(false)
  var route: Dictionary=phase._phase.platforms.filter(func(p: Dictionary) -> bool:return p.get("parkour_route",false))[0]
  var at:=Vector3(float(route.span_start)+0.7,float(route.pos[1])+float(route.size[1])*0.5+0.04,0)
  phase._player.position=at
  phase._stream_world(at.x,true)
  for i in 2400:
   if phase._build_queue.is_empty():break
   phase._process(0)
  for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
  for i in 20:await physics_frame
  if not phase._player.is_on_floor():quit(1);return
  phase._player.set_physics_process(false)
  await shot("parkour_%02d" % order)
  phase.free()
  await process_frame
 phase=load("res://scenes/desert/phase_04.tscn").instantiate()
 root.add_child(phase)
 phase.set_physics_process(false)
 var task: Dictionary=phase._phase.tasks[0]
 phase._stream_world(float(task.start),true)
 for i in 2400:
  if phase._build_queue.is_empty():break
  phase._process(0)
 for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
 var device: Node3D=get_nodes_in_group("earth_bridges").filter(func(n: Node) -> bool:return phase.is_ancestor_of(n) and n.hole.id==task.id)[0]
 for step in 2:
  phase._player.set_physics_process(true)
  phase._player.position=device.action_point(step)+Vector3.UP*0.04
  phase._player.velocity=Vector3.ZERO
  for i in 15:await physics_frame
  phase._update_bridge_hint()
  phase._player.set_physics_process(false)
  await shot("task_etapa_%d" % (step+1))
  phase._raise_earth_bridge()
 for i in 60:await physics_frame
 phase._player.set_physics_process(false)
 await shot("task_passagem_pronta")
 phase.free()
 quit(0)
