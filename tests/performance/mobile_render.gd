extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.mode = Window.MODE_WINDOWED
 root.size = Vector2i(844,390)
 var phase: Node = load("res://scenes/desert/phase_01.tscn").instantiate()
 root.add_child(phase)
 current_scene = phase
 for frame in 40: await physics_frame
 while not phase._build_queue.is_empty(): await process_frame
 await RenderingServer.frame_post_draw
 print("MOBILE_PRIMITIVES ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
 root.get_texture().get_image().save_png("/tmp/qse-native-perf.png")
 for actor in get_nodes_in_group("player") + get_nodes_in_group("enemies"):
  for mesh in actor.find_children("*", "MeshInstance3D", true, false): mesh.lod_bias = 1.0
 for frame in 10: await physics_frame
 await RenderingServer.frame_post_draw
 print("BASELINE_PRIMITIVES ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
 quit()
