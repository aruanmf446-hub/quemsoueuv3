extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 var args:=OS.get_cmdline_user_args()
 var size:=args[0].split("x")
 root.size=Vector2i(int(size[0]),int(size[1]))
 for order in [4]:
  var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
  root.add_child(phase)
  current_scene=phase
  phase.set_physics_process(false)
  var floor: Dictionary=preload("res://scripts/desert/t15d/campaign_layout.gd").floor_at(phase._phase,35.0)
  phase._player.position=Vector3(35.0,float(floor.height)+0.03,0)
  phase._stream_world(35,true)
  for i in 2400:
   if phase._build_queue.is_empty():break
   phase._process(0)
  for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
  for i in 20:await physics_frame
  phase._player.set_physics_process(false)
  for i in 3:phase._follow_camera(1.0)
  phase._scenery.follow(phase._camera,phase._player.position.x)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_jpg(args[1]+"/fase_%02d.jpg" % order,0.94)
  phase.free()
  await process_frame
 quit()
