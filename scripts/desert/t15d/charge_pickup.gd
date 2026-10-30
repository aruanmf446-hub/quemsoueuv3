extends Area3D
## Reposição real: cheia não é consumida; ID persiste ao descarregar o distrito.
signal collected(id: String, kind: String)
signal full_touched(kind: String)
const Icons = preload("res://scripts/desert/t15d/resource_icons.gd")
static var _halo_texture: GradientTexture2D
var pickup_id := ""
var kind := "attack"
var _visual: Node3D
var _time := 0.0
var _player: Node3D
var _taken := false
var _announced_full := false
func _ready() -> void:
	add_to_group("campaign_pickups")
	set_meta("pickup_id",pickup_id)
	set_meta("kind",kind)
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.62
	shape.shape = sphere
	shape.position.y = 0.7
	add_child(shape)
	_visual = Node3D.new()
	_visual.position.y = 0.85
	add_child(_visual)
	# Mesmo medalhão do HUD (emblema + anel do kit), sempre virado para a câmera, com
	# um halo aditivo na cor do recurso para ser visto de longe.
	var color: Color = {"attack": Color("#ff9a3c"), "defense": Color("#5ec4ef"), "health": Color("#ff5d6a")}.get(kind, Color.WHITE)
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.25, 1.25)
	halo.mesh = quad
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.material_override = _halo_material(color)
	_visual.add_child(halo)
	var medal := Sprite3D.new()
	medal.texture = Icons.medallion(kind if kind in ["attack", "defense"] else "health", 256, true, true)
	medal.pixel_size = 0.64 / 256.0
	medal.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	medal.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	medal.render_priority = 1
	medal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(medal)
	body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"): _try_collect(body))
func _physics_process(delta: float) -> void:
	_time += delta
	_visual.position.y = 0.85+sin(_time*2.8)*0.06
	_visual.scale = Vector3.ONE*(1.0+sin(_time*3.4)*0.035)
	if not is_instance_valid(_player): _player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_player) and absf(_player.position.x-global_position.x)<0.65 and absf(_player.position.y-global_position.y)<1.15:
		_try_collect(_player)
	elif is_instance_valid(_player) and absf(_player.position.x-global_position.x)>1.1:
		_announced_full = false
func _try_collect(body: Node3D) -> void:
	if _taken or not body.has_method("restore_charge"): return
	if not body.restore_charge(kind):
		if not _announced_full and not body.is_dead:
			_announced_full = true
			full_touched.emit(kind)
		return
	_taken = true
	collected.emit(pickup_id,kind)
	queue_free()
static func _halo_material(color: Color) -> StandardMaterial3D:
	if _halo_texture == null:
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
		_halo_texture = GradientTexture2D.new()
		_halo_texture.gradient = ramp
		_halo_texture.fill = GradientTexture2D.FILL_RADIAL
		_halo_texture.fill_from = Vector2(0.5, 0.5)
		_halo_texture.fill_to = Vector2(0.5, 0.0)
		_halo_texture.width = 64
		_halo_texture.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _halo_texture
	mat.albedo_color = Color(color, 0.55)
	return mat
