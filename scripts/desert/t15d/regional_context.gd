extends RefCounted
## Infraestrutura e margens, em lotes de material do próprio chunk.
## Ilustrações limitadas por laje; caixas e carrinhos recebem apoio opcional por cima.
static var _materials: Dictionary={}
static var _textures: Dictionary={}
const ROOT="res://assets/desert/modular/"
const WATER=preload("res://scripts/desert/t15d/regional_water.gdshader")
const OASIS_WATER=preload("res://scripts/desert/t15d/oasis_water.gdshader")
const Landings=preload("res://scripts/desert/t15d/prop_landings.gd")

static func build(props: Node3D,order: int,slot: int,left: float,right: float,top: float) -> void:
	if order==2 or right-left<7.0 or (order==10 and slot>=40):return
	var a:=left+0.8
	var b:=right-0.8
	var kind: String
	match order:
		4,5:
			kind="riverbank" if order==5 else "canal"
			_waterway(props,a,b,top,order==5,slot)
		1,3:
			kind="city_courtyard" if order==1 else "market_delivery"
			_apron(props,a,b,top)
			var fraction: float=[0.50,0.43,0.65][slot%3] if order==3 else 0.34+float(slot%3)*0.06
			_decoration(props,"city_supplies_context",Vector3(lerpf(a,b,fraction),top-0.60,-6.6),3.3 if order==1 else 3.6,slot%3==1,Vector2(a,b),top)
		6:
			kind="buried_courtyard"
			_apron(props,a,b,top,true)
			var x:=lerpf(a,b,0.52)
			for i in 5:
				_lathe(props,Vector3(x+float(i-2)*0.42,top-0.60,-5.0),0.22+float(i%3)*0.13,0.25,[Vector2(0.9,0),Vector2(1,0.25),Vector2(0.55,0.8),Vector2(0.01,1)],"context_earth",Color("#ccc6b9"))
			_lathe(props,Vector3(x+1.5,top-0.7,-5.2),0.65,0.30,[Vector2(0.6,0),Vector2(1,0.3),Vector2(0.85,0.65),Vector2(0.4,0.9),Vector2(0.44,1)],"context_props",Color("#a36e51"))
		7,9,10:
			kind="ore_road" if order==7 else ("loading_yard" if order==9 else "mine_railway")
			_apron(props,a,b,top,true)
			_railway(props,a,b,top-0.60)
			if slot%2==0:_decoration(props,"ore_cart_context",Vector3(lerpf(a,b,0.45),top-0.49,-5.6),2.5,false,Vector2(a,b),top)
		8:
			kind="guard_supplies"
			_apron(props,a,b,top)
			var at:=Vector3(lerpf(a,b,0.42),top-0.60,-6.0)
			for i in 2:
				var center:=at+Vector3(float(i)*1.06,0.43,0)
				_box(props,center,Vector3(0.94,0.86,0.86),"context_wood",Color("#d3c6b0"))
				Landings.attach_box(props,center,Vector3(0.94,0.86,0.86),top)
				for y: float in [-0.32,0.32]:_box(props,center+Vector3(0,y,0.46),Vector3(0.98,0.075,0.06),"context_props",Color("#4a4b49"))
				for x: float in [-0.35,0.35]:_box(props,center+Vector3(x,0,0.46),Vector3(0.065,0.88,0.06),"context_props",Color("#4a4b49"))
		_:return
	props.add_to_group("regional_context")
	var records: Array=props.get_meta("regional_context",[])
	records.append({"id":"p%02d.context.%03d" % [order,slot],"order":order,"slot":slot,"left":a,"right":b,"top":top,"kind":kind})
	props.set_meta("regional_context",records)

static func _decoration(props: Node3D,id: String,at: Vector3,width: float,flip:=false,bounds:=Vector2(-INF,INF),floor_top:=INF) -> void:
	at.x=clampf(at.x,bounds.x+width*0.5,bounds.y-width*0.5)
	if not _textures.has(id):
		if id=="ore_cart_context":
			var base:=load(ROOT+"desert_mining_gantry.res") as Texture2D
			var crop:=AtlasTexture.new()
			crop.atlas=base
			crop.region=Rect2(base.get_width()*0.332,base.get_height()*0.686,base.get_width()*0.292,base.get_height()*0.250)
			crop.filter_clip=true
			_textures[id]=crop
		else:_textures[id]=load(ROOT+id+".res")
	var texture: Texture2D=_textures[id]
	var pixels:=width/texture.get_width()
	var sprite: Sprite3D=props._house_sprite(texture,at+Vector3.UP*texture.get_height()*pixels*0.5,pixels)
	sprite.flip_h=flip
	sprite.add_to_group("regional_context_art")
	sprite.set_meta("context_asset",id)
	sprite.set_meta("ground_y",at.y)
	sprite.set_meta("context_span",bounds)
	if is_finite(floor_top):Landings.attach(sprite,id,props._order,bounds.x,bounds.y,floor_top)

static func _apron(props: Node3D,left: float,right: float,top: float,earth:=false) -> void:
	var key:="context_earth" if earth else "context_masonry"
	_box(props,Vector3((left+right)*0.5,top-0.76,-8.4),Vector3(right-left,0.32,9.6),key,Color("#c7beb2"))
	_quad(props,key,Vector3(left,top-0.60,-3.6),Vector3(left,top-0.18,-2.7),Vector3(right,top-0.18,-2.7),Vector3(right,top-0.60,-3.6),Color("#bbb2a7"))

static func _railway(props: Node3D,left: float,right: float,floor_y: float) -> void:
	for z: float in [-6.14,-5.06]:_box(props,Vector3((left+right)*0.5,floor_y+0.10,z),Vector3(right-left,0.10,0.10),"context_props",Color("#56616a"))
	var ties:=ceili((right-left)/1.2)
	for i in ties:
		_box(props,Vector3(lerpf(left,right,(float(i)+0.5)/ties),floor_y+0.025,-5.6),Vector3(0.15,0.05,1.65),"context_wood",Color("#9d8c79"))

static func _river_bend(x: float) -> float:
	# Coordenada mundial: a curva não reinicia ao trocar de laje ou de chunk.
	return sin(x*0.17)*0.50+sin(x*0.41+1.3)*0.18

static func _waterway(props: Node3D,left: float,right: float,top: float,natural: bool,slot: int) -> void:
	var segments:=8 if natural else 1
	for i in segments:
		var a:=lerpf(left,right,float(i)/segments)
		var b:=lerpf(left,right,float(i+1)/segments)
		var bend_a:=_river_bend(a) if natural else 0.0
		var bend_b:=_river_bend(b) if natural else 0.0
		var near_a:=-6.7+bend_a
		var near_b:=-6.7+bend_b
		var far_a:=(-18.6 if natural else -16.0)+bend_a
		var far_b:=(-18.6 if natural else -16.0)+bend_b
		_quad(props,"context_water_oasis" if natural else "context_water",Vector3(a,top-0.28,near_a),Vector3(b,top-0.28,near_b),Vector3(b,top-0.28,far_b),Vector3(a,top-0.28,far_a),Color.WHITE)
		# Margens com espessura e terreno de apoio: a água fica no interior.
		for edge in [0,1]:
			var z_a: float=near_a if edge==0 else far_a
			var z_b: float=near_b if edge==0 else far_b
			var outward:=1.0 if edge==0 else -1.0
			if natural:
				var width_a: float=(2.0 if edge==0 else 3.2)+sin(a*0.25+edge)*0.22
				var width_b: float=(2.0 if edge==0 else 3.2)+sin(b*0.25+edge)*0.22
				# Lábio molhado, pequena rampa e terraço seco: tudo no lote de terra existente.
				_quad(props,"context_earth",Vector3(a,top-0.29,z_a),Vector3(a,top-0.21,z_a+outward*0.15),Vector3(b,top-0.21,z_b+outward*0.15),Vector3(b,top-0.29,z_b),Color("#7d8c85"))
				_quad(props,"context_earth",Vector3(a,top-0.21,z_a+outward*0.15),Vector3(a,top-0.015,z_a+outward*0.50),Vector3(b,top-0.015,z_b+outward*0.50),Vector3(b,top-0.21,z_b+outward*0.15),Color("#a09c8b"))
				_quad(props,"context_earth",Vector3(a,top-0.015,z_a+outward*0.50),Vector3(a,top,z_a+outward*width_a),Vector3(b,top,z_b+outward*width_b),Vector3(b,top-0.015,z_b+outward*0.50),Color("#b7ab94"))
			else:
				# Pedra escurecida junto à água e remate chanfrado no mesmo lote.
				_quad(props,"context_masonry",Vector3(a,top-0.34,z_a),Vector3(a,top-0.04,z_a),Vector3(b,top-0.04,z_b),Vector3(b,top-0.34,z_b),Color("#747d7d"))
				_quad(props,"context_masonry",Vector3(a,top-0.04,z_a),Vector3(a,top+0.045,z_a+outward*0.14),Vector3(b,top+0.045,z_b+outward*0.14),Vector3(b,top-0.04,z_b),Color("#b6b0a5"))
				_quad(props,"context_masonry",Vector3(a,top+0.045,z_a+outward*0.14),Vector3(a,top,z_a+outward*1.4),Vector3(b,top,z_b+outward*1.4),Vector3(b,top+0.045,z_b+outward*0.14),Color("#a39c92"))
	if natural:
		var near_x:=lerpf(left,right,0.38 if slot%2==0 else 0.56)
		var far_x:=lerpf(left,right,0.68 if slot%2==0 else 0.30)
		_decoration(props,"riverbank_context",Vector3(near_x,top-0.025,-6.7+_river_bend(near_x)+0.75),4.7,slot%2==1,Vector2(left,right))
		_decoration(props,"riverbank_context",Vector3(far_x,top-0.025,-18.6+_river_bend(far_x)-1.10),5.8,true,Vector2(left,right))
	else:
		for fraction: float in [0.18,0.78]:
			var x:=lerpf(left,right,fraction)
			_box(props,Vector3(x,top+0.20,-6.0),Vector3(0.30,0.40,0.30),"context_masonry",Color("#afa494"))
			_box(props,Vector3(x,top+0.43,-6.0),Vector3(0.44,0.08,0.44),"context_masonry",Color("#c1ad8c"))
		if slot%3==1:_decoration(props,"riverbank_context",Vector3(lerpf(left,right,0.45),top,-5.8),3.2,false,Vector2(left,right))

static func _lathe(props: Node3D,at: Vector3,height: float,radius: float,profile: Array,key: String,color: Color,basis:=Basis.IDENTITY) -> void:
	for ring in range(profile.size()-1):
		var a: Vector2=profile[ring]
		var b: Vector2=profile[ring+1]
		for i in 10:
			var angle0:=TAU*i/10.0
			var angle1:=TAU*(i+1)/10.0
			var u:=Vector3(cos(angle0)*radius,0,sin(angle0)*radius)
			var v:=Vector3(cos(angle1)*radius,0,sin(angle1)*radius)
			_quad(props,key,at+basis*(u*a.x+Vector3.UP*a.y*height),at+basis*(u*b.x+Vector3.UP*b.y*height),at+basis*(v*b.x+Vector3.UP*b.y*height),at+basis*(v*a.x+Vector3.UP*a.y*height),color)

static func _box(props: Node3D,at: Vector3,size: Vector3,key: String,color: Color) -> void:
	var r:=size*0.5
	var p: Array[Vector3]=[]
	for v: Vector3 in [Vector3(-1,-1,1),Vector3(-1,1,1),Vector3(1,1,1),Vector3(1,-1,1),Vector3(-1,-1,-1),Vector3(-1,1,-1),Vector3(1,1,-1),Vector3(1,-1,-1)]:p.append(at+v*r)
	for face: Array in [[0,1,2,3],[7,6,5,4],[4,5,1,0],[3,2,6,7],[1,5,6,2],[4,0,3,7]]:_quad(props,key,p[face[0]],p[face[1]],p[face[2]],p[face[3]],color)

static func _quad(props: Node3D,key: String,a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
	if not props._builders.has(key):
		var builder:=SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		props._builders[key]=builder
	var st: SurfaceTool=props._builders[key]
	var normal:=(b-a).cross(c-a).normalized()
	st.set_color(color)
	var corners: Array[Vector3]=[a,b,c,d]
	var wood_uv: Array[Vector2]=[Vector2(0.105,0.848),Vector2(0.105,0.888),Vector2(0.280,0.888),Vector2(0.280,0.848)]
	for i in [0,2,1,0,3,2]:
		var point: Vector3=corners[i]
		st.set_uv(wood_uv[i] if key=="context_wood" else Vector2(point.x,point.z if absf(normal.y)>0.65 else point.y)*0.30)
		st.add_vertex(point)

static func material(key: String) -> Material:
	if not _materials.has(key):
		if key in ["context_water","context_water_oasis"]:
			var water:=ShaderMaterial.new()
			water.shader=OASIS_WATER if key=="context_water_oasis" else WATER
			water.set_shader_parameter("water_detail",load(ROOT+"oasis_water_surface.png"))
			_materials[key]=water
		else:
			var surface:=StandardMaterial3D.new()
			surface.vertex_color_use_as_albedo=true
			surface.vertex_color_is_srgb=true
			surface.cull_mode=BaseMaterial3D.CULL_DISABLED
			surface.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			surface.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			if key=="context_masonry":surface.albedo_texture=load("res://assets/desert/modular/stone_masonry.res")
			if key=="context_earth":surface.albedo_texture=preload("res://assets/desert/phase01/sandstone.png")
			if key=="context_wood":surface.albedo_texture=load("res://assets/desert/modular/desert_timber_bridge.res")
			_materials[key]=surface
	return _materials[key]
