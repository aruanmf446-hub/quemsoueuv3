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
	apply_profile("alto")
	_key_light.light_energy = 1.0
	_key_light.light_color = Color("#fff1d5")
	_rim_light.light_energy = 1.25
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


func frame_character() -> void:
	if not is_inside_tree() or not is_instance_valid(character) or not character.is_inside_tree():
		return
	super.frame_character()
	# A pose importada pode exceder a caixa estática da malha (El Fuego).
	# Meça os ossos na pose atual, já transformados pela escala do slot.
	var skeleton := character.find_child("*", true, false) as Skeleton3D
	for child in character.find_children("*", "Skeleton3D", true, false):
		skeleton = child as Skeleton3D
		break
	if skeleton == null:
		return
	skeleton.force_update_all_bone_transforms()
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for bone in range(skeleton.get_bone_count()):
		var point := character.to_local(skeleton.to_global(skeleton.get_bone_global_pose(bone).origin))
		low = low.min(point)
		high = high.max(point)
	if not is_finite(low.y):
		return
	var height := maxf(high.y - low.y, float(character.get_framing().get("height", 1.8)))
	var ground := minf(0.0, low.y - height * 0.04)
	var pedestal := get_node_or_null("Viewport/World/ShowcasePedestal") as Node3D
	var ring := get_node_or_null("Viewport/World/ShowcaseRing") as Node3D
	if pedestal != null:
		pedestal.position.y = ground - 0.07
		ring.position.y = ground + 0.005
	# Margem para cabelo/chapéu além do esqueleto e para a plataforma.
	_target_y = (high.y + low.y) * 0.5
	var aspect := maxf(size.x / maxf(size.y, 1.0), 0.3)
	var vertical := height * 1.16 / fill_ratio
	var horizontal := maxf(high.x - low.x, 1.6) * 1.12 / aspect
	_base_distance = maxf(vertical, horizontal) / (2.0 * tan(deg_to_rad(CAMERA_FOV * 0.5)))
	_update_camera()
