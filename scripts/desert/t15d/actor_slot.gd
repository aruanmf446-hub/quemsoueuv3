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
	# O FBX de ataque é um combo (passo, investida e mortal). O golpe usa só a investida:
	# agacha, estende o braço no quadro de impacto e volta a ficar de pé, sem o mortal final.
	if entry.id == "el_fuego" and lib.has_animation(&"ataque"):
		lib.add_animation(&"golpe", _excerpt(lib.get_animation(&"ataque"), 0.42, 0.76))
	# Queda: pose do próprio salto com as pernas estendidas procurando o chão.
	if entry.id == "el_fuego" and lib.has_animation(&"pulo"):
		var fall := _excerpt(lib.get_animation(&"pulo"), 1.02, 1.12)
		fall.loop_mode = Animation.LOOP_PINGPONG
		lib.add_animation(&"queda", fall)
		# Aterrissagem: o agachamento de amortecimento do mesmo clipe.
		lib.add_animation(&"aterrissagem", _excerpt(lib.get_animation(&"pulo"), 1.32, 1.70))
	# O FBX "retorno" é um recuo para trás seguido de recuperação: vira a reação ao dano.
	if entry.id == "el_fuego" and lib.has_animation(&"retorno"):
		lib.add_animation(&"dano", _excerpt(lib.get_animation(&"retorno"), 0.15, 0.75))
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
		if name not in ["base","pronto","defesa","agachado","ataque","golpe","pulo","pulo_duplo","retorno","aterrissagem","dano"]: continue
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


## Trecho [from, to] de um clipe, reamostrado a 30 quadros/s e começando em zero.
static func _excerpt(source: Animation, from: float, to: float) -> Animation:
	var clip := Animation.new()
	clip.length = to-from
	var steps := maxi(1,roundi((to-from)*30.0))
	for track in range(source.get_track_count()):
		var kind := source.track_get_type(track)
		if kind not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]: continue
		if source.track_get_key_count(track) == 0: continue
		var target := clip.add_track(kind)
		clip.track_set_path(target, source.track_get_path(track))
		for step in range(steps+1):
			var t := lerpf(from,to,float(step)/steps)
			match kind:
				Animation.TYPE_POSITION_3D: clip.position_track_insert_key(target, t-from, source.position_track_interpolate(track,t))
				Animation.TYPE_ROTATION_3D: clip.rotation_track_insert_key(target, t-from, source.rotation_track_interpolate(track,t))
				Animation.TYPE_SCALE_3D: clip.scale_track_insert_key(target, t-from, source.scale_track_interpolate(track,t))
	return clip

## Velocidade-base de cada clipe, escolhida para casar o gesto com o tempo da ação física.
func clip_speed(anim_name: StringName) -> float:
	if character_id == &"el_fuego":
		match String(anim_name):
			"base": return 1.65
			# Investida: o braço chega à frente ~0,16s depois do comando (STRIKE_TIME).
			"golpe": return 1.75
			"pulo": return 2.3
			"pulo_duplo": return 1.4
			"retorno": return 3.0
			"queda": return 0.5
			"aterrissagem": return 1.5
			# Recuo completo dentro de HURT_TIME (0,32s).
			"dano": return 1.9
	elif character_id == &"cactus":
		match String(anim_name):
			# O impacto do clipe coincide com o fim da preparação de 0,36s.
			"ataque": return 1.25
	return 1.0

func play_animation(anim_name: StringName, loop: bool = true, blend := 0.07) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name): return
	if _anim_player.current_animation == String(anim_name) and _anim_player.is_playing(): return
	var clip := _anim_player.get_animation(anim_name)
	if clip.loop_mode != Animation.LOOP_PINGPONG:
		clip.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	is_static_pose = false
	_anim_player.play(anim_name, blend, clip_speed(anim_name))

## Ritmo extra aplicado à corrida para os pés acompanharem a velocidade real.
func set_rate(rate: float) -> void:
	if _anim_player != null: _anim_player.speed_scale = rate

func current_clip() -> String:
	return _anim_player.current_animation if _anim_player != null else ""

func clip_position() -> float:
	return _anim_player.current_animation_position if _anim_player != null and _anim_player.is_playing() else 0.0

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
