extends "res://scripts/desert/t15d/city_props.gd"
## Arte dos mecanismos, sem física. Madeira e pontes reutilizam o módulo aprovado.
## Geometria agrupada por material; nenhuma luz ou processamento contínuo adicional.
static var _task_materials := {}
var sections: Array[Node3D] = []

func gate(theme: int) -> void:
	var stone := theme == 6
	var face := 1.78
	if stone:
		for row in 8:
			for column in 3:
				_box(Vector3((column-1)*0.79,-2.27+row*0.65,face-0.12),Vector3(0.77,0.625,0.28),"stone" if (row+column)%3 else "trim")
		for side in [-1.0,1.0]:
			_beam(Vector3(side*0.69,-1.8,face+0.04),Vector3(side*0.69,1.8,face+0.04),0.06,"gold")
		_ring(Vector3(0,-0.2,face+0.08),0.42,0.045,"gold")
		for index in 6:
			var a := TAU*index/6.0
			_box(Vector3(cos(a)*0.24,-0.2+sin(a)*0.24,face+0.10),Vector3(0.065,0.065,0.04),"gold")
	elif theme==4:
		# Comporta de metal patinado, em vez de outra porta de madeira da cidade.
		for i in 6:
			var x:=-1.0+i*0.40
			_box(Vector3(x,0.30,face-0.12),Vector3(0.34,4.55,0.25),"iron")
			_box(Vector3(x,-2.22,face-0.12),Vector3(0.34,0.72,0.25),"patina")
		for y in [-2.12,-0.60,1.05,2.35]:
			_box(Vector3(0,y,face+0.04),Vector3(2.40,0.14,0.12),"rust")
			for x in [-1.0,-0.2,0.2,1.0]:_bolt(Vector3(x,y,face+0.12),0.035)
	else:
		# Tábuas separadas, com ferragens. A profundidade física não vira um caixote.
		for index in 8:
			var height := 5.12 - absf(index-3.5)*0.035
			_box(Vector3(-1.05+index*0.30,-2.6+height*0.5,face-0.12),Vector3(0.285,height,0.25),"wood" if index%3 else "wood_light")
		for y in [-2.12,-0.82,0.82,2.15]:
			_box(Vector3(0,y,face+0.04),Vector3(2.40,0.13,0.12),"iron")
			for x in [-1.05,-0.60,0.60,1.05]:_bolt(Vector3(x,y,face+0.12),0.038)
		for side in [-1.0,1.0]:
			_box(Vector3(side*1.14,0,face+0.04),Vector3(0.12,5.2,0.12),"iron")
			_beam(Vector3(side*1.02,-1.98,face+0.08),Vector3(side*0.06,0.65,face+0.08),0.11,"wood_dark")
		_ring(Vector3(0,-0.45,face+0.15),0.24,0.045,"iron")
		_bolt(Vector3(0,-0.17,face+0.13),0.08)
		if theme in [1,3,8,9]:
			_quad("cloth",Vector3(-0.35,1.95,face+0.13),Vector3(-0.35,1.13,face+0.13),Vector3(0.35,1.13,face+0.13),Vector3(0.35,1.95,face+0.13))
			_triangle("gold",Vector3(-0.35,1.13,face+0.14),Vector3(0,0.88,face+0.14),Vector3(0.35,1.13,face+0.14))
		if theme == 4:
			for y in [-1.6,-0.25,1.25]:
				for x in [-0.73,-0.24,0.24,0.73]:_box(Vector3(x,y,face+0.09),Vector3(0.27,0.10,0.08),"iron")
	# Retorno lateral escuro, sem a superfície bege lisa do protótipo.
	for side in [-1.0,1.0]:
		for row in 10:
			_box(Vector3(side*1.11,-2.32+row*0.51,0),Vector3(0.16,0.48,3.5),"stone" if stone else ("iron" if theme==4 else "wood_dark"))
	_flush()

func gate_frame(theme: int,at: Vector3) -> void:
	# O portal já aprovado permanece atrás da pista. Guias e guincho dão função à peça.
	var frame_id:="capital_archway"
	var frame_width:=6.5
	if theme==6:frame_id="desert_ancient_ruins"
	elif theme==8:
		frame_id="desert_military_gate"
		frame_width=10.8
	elif theme==9:frame_id="desert_mining_gantry"
	place_asset(frame_id,at+Vector3(0,0,-3.5),frame_width)
	if theme==3:place_asset("capital_market_stall",at+Vector3(-3.55,0,-4.0),3.2)
	if theme==5:place_asset("capital_palm_garden",at+Vector3(3.0,0,-4.0),3.0)
	for side in [-1.0,1.0]:
		var x: float = side*1.46
		_box(at+Vector3(x,2.76,1.72),Vector3(0.36,5.52,0.46),"wood_dark" if theme==9 else "stone")
		for y in [0.16,1.5,3.1,5.48]:_box(at+Vector3(x,y,1.75),Vector3(0.48,0.18,0.55),"iron" if theme==9 else "trim")
		_rope(at+Vector3(side*1.23,0.18,1.66),at+Vector3(side*1.23,5.55,1.66),0.025)
	_box(at+Vector3(0,5.53,1.70),Vector3(3.50,0.23,0.48),"trim")
	winch(at+Vector3(-2.06,0,-1.0),theme)
	_flush()

func passage(length: float,theme: int,lift := false) -> void:
	# Módulos na proporção original: nenhum esticamento de uma imagem sobre o vão todo.
	var count := ceili(length/6.7)
	var width := length/count
	for index in count:
		var section := get_script().new() as Node3D
		section.name = "TaskSection%02d" % index
		section.position.x = -length*0.5+width*(index+0.5)
		add_child(section)
		sections.append(section)
		section._passage_section(width,theme,lift,index)

func _passage_section(width: float,theme: int,lift: bool,index: int) -> void:
	if theme in [4,6]:
		for step in ceili(width/0.85):
			var w := width/ceili(width/0.85)
			_box(Vector3(-width*0.5+w*(step+0.5),0,0),Vector3(w-0.025,0.26,3.8),"stone" if step%3 else "trim")
		_box(Vector3(0,-0.25,1.73),Vector3(width,0.22,0.25),"trim")
		_lower_art("desert_aqueduct",width,0.17,0.11,2.03)
	elif theme == 5:
		for index_z in 6:
			_tube(Vector3(-width*0.5,-0.22,-1.55+index_z*0.62),Vector3(width*0.5,-0.22,-1.55+index_z*0.62),0.35,"wood" if index_z%2 else "wood_light",8)
		for x in [-width*0.32,width*0.32]:
			_rope(Vector3(x,0.145,-1.90),Vector3(x,0.145,1.90),0.045)
			_rope(Vector3(x,-0.57,-1.90),Vector3(x,-0.57,1.90),0.045)
			for z in [-1.9,1.9]:_rope(Vector3(x,0.145,z),Vector3(x,-0.57,z),0.045)
		_tube(Vector3(-width*0.18,-0.27,1.65),Vector3(-width*0.18+0.28,-0.16,2.08),0.12,"wood_dark",7)
	else:
		for plank in ceili(width/0.39):
			var w := width/ceili(width/0.39)
			_box(Vector3(-width*0.5+w*(plank+0.5),0,0),Vector3(w-0.022,0.26,3.8),"wood" if plank%4 else "wood_light")
		for z in [-1.65,1.65]:
			_box(Vector3(0,-0.27,z),Vector3(width,0.29,0.25),"wood_dark")
			for x in [-width*0.43,width*0.43]:
				_box(Vector3(x,-0.18,z+0.15),Vector3(0.21,0.42,0.07),"iron")
				_bolt(Vector3(x,-0.18,z+0.20),0.042)
		# A ponte ilustrada fica atrás do personagem; cordas não cobrem sua silhueta.
		if theme != 3:
			var texture := Assets.texture("desert_timber_bridge")
			var pixels := width/texture.get_width()
			_house_sprite(texture,Vector3(0,0.13+(0.32-0.5)*texture.get_height()*pixels,-1.94),pixels)
			# Treliça ilustrada na frente, recortada abaixo do piso: nunca oculta o herói.
			_lower_art("desert_timber_bridge",width,0.32,0.13,2.02)
		if theme == 3:
			# Toldo reforçado: tecido vermelho entre travessas, borda e franjas douradas.
			for panel in 4:
				var a := -width*0.5+panel*width/4.0
				var b := a+width/4.0
				_quad("cloth" if panel%2 else "cloth_light",Vector3(a,0.135,-1.85),Vector3(a,0.135,1.85),Vector3(b-0.015,0.135,1.85),Vector3(b-0.015,0.135,-1.85))
			# Dobras e bordado do toldo aprovado, em vez de uma faixa vermelha lisa.
			var fabric := load("res://assets/desert/modular/capital_market_stall.res") as Texture2D
			var canopy := AtlasTexture.new()
			canopy.atlas=fabric
			canopy.region=Rect2(fabric.get_width()*0.12,fabric.get_height()*0.105,fabric.get_width()*0.77,fabric.get_height()*0.225)
			canopy.filter_clip=true
			var pixels := width/canopy.get_width()
			_house_sprite(canopy,Vector3(0,0.10-canopy.get_height()*pixels*0.5,2.02),pixels)
	if lift:
		for side in [-1.0,1.0]:
			_beam(Vector3(side*width*0.43,-0.38,1.73),Vector3(0,-0.91,1.73),0.16,"wood_dark" if theme!=6 else "stone")
		for x in [-width*0.43,width*0.43]:
			_box(Vector3(x,0.44,-1.75),Vector3(0.12,0.87,0.12),"wood_dark")
		_rope(Vector3(-width*0.43,0.80,-1.75),Vector3(width*0.43,0.80,-1.75),0.035)
		for x in [-width*0.4,width*0.4]:
			_box(Vector3(x,-0.36,0),Vector3(0.21,0.22,3.95),"iron")
			for z in [-1.7,1.7]:_ring(Vector3(x,-0.15,z),0.11,0.03,"iron")
		if theme in [7,9,10] and index%2 == 0:
			_quad("cloth",Vector3(-0.31,-0.40,1.82),Vector3(-0.31,-0.92,1.82),Vector3(0.31,-0.92,1.82),Vector3(0.31,-0.40,1.82))
			_triangle("gold",Vector3(-0.31,-0.92,1.83),Vector3(0,-1.12,1.83),Vector3(0.31,-0.92,1.83))
	_flush()

func _lower_art(id: String,width: float,from_v: float,top: float,z: float) -> void:
	var texture := Assets.texture(id)
	var lower:=Assets.crop(texture,Rect2(0,texture.get_height()*from_v,texture.get_width(),texture.get_height()*(1.0-from_v)))
	var pixels := width/texture.get_width()
	_house_sprite(lower,Vector3(0,top-lower.get_height()*pixels*0.5,z),pixels)

func supports(start: Vector3,finish: Vector3,theme: int) -> void:
	for side in 2:
		var direction:=-1.0 if side==0 else 1.0
		var edge:=start if side==0 else finish
		# A instalação inteira cabe na margem. Antes a perna interior do asset
		# ultrapassava o início do abismo e parecia ficar suspensa.
		var point:=edge+Vector3(direction*2.3,0,0)
		place_asset("desert_mining_gantry" if theme!=6 else "desert_ancient_ruins",point+Vector3(0,0,-4.3),4.3)
		for x: float in [-1.85,1.85]:
			_box(point+Vector3(x,1.58,-2.3),Vector3(0.22,3.16,0.24),"wood_dark" if theme!=6 else "stone")
			_box(point+Vector3(x,0.08,-2.3),Vector3(0.42,0.16,0.50),"iron" if theme!=6 else "trim")
		_box(point+Vector3(0,3.16,-2.3),Vector3(4.0,0.22,0.26),"wood" if theme!=6 else "trim")
		var guide:=edge+Vector3(direction*0.85,2.9,-2.3)
		_beam(guide+Vector3(0,0.30,0),guide+Vector3(0,0.12,0),0.065,"iron")
		_ring(guide,0.13,0.030,"iron")
		_bolt(guide+Vector3(0,0,0.035),0.04)
		winch(edge+Vector3(direction*0.85,0,-1.35),theme)
	_flush()

func winch(at: Vector3,theme: int) -> void:
	_box(at+Vector3(0,0.13,0),Vector3(0.70,0.26,0.62),"stone" if theme==6 else "wood_dark")
	for x in [-0.23,0.23]:_box(at+Vector3(x,0.43,0),Vector3(0.12,0.60,0.40),"iron")
	_tube(at+Vector3(-0.37,0.62,0),at+Vector3(0.37,0.62,0),0.16,"rope",10)
	_ring(at+Vector3(0,0.68,0.29),0.24,0.035,"iron")
	for angle in [0.0,PI*0.5]:
		var delta := Vector3(cos(angle)*0.24,sin(angle)*0.24,0)
		_beam(at+Vector3(0,0.68,0.29)-delta,at+Vector3(0,0.68,0.29)+delta,0.035,"iron")
	_bolt(at+Vector3(0,0.68,0.31),0.07)
	_box(at+Vector3(0.20,0.86,0.36),Vector3(0.08,0.15,0.10),"gold")

func deploy() -> void:
	# Montagem por seções, em vez de girar uma laje gigante para dentro da câmera.
	for index in sections.size():
		var section := sections[index]
		section.position.y = -1.1
		section.scale = Vector3(0.94,0.6,0.98)
		var tween := section.create_tween().set_parallel(true)
		var delay := index*0.37/maxf(sections.size()-1,1)
		tween.tween_property(section,"position:y",0.0,0.38).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(section,"scale",Vector3.ONE,0.38).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _bolt(at: Vector3,radius: float) -> void:
	_tube(at-Vector3(0,0,0.02),at+Vector3(0,0,0.02),radius,"gold",6)

func _rope(a: Vector3,b: Vector3,radius: float) -> void:
	_tube(a,b,radius,"rope",6)

func _beam(a: Vector3,b: Vector3,width: float,key: String) -> void:
	_tube(a,b,width*0.707,key,4)

func _tube(a: Vector3,b: Vector3,radius: float,key: String,sides := 6) -> void:
	var direction := (b-a).normalized()
	var u := direction.cross(Vector3.FORWARD).normalized()
	if u.length_squared()<0.01:u=Vector3.RIGHT
	var v := direction.cross(u).normalized()
	for index in sides:
		var n := (u*cos(TAU*index/sides)+v*sin(TAU*index/sides))*radius
		var m := (u*cos(TAU*(index+1)/sides)+v*sin(TAU*(index+1)/sides))*radius
		var side_key := key
		if key.begins_with("wood") and sides==8:
			side_key="wood_light" if (n.y+m.y)>radius else ("wood_dark" if (n.y+m.y)<-radius else "wood")
		_quad(side_key,a+n,b+n,b+m,a+m)
		_triangle(key,a,a+m,a+n)
		_triangle(key,b,b+n,b+m)

func _ring(at: Vector3,radius: float,thickness: float,key: String) -> void:
	for index in 16:
		var a := TAU*index/16.0
		var b := TAU*(index+1)/16.0
		_tube(at+Vector3(cos(a),sin(a),0)*radius,at+Vector3(cos(b),sin(b),0)*radius,thickness,key,5)

func _quad(key: String,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	if not key.begins_with("wood") and not key.begins_with("cloth"):
		super._quad(key,a,b,c,d)
		return
	# Faces superiores mais claras separam piso e espessura na câmera inclinada.
	if key.begins_with("wood") and absf((b-a).cross(c-a).normalized().y)>0.65:key="wood_top"
	if not _builders.has(key):
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		_builders[key]=builder
	var st: SurfaceTool = _builders[key]
	# Recorte UV da travessa do asset aprovado. Não cria nem decodifica novas texturas.
	var uv := [Vector2(0.105,0.848),Vector2(0.105,0.888),Vector2(0.280,0.888),Vector2(0.280,0.848)]
	if key.begins_with("cloth"):uv=[Vector2(0.35,0.16),Vector2(0.35,0.25),Vector2(0.65,0.25),Vector2(0.65,0.16)]
	if (b-a).length()>(c-b).length():uv=[uv[0],uv[3],uv[2],uv[1]]
	var corners := [a,b,c,d]
	for index in [0,2,1,0,3,2]:
		st.set_uv(uv[index])
		st.add_vertex(corners[index])

func _triangle(key: String,a: Vector3,b: Vector3,c: Vector3) -> void:
	if not key.begins_with("wood") and not key.begins_with("cloth"):
		super._triangle(key,a,b,c)
		return
	if not _builders.has(key):
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		_builders[key]=builder
	var st: SurfaceTool = _builders[key]
	var uv := [Vector2(0.14,0.853),Vector2(0.21,0.883),Vector2(0.27,0.853)]
	if key.begins_with("cloth"):uv=[Vector2(0.35,0.16),Vector2(0.5,0.25),Vector2(0.65,0.16)]
	var corners := [a,b,c]
	for index in 3:
		st.set_uv(uv[index])
		st.add_vertex(corners[index])

func _material(key: String) -> StandardMaterial3D:
	if _task_materials.has(key):return _task_materials[key]
	var mat := StandardMaterial3D.new()
	mat.roughness=0.88
	mat.metallic_specular=0.12
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	var palette := {"wood":"#b7a491","wood_top":"#e8d2ad","wood_light":"#d1b89b","wood_dark":"#806954","iron":"#3e3630","gold":"#ba8e50","stone":"#b2a092","trim":"#c6b39a","rope":"#aa8150","cloth":"#7c2627","cloth_light":"#a94437","water":"#376f7a","rust":"#765e4c","patina":"#476b65"}
	mat.albedo_color=Color(palette.get(key,"#9a8068"))
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if key=="water":mat.roughness=0.35
	if key.begins_with("wood"):
		mat.albedo_texture=load("res://assets/desert/modular/desert_timber_bridge.res")
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	elif key in ["stone","trim"]:
		mat.albedo_texture=load("res://assets/desert/modular/stone_masonry.res")
	elif key.begins_with("cloth"):
		mat.albedo_texture=load("res://assets/desert/modular/capital_market_stall.res")
		mat.albedo_color=Color("#cebcaa") if key=="cloth_light" else Color("#ae9991")
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	_task_materials[key]=mat
	return mat
