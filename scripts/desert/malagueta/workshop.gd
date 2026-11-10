extends Node3D
## Phase-10 set dressing, behind the route. Existing textures/art, shared simple meshes.
var _iron: StandardMaterial3D
var _brass: StandardMaterial3D
var _rock: ShaderMaterial
func _ready()->void:
 _iron=_metal(Color("#41444a"),0.62);_brass=_metal(Color("#b38541"),0.58)
 _rock=ShaderMaterial.new();_rock.shader=preload("res://scripts/desert/malagueta/mine_rock.gdshader");_rock.set_shader_parameter("rock",preload("res://assets/desert/phase01/sandstone.png"))
 # Continuous mine wall descends below the playable floor and reaches the ceiling.
 _box(Vector3(0,4,-7.5),Vector3(36,26,1.5),_rock)
 for x in [-11.8,-5.8,0.2,6.2,11.8]:
  _box(Vector3(x,4.3,-5.5),Vector3(0.35,17,0.45),_iron)
  for y in [0.2,4.5,9.0]:_box(Vector3(x,y,-5.18),Vector3(0.56,0.42,0.12),_brass)
 for y in [-0.1,12.0]:_box(Vector3(0,y,-5.5),Vector3(24,0.32,0.4),_iron)
 for at in [Vector3(-8,4,1),Vector3(8,10,1)]:
  var light:=OmniLight3D.new();light.position=at;light.omni_range=9;light.light_color=Color("#ffd39b");light.light_energy=1.2;light.shadow_enabled=false;add_child(light)
 # The blade rails span the arena; only the cutter itself moves.
 for y in [1.2,3.1,5.0,6.9,8.8]:
  for dy in [-0.25,0.05]:_box(Vector3(0,y+dy,-1.38),Vector3(23.8,0.07,0.08),_iron)
  for x in [-11.7,11.7]:
   _box(Vector3(x,y-0.12,-1.2),Vector3(0.4,0.8,0.6),_iron)
   _box(Vector3(x,y-0.12,-0.88),Vector3(0.25,0.48,0.04),_brass)
 _box(Vector3(0,-3,-2.8),Vector3(36,6,1),_rock)
 # Boss laboratory: bottles and apparatus provide context for its three Tasks.
 _box(Vector3(9,9.5,-0.92),Vector3(2.55,0.13,0.7),_iron)
 for x in [8.05,9.95]:_box(Vector3(x,9.15,-0.92),Vector3(0.12,0.7,0.45),_iron)
 for i in 3:
  var bottle:=preload("res://scripts/desert/malagueta/bottle.gd").new();bottle.kind="green" if i!=1 else "red";bottle.position=Vector3(8.3+i*0.65,9.7,-0.8);add_child(bottle)
 # Upper landing trim and supports, with a readable uninterrupted top.
 _box(Vector3(9,8.43,0),Vector3(4.2,0.14,2.1),_brass)
 for x in [7.2,10.8]:_box(Vector3(x,4,-0.85),Vector3(0.24,8,0.3),_iron)
func _metal(color: Color,roughness: float)->StandardMaterial3D:
 var material:=StandardMaterial3D.new();material.albedo_color=color;material.metallic=0.6;material.roughness=roughness;return material
func _box(at: Vector3,size: Vector3,material: Material)->void:
 var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=at;node.material_override=material;add_child(node)
