extends Node3D
## Casulo de âmbar facetado: formação dos pés à cabeça, rosto legível e quebra curta.
## Só apresentação: duração, alcance e imobilização pertencem ao Cactus/Player.
const SHELL_SHADER=preload("res://scripts/desert/t15d/shaders/amber_crystal.gdshader")
const FROST_SHADER=preload("res://scripts/desert/t15d/shaders/amber_frost.gdshader")
const SIDES:=8
const RELEASE_TIME:=0.38
static var _shell_geometry: ArrayMesh
static var _chip_geometry: ArrayMesh
var _material: ShaderMaterial
var _shell: MeshInstance3D
var _chips: MultiMeshInstance3D
var _age:=0.0
var _remaining:=0.0
var _release_age:=-1.0
var actor_model: Node3D
var _frost: ShaderMaterial
func _ready() -> void:
	name="AmberFreeze"
	if _shell_geometry==null:_shell_geometry=_build_shell()
	_shell=MeshInstance3D.new()
	_shell.mesh=_shell_geometry
	_shell.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material=ShaderMaterial.new()
	_material.shader=SHELL_SHADER
	_frost=ShaderMaterial.new()
	_frost.shader=FROST_SHADER
	_shell.material_override=_material
	add_child(_shell)
	if _chip_geometry==null:
		var chip:=SurfaceTool.new()
		chip.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [Vector3(-0.055,-0.065,0),Vector3(0.065,0.01,0),Vector3(-0.01,0.10,0)]:chip.add_vertex(v)
		chip.generate_normals()
		_chip_geometry=chip.commit()
	_chips=MultiMeshInstance3D.new()
	_chips.multimesh=MultiMesh.new()
	_chips.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	_chips.multimesh.mesh=_chip_geometry
	_chips.multimesh.instance_count=12
	_chips.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var resin:=StandardMaterial3D.new()
	resin.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	resin.cull_mode=BaseMaterial3D.CULL_DISABLED
	resin.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	resin.albedo_color=Color("#efbd60")
	_chips.material_override=resin
	add_child(_chips)
	_chips.hide()
	set_process(false)
func begin(seconds: float) -> void:
	top_level=false
	transform=Transform3D.IDENTITY
	_age=0.0
	_remaining=seconds
	_release_age=-1.0
	show()
	_shell.show()
	_shell.scale=Vector3.ONE
	_chips.hide()
	_material.set_shader_parameter("formation",0.0)
	_material.set_shader_parameter("opacity",1.0)
	_frost.set_shader_parameter("strength",0.0)
	if is_instance_valid(actor_model):actor_model.set_status_overlay(_frost)
	set_process(true)
func extend(seconds: float) -> void:
	_remaining=maxf(_remaining,seconds)
func finish() -> void:
	if _release_age>=0.0:return
	if is_instance_valid(actor_model):actor_model.set_status_overlay(null)
	var at:=global_transform
	top_level=true
	global_transform=at
	_release_age=0.0
	_chips.show()
func _process(delta: float) -> void:
	_age+=delta
	_remaining=maxf(0.0,_remaining-delta)
	_material.set_shader_parameter("age",_age)
	_frost.set_shader_parameter("strength",minf(1.0,_age/0.18))
	_material.set_shader_parameter("formation",minf(1.0,_age/0.18))
	_material.set_shader_parameter("stress",clampf((0.65-_remaining)/0.65,0,1))
	if _release_age<0.0:return
	_release_age+=delta
	var fade:=clampf(1.0-_release_age/RELEASE_TIME,0,1)
	_material.set_shader_parameter("opacity",fade*fade)
	_shell.scale=Vector3.ONE*(1.0+_release_age*0.18)
	var resin:=_chips.material_override as StandardMaterial3D
	resin.albedo_color.a=fade
	for i in 12:
		var angle:=i*TAU/12.0
		var t:=_release_age
		var offset:=Vector3(cos(angle)*(0.43+t*0.72),0.28+(i%4)*0.40+t*0.55-t*t*3.4,sin(angle)*(0.32+t*0.35))
		var basis:=Basis.from_euler(Vector3(t*(i%3+1)*3.0,angle,t*2.0)).scaled(Vector3.ONE*(0.65+float(i%3)*0.22))
		_chips.multimesh.set_instance_transform(i,Transform3D(basis,offset))
	if _release_age>=RELEASE_TIME:
		hide()
		set_process(false)
static func _ring(level: int,index: int) -> Vector3:
	var angle:=TAU*(index%SIDES)/SIDES+PI/8.0
	var rx: float=[0.34,0.54,0.49,0.27][level]
	var rz: float=[0.29,0.41,0.37,0.23][level]
	return Vector3(cos(angle)*rx,[0.035,0.60,1.38,1.83][level],sin(angle)*rz)
static func _vertex(st: SurfaceTool,p: Vector3,u: float,edge: bool,shade:=1.0) -> void:
	st.set_color(Color(shade,shade,shade,1.0 if edge else 0.0))
	st.set_uv(Vector2(u,p.y/1.90))
	st.add_vertex(p)
static func _line(st: SurfaceTool,a: Vector3,b: Vector3) -> void:
	var normal:=(b-a).cross(Vector3.FORWARD).normalized()*0.006
	for p: Vector3 in [a-normal,b-normal,b+normal,a-normal,b+normal,a+normal]:_vertex(st,p,0.0,true)
static func _build_shell() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in 3:
		for i in SIDES:
			var a:=_ring(level,i)
			var b:=_ring(level,i+1)
			var c:=_ring(level+1,i+1)
			var d:=_ring(level+1,i)
			var shade:=0.70+float(i%3)*0.15
			_vertex(st,a,0.0,false,shade)
			_vertex(st,b,1.0,false,shade)
			_vertex(st,c,1.0,false,shade)
			_vertex(st,a,0.0,false,shade)
			_vertex(st,c,1.0,false,shade)
			_vertex(st,d,0.0,false,shade)
			if i in [0,3]:_line(st,a,d)
			# Friso só na base e no ombro: poucas arestas, sem grade sobre o rosto.
			if level==0:_line(st,a,b)
	for i in SIDES:
		for p: Vector3 in [_ring(3,i),_ring(3,i+1),Vector3(0,1.90,0)]:_vertex(st,p,0.0,false)
	st.generate_normals()
	return st.commit()
