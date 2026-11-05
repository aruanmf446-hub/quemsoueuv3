extends Node3D
## Arquitetura de fundo próxima, exclusiva da campanha noturna 01–09.
## Coordenadas mundiais como as plataformas clipadas do chunk; nunca cria colisores.
## Bordas artificiais de chunk NÃO recebem lanternas: para isso o chamador marca
## pit_left/pit_right somente nas extremidades que realmente tocam um buraco.
const Assets = preload("res://scripts/desert/t15d/kingdom_assets.gd")
const BUILDING_SPACING := 19.0
static var _house_texture: Texture2D
var _builders := {}
static var _shared_materials := {}
var _materials := {}
var _order := 1
var _spacing := 19.0
var _length := 1452.0
var _start := -8.0
var _light_added := false
var building_count := 0
var lantern_count := 0

## A mesma geometria pode ser criada por etapas sem perder o agrupamento por material.
func prepare_build(platforms: Array, order: int, length := 1452.0, start := -8.0) -> Array[Callable]:
	_order = clampi(order,1,10)
	var lantern_z := -1.72 if _order < 10 else -3.8
	_spacing = [13.0,13.0,11.0,25.0,18.0,18.0,22.0,19.0,22.0,18.0][_order-1]
	_length = maxf(length,1.0)
	_start = start
	var tasks: Array[Callable] = []
	var planned := {}
	for run: Dictionary in _ground_runs(platforms):
		var first := float(run.pos[0])-float(run.size[0])*0.5
		var last := float(run.pos[0])+float(run.size[0])*0.5
		for point: Dictionary in Assets.placements(_order):
			if point.anchor in ["facade","under_surface"] or point.asset=="desert_mine_entrance": continue
			if point.x>=first and point.x<last and not planned.has(point.id):
				planned[point.id]=true
				tasks.append(_planned_asset.bind(point))
	for platform: Dictionary in _ground_runs(platforms):
		var p: Array = platform.pos
		var dimensions: Array = platform.size
		var left := float(p[0])-float(dimensions[0])*0.5
		var right := float(p[0])+float(dimensions[0])*0.5
		var top := float(p[1])+float(dimensions[1])*0.5
		var module := int(platform.get("module",0))
		var whole := Assets.surface(_order,module)
		var center := (float(whole.left)+float(whole.right))*0.5
		# Uma composição por laje real, sem a grade mundial deixar módulos vazios.
		# O chunk que contém o centro é o único dono da composição.
		if center>=left and center<right:
			tasks.append(_build_slot.bind(module,float(whole.left),float(whole.right),top,center))
		if bool(platform.get("pit_left",false)):
			tasks.append(_lantern.bind(Vector3(left+0.55,top,lantern_z)))
		if bool(platform.get("pit_right",false)):
			tasks.append(_lantern.bind(Vector3(right-0.55,top,lantern_z)))
	tasks.append(_flush)
	return tasks

func build(platforms: Array, order: int) -> void:
	for task in prepare_build(platforms,order): task.call()

func _build_slot(slot: int, left: float, right: float, top: float,_at_x := INF) -> void:
	var piece := 0
	for part: Dictionary in Assets.composition(_order,slot,left,right,top):
		# Marcos preservam o primeiro plano; o casario de fundo pode continuar atrás.
		var reserved := false
		if float(part.z) > -9.0:
			for point: Dictionary in Assets.placements(_order):
				if point.anchor == "background" and absf(float(part.x)-float(point.x)) < (float(part.width)+float(point.width))*0.5+0.6:
					reserved = true
					break
		if reserved: continue
		var art := place_asset(part.asset,Vector3(part.x,part.y,part.z),part.width)
		if art != null:
			art.set_meta("composition_id","p%02d.block.%02d.%d" % [_order,slot,piece])
			art.set_meta("surface_left",left)
			art.set_meta("surface_right",right)
			building_count += 1
		piece += 1
	if _order == 2: _roof_terrace(slot,left,right,top)

func _roof_terrace(slot: int,left: float,right: float,top: float) -> void:
	var x := clampf(lerpf(left,right,0.36 if slot%2==0 else 0.65),left+3.0,right-3.0)
	var at := Vector3(x,top,-3.0)
	_box(at-Vector3.UP*0.12,Vector3(4.8,0.24,2.0),"roof")
	var marker := Node3D.new()
	marker.name = "RooftopTerrace"
	marker.position = at
	marker.set_meta("surface",slot)
	marker.add_to_group("rooftop_terraces")
	add_child(marker)
	match slot%3:
		0:
			_box(at+Vector3(0,0.8,0),Vector3(2.5,1.6,1.3),"stone")
			_box(at+Vector3(0,1.65,0),Vector3(2.7,0.12,1.5),"trim")
			_dome(at+Vector3(0,1.69,0),0.85,0.55,"dome")
			_arch_frame(at+Vector3(0,0,0.7),0.75,1.35,0.08)
			_city_door(at+Vector3(0,0,0.71),0.75,1.35)
		1:
			_box(at+Vector3(-0.8,1.2,0),Vector3(0.85,2.4,0.85),"stone")
			_box(at+Vector3(-0.8,2.45,0),Vector3(1.12,0.14,1.12),"trim")
			for vent in range(3):
				_box(at+Vector3(-0.8,1.72+vent*0.18,0.44),Vector3(0.60,0.09,0.03),"recess")
			_dome(at+Vector3(0.9,0.12,0),0.6,1.0,"metal")
		_:
			_awning(at+Vector3(0,2.0,-0.25),3.6,"cloth")

func _building(origin: Vector3, width: float, rng: RandomNumberGenerator) -> void:
	if _order in [1,2] and _painted_house(origin,width): return
	var district := int((_order-1)/3.0)
	var variant := rng.randi_range(0,3)
	var height := rng.randf_range(3.6,5.5)+float(district)*0.23
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
	if _order in [1,2]: _city_door(doorway,0.88,1.70)
	else: _arch_patch(doorway,0.88,1.70,"recess")
	# A base escura da porta é visível; brilho limitado a uma faixa interior estreita.
	_arch_patch(doorway+Vector3(0.22,0.06,0.008),0.12,1.42,"window")
	var windows := maxi(2,int(width/1.45))
	for index in range(windows):
		var x := origin.x-width*0.5+0.8+float(index)*(width-1.6)/maxf(windows-1,1)
		if absf(x-doorway.x) < 0.65 and height < 3.2: continue
		var y := origin.y+height-1.02
		_arch_frame(Vector3(x,y-0.04,front+0.075),0.48,0.78,0.055)
		_arch_patch(Vector3(x,y-0.04,front+0.075),0.48,0.78,"recess")
		if _order in [1,2]: _city_window(Vector3(x,y,front+0.085),0.34,0.64)
		else: _arch_patch(Vector3(x,y,front+0.085),0.30,0.61,"window")
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

	if _order != 2 and variant%2 == 0: _banner(Vector3(origin.x+width*0.28,origin.y+height*0.53,front+0.1))

func place_asset(id: String,base: Vector3,width: float,landmark_id := "") -> Sprite3D:
	var texture := Assets.texture(id)
	if texture == null: return null
	var pixels := width/texture.get_width()
	var sprite := _house_sprite(texture,base+Vector3.UP*texture.get_height()*pixels*0.5,pixels)
	sprite.set_meta("asset_id",id)
	sprite.add_to_group("kingdom_art")
	if not landmark_id.is_empty():
		sprite.set_meta("landmark_id",landmark_id)
		sprite.add_to_group("kingdom_landmark")
	# Fundação atrás da pista, sem colisor e sem atravessar a lacuna do percurso.
	_box(base-Vector3.UP*0.35,Vector3(width,0.7,1.0),"wood" if id.begins_with("desert_mining") else "stone")
	return sprite

func _planned_asset(point: Dictionary) -> void:
	var base := Vector3(float(point.x),float(point.y),-5.0)
	if point.anchor=="street_below": base.y-=8.0
	place_asset(point.asset,base,float(point.width),point.id)

func _house_art() -> Texture2D:
	if _house_texture == null and ResourceLoader.exists("res://assets/desert/modular/capital_house.res"):
		_house_texture=load("res://assets/desert/modular/capital_house.res")
	return _house_texture

func _house_sprite(texture: Texture2D,at: Vector3,pixels: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name="CapitalHouseArt"
	sprite.texture=texture
	sprite.pixel_size=pixels
	sprite.position=at
	sprite.shaded=false
	sprite.modulate=Color(0.82,0.84,0.94)
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite

func _painted_house(origin: Vector3,width: float) -> bool:
	var texture := _house_art()
	if texture == null: return false
	var pixels := width/texture.get_width()
	_box(origin+Vector3(0,-0.45,0),Vector3(width,0.9,1.4),"stone")
	_house_sprite(texture,origin+Vector3.UP*texture.get_height()*pixels*0.5,pixels)
	return true

func _painted_facade(left: float,right: float,top: float,z: float,asset_id := "capital_house",tile_width := 6.0) -> bool:
	var texture := Assets.texture(asset_id)
	if texture == null: return false
	# Um recorte por peça física: não atravessa vãos nem cobre piso rompido.
	# Atlas mantém proporção e coordenada mundial mesmo com o piso dividido em3.
	var pixels := tile_width/texture.get_width()
	for tile in range(floori(left/tile_width),ceili(right/tile_width)):
		var selected := asset_id
		if _order==2 and asset_id=="capital_house":
			selected=["capital_house","capital_balcony_house","capital_merchant"][posmod(tile,3)]
			for point: Dictionary in Assets.placements(2):
				if point.anchor=="facade" and absf((tile+0.5)*tile_width-float(point.x))<tile_width: selected=point.asset
		texture=Assets.texture(selected)
		pixels=tile_width/texture.get_width()
		var a := maxf(left,tile*tile_width)
		var b := minf(right,(tile+1)*tile_width)
		if b-a < 0.01: continue
		var slice := AtlasTexture.new()
		slice.atlas=texture
		slice.region=Rect2((a-tile*tile_width)/pixels,0,(b-a)/pixels,texture.get_height())
		slice.filter_clip=true
		var sprite := _house_sprite(slice,Vector3((a+b)*0.5,top-texture.get_height()*pixels*0.5,z),pixels)
		sprite.set_meta("asset_id",selected)
		sprite.set_meta("clip_left",a)
		sprite.set_meta("clip_right",b)
		sprite.add_to_group("kingdom_art")
	return true

func _city_door(at: Vector3,width: float,height: float) -> void:
	_arch_patch(at,width,height,"wood")
	# Tábuas estreitas, travessas e ferragens sobre madeira, sem porta azul lisa.
	for index in range(1,6):
		var x := -width*0.5+width*index/6.0
		_box(at+Vector3(x,(height-width*0.5)*0.5,0.025),Vector3(0.018,height-width*0.5,0.018),"metal")
	for y: float in [height*0.25,height*0.62]:
		_box(at+Vector3(0,y,0.045),Vector3(width*0.9,0.055,0.045),"metal")
	_box(at+Vector3(width*0.23,height*0.43,0.065),Vector3(0.07,0.10,0.04),"trim")

func _city_window(at: Vector3,width: float,height: float) -> void:
	_arch_patch(at,width,height,"window")
	var center := at+Vector3(0,height*0.44,0.025)
	_box(center,Vector3(0.035,height*0.87,0.04),"wood")
	_box(center,Vector3(width,0.035,0.04),"wood")
	_box(at+Vector3(0,-0.045,0.08),Vector3(width+0.18,0.09,0.18),"trim")

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
		st.set_uv(uv*(0.48 if _order in [1,2] else 0.30))
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
	if _shared_materials.has(key): return _shared_materials[key]
	var mat := StandardMaterial3D.new()
	var colors := {"stone":"#b4acbb","trim":"#c8b79b","recess":"#354051","dome":"#9d292e","metal":"#344054","cloth":"#6b1018","cloth_alt":"#59151c","window":"#d5a667","leaf":"#396d50","water":"#286f85","wood":"#816044","crystal":"#e9a84e","roof":"#b88669"}
	mat.albedo_color = Color(colors.get(key,"#72849a"))
	mat.roughness = 0.15 if key == "water" else 0.92
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if key in ["stone","trim","dome","roof"]:
		mat.albedo_texture = load("res://assets/desert/modular/stone_masonry.res") if ResourceLoader.exists("res://assets/desert/modular/stone_masonry.res") else preload("res://assets/desert/phase01/sandstone.png")
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if key in ["window","crystal"]:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("#ca9554").srgb_to_linear()
		mat.emission_enabled = true
		mat.emission = Color("#c88a42").srgb_to_linear()
		mat.emission_energy_multiplier = 0.18
	_shared_materials[key] = mat
	return mat

## Marcos próximos específicos de cada rota, agrupados nas malhas já existentes.
func _signature(origin: Vector3, slot: int) -> void:
	var district := clampi(int((origin.x-_start)/_length*8.0),0,7)
	match _order:
		1,8:
			if district%2 == 0:
				_arch_frame(origin,3.3,4.5,0.25)
				_box(origin+Vector3(-1.8,2.4,0),Vector3(0.8,4.8,0.8),"stone")
		3:
			_awning(origin+Vector3(0,2.7,0.5),4.8,"cloth")
			for side in [-1,1]: _box(origin+Vector3(side*1.6,0.4,0.7),Vector3(0.9,0.8,0.9),"metal")
		2:
			_box(origin+Vector3(0,3.8,0),Vector3(5.4,0.25,1.5),"trim")
			_awning(origin+Vector3(0,3.6,0.7),3.0,"cloth")
		4:
			_arch_frame(origin,4.6,4.7,0.3)
			_box(origin+Vector3(0,4.8,0),Vector3(5.0,0.35,0.8),"stone")
		5:
			_box(origin+Vector3(0,0.025,-0.4),Vector3(6,0.05,1.2),"water")
			for side in [-1,1]:
				_box(origin+Vector3(side*2,1.5,0),Vector3(0.25,3.0,0.25),"metal")
				_awning(origin+Vector3(side*2,3.0,0),2.3,"leaf")
		6:
			_box(origin+Vector3(0,0.65,0),Vector3(2.8,1.3,1.2),"stone")
			_arch_frame(origin+Vector3(1,0,0),1.8,2.8,0.16)
		7,9,10:
			for side in [-1.0,1.0]:
				_box(origin+Vector3(0,0.05,side*0.6),Vector3(18,0.06,0.06),"metal")
			_box(origin+Vector3(-2,2.5,0),Vector3(0.22,5,0.25),"metal")
			_box(origin+Vector3(0,5,0),Vector3(5,0.22,0.25),"metal")
			_box(origin+Vector3(1,3.5,0),Vector3(0.06,3,0.06),"metal")
			_box(origin+Vector3(1,1.8,0),Vector3(1.0,0.7,0.9),"stone")

## A partição física da ruptura não pode criar fachadas cortadas ou ruas vazias.
## Somente geometria decorativa é reunida; colisores e IDs de piso permanecem separados.
static func _ground_runs(platforms: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for value: Dictionary in platforms:
		if value.get("kind","") == "ground": entries.append(value.duplicate(true))
	entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.pos[0])-float(a.size[0])*0.5 < float(b.pos[0])-float(b.size[0])*0.5)
	var runs: Array[Dictionary] = []
	for value: Dictionary in entries:
		var left := float(value.pos[0])-float(value.size[0])*0.5
		var right := float(value.pos[0])+float(value.size[0])*0.5
		if not runs.is_empty() and left <= float(runs[-1].run_right)+0.01 and absf(float(value.pos[1])-float(runs[-1].pos[1])) < 0.01:
			var previous: Dictionary = runs[-1]
			previous.run_right = maxf(float(previous.run_right),right)
			previous.pos[0] = (float(previous.run_left)+float(previous.run_right))*0.5
			previous.size[0] = float(previous.run_right)-float(previous.run_left)
			previous.pit_right = value.get("pit_right",false)
		else:
			value.run_left = left
			value.run_right = right
			runs.append(value)
	return runs

func _banner(origin: Vector3) -> void:
	_box(origin,Vector3(0.58,0.96,0.04),"cloth")
	_box(origin+Vector3(0,0.52,0),Vector3(0.76,0.06,0.08),"metal")
	var contour := [Vector2(-0.15,-0.22),Vector2(-0.22,0.0),Vector2(0.02,0.34),Vector2(0.03,0.08),Vector2(0.17,0.24),Vector2(0.22,-0.08),Vector2(0.1,-0.24)]
	for index in range(contour.size()):
		var a: Vector2 = contour[index]
		var b: Vector2 = contour[(index+1)%contour.size()]
		_triangle("window",origin+Vector3(0,0,0.03),origin+Vector3(a.x,a.y,0.03),origin+Vector3(b.x,b.y,0.03))

func _warehouse(origin: Vector3, width: float) -> void:
	_box(origin+Vector3(0,1.2,0),Vector3(width,2.4,1.7),"stone")
	_box(origin+Vector3(0,2.45,0),Vector3(width+0.3,0.16,1.9),"metal")
	_box(origin+Vector3(0,0.92,0.88),Vector3(1.45,1.84,0.05),"recess")
	for side in [-1.0,1.0]:
		_box(origin+Vector3(side*width*0.35,1.1,0.9),Vector3(0.08,2.2,0.07),"metal")
	_banner(origin+Vector3(width*0.32,1.45,0.94))
