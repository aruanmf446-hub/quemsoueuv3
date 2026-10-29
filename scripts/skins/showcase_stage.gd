extends LobbyStage
## Palco exclusivo da coleção. Mantém o lobby e seu perfil visual intactos.
func prepare_showcase() -> void:
	# Referências do palco compartilhado; somente esta instância recebe decoração.
	character = get_node("Viewport/World/Character")
	_viewport = get_node("Viewport")
	_camera = get_node("Viewport/World/Camera")
	_key_light = get_node("Viewport/World/KeyLight")
	_rim_light = get_node("Viewport/World/RimLight")
	pedestal_lift = -0.02
	_key_light.light_energy = 1.25
	_key_light.light_color = Color("#fff1d5")
	_rim_light.light_energy = 2.2
	_rim_light.light_color = Color("#84bcff")
	var world := get_node("Viewport/World")
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 0.70
	floor_mesh.bottom_radius = 0.76
	floor_mesh.height = 0.12
	floor_mesh.radial_segments = 64
	var floor := MeshInstance3D.new()
	floor.name = "ShowcasePedestal"
	floor.mesh = floor_mesh
	floor.position.y = -0.07
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#26364d")
	material.metallic = 0.35
	material.roughness = 0.65
	floor.material_override = material
	world.add_child(floor)
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.67
	mesh.outer_radius = 0.70
	mesh.rings = 48
	mesh.ring_segments = 12
	ring.name = "ShowcaseRing"
	ring.mesh = mesh
	ring.position.y = 0.005
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("#d9bb77")
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.emission_enabled = false
	gold.emission = Color("#7e682c")
	ring.material_override = gold
	world.add_child(ring)
	# Inclinação leve revela a plataforma e mantém o corpo inteiro no quadro.
	_pitch = 0.08
	resized.connect(frame_character)
	_capture_pose_bounds.call_deferred()


var _display_bounds := AABB()
var _pose_measured := false
var _fit_boxes: Array[AABB] = []


func _capture_pose_bounds() -> void:
	if not is_inside_tree() or not is_instance_valid(character):
		return
	# Capture a caixa real da pose, incluindo pele, roupas, cabelo e chapéu.
	# O bake é apenas uma medição CPU por seleção, nunca substitui a malha real.
	for skeleton: Skeleton3D in character.find_children("*", "Skeleton3D", true, false):
		skeleton.force_update_all_bone_transforms()
	var first := true
	_fit_boxes.clear()
	for instance: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false):
		if instance.mesh == null or not instance.is_visible_in_tree():
			continue
		var mesh := instance.mesh
		# O renderizador dummy não registra skins; o smoke headless usa
		# a caixa importada. A medição da pose é validada no teste visual.
		if instance.skin != null and DisplayServer.get_name() != "headless":
			var posed := instance.bake_mesh_from_current_skeleton_pose()
			if posed != null:
				mesh = posed
		var box: AABB = character.global_transform.affine_inverse() * instance.global_transform * mesh.get_aabb()
		_fit_boxes.append(box)
		_display_bounds = box if first else _display_bounds.merge(box)
		first = false
	if first:
		return
	var ground := _display_bounds.position.y
	var pedestal := get_node("Viewport/World/ShowcasePedestal") as Node3D
	var ring := get_node("Viewport/World/ShowcaseRing") as Node3D
	pedestal.position.y = ground - 0.07
	ring.position.y = ground + 0.005
	var pedestal_bounds := AABB(Vector3(-0.76, ground - 0.13, -0.76), Vector3(1.52, 0.15, 1.52))
	_fit_boxes.append(pedestal_bounds)
	_display_bounds = _display_bounds.merge(pedestal_bounds)
	_pose_measured = true
	frame_character()


func frame_character() -> void:
	if not is_inside_tree() or not is_instance_valid(character) or not character.is_inside_tree():
		return
	if not _pose_measured:
		super.frame_character()
		return
	_update_camera()


func _update_camera() -> void:
	if not _pose_measured:
		super._update_camera()
		return
	if not is_inside_tree() or not is_instance_valid(_camera):
		return
	var target := _display_bounds.get_center()
	var direction := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	_camera.position = target + direction
	_camera.look_at(target, Vector3.UP)
	# Resolva a distância de cada canto em espaço de câmera. Inclui profundidade
	# e pedestal, e recalcula ao girar ou redimensionar sem recarregar o modelo.
	var view_rotation := _camera.basis.inverse()
	var tangent := tan(deg_to_rad(CAMERA_FOV * 0.5))
	var aspect := maxf(size.x / maxf(size.y, 1.0), 0.3)
	var distance := 0.1
	for box in _fit_boxes:
		for index in range(8):
			var corner := view_rotation * (box.get_endpoint(index) - target)
			distance = maxf(distance, corner.z + absf(corner.y) / (tangent * 0.91))
			distance = maxf(distance, corner.z + absf(corner.x) / (tangent * aspect * 0.82))
	_base_distance = distance
	_camera.position = target + direction * distance * _zoom
	_camera.look_at(target, Vector3.UP)
