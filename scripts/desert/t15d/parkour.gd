extends RefCounted
## Peças de parkour da campanha noturna: gêiser de areia e pedra que desmorona.

## Gêiser: lança o jogador alto o bastante para passar a muralha (5,7m de altura).
## Depois do lançamento o pulo duplo fica gasto, para a trajetória ser previsível.
class Geyser extends Area3D:
	signal launched
	const LAUNCH := 16.5
	var _spout: CPUParticles3D
	var _cooldown := 0.0
	var _time := 0.0
	var _glow: MeshInstance3D

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.1, 0.6, 2.0)
		shape.shape = box
		shape.position.y = 0.3
		add_child(shape)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.42
		torus.outer_radius = 0.62
		torus.rings = 24
		torus.ring_segments = 8
		ring.mesh = torus
		ring.scale.y = 0.6
		var stone := StandardMaterial3D.new()
		stone.albedo_texture = preload("res://assets/desert/phase01/sandstone.png")
		stone.albedo_color = Color(0.75, 0.62, 0.5)
		ring.material_override = stone
		add_child(ring)
		_glow = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.42
		disc.bottom_radius = 0.42
		disc.height = 0.04
		_glow.mesh = disc
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("#ffcf7a")
		_glow.material_override = glow
		_glow.position.y = 0.03
		add_child(_glow)
		var light := OmniLight3D.new()
		light.light_color = Color("#ffc46b")
		light.light_energy = 0.8
		light.omni_range = 3.0
		light.position.y = 0.6
		add_child(light)
		_spout = CPUParticles3D.new()
		_spout.amount = 60
		_spout.lifetime = 0.7
		_spout.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_spout.emission_sphere_radius = 0.25
		_spout.direction = Vector3.UP
		_spout.spread = 12
		_spout.initial_velocity_min = 2.0
		_spout.initial_velocity_max = 4.0
		_spout.gravity = Vector3(0, -4, 0)
		var grain := BoxMesh.new()
		grain.size = Vector3.ONE * 0.05
		var sand := StandardMaterial3D.new()
		sand.albedo_color = Color("#e3b56f")
		grain.material = sand
		_spout.mesh = grain
		add_child(_spout)
		body_entered.connect(_launch)

	func _physics_process(delta: float) -> void:
		_time += delta
		_cooldown = maxf(_cooldown - delta, 0.0)
		_glow.scale = Vector3.ONE * (0.9 + 0.1 * sin(_time * 6.0))
		for body in get_overlapping_bodies(): _launch(body)

	func _launch(body: Node3D) -> void:
		if _cooldown > 0.0 or not body.is_in_group("player") or body.get("is_dead"): return
		if body.velocity.y > 2.0: return
		_cooldown = 0.4
		body.velocity.y = LAUNCH
		body.set("jumps_used", 2)
		body.set("_coyote_timer", 0.0)
		var actor = body.get("_actor")
		if actor != null: actor.play_animation("pulo_duplo", false, 0.05)
		_spout.initial_velocity_min = 8.0
		_spout.initial_velocity_max = 13.0
		_spout.restart()
		get_tree().create_timer(0.5, false).timeout.connect(func() -> void:
			if is_instance_valid(_spout):
				_spout.initial_velocity_min = 2.0
				_spout.initial_velocity_max = 4.0)
		launched.emit()

## Pedra no meio do vão: treme ao ser pisada, cai 0,55s depois e volta 2,5s mais tarde.
class CrumbleStone extends StaticBody3D:
	signal crumbled
	const DELAY := 0.55
	const RETURN := 2.5
	var stone_size := Vector3(2.4, 0.6, 3.0)
	var _shape: CollisionShape3D
	var _mesh: MeshInstance3D
	var _timer := -1.0
	var _gone := 0.0
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		collision_layer = 1
		add_to_group("crumble_stones")
		_shape = CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = stone_size
		_shape.shape = box
		add_child(_shape)
		_mesh = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = stone_size
		_mesh.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = preload("res://assets/desert/phase01/sandstone.png")
		mat.albedo_color = Color(0.85, 0.66, 0.48)
		mat.uv1_scale = Vector3(1.5, 1.5, 1)
		_mesh.material_override = mat
		add_child(_mesh)
		# Rachaduras escuras indicam que a pedra não aguenta.
		for crack in range(3):
			var line := MeshInstance3D.new()
			var bar := BoxMesh.new()
			bar.size = Vector3(0.04, stone_size.y * 0.8, 0.02)
			line.mesh = bar
			var dark := StandardMaterial3D.new()
			dark.albedo_color = Color("#2b1a10")
			line.material_override = dark
			line.position = Vector3(-0.5 + crack * 0.5, 0, stone_size.z * 0.5 + 0.01)
			line.rotation.z = [0.3, -0.2, 0.4][crack]
			_mesh.add_child(line)

	func _physics_process(delta: float) -> void:
		if _gone > 0.0:
			_gone -= delta
			if _gone <= 0.0: _restore()
			return
		if _timer < 0.0:
			for player in get_tree().get_nodes_in_group("player"):
				if player.is_on_floor() and absf(player.global_position.x - global_position.x) < stone_size.x * 0.5 + 0.3 \
						and absf(player.global_position.y - (global_position.y + stone_size.y * 0.5)) < 0.15:
					_timer = DELAY
			return
		_timer -= delta
		_mesh.position = Vector3(_rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.03, 0.0), 0)
		if _timer <= 0.0: _crumble()

	func _crumble() -> void:
		_timer = -1.0
		_gone = RETURN
		_shape.set_deferred("disabled", true)
		var fall := create_tween()
		fall.tween_property(_mesh, "position:y", -4.0, 0.5).set_ease(Tween.EASE_IN)
		fall.parallel().tween_property(_mesh, "rotation:z", 0.6, 0.5)
		crumbled.emit()

	func _restore() -> void:
		_mesh.position = Vector3.ZERO
		_mesh.rotation = Vector3.ZERO
		_mesh.scale = Vector3.ONE * 0.2
		_shape.set_deferred("disabled", false)
		create_tween().tween_property(_mesh, "scale", Vector3.ONE, 0.25)

## Balsa de pedra: vai e volta sobre o vão largo (4s por volta, pausa curta em cada borda).
## AnimatableBody3D carrega o jogador junto; o topo fica no nível do chão.
class Ferry extends AnimatableBody3D:
	const PERIOD := 4.0
	var from_x := 0.0
	var to_x := 0.0
	var _time := 0.0

	func _ready() -> void:
		add_to_group("ferries")
		collision_layer = 1
		sync_to_physics = true
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.6, 0.5, 3.0)
		shape.shape = box
		shape.position.y = -0.25
		add_child(shape)
		var stone := StandardMaterial3D.new()
		stone.albedo_texture = preload("res://assets/desert/phase01/sandstone.png")
		stone.albedo_color = Color(0.82, 0.66, 0.5)
		stone.uv1_triplanar = true
		var deck := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.6, 0.5, 3.0)
		deck.mesh = mesh
		deck.material_override = stone
		deck.position.y = -0.25
		add_child(deck)
		# Lanternas nas pontas: a balsa fica visível sobre o poço escuro.
		for side in [-1.0, 1.0]:
			var lamp := MeshInstance3D.new()
			var orb := SphereMesh.new()
			orb.radius = 0.09
			orb.height = 0.18
			lamp.mesh = orb
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color = Color("#ffc46b")
			lamp.material_override = glow
			lamp.position = Vector3(side * 1.15, 0.12, -1.2)
			add_child(lamp)
		var light := OmniLight3D.new()
		light.light_color = Color("#ffc46b")
		light.light_energy = 0.7
		light.omni_range = 3.0
		light.position = Vector3(0, 0.6, -1.0)
		add_child(light)
		position.x = from_x

	func _physics_process(delta: float) -> void:
		_time += delta
		var phase := fmod(_time, PERIOD) / PERIOD
		# 0→1→0 com pausa nas bordas: tempo para subir e descer.
		var t := clampf((1.0 - cos(phase * TAU)) * 0.5 * 1.2 - 0.1, 0.0, 1.0)
		position.x = lerpf(from_x, to_x, t)
