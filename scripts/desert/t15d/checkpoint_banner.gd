extends Node3D
## Bandeira de checkpoint: apagada até o jogador passar por ela, depois acesa em âmbar.
var index := 0
var _flame: MeshInstance3D
var _light: OmniLight3D
var _cloth: MeshInstance3D

func _ready() -> void:
	add_to_group("campaign_checkpoints")
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#3a4252")
	metal.roughness = 0.6
	var pole := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.05
	shaft.bottom_radius = 0.06
	shaft.height = 2.0
	pole.mesh = shaft
	pole.position.y = 1.0
	pole.material_override = metal
	add_child(pole)
	_cloth = MeshInstance3D.new()
	var flag := BoxMesh.new()
	flag.size = Vector3(0.9,0.55,0.03)
	_cloth.mesh = flag
	_cloth.position = Vector3(0.48,1.7,0)
	add_child(_cloth)
	_flame = MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.13
	orb.height = 0.26
	_flame.mesh = orb
	_flame.position.y = 2.1
	add_child(_flame)
	_light = OmniLight3D.new()
	_light.position.y = 2.0
	_light.omni_range = 4.0
	_light.light_color = Color("#ffbe6b")
	_light.shadow_enabled = false
	add_child(_light)

func refresh_lit(active_index: int) -> void:
	if not is_inside_tree(): return
	var lit := index <= active_index
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("#d9a441") if lit else Color("#4d5566")
	cloth.emission_enabled = lit
	cloth.emission = Color("#b5742a")
	cloth.emission_energy_multiplier = 0.4
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cloth.material_override = cloth
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("#ffcf7a") if lit else Color("#5d6575")
	_flame.material_override = glow
	_light.visible = lit
	_light.light_energy = 0.9
