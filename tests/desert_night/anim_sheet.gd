extends SceneTree
## Folha de quadros de cada clipe do protagonista/Cactus, amostrados pelo tempo da fonte.
## Ferramenta de revisão de animação; não participa das regras do jogo.
## -- <output_prefix> <el_fuego|cactus>
const ActorSlot = preload("res://scripts/desert/t15d/actor_slot.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if args.size() > 0 else "/tmp/anim"
	var who := args[1] if args.size() > 1 else "el_fuego"
	root.size = Vector2i(400,400)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#30405a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	world.add_child(env)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	camera.position = Vector3(0,0.9,6)
	world.add_child(camera)
	camera.current = true
	var floor_line := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(4,0.01,0.01)
	floor_line.mesh = bar
	world.add_child(floor_line)
	var slot := ActorSlot.new()
	world.add_child(slot)
	slot.rotation.y = PI*0.5
	var entry: Dictionary
	if who == "cactus":
		entry = JSON.parse_string(FileAccess.get_file_as_string("res://data/desert_enemies.json")).enemies.cactus
	else:
		for item: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json")).unlockable:
			if item.id == who: entry = item
	slot.load_entry(entry)
	await process_frame
	var player: AnimationPlayer = slot._anim_player
	var only := args[2] if args.size() > 2 else ""
	for anim_name in player.get_animation_list():
		if only != "" and anim_name != only: continue
		var length := player.get_animation(anim_name).length
		var start := float(args[3]) if args.size() > 3 else 0.0
		if args.size() > 4: length = float(args[4])-start
		var count := 12
		var sheet := Image.create(200*count,200,false,Image.FORMAT_RGBA8)
		for index in range(count):
			var t := start+length*index/float(count-1)
			player.play(anim_name)
			player.seek(t,true)
			player.pause()
			slot._process(1.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			image.resize(200,200)
			sheet.blit_rect(image,Rect2i(0,0,200,200),Vector2i(index*200,0))
		sheet.save_png("%s_%s.png" % [output,anim_name])
		print("CLIP ",anim_name," length=",length)
	quit()
