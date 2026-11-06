extends SceneTree
## Ilustrações didáticas: personagens e efeitos reais do jogo, com setas explicativas.
## Aproximação/configuração por fixture; não é evidência de percurso.
func _initialize() -> void:call_deferred("run")
func ticks(n: int) -> void:
	for i in n:await physics_frame
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	root.size=Vector2i(1280,480)
	var directory:="res://assets/desert/tutorial"
	DirAccess.make_dir_recursive_absolute(directory+"/source")
	FileAccess.open(directory+"/source/.gdignore",FileAccess.WRITE).store_string("")
	for spec: Array in [[3,"amber"],[4,"dash"],[5,"rupture"]]:
		var selected:=OS.get_cmdline_user_args()
		if not selected.is_empty() and not str(spec[1]) in selected:continue
		var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % spec[0]).instantiate()
		root.add_child(phase)
		current_scene=phase
		phase.set_physics_process(false)
		var player: Node3D=phase._player
		var floor: Dictionary=phase._phase.surfaces[6]
		var x:=float(floor.left)+12.0
		var y:=float(floor.height)
		if spec[1]=="rupture":
			var broken: Dictionary=phase._phase.platforms.filter(func(p: Dictionary) -> bool:return p.get("breakable",false))[0]
			x=float(broken.span_end)+3.0
			y=float(broken.surface_top)
		player.position=Vector3(x,y+0.03,0)
		player.velocity=Vector3.ZERO
		player.facing=1.0
		player._invulnerable=999
		phase._stream_world(x,true)
		for i in 2400:
			if phase._build_queue.is_empty():break
			phase._process(0)
		for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
		for group in ["campaign_pickups","campaign_pedestals"]:
			for item in get_nodes_in_group(group):
				if phase.is_ancestor_of(item):item.hide()
		var cactus: Node3D=phase._create_enemy()
		cactus.reparent(phase._troops)
		cactus.setup(phase._enemy_catalog.cactus,{"patrol":[x-7.0,x+7.0]})
		cactus.position=Vector3(x-2.8 if spec[1]=="amber" else (x-7.0 if spec[1]=="rupture" else x+4.0),y+0.03,0)
		cactus.set_physics_process(false)
		await ticks(12)
		player.restore_charge(spec[1])
		player.use_ability(spec[1])
		if spec[1]=="dash":
			Input.action_press("move_right")
			await ticks(6)
			Input.action_release("move_right")
		else:await ticks(28 if spec[1]=="rupture" else 4)
		player.set_physics_process(false)
		player._model.visible=true
		phase._hud._root.hide()
		phase._hud._flash.hide()
		phase._touch_pad.hide()
		phase._first_use._root.hide()
		var camera: Camera3D=phase._camera
		camera.size=4.3 if spec[1]=="rupture" else 3.4
		var focus: Vector3=player.position+Vector3.UP*1.0
		if spec[1]=="rupture":focus.x-=2.2
		camera.position=focus+Vector3(0,1.1,14.0)
		camera.look_at(focus)
		phase._scenery.follow(camera,player.position.x)
		var layer:=CanvasLayer.new()
		root.add_child(layer)
		var start:=camera.unproject_position(player.position+Vector3(-0.6,2.30,0))
		var end:=camera.unproject_position(player.position+Vector3(-2.7 if spec[1]!="dash" else 2.7,2.30,0))
		var line:=Line2D.new()
		line.width=6.0
		line.default_color=Color("#eac784")
		line.points=PackedVector2Array([start,end])
		layer.add_child(line)
		var direction:=(end-start).normalized()
		var tip:=Polygon2D.new()
		tip.polygon=PackedVector2Array([end,end-direction*21+direction.orthogonal()*12,end-direction*21-direction.orthogonal()*12])
		tip.color=line.default_color
		layer.add_child(tip)
		await ticks(3)
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image()
		image.save_png(directory+"/source/"+str(spec[1])+".png")
		image.resize(960,360,Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGB8)
		image.generate_mipmaps()
		var error:=ResourceSaver.save(ImageTexture.create_from_image(image),directory+"/"+str(spec[1])+".res",ResourceSaver.FLAG_COMPRESS)
		print("POWER_LESSON ",spec[1]," save=",error)
		layer.free()
		phase.free()
		current_scene=null
		paused=false
		await ticks(3)
	quit()
