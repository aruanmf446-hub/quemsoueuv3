extends RefCounted
## Estações rasas embutidas no piso. Uma malha/desenho por base, sem luzes,
## colisores nem processamento; geometria e materiais compartilhados.
static var _meshes: Dictionary={}
static var _materials: Dictionary={}
const RESOURCE_COLORS={"attack":"#d49b59","defense":"#70a9bd","health":"#b96e75","amber":"#d4bb81","dash":"#d1bd64","rupture":"#bc9465"}

static func create(kind: String,theme: int,spent: bool) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var key:="%d/%s" % [theme,kind]
	if not _meshes.has(key):_meshes[key]=_build(kind,theme)
	node.mesh=_meshes[key]
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_spent(node,spent)
	return node

static func set_spent(node: MeshInstance3D,spent: bool) -> void:
	if not _materials.has(spent):
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo=true
		material.albedo_color=Color("#a8a49e") if spent else Color.WHITE
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		_materials[spent]=material
	node.material_override=_materials[spent]
	node.set_meta("spent",spent)

static func _build(kind: String,theme: int) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top:=Color(["#747875","#4c505b","#6c6058","#526c76","#59685e","#7b7268","#484a49","#5a5858","#484a49","#484a49"][clampi(theme,1,10)-1])
	var rim:=Color("#8d795d") if theme not in [4,5,6] else top.lightened(0.14)
	var edge:=Color("#343638")
	var outer:=_contour(0.38,0.29,0.075)
	var inner:=_contour(0.32,0.23,0.055)
	for i in 8:
		var j:=(i+1)%8
		_quad(st,Vector3(outer[i].x,-0.025,outer[i].y),Vector3(outer[i].x,0.010,outer[i].y),Vector3(outer[j].x,0.010,outer[j].y),Vector3(outer[j].x,-0.025,outer[j].y),edge)
		_quad(st,Vector3(outer[i].x,0.010,outer[i].y),Vector3(inner[i].x,0.015,inner[i].y),Vector3(inner[j].x,0.015,inner[j].y),Vector3(outer[j].x,0.010,outer[j].y),rim)
		_triangle(st,Vector3(0,0.008,0),Vector3(inner[i].x,0.008,inner[i].y),Vector3(inner[j].x,0.008,inner[j].y),top)
	# Parafusos e indicação do recurso ficam rasos: não viram obstáculo ou torrão.
	for x: float in [-0.29,0.29]:
		for z: float in [-0.20,0.20]:_disc(st,Vector3(x,0.017,z),0.018,edge)
	var ink:=Color(RESOURCE_COLORS.get(kind,"#bba988"))
	match kind:
		"health":
			_bar(st,Vector2(-0.12,0),Vector2(0.12,0),0.044,ink)
			_bar(st,Vector2(0,-0.12),Vector2(0,0.12),0.044,ink)
		"defense":_line(st,[Vector2(-0.10,-0.10),Vector2(0.10,-0.10),Vector2(0.09,0.04),Vector2(0,0.13),Vector2(-0.09,0.04),Vector2(-0.10,-0.10)],0.024,ink)
		"amber":_line(st,[Vector2(0,-0.13),Vector2(0.10,0),Vector2(0,0.13),Vector2(-0.10,0),Vector2(0,-0.13)],0.024,ink)
		"dash":_line(st,[Vector2(0.07,-0.13),Vector2(-0.06,0.015),Vector2(0.06,0.015),Vector2(-0.07,0.13)],0.035,ink)
		"rupture":
			_line(st,[Vector2(-0.025,-0.13),Vector2(0.045,-0.035),Vector2(-0.045,0.045),Vector2(0.01,0.13)],0.025,ink)
			_bar(st,Vector2(0.045,-0.035),Vector2(0.12,-0.06),0.022,ink)
		_:
			_line(st,[Vector2(-0.10,0.10),Vector2(-0.11,0),Vector2(-0.015,-0.14),Vector2(0.02,-0.02),Vector2(0.09,-0.07),Vector2(0.10,0.10),Vector2(-0.10,0.10)],0.026,ink)
	return st.commit()

static func _contour(x: float,z: float,cut: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-x+cut,-z),Vector2(x-cut,-z),Vector2(x,-z+cut),Vector2(x,z-cut),Vector2(x-cut,z),Vector2(-x+cut,z),Vector2(-x,z-cut),Vector2(-x,-z+cut)])
static func _line(st: SurfaceTool,points: Array,width: float,color: Color) -> void:
	for i in range(points.size()-1):_bar(st,points[i],points[i+1],width,color)
static func _bar(st: SurfaceTool,a: Vector2,b: Vector2,width: float,color: Color) -> void:
	var normal:=(b-a).orthogonal().normalized()*width*0.5
	_quad(st,Vector3(a.x+normal.x,0.018,a.y+normal.y),Vector3(b.x+normal.x,0.018,b.y+normal.y),Vector3(b.x-normal.x,0.018,b.y-normal.y),Vector3(a.x-normal.x,0.018,a.y-normal.y),color)
static func _disc(st: SurfaceTool,center: Vector3,radius: float,color: Color) -> void:
	for i in 6:
		var a:=TAU*i/6.0
		var b:=TAU*(i+1)/6.0
		_triangle(st,center,center+Vector3(cos(a)*radius,0,sin(a)*radius),center+Vector3(cos(b)*radius,0,sin(b)*radius),color)
static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
	_triangle(st,a,b,c,color)
	_triangle(st,a,c,d,color)
static func _triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	st.set_color(color)
	st.set_normal((b-a).cross(c-a).normalized())
	for point in [a,b,c]:st.add_vertex(point)
