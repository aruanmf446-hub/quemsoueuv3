extends Node3D
## Shared stylized flask geometry, for the hand and the projectile (world metres).
var kind:="green"
func _ready()->void:
 var liquid:=StandardMaterial3D.new()
 liquid.albedo_color=Color("#77cb55") if kind=="green" else Color("#d94d38")
 liquid.metallic=0.18;liquid.roughness=0.23
 var brass:=StandardMaterial3D.new();brass.albedo_color=Color("#b48b46");brass.metallic=0.7;brass.roughness=0.35
 var body:=SphereMesh.new();body.radius=0.135;body.height=0.25;body.radial_segments=16;body.rings=8
 _part(body,Vector3.ZERO,liquid)
 var neck:=CylinderMesh.new();neck.top_radius=0.045;neck.bottom_radius=0.06;neck.height=0.14;neck.radial_segments=12
 _part(neck,Vector3(0,0.16,0),liquid)
 var cap:=CylinderMesh.new();cap.top_radius=0.057;cap.bottom_radius=0.057;cap.height=0.055;cap.radial_segments=12
 _part(cap,Vector3(0,0.245,0),brass)
func _part(mesh: Mesh,at: Vector3,material: Material)->void:
 var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at;node.material_override=material;add_child(node)
