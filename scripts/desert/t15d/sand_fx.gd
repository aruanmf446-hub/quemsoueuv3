extends RefCounted
## Poderes de areia do El Fuego: soco com explosão de areia e choque (ataque) e parede de
## terra que sobe do chão (defesa). Tudo gerado em código: partículas macias, riscos
## alinhados ao movimento e raios em faixas luminosas.
const SAND := Color("#d9a35e")
const SAND_DARK := Color("#8a5a2b")
const SAND_LIGHT := Color("#f3cf8e")
const SPARK := Color("#7fd4ff")

## Soco de areia: a areia envolve o punho durante o golpe (redemoinho que deixa rastro
## seguindo o braço) com faíscas pequenas em volta da mão; no quadro do soco, uma
## explosão curta de areia sai da ponta do punho. Nada voa para longe.
class SandPunch extends Node3D:
	var direction := 1.0
	var skeleton: Skeleton3D
	var bone := -1
	var _swirl: CPUParticles3D
	var _grains: CPUParticles3D
	var _bolt_mesh: ImmediateMesh
	var _light: OmniLight3D
	var _rng := RandomNumberGenerator.new()
	var _life := 0.0
	var _rebuild := 0.0
	var _struck := false

	func _ready() -> void:
		top_level = true
		_rng.randomize()
		_follow()
		# Redemoinho em volta do punho; em coordenadas do mundo, então deixa rastro.
		_swirl = CPUParticles3D.new()
		_swirl.amount = 46
		_swirl.lifetime = 0.28
		_swirl.local_coords = false
		_swirl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
		_swirl.emission_sphere_radius = 0.09
		_swirl.spread = 180
		_swirl.initial_velocity_min = 0.05
		_swirl.initial_velocity_max = 0.25
		_swirl.tangential_accel_min = 2.0
		_swirl.tangential_accel_max = 4.0
		_swirl.gravity = Vector3(0, -0.6, 0)
		_swirl.scale_amount_min = 0.7
		_swirl.scale_amount_max = 1.2
		_swirl.mesh = Res.sprite(0.11)
		_swirl.color_ramp = Res.ramp([Color(SAND_LIGHT, 0.95), Color(SAND, 0.7), Color(SAND_DARK, 0.0)])
		add_child(_swirl)
		# Grãos finos que escorrem do punho.
		_grains = CPUParticles3D.new()
		_grains.amount = 36
		_grains.lifetime = 0.35
		_grains.local_coords = false
		_grains.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_grains.emission_sphere_radius = 0.07
		_grains.spread = 180
		_grains.initial_velocity_min = 0.1
		_grains.initial_velocity_max = 0.5
		_grains.gravity = Vector3(0, -4, 0)
		_grains.particle_flag_align_y = true
		_grains.mesh = Res.streak(0.012, 0.05)
		_grains.color_ramp = Res.ramp([Color(SAND_LIGHT, 1.0), Color(SAND_DARK, 0.0)])
		add_child(_grains)
		_bolt_mesh = ImmediateMesh.new()
		var bolts := MeshInstance3D.new()
		bolts.mesh = _bolt_mesh
		bolts.material_override = Res.lightning_material()
		bolts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bolts)
		_light = OmniLight3D.new()
		_light.light_color = Color("#ffd49a")
		_light.light_energy = 0.6
		_light.omni_range = 1.2
		add_child(_light)

	func _follow() -> void:
		if is_instance_valid(skeleton) and bone >= 0:
			global_position = skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin + Vector3(0, 0, 0.12)

	## Quadro do soco: explosão compacta na ponta do punho.
	func strike() -> void:
		_struck = true
		var puff := CPUParticles3D.new()
		puff.one_shot = true
		puff.explosiveness = 0.95
		puff.amount = 14
		puff.lifetime = 0.35
		puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		puff.emission_sphere_radius = 0.06
		puff.direction = Vector3(direction, 0.1, 0)
		puff.spread = 40
		puff.initial_velocity_min = 1.0
		puff.initial_velocity_max = 2.4
		puff.damping_min = 6.0
		puff.damping_max = 9.0
		puff.gravity = Vector3.ZERO
		puff.scale_amount_curve = Res.grow()
		puff.mesh = Res.sprite(0.26)
		puff.color_ramp = Res.ramp([Color(SAND_LIGHT, 0.9), Color(SAND, 0.55), Color(SAND_DARK, 0.0)])
		add_child(puff)
		var spray := CPUParticles3D.new()
		spray.one_shot = true
		spray.explosiveness = 1.0
		spray.amount = 30
		spray.lifetime = 0.3
		spray.direction = Vector3(direction, 0.15, 0)
		spray.spread = 30
		spray.initial_velocity_min = 2.0
		spray.initial_velocity_max = 4.5
		spray.damping_min = 5.0
		spray.damping_max = 8.0
		spray.gravity = Vector3(0, -5, 0)
		spray.particle_flag_align_y = true
		spray.mesh = Res.streak(0.014, 0.08)
		spray.color_ramp = Res.ramp([Color(SAND_LIGHT, 1.0), Color(SAND_DARK, 0.0)])
		add_child(spray)
		for particles in [puff, spray]:
			particles.local_coords = false
			particles.emitting = true
		_light.light_energy = 1.6
		_light.light_color = Color("#bfe6ff")
		create_tween().tween_property(_light, "light_energy", 0.0, 0.25)

	func _process(delta: float) -> void:
		_life += delta
		if _life < 0.32: _follow()
		if _life > 0.3:
			_swirl.emitting = false
			_grains.emitting = false
		if _life > 0.9:
			queue_free()
			return
		_rebuild -= delta
		if _rebuild > 0.0: return
		_rebuild = 0.04
		_bolt_mesh.clear_surfaces()
		if _life > (0.36 if _struck else 0.3): return
		# Faíscas curtas em volta da mão (dois ou três estalos finos).
		var paths: Array = []
		for bolt in range(2 if not _struck else 3):
			var angle := _rng.randf() * TAU
			var start := Vector3(cos(angle), sin(angle), 0) * 0.06
			var points := PackedVector3Array([start])
			var reach := 0.12 if not _struck else 0.22
			for index in range(1, 4):
				points.append(start + Vector3(cos(angle), sin(angle), 0) * reach * index / 3.0 + Vector3(_rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.04, 0.04), 0))
			paths.append(points)
		Res.draw_lightning(_bolt_mesh, paths, 0.45)

	## Impacto no Cactus: poeira, grãos e faíscas no ponto do golpe.
	static func impact(parent: Node, point: Vector3) -> void:
		var node := Node3D.new()
		parent.add_child(node)
		node.global_position = point
		var dust := CPUParticles3D.new()
		dust.one_shot = true
		dust.explosiveness = 0.95
		dust.amount = 14
		dust.lifetime = 0.5
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		dust.emission_sphere_radius = 0.18
		dust.spread = 180
		dust.initial_velocity_min = 0.8
		dust.initial_velocity_max = 2.4
		dust.damping_min = 2.5
		dust.damping_max = 4.0
		dust.gravity = Vector3(0, -1.5, 0)
		dust.scale_amount_curve = Res.grow()
		dust.mesh = Res.sprite(0.32)
		dust.color_ramp = Res.ramp([Color(SAND, 0.85), Color("#b97d3e", 0.5), Color(SAND_DARK, 0.0)])
		node.add_child(dust)
		var sparks := CPUParticles3D.new()
		sparks.one_shot = true
		sparks.explosiveness = 1.0
		sparks.amount = 14
		sparks.lifetime = 0.25
		sparks.spread = 180
		sparks.initial_velocity_min = 4.0
		sparks.initial_velocity_max = 9.0
		sparks.gravity = Vector3.ZERO
		sparks.particle_flag_align_y = true
		sparks.mesh = Res.streak(0.018, 0.2, true)
		sparks.color_ramp = Res.ramp([Color(0.9, 0.98, 1.0, 1.0), Color(SPARK, 0.0)])
		node.add_child(sparks)
		for particles in [dust, sparks]: particles.emitting = true
		node.get_tree().create_timer(0.8, false).timeout.connect(node.queue_free)

## Escudo de terra: uma parede de areia compactada sobe do chão na frente do El Fuego,
## solta grãos enquanto está de pé e desmorona em areia quando acaba. Ao segurar um
## golpe, treme e lasca.
class SandShield extends Node3D:
	var active := false
	var facing := 1.0
	var _wall: Node3D
	var _rise := 0.0
	var _shake := 0.0
	var _trickle: CPUParticles3D
	var _was_active := false
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.seed = 4242
		_wall = Node3D.new()
		add_child(_wall)
		var material := StandardMaterial3D.new()
		material.albedo_texture = preload("res://assets/desert/phase01/sandstone.png")
		material.albedo_color = Color(0.42, 0.32, 0.25)
		material.uv1_triplanar = true
		material.uv1_scale = Vector3(1.6, 1.6, 1.6)
		material.roughness = 1.0
		# Lajes de pedra lado a lado no sentido da tela (câmera lateral), alturas diferentes
		# e levemente inclinadas: de lado lê como uma parede de terra com topo recortado.
		# [deslocamento x, altura, espessura, inclinação]
		var slabs := [[-0.1, 1.15, 0.15, 0.1], [0.0, 1.75, 0.16, 0.04], [0.1, 1.5, 0.15, -0.03], [0.2, 1.05, 0.14, -0.1]]
		for slab: Array in slabs:
			var piece := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(float(slab[2]), float(slab[1]), 1.5)
			piece.mesh = box
			piece.material_override = material
			piece.position = Vector3(float(slab[0]), float(slab[1]) * 0.5 - 0.05, 0)
			piece.rotation = Vector3(0, _rng.randf_range(-0.1, 0.1), float(slab[3]))
			_wall.add_child(piece)
			# Pedra solta no topo de cada laje.
			var cap := MeshInstance3D.new()
			var rock := SphereMesh.new()
			rock.radius = 0.08
			rock.height = 0.12
			rock.radial_segments = 6
			rock.rings = 3
			cap.mesh = rock
			cap.material_override = material
			cap.position = Vector3(0, float(slab[1]) * 0.5, 0)
			piece.add_child(cap)
		_trickle = CPUParticles3D.new()
		_trickle.amount = 40
		_trickle.lifetime = 0.8
		_trickle.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_trickle.emission_box_extents = Vector3(0.35, 0.05, 0.5)
		_trickle.position.y = 1.6
		_trickle.direction = Vector3.DOWN
		_trickle.spread = 10
		_trickle.initial_velocity_min = 0.2
		_trickle.initial_velocity_max = 0.6
		_trickle.gravity = Vector3(0, -6, 0)
		_trickle.particle_flag_align_y = true
		_trickle.mesh = Res.streak(0.012, 0.06)
		_trickle.color_ramp = Res.ramp([Color(SAND, 1.0), Color(SAND_DARK, 0.0)])
		_trickle.emitting = false
		_wall.add_child(_trickle)
		hide()

	func _process(delta: float) -> void:
		if active and not _was_active: _dust_burst(14, 1.0)
		if not active and _was_active: _dust_burst(26, 0.6)
		_was_active = active
		# Sobe rápido (0,12s) e afunda desmoronando quando a defesa termina.
		_rise = move_toward(_rise, 1.0 if active else 0.0, delta * (8.0 if active else 3.5))
		_shake = maxf(_shake - delta * 4.0, 0.0)
		visible = _rise > 0.01
		_trickle.emitting = active
		if not visible: return
		_wall.position = Vector3(facing * 0.72 + _rng.randf_range(-0.03, 0.03) * _shake, (_rise - 1.0) * 1.9, 0.05)
		_wall.rotation.y = 0.0 if facing > 0 else PI
		_wall.scale = Vector3(1, 1, 1) if active else Vector3.ONE * (0.75 + 0.25 * _rise)

	## Golpe segurado: a parede treme e lasca pedaços para o lado de quem bateu.
	func absorb(_direction: float) -> void:
		_shake = 1.0
		var chips := CPUParticles3D.new()
		chips.one_shot = true
		chips.explosiveness = 1.0
		chips.amount = 18
		chips.lifetime = 0.7
		chips.direction = Vector3(facing, 0.6, 0)
		chips.spread = 45
		chips.initial_velocity_min = 2.0
		chips.initial_velocity_max = 5.0
		chips.gravity = Vector3(0, -12, 0)
		chips.particle_flag_align_y = true
		chips.mesh = Res.streak(0.06, 0.1)
		chips.color_ramp = Res.ramp([Color("#9b7352", 1.0), Color("#6b4a30", 0.0)])
		chips.position = Vector3(facing * 0.9, 1.0, 0)
		add_child(chips)
		chips.emitting = true
		_dust_burst(10, 1.0, 1.0)
		get_tree().create_timer(0.9, false).timeout.connect(chips.queue_free)

	func _dust_burst(amount: int, height: float, along := 0.0) -> void:
		var dust := CPUParticles3D.new()
		dust.one_shot = true
		dust.explosiveness = 0.9
		dust.amount = amount
		dust.lifetime = 0.6
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.emission_box_extents = Vector3(0.25, 0.1 + along * 0.5, 0.6)
		dust.direction = Vector3(facing * 0.4, 1, 0)
		dust.spread = 50
		dust.initial_velocity_min = 0.6
		dust.initial_velocity_max = 1.8
		dust.damping_min = 2.0
		dust.damping_max = 3.0
		dust.gravity = Vector3(0, -0.8, 0)
		dust.scale_amount_curve = Res.grow()
		dust.mesh = Res.sprite(0.45)
		dust.color_ramp = Res.ramp([Color(SAND, 0.75), Color("#b97d3e", 0.45), Color(SAND_DARK, 0.0)])
		dust.position = Vector3(facing * 0.72, 0.15 + along * height * 0.5, 0.1)
		add_child(dust)
		dust.emitting = true
		get_tree().create_timer(0.8, false).timeout.connect(dust.queue_free)

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
	static func draw_lightning(mesh: ImmediateMesh, paths: Array, scale := 1.0) -> void:
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for pass_index in range(2):
			var width := (0.11 if pass_index == 0 else 0.026) * scale
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
