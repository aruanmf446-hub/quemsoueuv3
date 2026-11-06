extends "res://scripts/desert/t15d/city_props.gd"
## O checkpoint usa a lanterna já presente na cidade, fora da linha de corrida.
## Mantém o mesmo grupo, índice e sinalização de ativação, sem estandarte no piso.
var index := 0
var _flame: MeshInstance3D
var _light: OmniLight3D
static var _checkpoint_glass: Dictionary={}

func _ready() -> void:
	add_to_group("campaign_checkpoints")
	# Lanterna baixa no recuo da pista: não cria outro poste junto aos existentes.
	_box(Vector3(0,0.045,0),Vector3(0.40,0.09,0.40),"trim")
	_box(Vector3(0,0.12,0),Vector3(0.28,0.06,0.28),"lantern_iron")
	_box(Vector3(0,0.29,0),Vector3(0.18,0.25,0.18),"lantern_glass")
	for x: float in [-0.12,0.12]:
		for z: float in [-0.12,0.12]:
			_box(Vector3(x,0.29,z),Vector3(0.025,0.34,0.025),"lantern_iron")
	_box(Vector3(0,0.46,0),Vector3(0.31,0.06,0.31),"lantern_iron")
	_box(Vector3(0,0.51,0),Vector3(0.20,0.04,0.20),"lantern_iron")
	_flush()
	_flame=get_node("City_lantern_glass")
	_light=OmniLight3D.new()
	_light.position.y=0.35
	_light.omni_range=4.0
	_light.light_color=Color("#ffbe6b")
	_light.shadow_enabled=false
	_light.visible=false
	add_child(_light)

func refresh_lit(active_index: int) -> void:
	if not is_inside_tree():return
	var lit:=index<=active_index
	if not _checkpoint_glass.has(lit):
		var glass:=StandardMaterial3D.new()
		glass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		glass.albedo_color=Color("#ffcf7a") if lit else Color("#6c6659")
		_checkpoint_glass[lit]=glass
	_flame.material_override=_checkpoint_glass[lit]
	_light.visible=lit
	_light.light_energy=0.9
