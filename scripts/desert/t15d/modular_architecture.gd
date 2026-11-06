extends "res://scripts/desert/t15d/city_props.gd"
## Biblioteca de módulos 3D editáveis: materiais e malhas agrupadas por trecho.
## Apenas decoração; os corpos de colisão usam os mesmos limites do CampaignLayout.
var _theme := 1
static var _water: ShaderMaterial

func build_surface(platform: Dictionary, order: int) -> void:
	_theme = order
	_order = order
	_light_added = true # Luz real limitada ao construtor de cada chunk; janelas seguem emissivas.
	var x := float(platform.pos[0])
	var width := float(platform.size[0])
	var top := float(platform.pos[1])+float(platform.size[1])*0.5
	var left := x-width*0.5
	var right := x+width*0.5
	var module: int = platform.get("module",0)
	if order==2 and platform.kind=="ground":
		_house_roof_slice(platform)
		return
	if platform.get("parkour_route",false):
		_build_running_obstacle(x,width,float(platform.surface_top),top,order,int(platform.get("module",0)))
		_flush()
		return
	if platform.kind != "ground":
		_crate(Vector3(x,top-float(platform.size[1]),0),width,float(platform.size[1]))
		_flush()
		return
	# Superfície sólida, frisos e fundações; não contém uma imagem de fase.
	var bridge := false
	if order in [7,9,10]:
		for point: Dictionary in Assets.placements(order):
			if point.asset=="desert_timber_bridge" and int(point.surface)==module: bridge=true
	var material := "wood" if order in [7,9,10] and (module%3 == 1 or bridge) else "stone"
	_box(Vector3(x,top-0.25,0),Vector3(width,0.5,4.0),material)
	_box(Vector3(x,top-0.08,2.02),Vector3(width,0.16,0.16),"trim")
	match order:
		4:
			_painted_facade(left,right,top-0.18,2.12,"desert_aqueduct",9.0)
			# O tabuleiro volumétrico e a água animada continuam independentes da arte.
			_water_strip(Vector3(x,top-0.04,-2.8),Vector2(width,1.2),false)
			if module%3 == 2 and width > 4: _water_strip(Vector3(x,top-2.2,-2.8),Vector2(1.8,4.2),true)
		6,10:
			_cave_wall(left,right,top)
			for column in range(ceili(left/4.0),floori(right/4.0)):
				_box(Vector3(column*4,top-1.8,-0.8),Vector3(0.4,3.1,2.8),"wood" if order == 10 else "stone")
			if order==10 and material=="wood": _painted_facade(left,right,top-0.18,2.12,"desert_timber_bridge",7.0)
			if order == 10:
				for z: float in [-0.75,0.75]: _box(Vector3(x,top+0.035,z),Vector3(width,0.07,0.08),"metal")
				for tie in range(ceili(left/1.3),floori(right/1.3)):
					_box(Vector3(tie*1.3,top+0.015,0),Vector3(0.17,0.03,1.95),"wood")
		5:
			_water_strip(Vector3(x,top-0.18,-3.1),Vector2(width,1.9),false)
		7,9:
			if material == "wood":
				_painted_facade(left,right,top-0.18,2.12,"desert_timber_bridge",7.0)
				for column in range(ceili(left/3.2),floori(right/3.2)):
					_box(Vector3(column*3.2,top-2.8,-0.7),Vector3(0.24,5.2,2.8),"wood")
		_:
			_box(Vector3(x,top-1.0,0),Vector3(width,1.5,3.8),"stone")
	# Variantes sémanticas aux limites des modules; aucun escalier.
	for marker in range(ceili((left+1)/7.0),floori((right-1)/7.0)+1):
		var at := Vector3(marker*7.0,top,-2.1)
		if order == 4 and marker%3 == 1: _water_strip(at+Vector3(0,-1.5,-0.7),Vector2(1.6,3.0),true)
		if order in [6,10] and marker%3==0: _underground(at,marker)
	_flush()

func _house_roof_slice(platform: Dictionary) -> void:
	var house := Assets.surface(2,int(platform.module))
	var width := float(house.right)-float(house.left)
	var texture := Assets.texture("capital_house" if int(house.index)%2==0 else "capital_balcony_house")
	var pixels := width/texture.get_width()
	var left := float(platform.pos[0])-float(platform.size[0])*0.5
	var right := float(platform.pos[0])+float(platform.size[0])*0.5
	var slice:=Assets.crop(texture,Rect2((left-float(house.left))/pixels,0,(right-left)/pixels,texture.get_height()))
	# O piso pintado no asset está a 10,5% do recorte. Compensa a câmera 2,2/14.
	var walk_y := float(house.height)-0.4*(2.2/14.0)
	var art := _house_sprite(slice,Vector3((left+right)*0.5,walk_y-(0.5-0.105)*texture.get_height()*pixels,-0.4),pixels)
	art.set_meta("house_id",int(house.index))
	art.set_meta("roof_y",float(house.height))
	art.set_meta("surface_left",float(house.left))
	art.set_meta("surface_right",float(house.right))
	art.set_meta("asset_id","capital_house" if int(house.index)%2==0 else "capital_balcony_house")
	art.add_to_group("playable_house_roofs")
	art.add_to_group("kingdom_art")

func _build_running_obstacle(x: float,width: float,base: float,top: float,order: int,module:=0) -> void:
	var art:=preload("res://scripts/desert/t15d/obstacle_art.gd").new()
	art.position=Vector3(x,base,0)
	add_child(art)
	art.build_obstacle(width,top-base,order,module)

func _facade(left: float,right: float,top: float,bottom: float) -> void:
	_box(Vector3((left+right)*0.5,(top+bottom)*0.5,-0.25),Vector3(right-left,top-bottom,3.4),"stone")
	if _painted_facade(left,right,top+0.25,1.65): return
	for x in range(ceili((left+0.4)/2.5),floori((right-0.4)/2.5)+1):
		for row in range(3):
			var at := Vector3(x*2.5,top-2.1-row*2.1,1.48)
			_city_window(at,0.62,1.25)
			_arch_frame(at,0.62,1.25,0.10)
			_box(at+Vector3(0,0.60,0.06),Vector3(0.055,1.2,0.06),"metal")
		_box(Vector3(x*2.5,top-4.3,1.6),Vector3(0.13,8.0,0.2),"trim")

func _crate(at: Vector3,width: float,height: float) -> void:
	_box(at+Vector3.UP*height*0.5,Vector3(width,height,2.6),"wood")
	for y: float in [0.08,height-0.08]:_box(at+Vector3(0,y,1.32),Vector3(width,0.10,0.10),"metal")
	for side: float in [-1,1]:_box(at+Vector3(side*(width*0.5-0.08),height*0.5,1.32),Vector3(0.12,height,0.10),"metal")

func _palm(at: Vector3) -> void:
	_box(at+Vector3(0,1.45,0),Vector3(0.22,2.9,0.22),"wood")
	for index in range(7):
		var angle := TAU*index/7.0
		var direction := Vector3(cos(angle),0,sin(angle))
		var edge := Vector3(-sin(angle),0,cos(angle))*0.32
		var center := at+Vector3.UP*3.0
		_quad("leaf",center-edge,center+direction*0.8+Vector3.UP*0.35,center+direction*1.8-Vector3.UP*0.35,center+edge)

func _military(at: Vector3) -> void:
	_box(at+Vector3(0,1.1,-0.2),Vector3(1.6,2.2,1.5),"stone")
	_dome(at+Vector3(0,2.2,-0.2),0.9,0.65,"dome")
	_banner(at+Vector3(0,1.15,0.61))

func _mine_cart(at: Vector3) -> void:
	_box(at+Vector3(0,0.53,0),Vector3(1.4,0.8,0.9),"metal")
	for side: float in [-1,1]:
		for end: float in [-1,1]:
			_dome(at+Vector3(side*0.5,0.14,end*0.5),0.18,0.18,"metal")
	for index in range(4):_dome(at+Vector3((index%2-0.5)*0.5,1.0,(index/2-0.5)*0.3),0.35,0.25,"stone")

func _underground(at: Vector3,index: int) -> void:
	var top := at+Vector3(0,4.4,-1.5)
	if _theme == 10:
		Context._box(self,top,Vector3(5.2,0.35,3.8),"context_wood",Color("#b2a38e"))
		for side: float in [-1,1]:Context._box(self,top+Vector3(side*2.35,-2.2,0),Vector3(0.35,4.4,0.35),"context_wood",Color("#b2a38e"))
		# Veio aprovado substitui as antigas cápsulas laranjas; arena fica livre.
		if at.x<_length*0.78:place_asset("desert_mine_crystals",at+Vector3(1.4,-0.60,-3.0),1.6)
	else:
		_box(top,Vector3(5.2,0.35,3.8),"stone")
		for side: float in [-1,1]:_box(top+Vector3(side*2.35,-2.2,0),Vector3(0.35,4.4,0.35),"stone")
		_arch_frame(at+Vector3(0,0,-1.9),2.3,3.0,0.3)

func _water_strip(at: Vector3,dimensions: Vector2,vertical: bool) -> void:
	if _water == null:
		_water = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode blend_mix, cull_disabled, depth_draw_opaque; void fragment(){float flow=sin(UV.y*65.0-TIME*5.0+sin(UV.x*25.0)*1.2); ALBEDO=mix(vec3(0.025,0.16,0.27),vec3(0.18,0.65,0.8),flow*0.5+0.5); ROUGHNESS=0.24; METALLIC=0.15; ALPHA=0.75; EMISSION=ALBEDO*0.12;}"
		_water.shader = shader
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = dimensions
	water.mesh = plane
	water.material_override = _water
	water.position = at
	if vertical:water.rotation.x = PI*0.5
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func build_portal(at: Vector3,order: int) -> void:
	_theme=order
	_order=order
	if order in [1,8,9]:
		var id := "capital_archway" if order==1 else ("desert_military_gate" if order==8 else "desert_mine_entrance")
		var landmark := ""
		if order==9:
			for point: Dictionary in Assets.placements(9):
				if point.asset==id: landmark=point.id
		place_asset(id,at+Vector3(0,0,0.7),8.0,landmark)
		if order==1:
			for side: float in [-1,1]: place_asset("capital_watchtower",at+Vector3(side*5.0,0,-0.4),3.0)
		_flush()
		return
	var mining := order in [9,10]
	_arch_frame(at,7.5,8.0,0.7)
	for side: float in [-1,1]:
		_box(at+Vector3(side*4.4,3.8,-0.6),Vector3(1.9,7.6,2.4),"stone")
		_box(at+Vector3(side*4.4,7.7,-0.6),Vector3(2.3,0.3,2.7),"trim")
		if not mining: _dome(at+Vector3(side*4.4,7.9,-0.6),1.15,0.9,"dome")
		_banner(at+Vector3(side*4.4,4.7,0.7))
		_lantern(at+Vector3(side*3.2,0.0,0.7))
	if mining:
		for index in range(4):
			var offset := Vector3(0,0,-index*2.0)
			_arch_frame(at+offset,6.5-index*0.5,7.0-index*0.3,0.32)
			for side: float in [-1,1]: _box(at+offset+Vector3(side*2.8,2.8,0),Vector3(0.25,5.6,0.3),"wood")
		for side: float in [-1,1]:_box(at+Vector3(side*0.65,0.1,1.0),Vector3(0.1,0.1,8.0),"metal")
	_flush()

func _cave_wall(left: float,right: float,top: float) -> void:
	# Parede volumétrica em faixas desencontradas, atrás da pista e das estruturas.
	_box(Vector3((left+right)*0.5,top+3.5,-13.5),Vector3(right-left+7.0,12.0,0.4),"stone")
	var transforms: Array[Transform3D] = []
	for index in range(ceili(left/6.0),floori(right/6.0)+1):
		for row in range(2):
			var basis := Basis(Vector3.FORWARD,sin(index*1.7+row)*0.3).scaled(Vector3(3.3,2.8,1.5))
			var position := Vector3(index*6.0+sin(row*1.7)*0.5,top+row*4.3-0.6,-11.0-sin(index*1.3)*0.4)
			transforms.append(Transform3D(basis,position))
	if transforms.is_empty(): return
	var rock := MultiMeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments=12
	mesh.rings=7
	mesh.radius=1.0
	mesh.height=2.0
	var batch := MultiMesh.new()
	batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.mesh=mesh
	batch.instance_count=transforms.size()
	for index in range(transforms.size()): batch.set_instance_transform(index,transforms[index])
	rock.multimesh=batch
	rock.material_override=_material("stone")
	add_child(rock)

func _crystal(at: Vector3) -> void:
	var crystal := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.35
	mesh.height = 1.4
	mesh.radial_segments = 6
	crystal.mesh = mesh
	crystal.material_override = _material("crystal")
	crystal.position = at+Vector3.UP*0.7
	crystal.rotation.z = 0.2*sin(at.x)
	add_child(crystal)

func _market_stall(at: Vector3,index: int) -> void:
	var width := 3.0+0.3*posmod(index,3)
	_awning(at+Vector3(0,2.45,-0.15),width,"cloth" if index%4==0 else "cloth_alt")
	_box(at+Vector3(0,0.50,0.1),Vector3(width-0.2,0.20,0.85),"wood")
	for side: float in [-1,1]:
		_box(at+Vector3(side*(width*0.5-0.25),0.22,0.1),Vector3(0.12,0.44,0.7),"wood")
	for item in range(5):
		var position := at+Vector3((item-2)*0.46,0.63,0.13)
		if index%4==0:_dome(position,0.22,0.38,"trim")
		else:_box(position+Vector3.UP*0.16,Vector3(0.33,0.32,0.46),"wood")

func _garden(at: Vector3) -> void:
	_box(at+Vector3.UP*0.20,Vector3(1.7,0.4,0.9),"trim")
	_dome(at+Vector3(0,0.4,0),0.65,0.38,"leaf")
	_water_strip(at+Vector3(0,0.43,0),Vector2(1.25,0.65),false)

func _crane(at: Vector3) -> void:
	_box(at+Vector3(0,1.8,0),Vector3(0.28,3.6,0.3),"wood")
	_box(at+Vector3(0.5,3.6,0),Vector3(3.8,0.26,0.4),"wood")
	_box(at+Vector3(1.7,2.5,0),Vector3(0.06,2.0,0.06),"metal")
	_box(at+Vector3(1.7,1.43,0),Vector3(0.75,0.75,0.7),"metal")
