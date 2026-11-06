extends Node3D
## Bandeira de checkpoint: apagada até o jogador passar por ela, depois acesa em âmbar.
var index := 0
var _flame: MeshInstance3D
var _light: OmniLight3D
var _cloth: MeshInstance3D
static var _flag_mesh: ArrayMesh
static var _flag_materials: Dictionary={}

func _ready() -> void:
	add_to_group("campaign_checkpoints")
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#4b3c30")
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
	var foot:=MeshInstance3D.new()
	var plinth:=CylinderMesh.new()
	plinth.height=0.08
	plinth.top_radius=0.13
	plinth.bottom_radius=0.17
	plinth.radial_segments=8
	foot.mesh=plinth
	foot.position.y=0.04
	foot.material_override=metal
	add_child(foot)
	var arm:=MeshInstance3D.new()
	var bar:=BoxMesh.new()
	bar.size=Vector3(0.70,0.045,0.06)
	arm.mesh=bar
	arm.position=Vector3(0.31,1.94,0)
	arm.material_override=metal
	add_child(arm)
	var source:=load("res://assets/desert/modular/desert_timber_bridge.res") as Texture2D
	var height:=0.55*source.get_height()*0.36/(source.get_width()*0.059)
	if _flag_mesh==null:
		# Recorta a própria silhueta do estandarte aprovado; não leva um pedaço
		# retangular da treliça para o pano. Mantém a proporção original do desenho.
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var points:=[Vector3(-0.275,height*0.5,0),Vector3(0.275,height*0.5,0),Vector3(0.275,-height*0.27778,0),Vector3(0,-height*0.5,0),Vector3(-0.275,-height*0.27778,0)]
		var uv:=[Vector2(0.165,0.44),Vector2(0.224,0.44),Vector2(0.224,0.72),Vector2(0.1945,0.80),Vector2(0.165,0.72)]
		for i in [0,1,2,0,2,4,2,3,4]:
			st.set_uv(uv[i])
			st.set_normal(Vector3.FORWARD)
			st.add_vertex(points[i])
		_flag_mesh=st.commit()
	_cloth = MeshInstance3D.new()
	_cloth.mesh=_flag_mesh
	_cloth.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloth.position = Vector3(0.34,1.93-height*0.5,0.01)
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
	if not _flag_materials.has(lit):
		var cloth:=StandardMaterial3D.new()
		cloth.albedo_texture=load("res://assets/desert/modular/desert_timber_bridge.res")
		cloth.albedo_color=Color("#e8d5b8") if lit else Color("#777781")
		cloth.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		cloth.cull_mode=BaseMaterial3D.CULL_DISABLED
		cloth.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_flag_materials[lit]=cloth
	_cloth.material_override=_flag_materials[lit]
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("#ffcf7a") if lit else Color("#5d6575")
	_flame.material_override = glow
	_light.visible = lit
	_light.light_energy = 0.9
