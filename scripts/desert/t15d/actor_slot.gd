extends CharacterSlot
## Clipes exclusivos desta fase: remove deslocamento de raiz que afastava o visual da cápsula.
var _flash_left := 0.0
var _flash_material: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _ground_offsets := {}
func load_entry(entry: Dictionary) -> void:
	super.load_entry(entry)
	_meshes.clear()
	for mesh: MeshInstance3D in _model_root.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mesh)
	if _anim_player == null or _skeleton == null: return
	var lib := _anim_player.get_animation_library(&"").duplicate(true) as AnimationLibrary
	_anim_player.remove_animation_library(&"")
	_anim_player.add_animation_library(&"", lib)
	for name in lib.get_animation_list():
		var clip := lib.get_animation(name)
		for track in range(clip.get_track_count()):
			if clip.track_get_type(track) != Animation.TYPE_POSITION_3D: continue
			var path := str(clip.track_get_path(track))
			if not "Hips" in path: continue
			var bone := _skeleton.find_bone(path.get_slice(":", 1))
			if bone < 0: continue
			var rest := _skeleton.get_bone_rest(bone).origin
			for key in range(clip.track_get_key_count(track)):
				var value: Vector3 = clip.track_get_key_value(track, key)
				value.x = rest.x
				value.z = rest.z
				clip.track_set_key_value(track, key, value)
	# O FBX de ataque contém uma sequência longa. O primeiro golpe passa a casar com a hitbox.
	if entry.id == "el_fuego" and lib.has_animation(&"ataque"):
		lib.get_animation(&"ataque").length = 0.95
	# Repouso em guarda derivado dos próprios ossos/clipe, sem congelar uma pose de corrida.
	if lib.has_animation(&"ataque"):
		var source := lib.get_animation(&"ataque")
		var idle := Animation.new()
		idle.length = 2.4
		idle.loop_mode = Animation.LOOP_LINEAR
		for track in range(source.get_track_count()):
			if source.track_get_key_count(track) == 0: continue
			var target := idle.add_track(source.track_get_type(track))
			idle.track_set_path(target, source.track_get_path(track))
			var value: Variant = source.track_get_key_value(track, 0)
			idle.track_insert_key(target, 0.0, value)
			if source.track_get_type(track) == Animation.TYPE_ROTATION_3D and "Spine" in str(source.track_get_path(track)):
				idle.track_insert_key(target, 1.2, (value as Quaternion) * Quaternion(Vector3.RIGHT, 0.015))
			idle.track_insert_key(target, 2.4, value)
		lib.add_animation(&"pronto", idle)
	# Mantém as solas junto à cápsula ao trocar de clipe, sem bake por quadro.
	var base_y := _model_root.position.y
	for name in lib.get_animation_list():
		if name not in ["base","pronto","defesa","agachado","ataque","pulo","pulo_duplo","retorno"]: continue
		_anim_player.play(name)
		_anim_player.seek(0.0,true)
		_skeleton.force_update_all_bone_transforms()
		var feet := INF
		for bone in range(_skeleton.get_bone_count()):
			if "ToeBase" in _skeleton.get_bone_name(bone):
				var point := to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(bone).origin))
				feet = minf(feet,point.y)
		_ground_offsets[String(name)] = base_y+0.035-feet if is_finite(feet) else base_y
	_model_root.position.y = base_y


func play_animation(anim_name: StringName, loop: bool = true) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name): return
	if _anim_player.current_animation == String(anim_name) and _anim_player.is_playing(): return
	var speed := 1.0
	if character_id == &"el_fuego":
		match String(anim_name):
			"base": speed = 1.65
			"ataque": speed = 0.95 / 0.52
			"pulo": speed = 2.3
			"pulo_duplo": speed = 1.4
			"retorno": speed = 3.0
	_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	is_static_pose = false
	_anim_player.play(anim_name, 0.07, speed)

func flash(color: Color) -> void:
	_flash_left = 0.09
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(color, 0.48)
	for mesh in _meshes:
		mesh.material_overlay = _flash_material

func _process(delta: float) -> void:
	if is_instance_valid(_model_root) and is_instance_valid(_anim_player):
		var target := float(_ground_offsets.get(_anim_player.assigned_animation,0.0))
		_model_root.position.y = lerpf(_model_root.position.y,target,1.0-exp(-24.0*delta))
	if _flash_left <= 0.0: return
	_flash_left -= delta
	if _flash_left <= 0.0:
		for mesh in _meshes:
			mesh.material_overlay = null
		_flash_material = null
