extends RefCounted
## Poderes de areia do El Fuego: rajada de areia com choque (ataque) e escudo de areia
## seca (defesa). Tudo gerado em código: partículas macias (sprites com borda suave),
## riscos alinhados ao movimento, raios em faixas luminosas e um shader para o escudo.
const SAND := Color("#d9a35e")
const SAND_DARK := Color("#8a5a2b")
const SAND_LIGHT := Color("#f3cf8e")
const SPARK := Color("#7fd4ff")

## Rajada: miolo dourado, nuvem de areia solta alongada, riscos de grãos para trás e
## raios elétricos atravessando a rajada. Viaja em linha reta, para em parede e atinge
## o primeiro Cactus no caminho.
class SandBolt extends Node3D:
	signal hit(point: Vector3)
	const SPEED := 15.0
	const RANGE := 3.6
	var direction := 1.0
	var _travelled := 0.0
	var _done := false
	var _bolts: MeshInstance3D
	var _bolt_mesh: ImmediateMesh
	var _light: OmniLight3D
	var _head: Node3D
	var _rng := RandomNumberGenerator.new()
	var _rebuild := 0.0

	func _ready() -> void:
		_rng.randomize()
		_head = Node3D.new()
		add_child(_head)
		# Miolo quente: brilho aditivo pequeno no centro da rajada.
		var glow := CPUParticles3D.new()
		glow.amount = 10
		glow.lifetime = 0.12
		glow.local_coords = true
		glow.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		glow.emission_sphere_radius = 0.06
		glow.spread = 180
		glow.initial_velocity_max = 0.2
		glow.gravity = Vector3.ZERO
		glow.scale_amount_min = 0.8
		glow.scale_amount_max = 1.2
		glow.mesh = Res.sprite(0.22, true)
		glow.color_ramp = Res.ramp([Color(0.9, 0.6, 0.25, 0.45), Color(0.8, 0.45, 0.15, 0.0)])
		_head.add_child(glow)
		# Corpo da rajada: nuvem de areia alongada no sentido do voo.
		var cloud := CPUParticles3D.new()
		cloud.amount = 95
		cloud.lifetime = 0.22
		cloud.local_coords = true
		cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		cloud.emission_box_extents = Vector3(0.34, 0.11, 0.05)
		cloud.direction = Vector3(-direction, 0, 0)
		cloud.spread = 35
		cloud.initial_velocity_min = 0.5
		cloud.initial_velocity_max = 1.6
		cloud.gravity = Vector3.ZERO
		cloud.scale_amount_min = 0.6
		cloud.scale_amount_max = 1.3
		cloud.scale_amount_curve = Res.grow()
		cloud.mesh = Res.sprite(0.23)
		cloud.color_ramp = Res.ramp([Color(SAND, 0.95), Color(Color("#b97d3e"), 0.8), Color(SAND_DARK, 0.0)])
		_head.add_child(cloud)
		# Rastro: riscos finos de grãos que ficam para trás e caem.
		var streaks := CPUParticles3D.new()
		streaks.amount = 70
		streaks.lifetime = 0.42
		streaks.local_coords = false
		streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		streaks.emission_sphere_radius = 0.14
		streaks.direction = Vector3(-direction, 0.1, 0)
		streaks.spread = 14
		streaks.initial_velocity_min = 1.5
		streaks.initial_velocity_max = 4.0
		streaks.gravity = Vector3(0, -5, 0)
		streaks.particle_flag_align_y = true
		streaks.mesh = Res.streak(0.022, 0.16)
		streaks.color_ramp = Res.ramp([Color(SAND_LIGHT, 1.0), Color(SAND, 0.9), Color(SAND_DARK, 0.0)])
		add_child(streaks)
		# Poeira fina que se espalha atrás.
		var haze := CPUParticles3D.new()
		haze.amount = 24
		haze.lifetime = 0.6
		haze.local_coords = false
		haze.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		haze.emission_sphere_radius = 0.12
		haze.spread = 180
		haze.initial_velocity_min = 0.1
		haze.initial_velocity_max = 0.5
		haze.gravity = Vector3(0, 0.3, 0)
		haze.scale_amount_curve = Res.grow()
		haze.mesh = Res.sprite(0.4)
		haze.color_ramp = Res.ramp([Color("#b98447", 0.5), Color(SAND_DARK, 0.0)])
		add_child(haze)
		_bolt_mesh = ImmediateMesh.new()
		_bolts = MeshInstance3D.new()
		_bolts.mesh = _bolt_mesh
		_bolts.material_override = Res.lightning_material()
		_bolts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bolts.position.z = 0.08
		add_child(_bolts)
		_light = OmniLight3D.new()
		_light.light_color = SPARK
		_light.light_energy = 1.0
		_light.omni_range = 2.4
		add_child(_light)

	func _physics_process(delta: float) -> void:
		if _done: return
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
		if _travelled >= RANGE: _burst(global_position, false)

	func _process(delta: float) -> void:
		if _done: return
		# Raios trocam de forma a cada ~50ms: cintilam sem virar ruído.
		_rebuild -= delta
		if _rebuild > 0.0: return
		_rebuild = 0.05
		_bolt_mesh.clear_surfaces()
		var length := minf(_travelled + 0.3, 1.2)
		var paths: Array = []
		for bolt in range(2):
			var points := PackedVector3Array()
			var count := 7
			for index in range(count + 1):
				var t := float(index) / count
				var jitter := 0.0 if index == 0 or index == count else _rng.randf_range(-0.16, 0.16)
				points.append(Vector3(lerpf(-direction * length, direction * 0.28, t), jitter + (bolt - 0.5) * 0.06, 0))
			paths.append(points)
			# Galho curto saindo de um ponto do raio.
			var from := points[_rng.randi_range(2, count - 2)]
			paths.append(PackedVector3Array([from, from + Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0.12, 0.26) * (1.0 if _rng.randf() > 0.5 else -1.0), 0)]))
		Res.draw_lightning(_bolt_mesh, paths)
		_light.light_energy = 0.8 + _rng.randf() * 1.0

	## Impacto: anel de choque, nuvem de areia, faíscas em riscos e clarão.
	func _burst(point: Vector3, on_enemy: bool) -> void:
		_done = true
		global_position = point
		_head.hide()
		_bolt_mesh.clear_surfaces()
		if on_enemy: hit.emit(point)
		var ring := MeshInstance3D.new()
		ring.mesh = Res.ring_quad()
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.scale = Vector3.ONE * 0.3
		ring.position.z = 0.1
		add_child(ring)
		var ring_mat: StandardMaterial3D = ring.mesh.surface_get_material(0).duplicate()
		ring.material_override = ring_mat
		var grow := create_tween().set_parallel(true)
		grow.tween_property(ring, "scale", Vector3.ONE * (2.2 if on_enemy else 1.4), 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		grow.tween_property(ring_mat, "albedo_color:a", 0.0, 0.28)
		var dust := CPUParticles3D.new()
		dust.one_shot = true
		dust.explosiveness = 0.95
		dust.amount = 26
		dust.lifetime = 0.7
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		dust.emission_sphere_radius = 0.18
		dust.spread = 180
		dust.initial_velocity_min = 0.8
		dust.initial_velocity_max = 2.6
		dust.damping_min = 2.5
		dust.damping_max = 4.0
		dust.gravity = Vector3(0, -1.5, 0)
		dust.scale_amount_curve = Res.grow()
		dust.mesh = Res.sprite(0.5)
		dust.color_ramp = Res.ramp([Color(SAND_LIGHT, 0.9), Color(SAND, 0.6), Color(SAND_DARK, 0.0)])
		add_child(dust)
		var grains := CPUParticles3D.new()
		grains.one_shot = true
		grains.explosiveness = 1.0
		grains.amount = 40
		grains.lifetime = 0.55
		grains.spread = 180
		grains.initial_velocity_min = 2.5
		grains.initial_velocity_max = 6.0
		grains.gravity = Vector3(0, -9, 0)
		grains.particle_flag_align_y = true
		grains.mesh = Res.streak(0.02, 0.12)
		grains.color_ramp = Res.ramp([Color(SAND_LIGHT, 1.0), Color(SAND_DARK, 0.0)])
		add_child(grains)
		var sparks := CPUParticles3D.new()
		sparks.one_shot = true
		sparks.explosiveness = 1.0
		sparks.amount = 16 if on_enemy else 8
		sparks.lifetime = 0.25
		sparks.spread = 180
		sparks.initial_velocity_min = 4.0
		sparks.initial_velocity_max = 9.0
		sparks.gravity = Vector3.ZERO
		sparks.particle_flag_align_y = true
		sparks.mesh = Res.streak(0.018, 0.2, true)
		sparks.color_ramp = Res.ramp([Color(0.9, 0.98, 1.0, 1.0), Color(SPARK, 0.0)])
		add_child(sparks)
		for particles in [dust, grains, sparks]: particles.emitting = true
		_light.light_energy = 4.0 if on_enemy else 2.0
		create_tween().tween_property(_light, "light_energy", 0.0, 0.3)
		get_tree().create_timer(0.9, false).timeout.connect(queue_free)

## Escudo: casca com borda brilhante e faixas de areia correndo (shader), redemoinho de
## areia em volta e poeira levantando do chão. Ao absorver um golpe, a casca pulsa.
class SandShield extends Node3D:
	var _shell: MeshInstance3D
	var _shell_mat: ShaderMaterial
	var _swirl: CPUParticles3D
	var _swirl_back: CPUParticles3D
	var _ground: CPUParticles3D
	var _strength := 0.0
	var _flash := 0.0
	var active := false

	func _ready() -> void:
		_shell = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.85
		sphere.height = 1.9
		sphere.radial_segments = 40
		sphere.rings = 20
		_shell.mesh = sphere
		_shell_mat = ShaderMaterial.new()
		_shell_mat.shader = Res.shield_shader()
		_shell_mat.set_shader_parameter("noise_tex", Res.noise_texture())
		_shell.material_override = _shell_mat
		_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shell.position.y = 0.88
		add_child(_shell)
		_swirl = _ring_particles(0.95, 1.0)
		_swirl_back = _ring_particles(0.8, -1.0)
		_ground = CPUParticles3D.new()
		_ground.amount = 22
		_ground.lifetime = 0.7
		_ground.local_coords = true
		_ground.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_ground.emission_ring_axis = Vector3.UP
		_ground.emission_ring_radius = 0.7
		_ground.emission_ring_inner_radius = 0.4
		_ground.emission_ring_height = 0.02
		_ground.direction = Vector3.UP
		_ground.spread = 60
		_ground.initial_velocity_min = 0.3
		_ground.initial_velocity_max = 0.8
		_ground.gravity = Vector3(0, 0.2, 0)
		_ground.scale_amount_curve = Res.grow()
		_ground.mesh = Res.sprite(0.38)
		_ground.color_ramp = Res.ramp([Color(SAND, 0.5), Color(SAND_DARK, 0.0)])
		_ground.emitting = false
		add_child(_ground)
		hide()

	func _ring_particles(radius: float, spin: float) -> CPUParticles3D:
		var swirl := CPUParticles3D.new()
		swirl.amount = 60
		swirl.lifetime = 0.8
		swirl.local_coords = true
		swirl.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		swirl.emission_ring_axis = Vector3.UP
		swirl.emission_ring_radius = radius
		swirl.emission_ring_inner_radius = radius - 0.12
		swirl.emission_ring_height = 1.6
		swirl.direction = Vector3.UP
		swirl.spread = 8
		swirl.initial_velocity_min = 0.3
		swirl.initial_velocity_max = 0.7
		swirl.tangential_accel_min = 7.0 * spin
		swirl.tangential_accel_max = 10.0 * spin
		swirl.gravity = Vector3.ZERO
		swirl.particle_flag_align_y = true
		swirl.mesh = Res.streak(0.022, 0.13)
		swirl.color_ramp = Res.ramp([Color(SAND_LIGHT, 0.0), Color(SAND_LIGHT, 0.95), Color(SAND, 0.0)])
		swirl.position.y = 0.88
		swirl.emitting = false
		add_child(swirl)
		return swirl

	func _process(delta: float) -> void:
		_strength = move_toward(_strength, 1.0 if active else 0.0, delta * (8.0 if active else 4.0))
		_flash = move_toward(_flash, 0.0, delta * 4.0)
		visible = _strength > 0.01 or _flash > 0.01
		for particles in [_swirl, _swirl_back, _ground]: particles.emitting = active
		if not visible: return
		var pop := 0.82 + 0.18 * _strength + 0.06 * _flash
		_shell.scale = Vector3.ONE * pop
		_shell_mat.set_shader_parameter("strength", _strength)
		_shell_mat.set_shader_parameter("flash", _flash)

	## Golpe absorvido: casca pulsa e areia espirra para o lado do impacto.
	func absorb(direction: float) -> void:
		_flash = 1.0
		var spray := CPUParticles3D.new()
		spray.one_shot = true
		spray.explosiveness = 1.0
		spray.amount = 30
		spray.lifetime = 0.55
		spray.direction = Vector3(direction, 0.35, 0)
		spray.spread = 50
		spray.initial_velocity_min = 2.0
		spray.initial_velocity_max = 5.5
		spray.gravity = Vector3(0, -8, 0)
		spray.particle_flag_align_y = true
		spray.mesh = Res.streak(0.024, 0.14)
		spray.color_ramp = Res.ramp([Color(SAND_LIGHT, 1.0), Color(SAND_DARK, 0.0)])
		spray.position = Vector3(direction * 0.8, 0.9, 0)
		add_child(spray)
		spray.emitting = true
		get_tree().create_timer(0.8, false).timeout.connect(spray.queue_free)

# --- recursos compartilhados ------------------------------------------------

class Res:
	static var _cache := {}

	## Sprite macio (borda radial suave), de frente para a câmera lateral.
	static func sprite(size: float, additive := false) -> Mesh:
		var key := "sprite_%s_%s" % [size, additive]
		if _cache.has(key): return _cache[key]
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * size
		# Câmera lateral fixa: o quad já está de frente; o modo billboard de partículas
		# saía preto no renderizador Compatibility.
		quad.material = _particle_material(_soft_dot(), additive)
		_cache[key] = quad
		return quad

	## Risco alinhado à velocidade (usar com particle_flag_align_y).
	static func streak(width: float, length: float, additive := false) -> Mesh:
		var key := "streak_%s_%s_%s" % [width, length, additive]
		if _cache.has(key): return _cache[key]
		var quad := QuadMesh.new()
		quad.size = Vector2(width, length)
		quad.material = _particle_material(_soft_dot(), additive)
		_cache[key] = quad
		return quad

	static func _particle_material(texture: Texture2D, additive: bool) -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		return mat

	static func _soft_dot() -> Texture2D:
		if _cache.has("dot"): return _cache.dot
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_cache.dot = texture
		return texture

	static func ramp(colors: Array) -> Gradient:
		var gradient := Gradient.new()
		var offsets := PackedFloat32Array()
		for index in range(colors.size()): offsets.append(float(index) / (colors.size() - 1))
		gradient.offsets = offsets
		gradient.colors = PackedColorArray(colors)
		return gradient

	## Partícula cresce levemente ao longo da vida (a cor/alfa vem da rampa).
	static func grow() -> Curve:
		if _cache.has("grow"): return _cache.grow
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.5))
		curve.add_point(Vector2(1, 1.0))
		_cache.grow = curve
		return curve

	## Anel de choque: textura radial em forma de aro, aditiva.
	static func ring_quad() -> Mesh:
		if _cache.has("ring"): return _cache.ring
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.62, 0.78, 0.9, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 128
		texture.height = 128
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.6
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_texture = texture
		mat.albedo_color = Color(0.75, 0.92, 1.0, 1.0)
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		quad.material = mat
		_cache.ring = quad
		return quad

	## Material dos raios: faixa com brilho que cai para as bordas, aditiva.
	static func lightning_material() -> StandardMaterial3D:
		if _cache.has("lightning"): return _cache.lightning
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.5, 0.58, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 64
		texture.height = 4
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_cache.lightning = mat
		return mat

	## Desenha cada caminho como duas faixas: halo azul largo e núcleo branco fino.
	static func draw_lightning(mesh: ImmediateMesh, paths: Array) -> void:
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for pass_index in range(2):
			var width := 0.11 if pass_index == 0 else 0.026
			var color := Color(0.35, 0.7, 1.0, 0.85) if pass_index == 0 else Color(0.85, 0.95, 1.0, 1.0)
			for path: PackedVector3Array in paths:
				var shrink := 1.0 if path.size() > 2 else 0.6
				for index in range(path.size() - 1):
					var a := path[index]
					var b := path[index + 1]
					var side := Vector3(-(b.y - a.y), b.x - a.x, 0).normalized() * width * 0.5 * shrink
					for vertex: Array in [[a - side, 0.0], [a + side, 1.0], [b + side, 1.0], [a - side, 0.0], [b + side, 1.0], [b - side, 0.0]]:
						mesh.surface_set_color(color)
						mesh.surface_set_uv(Vector2(vertex[1], 0.5))
						mesh.surface_add_vertex(vertex[0])
		mesh.surface_end()

	static func noise_texture() -> Texture2D:
		if _cache.has("noise"): return _cache.noise
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.03
		noise.fractal_octaves = 3
		noise.seed = 19
		var texture := NoiseTexture2D.new()
		texture.width = 256
		texture.height = 256
		texture.seamless = true
		texture.noise = noise
		_cache.noise = texture
		return texture

	## Casca do escudo: transparente no meio, borda dourada (fresnel) e faixas de areia
	## que correm na superfície. "flash" pulsa quando um golpe é absorvido.
	static func shield_shader() -> Shader:
		if _cache.has("shield"): return _cache.shield
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform float strength = 1.0;
uniform float flash = 0.0;
uniform vec3 sand = vec3(0.85, 0.64, 0.37);
uniform vec3 edge = vec3(1.0, 0.86, 0.56);
uniform sampler2D noise_tex : repeat_enable, filter_linear;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec2 uv = UV * vec2(3.0, 1.5);
	float a = texture(noise_tex, uv + vec2(TIME * 0.32, TIME * 0.08)).r;
	float b = texture(noise_tex, uv * 1.8 + vec2(-TIME * 0.45, TIME * 0.05)).r;
	float bands = smoothstep(0.55, 0.85, a * 0.65 + b * 0.5);
	ALBEDO = mix(sand, edge, clamp(rim + bands * 0.4, 0.0, 1.0)) + vec3(flash * 0.35);
	ALPHA = strength * clamp(rim * 0.95 + bands * 0.22 + flash * 0.25, 0.0, 0.92);
}
"""
		_cache.shield = shader
		return shader
