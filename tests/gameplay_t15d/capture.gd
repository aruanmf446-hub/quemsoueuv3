extends SceneTree
var phase: Node3D
var output := "/tmp/t15d"
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func snap(label: String) -> void:
	assert(not phase._player.is_dead and not phase._respawning,"captura exige jogador vivo")
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output+"_"+label+".png")
	assert(result == OK)
	print("CAPTURE ",label," player=",phase._player.position," camera=",phase._camera.position," health=",phase._player.health)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0] if args.size() > 0 else output
	var dimensions := (args[1] if args.size() > 1 else "1920x1080").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	await process_frame
	phase = load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(45)
	await snap("start")
	Input.action_press("move_right")
	await frames(50)
	await snap("run")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(12)
	await snap("jump")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(20)
	await snap("double")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await frames(30)
	Input.action_release("move_left")
	await frames(80)
	Input.action_press("defend")
	phase._player.position = Vector3(12,0.1,0)
	phase._player.velocity = Vector3.ZERO
	await frames(35)
	Input.action_press("defend")
	await frames(40)
	await snap("defend")
	Input.action_release("defend")
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(12)
	await snap("combat")
	await frames(45)
	print("CAPTURE_COMPLETE")
	quit()
