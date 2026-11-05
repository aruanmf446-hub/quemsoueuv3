extends SceneTree
## Exercita os FBX originais, não animações sintetizadas. Sem rede.
var checks := 0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		push_error("AVATAR_FAIL "+message)
		quit(1)
		assert(value,message)
func _initialize() -> void: call_deferred("_run")
func settle() -> void:
	for i in 5: await process_frame
func _run() -> void:
	root.size=Vector2i(844,390)
	var stage: LobbyStage=preload("res://scenes/lobby/lobby_stage.tscn").instantiate()
	stage.profile_name="baixo"
	root.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else ""
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for entry: Dictionary in CharacterCatalog.load_all().playable:
		stage.show_character(entry)
		for alias: String in ["anim_2","anim_3","anim_4"]:
			check(stage.character.has_animation(StringName(alias)),str(entry.id)+" "+alias+" existe")
			stage.character.play_animation(StringName(alias),alias=="anim_2")
			var player: AnimationPlayer=stage.character.get("_anim_player")
			var clip := player.get_animation(alias)
			check(clip.length>0.3 and clip.get_track_count()>0,str(entry.id)+" "+alias+" tem movimento")
			var skeleton: Skeleton3D=stage.character.get("_skeleton")
			player.seek(0.0,true)
			var before: Array=[]
			for bone in skeleton.get_bone_count(): before.append(skeleton.get_bone_pose(bone))
			player.seek(minf(1.2,clip.length*0.5),true)
			var moved := false
			for bone in skeleton.get_bone_count():
				if not before[bone].is_equal_approx(skeleton.get_bone_pose(bone)): moved=true
			check(moved,str(entry.id)+" "+alias+" move o esqueleto do modelo principal")
			print("AVATAR_CLIP ",entry.id," ",alias," seconds=",clip.length)
			if not output.is_empty() and entry.id=="cowboy":
				player.pause()
				await settle()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output+"/cowboy_"+alias+".png")
	var fuego: Dictionary=CharacterCatalog.load_all().unlockable[0]
	stage.show_character(fuego)
	check(not stage.character.has_animation(&"anim_2") and not stage.character.has_animation(&"anim_3") and not stage.character.has_animation(&"anim_4"),"não inventa clipes para El Fuego")
	check(stage.character.has_animation(&"ataque") and stage.character.has_animation(&"defesa"),"clipes originais de gameplay de El Fuego preservados")
	var second := CharacterSlot.new()
	root.add_child(second)
	var cowboy: Dictionary=CharacterCatalog.load_all().playable[0]
	stage.show_character(cowboy)
	second.load_entry(cowboy)
	stage.character.play_animation(&"anim_4",false)
	second.play_animation(&"anim_4",true)
	check(stage.character.get("_anim_player").get_animation("anim_4").loop_mode==Animation.LOOP_NONE,"biblioteca não compartilha alterações de loop entre avatares")
	second.queue_free()
	if AudioServer.get_bus_index("Music")<0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count-1,"Music")
	var music := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music,-7.0)
	var effects := AudioServer.get_bus_effect_count(music) if music>=0 else 0
	var volume := AudioServer.get_bus_volume_db(music) if music>=0 else 0.0
	var sequence := preload("res://scripts/ui/battle/avatar_sequence.gd").new()
	root.add_child(sequence)
	sequence.present([{"nickname":"Teste","skin_id":"cowboy"}],"anim_2",0.4,true)
	await sequence.finished
	await settle()
	if music>=0:
		check(AudioServer.get_bus_effect_count(music)==effects,"duck removido após apresentação")
		check(is_equal_approx(AudioServer.get_bus_volume_db(music),volume),"volume escolhido pelo jogador preservado")
	# Saída durante a apresentação também restaura o bus.
	sequence=preload("res://scripts/ui/battle/avatar_sequence.gd").new()
	root.add_child(sequence)
	sequence.present([{"nickname":"Teste","skin_id":"cowboy"}],"anim_2",4.0,true)
	await settle()
	sequence.queue_free()
	await settle()
	if music>=0: check(AudioServer.get_bus_effect_count(music)==effects,"duck removido ao sair")
	stage.queue_free()
	await settle()
	print("AVATAR_PASS ",checks)
	quit(0)
