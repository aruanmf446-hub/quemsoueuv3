extends "res://scripts/desert/t15d/city_props.gd"
## Marco de salvamento visível na pista. Sem bandeira e sem colisão adicional.
var index := 0
var _flame: MeshInstance3D
var _light: OmniLight3D
var _caption: Label3D
static var _checkpoint_glass: Dictionary={}

func _ready() -> void:
 add_to_group("campaign_checkpoints")
 _box(Vector3(0,0.08,0),Vector3(0.64,0.16,0.58),"trim")
 _box(Vector3(0,0.54,0),Vector3(0.38,0.88,0.36),"stone")
 _box(Vector3(0,1.02,0),Vector3(0.58,0.14,0.50),"trim")
 _box(Vector3(0,1.30,0),Vector3(0.34,0.44,0.30),"lantern_glass")
 for x: float in [-0.22,0.22]:
  for z: float in [-0.20,0.20]:_box(Vector3(x,1.32,z),Vector3(0.045,0.58,0.045),"lantern_iron")
 _box(Vector3(0,1.60,0),Vector3(0.58,0.11,0.50),"lantern_iron")
 _flush()
 _flame=get_node("City_lantern_glass")
 _light=OmniLight3D.new()
 _light.position.y=1.3
 _light.omni_range=3.0
 _light.shadow_enabled=false
 _light.visible=false
 add_child(_light)
 _caption=Label3D.new()
 _caption.name="CheckpointCaption"
 _caption.font=preload("res://assets/desert/phase01/interface.ttf")
 _caption.font_size=64
 _caption.pixel_size=0.0047
 _caption.outline_size=12
 _caption.outline_modulate=Color("#131c27")
 _caption.position=Vector3(0,2.0,0.30)
 _caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 _caption.shaded=false
 add_child(_caption)
 refresh_lit(-1)

func refresh_lit(active_index: int) -> void:
 if not is_inside_tree():return
 var lit:=index<=active_index
 if not _checkpoint_glass.has(lit):
  var glass:=StandardMaterial3D.new()
  glass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  glass.albedo_color=Color("#88dcc6") if lit else Color("#f0c17b")
  _checkpoint_glass[lit]=glass
 _flame.material_override=_checkpoint_glass[lit]
 _light.visible=lit
 _light.light_color=Color("#88dcc6")
 _light.light_energy=0.7
 _caption.text=("SALVO" if lit else "CHECKPOINT")+" %d/7" % (index+1)
 _caption.modulate=Color("#a5ecda") if lit else Color("#f6d9a6")
