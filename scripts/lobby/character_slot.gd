@tool
class_name CharacterSlot
extends Node3D

## Carrega somente o personagem selecionado e acrescenta animações de outros FBX
## que compartilham o mesmo rig (Mixamo). Cada entrada de `animation_sources`
## é um PackedScene cujo primeiro AnimationPlayer tem a animação `source_animation`.

@export var model: PackedScene:
	set(value):
		model = value
		if is_node_ready():
			load_character()
@export var animation_sources: Array[PackedScene] = []
@export var source_animation: StringName = &"mixamo_com"
@export var idle_animation: StringName = &"idle"
@export var model_scale: float = 1.0

## Nome do osso (Skeleton3D) usado como ponto de fixação para cada socket futuro.
const SOCKET_BONES := {
	&"hand_right": &"mixamorig_RightHand",
	&"hand_left": &"mixamorig_LeftHand",
	&"back": &"mixamorig_Spine2",
}

var _model_root: Node3D
var _anim_player: AnimationPlayer
var _skeleton: Skeleton3D
var _sockets: Dictionary = {}


func _ready() -> void:
	if not Engine.is_editor_hint():
		load_character()


## Substitui o personagem atual pelo modelo informado. Libera o anterior.
func load_character() -> void:
	if _model_root:
		_model_root.queue_free()
		_model_root = null
		_anim_player = null
		_skeleton = null
		_sockets.clear()
	if model == null:
		return

	_model_root = model.instantiate() as Node3D
	_model_root.scale = Vector3.ONE * model_scale
	add_child(_model_root)

	_anim_player = _find_node_of_type(_model_root, AnimationPlayer) as AnimationPlayer
	_skeleton = _find_node_of_type(_model_root, Skeleton3D) as Skeleton3D
	if _anim_player == null:
		push_warning("CharacterSlot: modelo sem AnimationPlayer: %s" % model.resource_path)
		return

	_merge_animation_sources()
	if _anim_player.has_animation(idle_animation):
		var idle := _anim_player.get_animation(idle_animation)
		idle.loop_mode = Animation.LOOP_LINEAR
		_anim_player.play(idle_animation)


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


func _merge_animation_sources() -> void:
	var target_library := _anim_player.get_animation_library(&"")
	for source_scene in animation_sources:
		if source_scene == null:
			continue
		var source_root := source_scene.instantiate()
		var source_player := _find_node_of_type(source_root, AnimationPlayer) as AnimationPlayer
		if source_player and source_player.has_animation(source_animation):
			var animation_name := StringName(source_scene.resource_path.get_file().get_basename())
			var clip := source_player.get_animation(source_animation).duplicate() as Animation
			target_library.add_animation(animation_name, clip)
		source_root.free()


func _find_node_of_type(root: Node, type: Variant) -> Node:
	if is_instance_of(root, type):
		return root
	for child in root.get_children():
		var found := _find_node_of_type(child, type)
		if found:
			return found
	return null
