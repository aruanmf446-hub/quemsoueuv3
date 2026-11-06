extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value: failures+=1
func settle() -> void:
	for i in 3: await process_frame
func run() -> void:
	var slot := CharacterSlot.new()
	root.add_child(slot)
	var entries := CharacterCatalog.load_all()
	for entry: Dictionary in entries.playable:
		var emotes := CharacterCatalog.emotes_for(entry)
		check(emotes.size()==3,str(entry.id)+" expõe os três FBX existentes")
	check(CharacterCatalog.emotes_for(entries.unlockable[0]).is_empty(),"ações de El Fuego não viram emotes")
	slot.load_entry(entries.playable[0])
	var player: AnimationPlayer=slot.get("_anim_player")
	var previous := player.assigned_animation
	var skeleton: Skeleton3D=slot.get("_skeleton")
	await settle()
	var pose: Array[Transform3D]=[]
	for bone in skeleton.get_bone_count(): pose.append(skeleton.get_bone_pose(bone))
	check(not slot.play_emote(&"inexistente"),"clipe ausente não altera a pose")
	for emote: Dictionary in CharacterCatalog.emotes_for(entries.playable[0]):
		check(slot.play_emote(StringName(emote.animation)),"inicia "+str(emote.name))
		check(player.current_animation==emote.animation and player.is_playing(),"emote em reprodução")
		player.advance(player.get_animation(emote.animation).length+0.1)
		await settle()
		check(slot.is_static_pose and not player.is_playing() and player.assigned_animation==previous,"terminar restaura a pose inicial")
		var restored := true
		for bone in skeleton.get_bone_count():
			if not pose[bone].is_equal_approx(skeleton.get_bone_pose(bone)): restored=false
		check(restored,"ossos retornam à pose anterior ao emote")
	slot.play_animation(&"anim_2",true)
	var original_loop := player.get_animation(&"anim_2").loop_mode
	slot.play_emote(&"anim_2")
	check(player.get_animation(&"anim_2").loop_mode==Animation.LOOP_NONE,"mesmo clipe do lobby toca uma única vez")
	player.advance(player.get_animation(&"anim_2").length+0.1)
	await settle()
	check(player.current_animation=="anim_2" and player.is_playing() and player.get_animation(&"anim_2").loop_mode==original_loop,"retorno restaura o loop do lobby")
	slot.play_emote(&"anim_4")
	slot.play_animation(&"anim_3",false)
	player.advance(player.get_animation(&"anim_3").length+0.1)
	await settle()
	check(player.assigned_animation=="anim_3" and slot.get("_emote_restore").is_empty(),"reação automática interrompe emote sem retorno atrasado")
	slot.play_emote(&"anim_4")
	slot.play_emote(&"anim_3")
	player.advance(player.get_animation(&"anim_3").length+0.1)
	await settle()
	check(slot.get("_emote_restore").is_empty(),"troca de emote não deixa restauração pendente")
	slot.unload()
	check(slot.get("_emote_restore").is_empty(),"liberação limpa o estado do emote")
	slot.queue_free();await settle()
	print("SKIN_EMOTES checks=",checks," failures=",failures)
	quit(1 if failures else 0)
