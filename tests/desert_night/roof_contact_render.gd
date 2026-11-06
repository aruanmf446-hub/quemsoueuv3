extends SceneTree
## Regressão gráfica: o piso da colisão deve aparecer SOBRE as lajes azuis dos
## assets reais, e não sobre a mureta marrom. Headless não valida este teste.
const Assets=preload("res://scripts/desert/t15d/kingdom_assets.gd")
var checks:=0
var failures:=0
var records: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func ticks(count: int) -> void:
	for i in count:await physics_frame
func flush(phase: Node3D) -> void:
	for i in 2000:
		if phase._build_queue.is_empty():break
		phase._process(0)
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var args:=OS.get_cmdline_user_args()
	var out:=args[0]
	var dimensions:=args[1].split("x")
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(int(dimensions[0]),int(dimensions[1]))
	DirAccess.make_dir_recursive_absolute(out)
	var phase: Node3D=load("res://scenes/desert/phase_02.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	phase.set_physics_process(false)
	for spec: Array in [[0,"parado",0],[1,"correndo_direita",1],[2,"correndo_esquerda",-1],[4,"borda",0],[0,"salto",0]]:
		var house: Dictionary=phase._phase.surfaces[int(spec[0])]
		var left:=float(house.left)
		var width:=float(house.right)-left
		var top:=float(house.height)
		var label:=str(spec[1])
		var player: Node3D=phase._player
		player.position=Vector3(left+width*(0.88 if label=="borda" else 0.5),top+0.03,0)
		player.velocity=Vector3.ZERO
		player._invulnerable=999
		player.set_physics_process(true)
		player._model.set_process(true)
		phase._stream_world(player.position.x,true)
		flush(phase)
		for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
		# Controle negativo opcional: recria somente na fixture o recorte aninhado
		# que causava a flutuação. Precisa reprovar os pixels, sem mudar a física.
		if args.has("--legacy-atlas"):
			for art: Sprite3D in get_nodes_in_group("playable_house_roofs"):
				if art.has_meta("legacy_fixture"):continue
				var catalog:=Assets.texture(str(art.get_meta("asset_id"))) as AtlasTexture
				var nested:=AtlasTexture.new()
				nested.atlas=catalog
				nested.region=Rect2((art.texture as AtlasTexture).region.position-catalog.region.position,(art.texture as AtlasTexture).region.size)
				nested.filter_clip=true
				art.texture=nested
				art.set_meta("legacy_fixture",true)
		await ticks(16)
		if int(spec[2])!=0:
			Input.action_press("move_right" if int(spec[2])>0 else "move_left")
			await ticks(10)
			Input.action_release("move_right")
			Input.action_release("move_left")
		if label=="salto":
			Input.action_press("jump")
			await ticks(8)
			Input.action_release("jump")
		check(not player.is_on_floor() and player.position.y>top+0.4 if label=="salto" else player.is_on_floor(),label+": contato físico ou salto real")
		player.set_physics_process(false)
		var actor=player._model
		var clip: String=actor._anim_player.assigned_animation
		var time: float=actor._anim_player.current_animation_position
		actor._anim_player.pause()
		actor.set_process(false)
		actor.visible=true
		phase._follow_camera(1.0)
		phase._hud._toast.hide()
		if is_instance_valid(phase._hud._place):phase._hud._place.hide()
		await ticks(3)
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image()
		var points: Array=[]
		# Pontos livres do personagem e das recargas, na altura física exata.
		for fraction: float in ([0.35,0.50,0.65] if label=="borda" else [0.20,0.75,0.85]):
			var screen: Vector2=phase._camera.unproject_position(Vector3(left+width*fraction,top,0))
			screen*=Vector2(image.get_size())/root.get_visible_rect().size
			var pixel:=Vector2i(screen.round())
			var valid:=Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel)
			var color:=image.get_pixelv(pixel) if valid else Color.BLACK
			# Os dois telhados aprovados têm piso azulado e mureta de pedra quente.
			var pavement:=valid and color.b-color.r>0.10 and color.b-color.g>0.10
			check(pavement,"%s: piso visível coincide com colisão em %.2f" % [label,fraction])
			points.append({"screen":[pixel.x,pixel.y],"rgb":[color.r,color.g,color.b],"pavement":pavement})
		var sole:=INF
		# Bake apenas de diagnóstico: mede a sola da malha real, não só o osso.
		for mesh: MeshInstance3D in actor._meshes:
			var baked:=mesh.bake_mesh_from_current_skeleton_pose()
			sole=minf(sole,(mesh.global_transform*baked.get_aabb()).position.y)
		check(sole>top+0.4 if label=="salto" else absf(sole-top)<0.12,label+": sola real apoiada ou elevada no salto")
		var error:=image.save_png(out+"/"+label+".png")
		check(error==OK,label+": captura real salva")
		records.append({"name":label,"house":int(spec[0]),"grounded":player.is_on_floor(),"sole_above_roof":sole-top,"clip":clip,"clip_time":time,"pixels":points,"fixture_teleport":true})
		actor.set_process(true)
		actor._anim_player.play(clip)
		actor._anim_player.seek(time,true)
	phase.free()
	current_scene=null
	FileAccess.open(out+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"graphical":true,"legacy_fixture":args.has("--legacy-atlas"),"physical_device":false,"records":records},"\t"))
	print("ROOF_CONTACT_RENDER checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
