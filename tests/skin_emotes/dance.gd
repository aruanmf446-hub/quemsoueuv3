extends SceneTree
const DANCE=preload("res://scripts/skins/dance_preview.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value: failures+=1
func run() -> void:
	var slot := CharacterSlot.new()
	root.add_child(slot)
	for entry: Dictionary in CharacterCatalog.load_entries():
		slot.load_entry(entry)
		check(not slot.has_animation(DANCE.ALIAS),str(entry.id)+" não altera o modelo original")
		check(DANCE.install(slot) and DANCE.install(slot),str(entry.id)+" prepara uma única dança demonstrativa")
		var player: AnimationPlayer=slot.get("_anim_player")
		var skeleton: Skeleton3D=slot.get("_skeleton")
		slot.play_emote(DANCE.ALIAS)
		player.advance(0.2)
		player.seek(0.0,true)
		var pose: Array=[]
		for bone in skeleton.get_bone_count(): pose.append(skeleton.get_bone_pose(bone))
		player.advance(0.375)
		var moving := false
		for bone in skeleton.get_bone_count():
			if not pose[bone].is_equal_approx(skeleton.get_bone_pose(bone)): moving=true
		check(moving,str(entry.id)+" dança com seu esqueleto original")
		player.advance(5.0)
		check(slot.is_static_pose and not player.is_playing(),str(entry.id)+" retorna à pose anterior")
	slot.queue_free()
	await process_frame
	print("DANCE_PREVIEW checks=",checks," failures=",failures)
	quit(1 if failures else 0)
