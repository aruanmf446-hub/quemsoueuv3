class_name CharacterSlot
extends Node3D

## Carrega um único personagem por vez a partir de uma entrada do catálogo.
## - Normaliza a altura do modelo para `height`, sem depender da escala do FBX.
## - Acrescenta as animações nomeadas do catálogo ao AnimationPlayer do modelo.
## - Expõe `get_framing()` com altura e centro verticais para o enquadramento da câmera.
## - Expõe `get_socket()` com BoneAttachment3D para armas e acessórios.

signal loaded(character_id: StringName)

const DEFAULT_HEIGHT := 1.8

## Ossos Mixamo verificados no esqueleto do Cowboy (ver mixamorig_* no Skeleton3D).
const SOCKET_BONES := {
	&"hand_right": &"mixamorig_RightHand",
	&"hand_left": &"mixamorig_LeftHand",
	&"back": &"mixamorig_Spine2",
}

static var _clip_cache := {}
static var _warm_scenes := {}
static var _requested := {}

## Prepara apenas os avatares dos participantes durante a escolha de cartas.
## Leitura em segundo plano; nenhuma espera bloqueante no início da apresentação.
static func prepare_participants(players: Array) -> void:
	var ids := players.map(func(p: Dictionary)->String:return str(p.get("skin_id","")))
	for entry: Dictionary in CharacterCatalog.load_entries():
		if not ids.has(str(entry.id)): continue
		var paths: Array=[entry.model]
		for alias in ["base","anim_2","anim_3","anim_4"]:
			if entry.get("animations",{}).has(alias): paths.append(entry.animations[alias])
		for path: String in paths:
			if not _requested.has(path) and not _warm_scenes.has(path):
				if ResourceLoader.load_threaded_request(path,"PackedScene")==OK: _requested[path]=true

static func collect_prepared() -> void:
	for path: String in _requested.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			_warm_scenes[path]=ResourceLoader.load_threaded_get(path)
			_requested.erase(path)
		elif status==ResourceLoader.THREAD_LOAD_FAILED or status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_requested.erase(path)

## A apresentação pode aguardar frames sem bloquear a interface nem o áudio.
static func entry_pending(entry: Dictionary) -> bool:
	collect_prepared()
	var paths: Array=[entry.model]
	paths.append_array(entry.get("animations",{}).values())
	return paths.any(func(path: String)->bool:return _requested.has(path))

static func prepared_scene(path: String) -> PackedScene:
	collect_prepared()
	return _warm_scenes[path] as PackedScene if _warm_scenes.has(path) else load(path) as PackedScene


var character_id: StringName = &""
var is_static_pose: bool = false

var _model_root: Node3D
var _anim_player: AnimationPlayer
var _skeleton: Skeleton3D
var _sockets: Dictionary = {}
var _framing: Dictionary = {}
var _emote_restore: Dictionary = {}
var _pose_time := 0.0


## Substitui o personagem atual pelo descrito em `entry`. Libera o anterior antes de carregar.
func load_entry(entry: Dictionary) -> void:
	unload()
	character_id = StringName(entry["id"])

	var model := prepared_scene(entry["model"])
	if model == null:
		push_error("Modelo não encontrado: %s" % entry["model"])
		return

	_model_root = model.instantiate() as Node3D
	add_child(_model_root)
	_anim_player = _find_node_of_type(_model_root, AnimationPlayer) as AnimationPlayer
	if _anim_player: _anim_player.animation_finished.connect(_emote_finished)
	_skeleton = _find_node_of_type(_model_root, Skeleton3D) as Skeleton3D

	_tune_materials()
	_normalize_height(float(entry.get("height", DEFAULT_HEIGHT)))
	if _anim_player:
		_merge_animations(entry)
		_play_idle(entry)
	loaded.emit(character_id)


## Remove o personagem atual e libera seus recursos da cena.
func unload() -> void:
	_cancel_emote()
	if _model_root:
		remove_child(_model_root)
		_model_root.queue_free()
	_model_root = null
	_anim_player = null
	_skeleton = null
	_sockets.clear()
	_framing.clear()
	_pose_time=0.0
	is_static_pose = false


## Altura e centro vertical do personagem já normalizado, em metros locais do slot.
func get_framing() -> Dictionary:
	return _framing


## Toca uma animação nomeada do catálogo. `loop = false` para ações como ataque e morte.
func play_animation(anim_name: StringName, loop: bool = true) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return
	_cancel_emote()
	var clip := _anim_player.get_animation(anim_name)
	clip.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	is_static_pose = false
	# Chamadas repetidas (a cada quadro) não devem reiniciar uma animação em andamento.
	if _anim_player.current_animation == String(anim_name) and _anim_player.is_playing():
		return
	_anim_player.play(anim_name)


## Congela uma animação em um instante, usada como pose estática.
func set_pose(anim_name: StringName, time: float = 0.0) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return
	_cancel_emote()
	_anim_player.play(anim_name)
	_anim_player.seek(time, true)
	_anim_player.pause()
	_pose_time=time
	is_static_pose = true


## Um emote usa o clipe já carregado e retorna à pose/animação anterior.
## Ações automáticas que chamam play_animation/set_pose interrompem esse retorno.
func play_emote(anim_name: StringName) -> bool:
	if not has_animation(anim_name): return false
	if not _emote_restore.is_empty(): _emote_finished(StringName(_emote_restore.target))
	var clip := _anim_player.get_animation(anim_name)
	var previous := _anim_player.assigned_animation
	var position := _pose_time if is_static_pose else animation_length(StringName(previous))
	if not _anim_player.current_animation.is_empty(): position=_anim_player.current_animation_position
	_emote_restore={"target":String(anim_name),"loop":clip.loop_mode,
		"previous":previous,"position":position,
		"playing":_anim_player.is_playing(),"static":is_static_pose}
	clip.loop_mode=Animation.LOOP_NONE
	is_static_pose=false
	_anim_player.play(anim_name,0.16)
	_anim_player.seek(0.0,true)
	return true


func _cancel_emote() -> void:
	if _emote_restore.is_empty(): return
	if has_animation(StringName(_emote_restore.target)):
		_anim_player.get_animation(_emote_restore.target).loop_mode=_emote_restore.loop
	_emote_restore={}


func _emote_finished(anim_name: StringName) -> void:
	if _emote_restore.is_empty() or String(anim_name)!=str(_emote_restore.target): return
	var restore := _emote_restore.duplicate()
	_cancel_emote()
	var previous := StringName(restore.previous)
	if not has_animation(previous):
		_anim_player.stop()
		return
	_anim_player.play(previous,0.16 if restore.playing else 0.0)
	_anim_player.seek(float(restore.position),true)
	if not restore.playing: _anim_player.pause()
	is_static_pose=bool(restore.static)


func has_animation(anim_name: StringName) -> bool:
	return _anim_player != null and _anim_player.has_animation(anim_name)


## Duração em segundos de uma animação nomeada, ou 0 se não existir.
func animation_length(anim_name: StringName) -> float:
	if not has_animation(anim_name):
		return 0.0
	return _anim_player.get_animation(anim_name).length


## Retorna um BoneAttachment3D fixado ao osso do socket, criado sob demanda.
func get_socket(socket_name: StringName) -> BoneAttachment3D:
	if _sockets.has(socket_name):
		return _sockets[socket_name]
	if _skeleton == null or not SOCKET_BONES.has(socket_name):
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "Socket_%s" % socket_name
	attachment.bone_name = SOCKET_BONES[socket_name]
	_skeleton.add_child(attachment)
	_sockets[socket_name] = attachment
	return attachment


## Ajusta apenas o comportamento de luz dos materiais: reduz brilho especular
## exagerado e usa filtragem anisotrópica. Cores e texturas originais são preservadas.
func _tune_materials() -> void:
	for mesh_instance: MeshInstance3D in _find_all_of_type(_model_root, MeshInstance3D):
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var tuned := source.duplicate() as BaseMaterial3D
			tuned.roughness = clampf(tuned.roughness, 0.5, 1.0)
			tuned.metallic = minf(tuned.metallic, 0.3)
			tuned.metallic_specular = 0.35
			tuned.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			# Mantém o material vivo até a liberação completa do nó, inclusive do RID.
			mesh_instance.set_meta("qse_surface_material_%d" % surface, tuned)
			mesh_instance.set_surface_override_material(surface, tuned)


func _normalize_height(target_height: float) -> void:
	_model_root.scale = Vector3.ONE
	_model_root.position = Vector3.ZERO
	var bounds := _measure_bounds()
	if bounds.size.y <= 0.0:
		return
	_model_root.scale = Vector3.ONE * (target_height / bounds.size.y)
	bounds = _measure_bounds()
	_model_root.position.y = -bounds.position.y
	_framing = {"height": target_height, "center_y": target_height * 0.5}


## AABB combinada de todas as malhas do modelo, em coordenadas do slot.
func _measure_bounds() -> AABB:
	var combined := AABB()
	var first := true
	var meshes := _find_all_of_type(_model_root, MeshInstance3D)
	for mesh_instance: MeshInstance3D in meshes:
		var local_to_slot := global_transform.affine_inverse() * mesh_instance.global_transform
		var box: AABB = local_to_slot * mesh_instance.get_aabb()
		if first:
			combined = box
			first = false
		else:
			combined = combined.merge(box)
	return combined


func _merge_animations(entry: Dictionary) -> void:
	var library := _anim_player.get_animation_library(&"")
	if library == null:
		return
	library = library.duplicate()
	_anim_player.remove_animation_library(&"")
	_anim_player.add_animation_library(&"",library)
	var animations: Dictionary = entry.get("animations", {})
	for anim_name: String in animations:
		var source_path: String = animations[anim_name]
		var clip: Animation = null
		if source_path == entry["model"]:
			clip = _first_animation_of(_anim_player)
		else:
			clip = _extract_clip(source_path)
		if clip:
			library.add_animation(StringName(anim_name), clip)


## Carrega o FBX de origem, copia a primeira animação e libera a cena temporária.
func _extract_clip(source_path: String) -> Animation:
	if _clip_cache.has(source_path): return _clip_cache[source_path].duplicate() as Animation
	var source := prepared_scene(source_path)
	if source == null:
		push_warning("Animação não encontrada: %s" % source_path)
		return null
	var source_root := source.instantiate()
	var source_player := _find_node_of_type(source_root, AnimationPlayer) as AnimationPlayer
	var clip: Animation = null
	if source_player:
		clip = _first_animation_of(source_player)
	source_root.free()
	if clip != null: _clip_cache[source_path]=clip
	return clip


func _first_animation_of(player: AnimationPlayer) -> Animation:
	var names := player.get_animation_list()
	if names.is_empty():
		return null
	for key in names:
		if key != "RESET" and player.get_animation(key).length>0: return player.get_animation(key).duplicate() as Animation
	return null


func _play_idle(entry: Dictionary) -> void:
	var idle: String = entry.get("idle", "")
	var library := _anim_player.get_animation_library(&"")
	if idle != "" and library and library.has_animation(idle):
		var idle_clip := library.get_animation(idle)
		idle_clip.loop_mode = Animation.LOOP_LINEAR
		_anim_player.play(idle)
		return
	# Sem idle verificado: pose estática temporária (primeiro quadro da animação indicada).
	var pose: String = entry.get("pose", "base")
	if library and library.has_animation(pose):
		_anim_player.play(pose)
		_anim_player.seek(float(entry.get("pose_time", 0.0)), true)
		_anim_player.pause()
		_pose_time=float(entry.get("pose_time",0.0))
		is_static_pose = true


func _find_node_of_type(root: Node, type: Variant) -> Node:
	if is_instance_of(root, type):
		return root
	for child in root.get_children():
		var found := _find_node_of_type(child, type)
		if found:
			return found
	return null


func _find_all_of_type(root: Node, type: Variant) -> Array:
	var found: Array = []
	if is_instance_of(root, type):
		found.append(root)
	for child in root.get_children():
		found.append_array(_find_all_of_type(child, type))
	return found
