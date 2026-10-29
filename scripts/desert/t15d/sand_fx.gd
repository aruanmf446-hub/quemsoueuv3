extends RefCounted
## Poderes de areia do El Fuego: o disparo de areia com choque (ataque) e o escudo de
## areia seca (defesa). Tudo gerado em código: partículas, malhas e raios.
const SAND := Color("#e3b56f")
const SAND_DARK := Color("#9c6a35")
const SPARK := Color("#bfe6ff")

## Disparo: núcleo de areia girando, rastro de grãos e raios elétricos ao redor.
## Viaja em linha reta, para em parede e atinge o primeiro Cactus no caminho.
class SandBolt extends Node3D:
	signal hit(point: Vector3)
	const SPEED := 15.0
	const RANGE := 3.6
	var direction := 1.0
	var _travelled := 0.0
	var _done := false
	var _arcs: MeshInstance3D
	var _arc_mesh: ImmediateMesh
	var _light: OmniLight3D
	var _core: Node3D
	var _rng := RandomNumberGenerator.new()
	var _time := 0.0

	func _ready() -> void:
		_rng.randomize()
		_core = Node3D.new()
		add_child(_core)
		# Sem núcleo sólido: a frente do disparo é uma rajada de areia solta, mais densa no
		# centro e alongada na direção do voo (antes parecia uma pedra).
		var cloud := CPUParticles3D.new()
		cloud.amount = 200
		cloud.lifetime = 0.18
		cloud.local_coords = true
		cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		cloud.emission_box_extents = Vector3(0.32, 0.14, 0.12)
		cloud.spread = 180
		cloud.initial_velocity_min = 0.2
		cloud.initial_velocity_max = 0.8
		cloud.tangential_accel_min = 8.0
		cloud.tangential_accel_max = 14.0
		cloud.gravity = Vector3.ZERO
		cloud.scale_amount_min = 0.5
		cloud.scale_amount_max = 1.0
		cloud.mesh = Res.grain_mesh(0.03)
		cloud.scale_amount_curve = Res.shrink()
		cloud.color = Color.WHITE
		_core.add_child(cloud)
		var trail := CPUParticles3D.new()
		trail.amount = 320
		trail.lifetime = 0.5
		trail.local_coords = false
		trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		trail.emission_sphere_radius = 0.2
		trail.direction = Vector3(-direction, 0.15, 0)
		trail.spread = 18
		trail.initial_velocity_min = 0.5
		trail.initial_velocity_max = 2.0
		trail.gravity = Vector3(0, -3, 0)
		trail.scale_amount_min = 0.4
		trail.scale_amount_max = 0.9
		trail.mesh = Res.grain_mesh(0.03)
		trail.scale_amount_curve = Res.shrink()
		trail.color = Color.WHITE
		add_child(trail)
		_arc_mesh = ImmediateMesh.new()
		_arcs = MeshInstance3D.new()
		_arcs.mesh = _arc_mesh
		var arc_mat := StandardMaterial3D.new()
		arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		arc_mat.albedo_color = SPARK
		arc_mat.vertex_color_use_as_albedo = true
		_arcs.material_override = arc_mat
		_arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_arcs)
		_light = OmniLight3D.new()
		_light.light_color = Color("#9fd4ff")
		_light.light_energy = 0.9
		_light.omni_range = 2.6
		add_child(_light)

	func _physics_process(delta: float) -> void:
		if _done: return
		_time += delta
		var step := SPEED * delta * direction
		var space := get_world_3d().direct_space_state
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(step + direction * 0.2, 0, 0), 1))
		if not wall.is_empty():
			_burst(wall.position, false)
			return
		for enemy: Node3D in get_tree().get_nodes_in_group("enemies"):
			if not enemy.has_method("take_damage"): continue
			var offset := enemy.global_position + Vector3.UP * 0.75 - global_position
			if absf(offset.y) < 0.95 and absf(offset.x) < 0.5 + absf(step):
				enemy.take_damage(2)
				_burst(enemy.global_position + Vector3.UP * 0.8, true)
				return
		global_position.x += step
		_travelled += absf(step)
		_core.rotation.z += delta * 18.0 * direction
		if _travelled >= RANGE: _burst(global_position, false)

	func _process(_delta: float) -> void:
		# Raios recriados a cada quadro: arcos curtos e quebrados em volta do núcleo.
		_arc_mesh.clear_surfaces()
		if _done: return
		_arc_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		# Choque: raios em zigue-zague correndo ao longo do jato, de trás para a frente.
		for arc in range(4):
			var length := minf(_travelled + 0.4, 1.4)
			var point := Vector3(-direction * length, _rng.randf_range(-0.12, 0.12), _rng.randf_range(-0.05, 0.05))
			var steps := 7
			for segment in range(steps):
				var t := float(segment + 1) / steps
				var next := Vector3(lerpf(-direction * length, direction * 0.3, t), _rng.randf_range(-0.18, 0.18), _rng.randf_range(-0.06, 0.06))
				_arc_mesh.surface_set_color(SPARK)
				_arc_mesh.surface_add_vertex(point)
				_arc_mesh.surface_set_color(Color.WHITE)
				_arc_mesh.surface_add_vertex(next)
				point = next
		_arc_mesh.surface_end()
		_light.light_energy = 0.6 + _rng.randf() * 1.0

	## Explosão: nuvem de areia, faíscas elétricas e clarão; o nó some depois.
	func _burst(point: Vector3, on_enemy: bool) -> void:
		_done = true
		global_position = point
		_core.hide()
		if on_enemy: hit.emit(point)
		var dust := CPUParticles3D.new()
		dust.one_shot = true
		dust.explosiveness = 1.0
		dust.amount = 40
		dust.lifetime = 0.55
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		dust.emission_sphere_radius = 0.2
		dust.spread = 180
		dust.initial_velocity_min = 1.5
		dust.initial_velocity_max = 4.5
		dust.gravity = Vector3(0, -6, 0)
		dust.damping_min = 2.0
		dust.damping_max = 4.0
		dust.scale_amount_min = 0.6
		dust.scale_amount_max = 1.6
		dust.mesh = Res.grain_mesh(0.05)
		dust.scale_amount_curve = Res.shrink()
		dust.color = Color.WHITE
		add_child(dust)
		var sparks := CPUParticles3D.new()
		sparks.one_shot = true
		sparks.explosiveness = 1.0
		sparks.amount = 18 if on_enemy else 8
		sparks.lifetime = 0.25
		sparks.spread = 180
		sparks.initial_velocity_min = 4.0
		sparks.initial_velocity_max = 8.0
		sparks.gravity = Vector3.ZERO
		sparks.mesh = Res.grain_mesh(0.025, true, SPARK)
		sparks.scale_amount_curve = Res.shrink()
		add_child(sparks)
		dust.emitting = true
		sparks.emitting = true
		var flash := create_tween()
		_light.light_energy = 4.0 if on_enemy else 2.0
		_light.light_color = SPARK
		flash.tween_property(_light, "light_energy", 0.0, 0.25)
		get_tree().create_timer(0.7, false).timeout.connect(queue_free)

## Escudo: casca de areia translúcida que gira, com grãos orbitando e borda brilhante.
class SandShield extends Node3D:
	var _shell: MeshInstance3D
	var _shell_mat: StandardMaterial3D
	var _swirl: CPUParticles3D
	var _time := 0.0
	var _strength := 0.0
	var active := false

	func _ready() -> void:
		_shell = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.85
		sphere.height = 1.9
		sphere.radial_segments = 32
		sphere.rings = 16
		_shell.mesh = sphere
		_shell_mat = StandardMaterial3D.new()
		_shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shell_mat.albedo_texture = Res.grain_texture()
		_shell_mat.albedo_color = Color(SAND, 0.0)
		_shell_mat.emission_enabled = true
		_shell_mat.emission = SAND * 0.15
		_shell_mat.rim_enabled = true
		_shell_mat.rim = 1.0
		_shell_mat.rim_tint = 0.8
		_shell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shell_mat.uv1_scale = Vector3(6, 4, 1)
		_shell_mat.albedo_texture = Res.sand_veil_texture()
		_shell.material_override = _shell_mat
		_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shell.position.y = 0.85
		add_child(_shell)
		_swirl = CPUParticles3D.new()
		_swirl.amount = 160
		_swirl.lifetime = 0.9
		_swirl.local_coords = true
		_swirl.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_swirl.emission_ring_axis = Vector3.UP
		_swirl.emission_ring_radius = 0.9
		_swirl.emission_ring_inner_radius = 0.75
		_swirl.emission_ring_height = 1.6
		_swirl.direction = Vector3.UP
		_swirl.spread = 10
		_swirl.initial_velocity_min = 0.4
		_swirl.initial_velocity_max = 1.0
		_swirl.tangential_accel_min = 6.0
		_swirl.tangential_accel_max = 9.0
		_swirl.gravity = Vector3.ZERO
		_swirl.mesh = Res.grain_mesh(0.04)
		_swirl.scale_amount_min = 0.6
		_swirl.scale_amount_max = 1.5
		_swirl.scale_amount_curve = Res.shrink()
		_swirl.color = Color.WHITE
		_swirl.position.y = 0.85
		_swirl.emitting = false
		add_child(_swirl)
		hide()

	func _process(delta: float) -> void:
		_time += delta
		_strength = move_toward(_strength, 1.0 if active else 0.0, delta * (7.0 if active else 4.0))
		visible = _strength > 0.01
		_swirl.emitting = active
		if not visible: return
		_shell.scale = Vector3.ONE * (0.75 + 0.25 * _strength)
		_shell.rotation.y = _time * 2.4
		_shell_mat.albedo_color.a = 0.5 * _strength
		_shell_mat.uv1_offset.y = -_time * 0.6

	## Areia espirrando quando o escudo absorve um golpe.
	func absorb(direction: float) -> void:
		var spray := CPUParticles3D.new()
		spray.one_shot = true
		spray.explosiveness = 1.0
		spray.amount = 36
		spray.lifetime = 0.5
		spray.direction = Vector3(direction, 0.4, 0)
		spray.spread = 55
		spray.initial_velocity_min = 2.0
		spray.initial_velocity_max = 5.0
		spray.gravity = Vector3(0, -8, 0)
		spray.mesh = Res.grain_mesh(0.045)
		spray.scale_amount_curve = Res.shrink()
		spray.color = Color.WHITE
		spray.position = Vector3(direction * 0.8, 0.9, 0)
		add_child(spray)
		spray.emitting = true
		get_tree().create_timer(0.8, false).timeout.connect(spray.queue_free)

# --- recursos compartilhados ------------------------------------------------

class Res:
	const SAND_D := Color("#9c6a35")
	const SAND_L := Color("#e3b56f")

	static var _grain_cache := {}
	static var _texture_cache: Texture2D

	static func grain_mesh(size: float, glow := false, color := Color("#c98d4c")) -> Mesh:
		var key := "%s_%s_%s" % [size, glow, color.to_html()]
		if _grain_cache.has(key): return _grain_cache[key]
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * size
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.albedo_color = color
		mat.roughness = 1.0
		mesh.material = mat
		_grain_cache[key] = mesh
		return mesh

	static var _shrink_cache: Curve
	static func shrink() -> Curve:
		if _shrink_cache != null: return _shrink_cache
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(0.7, 0.8))
		curve.add_point(Vector2(1, 0))
		_shrink_cache = curve
		return curve

	static func fade(color: Color) -> Gradient:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		gradient.colors = PackedColorArray([color.lightened(0.15), color, Color(color.darkened(0.3), 0.0)])
		return gradient

	static var _veil_cache: Texture2D
	## Véu de areia: faixas de grãos com transparência, para o escudo não parecer bolha.
	static func sand_veil_texture() -> Texture2D:
		if _veil_cache != null: return _veil_cache
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.06
		noise.fractal_octaves = 4
		noise.seed = 19
		var texture := NoiseTexture2D.new()
		texture.width = 256
		texture.height = 256
		texture.seamless = true
		texture.noise = noise
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.45, 0.6, 1.0])
		ramp.colors = PackedColorArray([Color(SAND_D, 0.0), Color(SAND_D, 0.0), Color(SAND_L, 0.55), Color(SAND_L.lightened(0.25), 0.9)])
		texture.color_ramp = ramp
		_veil_cache = texture
		return texture

	static func grain_texture() -> Texture2D:
		if _texture_cache != null: return _texture_cache
		var noise := FastNoiseLite.new()
		noise.frequency = 0.25
		noise.seed = 77
		var texture := NoiseTexture2D.new()
		texture.width = 128
		texture.height = 128
		texture.seamless = true
		texture.noise = noise
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Res.SAND_D, Res.SAND_L.lightened(0.2)])
		texture.color_ramp = ramp
		_texture_cache = texture
		return texture
