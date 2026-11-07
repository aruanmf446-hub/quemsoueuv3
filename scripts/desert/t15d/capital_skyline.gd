extends Node3D
## Camada distante aditiva: mesmos módulos aprovados, sem trocar dunas nem prédios próximos.
## Pool fixo: paredes contínuas e três complexos palacianos com paralaxe lenta.
const Props = preload("res://scripts/desert/t15d/city_props.gd")
var _walls: Array[Node3D] = []
var _palaces: Array[Node3D] = []
var _order := 1
var _last_fade := -1.0
const WALL_SPAN := 28.0
const WALL_TOP := 1.20
const WALL_BOTTOM := -14.0
const PALACE_SPAN := 20.0
const PALACE_BASE_DEPTH := 36.0
func configure(order: int) -> void:
	_order = order
func _ready() -> void:
	add_to_group("capital_skyline")
	for i in 3:
		var wall := Props.new()
		wall.name = "DistantWall%d" % i
		add_child(wall)
		wall._box(Vector3(0,(WALL_TOP+WALL_BOTTOM)*0.5,0),Vector3(WALL_SPAN,WALL_TOP-WALL_BOTTOM,0.4),"stone")
		wall._box(Vector3(0,1.22,0.04),Vector3(WALL_SPAN,0.12,0.48),"trim")
		for tooth in range(-28,28):
			wall._box(Vector3(tooth*0.5+0.25,1.44,0),Vector3(0.28,0.34,0.40),"stone")
		for side in [-1.0,1.0]:
			wall.place_asset("capital_watchtower",Vector3(side*10.0,0,0.25),1.35)
		wall._flush()
		_tint(wall)
		_walls.append(wall)
		var palace := Props.new()
		palace.name = "DistantPalace%d" % i
		add_child(palace)
		# Embasamento liga o palácio elevado à muralha distante, sem peças suspensas.
		palace._box(Vector3(0,-PALACE_BASE_DEPTH*0.5,-0.3),Vector3(27.0,PALACE_BASE_DEPTH,2.0),"stone")
		# Alas unidas ao salão central; torres sobrepostas atrás das cornijas.
		palace.place_asset("capital_watchtower",Vector3(0,5.7,-0.8),5.0)
		for side in [-1.0,1.0]:
			palace.place_asset("capital_watchtower",Vector3(side*9.0,3.5,-0.6),3.5)
			palace.place_asset("capital_house",Vector3(side*8.4,0,-0.2),7.0)
		palace.place_asset("capital_merchant",Vector3.ZERO,12.0)
		palace.place_asset("capital_archway",Vector3(0,-0.1,0.4),4.5)
		palace._flush()
		_tint(palace)
		_palaces.append(palace)
func _tint(part: Node3D) -> void:
	for node in part.get_children():
		if node is Sprite3D:
			node.modulate = Color(0.48,0.57,0.75,0.88)
			node.set_meta("skyline",true)
		elif node is MeshInstance3D:
			var material := node.material_override.duplicate() as StandardMaterial3D
			material.albedo_color *= Color(0.48,0.57,0.75)
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.emission_enabled = false
			if _order in [7,9]: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			node.material_override = material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func follow(camera: Camera3D, _x: float, travel: float) -> void:
	var scale_factor := camera.size/7.0
	global_transform = Transform3D(camera.global_basis,camera.global_position-camera.global_basis.z*36.0)
	if _order==2:
		# A cidade abaixo dos telhados acompanha só uma fração da subida da câmera.
		# Seguir a câmera em Y na proporção 1:1 fazia o muro parecer suspenso no salto.
		var city_camera_y:=8.0+(0.20 if UIScale.is_iphone() else 0.50)+2.2
		global_position.y-=(camera.global_position.y-city_camera_y)*0.80
	var wall_offset := 0.0
	var palace_offset := fposmod(_order*2.0,PALACE_SPAN*scale_factor)
	for i in 3:
		_walls[i].scale = Vector3.ONE*scale_factor
		_walls[i].position = Vector3((i-1)*WALL_SPAN*scale_factor-wall_offset,-2.8*scale_factor,1.0)
		_palaces[i].scale = Vector3.ONE*scale_factor*0.26
		_palaces[i].position = Vector3((i-1)*PALACE_SPAN*scale_factor-palace_offset+4.0*scale_factor,-0.9*scale_factor,-0.4)
	# A capital fica para trás na estrada e nos pátios da mineração.
	var distance_fade := lerpf(1.0,0.35,travel) if _order in [7,9] else 1.0
	if absf(distance_fade-_last_fade) < 0.01: return
	_last_fade = distance_fade
	for part in _walls+_palaces:
		for node in part.get_children():
			if node is Sprite3D: node.modulate.a = 0.88*distance_fade
			elif node is MeshInstance3D:
				(node.material_override as StandardMaterial3D).albedo_color.a = distance_fade
