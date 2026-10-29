extends Node3D
## Geometria própria da Fase 01: superfícies coincidem com os colisores; vãos continuam abertos.
var _rng := RandomNumberGenerator.new()
func build(platforms: Array) -> void:
	_rng.seed = 150104
	for platform: Dictionary in platforms:
		var p: Array = platform.pos
		var s: Array = platform.size
		var top := float(p[1]) + float(s[1]) * 0.5
		var bottom := -5.5 if platform.kind == "ground" else 0.0
		_shelf(float(p[0]), float(s[0]), top, bottom, float(s[2]))
		if platform.kind == "ground":
			for i in range(int(float(s[0]) / 1.8)):
				var rock := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radial_segments = 8
				sphere.rings = 3
				sphere.radius = _rng.randf_range(0.08, 0.24)
				sphere.height = sphere.radius * 1.5
				rock.mesh = sphere
				rock.position = Vector3(float(p[0]) + _rng.randf_range(-float(s[0])*0.45, float(s[0])*0.45), top + 0.04, _rng.randf_range(-1.7, -1.0))
				rock.scale = Vector3(1.5, 0.7, 1)
				rock.material_override = stone_material(Color("#81705c"))
				add_child(rock)
	for x in [-11.0, 11.0, 30.0, 48.0]:
		arch(Vector3(x, 0, -4.5), 1.7)

func _shelf(x: float, width: float, top: float, bottom: float, depth: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := maxi(2, int(width / 0.9))
	var layers := maxi(1, int((top-bottom)/0.55))
	var back := -6.5 if bottom < -1.0 else -depth*0.5
	for n in range(sections):
		var x0 := x-width*0.5+width*n/sections
		var x1 := x-width*0.5+width*(n+1)/sections
		_quad(st, Vector3(x0,top,back), Vector3(x0,top,_cliff_z(x0,0,depth)), Vector3(x1,top,_cliff_z(x1,0,depth)), Vector3(x1,top,back), Color("#baa183"))
		for layer in range(layers):
			var y0 := lerpf(top,bottom,float(layer)/layers)
			var y1 := lerpf(top,bottom,float(layer+1)/layers)
			var color := Color("#a57852").lightened(sin(layer*1.9)*0.035+sin((x0+x1)*0.2)*0.018)
			_quad(st, Vector3(x0,y0,_cliff_z(x0,layer,depth)), Vector3(x0,y1,_cliff_z(x0,layer+1,depth)), Vector3(x1,y1,_cliff_z(x1,layer+1,depth)), Vector3(x1,y0,_cliff_z(x1,layer,depth)), color)
			_quad(st, Vector3(x1,y0,back), Vector3(x1,y1,back), Vector3(x0,y1,back), Vector3(x0,y0,back), color)
	_quad(st, Vector3(x-width*.5,top,-depth*.5), Vector3(x-width*.5,bottom,-depth*.5), Vector3(x-width*.5,bottom,depth*.5), Vector3(x-width*.5,top,depth*.5), Color("#9e694b"))
	_quad(st, Vector3(x+width*.5,top,depth*.5), Vector3(x+width*.5,bottom,depth*.5), Vector3(x+width*.5,bottom,-depth*.5), Vector3(x+width*.5,top,-depth*.5), Color("#a37650"))
	st.generate_normals()
	var visual := MeshInstance3D.new()
	visual.mesh = st.commit()
	var mat := stone_material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	# Microtextura de areia/arenito, gerada sem assets externos ou shaders customizados.
	var noise := FastNoiseLite.new()
	noise.seed = 15
	noise.frequency = 0.12
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#e7e0d4"), Color.WHITE])
	texture.color_ramp = gradient
	mat.albedo_texture = texture
	visual.material_override = mat
	add_child(visual)

func _cliff_z(x: float, layer: int, depth: float) -> float:
	return depth*0.5 + sin(x*2.0+layer*0.74)*0.12+cos(x*0.7+layer*1.2)*0.1

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for point in [a,c,b,a,d,c]:
		st.set_color(color.srgb_to_linear())
		st.set_uv(Vector2(point.x,point.y+point.z)*0.7)
		st.add_vertex(point)

static func stone_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.srgb_to_linear()
	mat.roughness = 0.92
	return mat

func arch(origin: Vector3, radius: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := radius-0.35
	for index in range(16):
		var t0 := PI*index/16.0
		var t1 := PI*(index+1)/16.0
		var a := Vector3(cos(t0)*radius,3.0+sin(t0)*radius,0)
		var b := Vector3(cos(t1)*radius,3.0+sin(t1)*radius,0)
		var c := Vector3(cos(t1)*inner,3.0+sin(t1)*inner,0)
		var d := Vector3(cos(t0)*inner,3.0+sin(t0)*inner,0)
		_quad(st,a,b,c,d,Color("#9b8064"))
		_quad(st,d+Vector3.BACK*.45,c+Vector3.BACK*.45,b+Vector3.BACK*.45,a+Vector3.BACK*.45,Color("#90745a"))
		_quad(st,a+Vector3.BACK*.45,b+Vector3.BACK*.45,b,a,Color("#b1987e"))
		_quad(st,d,c,c+Vector3.BACK*.45,d+Vector3.BACK*.45,Color("#8c6852"))
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.position = origin
	var mat := stone_material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	add_child(mesh)
	for side in [-1,1]:
		var pillar := MeshInstance3D.new()
		var column := CylinderMesh.new()
		column.top_radius = 0.22
		column.bottom_radius = 0.28
		column.radial_segments = 8
		column.height = 3.0
		pillar.mesh = column
		pillar.position = origin+Vector3(side*(radius-0.175),1.5,0.2)
		pillar.material_override = stone_material(Color("#8c7762"))
		add_child(pillar)
