extends Node3D
## Arquitetura de fundo próxima, exclusiva da campanha noturna 01–09.
## Coordenadas mundiais como as plataformas clipadas do chunk; nunca cria colisores.
## Bordas artificiais de chunk NÃO recebem lanternas: para isso o chamador marca
## pit_left/pit_right somente nas extremidades que realmente tocam um buraco.
const BUILDING_SPACING := 19.0
var _builders := {}
var _materials := {}
var _order := 1
var _light_added := false
var building_count := 0
var lantern_count := 0

func build(platforms: Array, order: int) -> void:
	_order = clampi(order,1,9)
	for platform: Dictionary in platforms:
		if platform.get("kind","") != "ground": continue
		var p: Array = platform.pos
		var dimensions: Array = platform.size
		var left := float(p[0])-float(dimensions[0])*0.5
		var right := float(p[0])+float(dimensions[0])*0.5
		var top := float(p[1])+float(dimensions[1])*0.5
		var first := ceili((left-4.0)/BUILDING_SPACING)
		var last := floori((right-4.0)/BUILDING_SPACING)
		for slot in range(first,last+1):
			var x := 4.0+float(slot)*BUILDING_SPACING
			var rng := RandomNumberGenerator.new()
			rng.seed = absi(_order*1000003+slot*9176+3059)
			# Deixa janelas para a cidade panorâmica entre as fachadas próximas.
			var width := rng.randf_range(3.8,5.1)
			if x-width*0.5 < left+0.15 or x+width*0.5 > right-0.15: continue
			_building(Vector3(x,top,rng.randf_range(-6.2,-5.3)),width,rng)
			building_count += 1
		if bool(platform.get("pit_left",false)):
			_lantern(Vector3(left+0.55,top,-3.8))
		if bool(platform.get("pit_right",false)):
			_lantern(Vector3(right-0.55,top,-3.8))
	_flush()

func _building(origin: Vector3, width: float, rng: RandomNumberGenerator) -> void:
	var district := int((_order-1)/3.0)
	var variant := rng.randi_range(0,3)
	var height := rng.randf_range(2.45,3.1)+float(district)*0.23
	var depth := rng.randf_range(1.1,1.6)
	var front := origin.z+depth*0.5
	_box(origin+Vector3(0,height*0.5,0),Vector3(width,height,depth),"stone")
	# Cornija e pilares discretos distinguem fachada de simples caixa de cenário.
	_box(origin+Vector3(0,height-0.13,0),Vector3(width+0.16,0.15,depth+0.12),"trim")
	_box(origin+Vector3(0,0.10,0),Vector3(width+0.12,0.20,depth+0.06),"trim")
	for side in [-1.0,1.0]:
		_box(Vector3(origin.x+side*(width*0.5-0.13),origin.y+height*0.5,front+0.03),Vector3(0.16,height,0.12),"trim")
	var doorway := Vector3(origin.x+rng.randf_range(-0.5,0.5),origin.y+0.14,front+0.085)
	_arch_frame(doorway,0.88,1.70,0.09)
	_arch_patch(doorway,0.88,1.70,"recess")
	# A base escura da porta é visível; brilho limitado a uma faixa interior estreita.
	_arch_patch(doorway+Vector3(0.22,0.06,0.008),0.12,1.42,"window")
	var windows := maxi(2,int(width/1.45))
	for index in range(windows):
		var x := origin.x-width*0.5+0.8+float(index)*(width-1.6)/maxf(windows-1,1)
		if absf(x-doorway.x) < 0.65 and height < 3.2: continue
		var y := origin.y+height-1.02
		_arch_frame(Vector3(x,y-0.04,front+0.075),0.48,0.78,0.055)
		_arch_patch(Vector3(x,y-0.04,front+0.075),0.48,0.78,"recess")
		_arch_patch(Vector3(x,y,front+0.085),0.30,0.61,"window")
		_box(Vector3(x,y+0.24,front+0.095),Vector3(0.035,0.48,0.028),"trim")
		if district == 2 and height > 3.6 and index%2 == 0:
			_arch_frame(Vector3(x,origin.y+0.71,front+0.065),0.46,0.76,0.05)
			_arch_patch(Vector3(x,origin.y+0.71,front+0.065),0.46,0.76,"recess")
			_arch_patch(Vector3(x,origin.y+0.75,front+0.075),0.34,0.64,"window")
	if variant == 0 or (district == 2 and variant == 3):
		var dome_radius := minf(width*0.22,1.10)
		var dome_height := 0.45+dome_radius*0.25
		_dome(origin+Vector3(0,height-0.04,0),dome_radius,dome_height,"dome")
		_box(origin+Vector3(0,height+dome_height+0.03,0),Vector3(0.07,0.24,0.07),"metal")
	elif variant == 1:
		# Torre lateral assimétrica; não se repete em cada casa.
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var tower_x := origin.x+side*(width*0.5-0.65)
		var tower_height := height+1.1
		_box(Vector3(tower_x,origin.y+tower_height*0.5,origin.z-0.18),Vector3(1.15,tower_height,1.15),"stone")
		_box(Vector3(tower_x,origin.y+tower_height-0.08,origin.z-0.18),Vector3(1.34,0.16,1.32),"trim")
		_dome(Vector3(tower_x,origin.y+tower_height,origin.z-0.18),0.58,0.56,"dome")
		_arch_frame(Vector3(tower_x,origin.y+tower_height-0.94,origin.z+0.40),0.44,0.76,0.05)
		_arch_patch(Vector3(tower_x,origin.y+tower_height-0.94,origin.z+0.40),0.44,0.76,"recess")
		_arch_patch(Vector3(tower_x,origin.y+tower_height-0.90,origin.z+0.41),0.30,0.60,"window")
	else:
		var merlons := maxi(3,int(width/0.85))
		for index in range(merlons):
			var x := origin.x-width*0.5+0.26+float(index)*(width-0.52)/maxf(merlons-1,1)
			_box(Vector3(x,origin.y+height+0.14,front-0.10),Vector3(0.34,0.28,0.28),"trim")
	if district == 1 or (variant == 2 and rng.randf() > 0.35):
		_awning(Vector3(origin.x,origin.y+2.0,front+0.05),minf(width-0.65,4.2),"cloth" if variant%2 == 0 else "cloth_alt")
	elif variant == 3:
		# Nichos de arcada, atrás da rota de jogo, dão profundidade à fachada.
		for side in [-1.0,1.0]:
			var niche := Vector3(origin.x+side*(width*0.33),origin.y+0.16,front+0.085)
			_arch_frame(niche,0.82,1.56,0.065)
			_arch_patch(niche,0.82,1.56,"recess")

func _awning(origin: Vector3, width: float, key: String) -> void:
	# O toldo avança apenas0.65m: a frente continua em z<-3.5.
	_quad(key,origin+Vector3(-width*0.5,0,0),origin+Vector3(-width*0.5,-0.21,0.65),origin+Vector3(width*0.5,-0.21,0.65),origin+Vector3(width*0.5,0,0))
	_box(origin+Vector3(0,-0.27,0.65),Vector3(width,0.12,0.04),key)
	for side in [-1.0,1.0]:
		_box(origin+Vector3(side*(width*0.5-0.05),-1.10,0.60),Vector3(0.055,1.80,0.055),"metal")

func _lantern(origin: Vector3) -> void:
	lantern_count += 1
	_box(origin+Vector3(0,0.08,0),Vector3(0.34,0.16,0.34),"trim")
	_box(origin+Vector3(0,0.71,0),Vector3(0.075,1.40,0.075),"metal")
	_box(origin+Vector3(0,1.49,0),Vector3(0.34,0.07,0.34),"metal")
	_box(origin+Vector3(0,1.27,0),Vector3(0.17,0.30,0.17),"window")
	_box(origin+Vector3(0,1.06,0),Vector3(0.30,0.08,0.30),"metal")
	for x in [-0.115,0.115]:
		for z in [-0.115,0.115]:
			_box(origin+Vector3(x,1.27,z),Vector3(0.025,0.35,0.025),"metal")
	if not _light_added:
		_light_added = true
		var glow := OmniLight3D.new()
		glow.name = "PitLanternFill"
		glow.position = origin+Vector3(0,1.25,0)
		glow.light_color = Color("#ffd49a")
		glow.light_energy = 0.60
		glow.omni_range = 5.2
		glow.shadow_enabled = false
		add_child(glow)

func _arch_patch(origin: Vector3, width: float, height: float, key: String) -> void:
	var radius := width*0.5
	var spring := height-radius
	_quad(key,origin+Vector3(-radius,0,0),origin+Vector3(-radius,spring,0),origin+Vector3(radius,spring,0),origin+Vector3(radius,0,0))
	var center := origin+Vector3(0,spring,0)
	for index in range(8):
		var a := PI*float(index)/8.0
		var b := PI*float(index+1)/8.0
		_triangle(key,center,center+Vector3(cos(a),sin(a),0)*radius,center+Vector3(cos(b),sin(b),0)*radius)

func _arch_frame(origin: Vector3, width: float, height: float, thickness: float) -> void:
	# Batentes e arco com espessura real; a luz não fica colada à parede como adesivo.
	var radius := width*0.5
	var spring := height-radius
	var outer := radius+thickness
	for side in [-1.0,1.0]:
		_box(origin+Vector3(side*(radius+thickness*0.5),spring*0.5,0.0),Vector3(thickness,spring,0.075),"trim")
	_box(origin+Vector3(0,-0.015,0.015),Vector3(width+thickness*2.4,0.065,0.12),"trim")
	var center := origin+Vector3(0,spring,0.04)
	var back := Vector3(0,0,-0.075)
	for index in range(8):
		var angle0 := PI*float(index)/8.0+0.006
		var angle1 := PI*float(index+1)/8.0-0.006
		var a := center+Vector3(cos(angle0),sin(angle0),0)*outer
		var b := center+Vector3(cos(angle1),sin(angle1),0)*outer
		var c := center+Vector3(cos(angle1),sin(angle1),0)*radius
		var d := center+Vector3(cos(angle0),sin(angle0),0)*radius
		_quad("trim",a,b,c,d)
		_quad("trim",a+back,b+back,b,a)
		_quad("trim",d,c,c+back,d+back)

func _dome(origin: Vector3, radius: float, height: float, key: String) -> void:
	for ring in range(4):
		var angle0 := PI*0.5*float(ring)/4.0
		var angle1 := PI*0.5*float(ring+1)/4.0
		for segment in range(12):
			var phi0 := TAU*float(segment)/12.0
			var phi1 := TAU*float(segment+1)/12.0
			var a := Vector3(cos(phi0)*cos(angle0)*radius,sin(angle0)*height,sin(phi0)*cos(angle0)*radius)
			var b := Vector3(cos(phi0)*cos(angle1)*radius,sin(angle1)*height,sin(phi0)*cos(angle1)*radius)
			var c := Vector3(cos(phi1)*cos(angle1)*radius,sin(angle1)*height,sin(phi1)*cos(angle1)*radius)
			var d := Vector3(cos(phi1)*cos(angle0)*radius,sin(angle0)*height,sin(phi1)*cos(angle0)*radius)
			_quad(key,origin+a,origin+b,origin+c,origin+d)

func _box(center: Vector3, size: Vector3, key: String) -> void:
	var r := size*0.5
	var a := center+Vector3(-r.x,-r.y,r.z)
	var b := center+Vector3(-r.x,r.y,r.z)
	var c := center+Vector3(r.x,r.y,r.z)
	var d := center+Vector3(r.x,-r.y,r.z)
	var e := center+Vector3(-r.x,-r.y,-r.z)
	var f := center+Vector3(-r.x,r.y,-r.z)
	var g := center+Vector3(r.x,r.y,-r.z)
	var h := center+Vector3(r.x,-r.y,-r.z)
	_quad(key,a,b,c,d)
	_quad(key,h,g,f,e)
	_quad(key,e,f,b,a)
	_quad(key,d,c,g,h)
	_quad(key,b,f,g,c)
	_quad(key,e,a,d,h)

func _quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(key,a,c,b)
	_triangle(key,a,d,c)

func _triangle(key: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	if not _builders.has(key):
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		_builders[key] = builder
	var st: SurfaceTool = _builders[key]
	var normal := (b-a).cross(c-a).normalized()
	for point in [a,b,c]:
		var uv := Vector2(point.x,point.y)
		if absf(normal.y) > 0.65: uv = Vector2(point.x,point.z)
		elif absf(normal.x) > 0.65: uv = Vector2(point.z,point.y)
		st.set_uv(uv*0.30)
		st.add_vertex(point)

func _flush() -> void:
	for key: String in _builders:
		var st: SurfaceTool = _builders[key]
		st.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name = "City_"+key
		mesh.mesh = st.commit()
		mesh.material_override = _material(key)
		if key in ["window","cloth","cloth_alt","recess"]:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	_builders.clear()

func _material(key: String) -> StandardMaterial3D:
	if _materials.has(key): return _materials[key]
	var mat := StandardMaterial3D.new()
	var colors := {"stone":"#927e74","trim":"#ae9480","recess":"#354051","dome":"#586883","metal":"#344054","cloth":"#446e76","cloth_alt":"#745c68","window":"#d5a667"}
	mat.albedo_color = Color(colors.get(key,"#72849a")).srgb_to_linear()
	mat.roughness = 0.92
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if key in ["stone","trim","dome"]:
		mat.albedo_texture = preload("res://assets/desert/phase01/sandstone.png")
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if key == "window":
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("#ca9554").srgb_to_linear()
		mat.emission_enabled = true
		mat.emission = Color("#c88a42").srgb_to_linear()
		mat.emission_energy_multiplier = 0.18
	_materials[key] = mat
	return mat
