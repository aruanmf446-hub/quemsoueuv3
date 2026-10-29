extends RefCounted
## Poderes de areia do El Fuego: soco com explosão de areia e choque (ataque) e parede de
## terra que sobe do chão (defesa). Tudo gerado em código: partículas macias, riscos
## alinhados ao movimento e raios em faixas luminosas.
const SAND := Color("#d9a35e")
const SAND_DARK := Color("#8a5a2b")
const SAND_LIGHT := Color("#f3cf8e")
const SPARK := Color("#7fd4ff")

## Soco de areia: do punho sai um cone curto de areia compactada, com anel de pressão e
## raios estalando em volta da mão. É só visual: o dano é corpo a corpo (player.gd).
class SandPunch extends Node3D:
	var direction := 1.0
	var _bolt_mesh: ImmediateMesh
	var _light: OmniLight3D
	var _rng := RandomNumberGenerator.new()
	var _life := 0.0
	var _rebuild := 0.0

	func _ready() -> void:
		_rng.randomize()
		# Cone de areia: grãos em riscos disparados para a frente, rápidos e curtos.
		var blast := CPUParticles3D.new()
		blast.one_shot = true
		blast.explosiveness = 0.85
		blast.amount = 110
		blast.lifetime = 0.32
		blast.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		blast.emission_sphere_radius = 0.08
		blast.direction = Vector3(direction, 0.04, 0)
		blast.spread = 16
		blast.initial_velocity_min = 5.0
		blast.initial_velocity_max = 10.0
		blast.damping_min = 10.0
		blast.damping_max = 16.0
		blast.gravity = Vector3(0, -3, 0)
		blast.particle_flag_align_y = true
		blast.mesh = Res.streak(0.045, 0.26)
		blast.color_ramp = Res.ramp([Color(SAND_LIGHT, 1.0), Color(SAND, 0.9), Color(SAND_DARK, 0.0)])
		add_child(blast)
		# Nuvem do soco: puffs de areia que se abrem à frente do punho.
		var puff := CPUParticles3D.new()
		puff.one_shot = true
		puff.explosiveness = 0.9
		puff.amount = 34
		puff.lifetime = 0.45
		puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		puff.emission_sphere_radius = 0.1
		puff.direction = Vector3(direction, 0, 0)
		puff.spread = 28
		puff.initial_velocity_min = 2.0
		puff.initial_velocity_max = 5.0
		puff.damping_min = 6.0
		puff.damping_max = 9.0
		puff.gravity = Vector3(0, 0.4, 0)
		puff.scale_amount_curve = Res.grow()
		puff.mesh = Res.sprite(0.5)
		puff.color_ramp = Res.ramp([Color(SAND, 1.0), Color("#b97d3e", 0.75), Color(SAND_DARK, 0.0)])
		add_child(puff)
		for particles in [blast, puff]: particles.emitting = true
		# Anel de pressão saindo do punho, achatado na direção do soco.
		var ring := MeshInstance3D.new()
		ring.mesh = Res.ring_quad()
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ring_mat: StandardMaterial3D = ring.mesh.surface_get_material(0).duplicate()
		ring_mat.albedo_color = Color(1.0, 0.85, 0.55, 0.9)
		ring.material_override = ring_mat
		ring.position = Vector3(direction * 0.05, 0, 0.1)
		ring.scale = Vector3(0.25, 0.5, 1)
		add_child(ring)
		var wave := create_tween().set_parallel(true)
		wave.tween_property(ring, "position:x", direction * 0.7, 0.2).set_ease(Tween.EASE_OUT)
		wave.tween_property(ring, "scale", Vector3(0.6, 1.6, 1), 0.2).set_ease(Tween.EASE_OUT)
		wave.tween_property(ring_mat, "albedo_color:a", 0.0, 0.2)
		_bolt_mesh = ImmediateMesh.new()
		var bolts := MeshInstance3D.new()
		bolts.mesh = _bolt_mesh
		bolts.material_override = Res.lightning_material()
		bolts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bolts.position.z = 0.12
		add_child(bolts)
		_light = OmniLight3D.new()
		_light.light_color = SPARK
		_light.light_energy = 2.0
		_light.omni_range = 2.2
		add_child(_light)
		create_tween().tween_property(_light, "light_energy", 0.0, 0.25)
		get_tree().create_timer(0.7, false).timeout.connect(queue_free)

	func _process(delta: float) -> void:
		_life += delta
		_rebuild -= delta
		if _rebuild > 0.0: return
		_rebuild = 0.04
		_bolt_mesh.clear_surfaces()
		if _life > 0.2: return
		# Raios curtos estalando do punho para a frente, dentro do cone de areia.
		var paths: Array = []
		for bolt in range(3):
			var points := PackedVector3Array([Vector3.ZERO])
			var reach := _rng.randf_range(0.5, 1.1)
			for index in range(1, 6):
				var t := float(index) / 5.0
				points.append(Vector3(direction * reach * t, _rng.randf_range(-0.14, 0.14) * t, 0))
			paths.append(points)
		Res.draw_lightning(_bolt_mesh, paths)

	## Impacto no Cactus: anel de choque, areia, grãos e faíscas.
	static func impact(parent: Node, point: Vector3) -> void:
		var node := Node3D.new()
		parent.add_child(node)
		node.global_position = point
		var ring := MeshInstance3D.new()
		ring.mesh = Res.ring_quad()
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.scale = Vector3.ONE * 0.3
		ring.position.z = 0.15
		var ring_mat: StandardMaterial3D = ring.mesh.surface_get_material(0).duplicate()
		ring.material_override = ring_mat
		node.add_child(ring)
		var grow := node.create_tween().set_parallel(true)
		grow.tween_property(ring, "scale", Vector3.ONE * 2.0, 0.26).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		grow.tween_property(ring_mat, "albedo_color:a", 0.0, 0.26)
		var dust := CPUParticles3D.new()
		dust.one_shot = true
		dust.explosiveness = 0.95
		dust.amount = 22
		dust.lifetime = 0.6
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		dust.emission_sphere_radius = 0.18
		dust.spread = 180
		dust.initial_velocity_min = 0.8
		dust.initial_velocity_max = 2.4
		dust.damping_min = 2.5
		dust.damping_max = 4.0
		dust.gravity = Vector3(0, -1.5, 0)
		dust.scale_amount_curve = Res.grow()
		dust.mesh = Res.sprite(0.45)
		dust.color_ramp = Res.ramp([Color(SAND, 0.9), Color("#b97d3e", 0.55), Color(SAND_DARK, 0.0)])
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
		var slabs := [[-0.22, 1.25, 0.26, 0.10], [0.0, 1.85, 0.3, 0.04], [0.24, 1.55, 0.28, -0.05], [0.44, 0.95, 0.24, -0.14]]
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
			rock.radius = 0.17
			rock.height = 0.22
			rock.radial_segments = 6
			rock.rings = 3
			cap.mesh = rock
			cap.material_override = material
			cap.position = Vector3(0, float(slab[1]) * 0.5, 0)
			piece.add_child(cap)
		_trickle = CPUParticles3D.new()
		_trickle.amount = 24
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
		_trickle.mesh = Res.streak(0.02, 0.09)
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
