extends "res://scripts/desert/t15d/task_art.gd"
## Objetos de parkour com o mesmo topo físico aprovado. Decoração apenas:
## todos os detalhes mais altos ficam atrás da pista, nunca no caminho dos pés.
func build_obstacle(width: float,height: float,order: int,module: int) -> void:
	var variant:=floori(module/5.0)
	match order:
		3:_market_counter(width,height)
		5:_fallen_trunk(width,height)
		6:_fallen_column(width,height)
		7,9:_cargo(width,height,order)
		10:_maintenance_walk(width,height)
		_:
			_arcade(width,height,order)
			if order==1 and variant%2==0:
				place_asset("capital_palm_garden",Vector3(-width*0.25,0,-3.4),2.5)
			if order==8 and variant%2==0:
				place_asset("capital_watchtower",Vector3(width*0.30,0,-4.0),3.0)
	if order==5 and variant%2==1:
		place_asset("capital_palm_garden",Vector3(width*0.25,0,-3.5),2.4)
	if order==6 and variant%2==0:
		place_asset("desert_ancient_ruins",Vector3(-width*0.30,-0.1,-4.5),3.2)
	_flush()

func _arcade(width: float,height: float,order: int) -> void:
	var bays:=4
	var step:=width/bays
	var opening:=step-0.26
	var arch_top:=height-0.27
	# Pequenos vãos completos, com pilares grossos. Não usar um arco de5m de
	# largura e1m de altura, que criava batentes de tamanho negativo sob a pista.
	for i in range(bays+1):
		_box(Vector3(-width*0.5+i*step,(height-0.16)*0.5,0),Vector3(0.25,height-0.16,3.50),"stone")
	for i in bays:
		var x:=-width*0.5+(i+0.5)*step
		_arch_frame(Vector3(x,0.06,1.76),opening,arch_top,0.09)
		_box(Vector3(x,(height-0.15)*0.5,-1.52),Vector3(opening,height-0.15,0.12),"stone")
	_box(Vector3(0,height-0.08,0),Vector3(width+0.06,0.16,3.8),"trim")
	_box(Vector3(0,0.06,0),Vector3(width+0.06,0.12,3.68),"stone")
	if order==4:
		_lower_art("desert_aqueduct",width,0.17,height-0.08,1.96)
		_box(Vector3(0,height-0.04,-1.30),Vector3(width-0.4,0.025,0.48),"water")

func _market_counter(width: float,height: float) -> void:
	_box(Vector3(0,(height-0.14)*0.5,0),Vector3(width,height-0.14,3.5),"wood_dark")
	_floor_boards(width,height)
	var texture:=Assets.texture("capital_market_stall")
	var face:=Assets.crop(texture,Rect2(texture.get_width()*0.08,texture.get_height()*0.70,texture.get_width()*0.84,texture.get_height()*0.28))
	var pixels:=width/face.get_width()
	_house_sprite(face,Vector3(0,height-0.12-face.get_height()*pixels*0.5,1.96),pixels)
	# Mercadorias na parte de trás do balcão, deixando todo o percurso livre.
	for i in 3:
		var x:=-width*0.26+i*width*0.26
		_tube(Vector3(x-0.35,height+0.14,-1.36),Vector3(x+0.35,height+0.14,-1.36),0.14,"cloth_light" if i%2 else "cloth",10)
		for side: float in [-1.0,1.0]:_box(Vector3(x+side*0.24,height+0.14,-1.20),Vector3(0.045,0.20,0.025),"gold")

func _fallen_trunk(width: float,height: float) -> void:
	var radius:=height*0.5
	var center:=Vector3(0,height-radius,0)
	_tube(center-Vector3.RIGHT*width*0.5,center+Vector3.RIGHT*width*0.5,radius,"wood",8)
	for x in [-width*0.32,width*0.32]:
		# Laços contornam o tronco; o diâmetro continua no topo físico aprovado.
		for i in 16:
			var a:=TAU*i/16.0
			var b:=TAU*(i+1)/16.0
			_rope(center+Vector3(x,cos(a)*(radius+0.008),sin(a)*(radius+0.008)),center+Vector3(x,cos(b)*(radius+0.008),sin(b)*(radius+0.008)),0.022)
	for x in [-width*0.18,width*0.24]:
		var at:=center+Vector3(x,-0.03,radius*0.80)
		_tube(at,at+Vector3(0.12,0.10,0.22),0.13,"wood_dark",7)
		_ring(at+Vector3(0.12,0.10,0.225),0.075,0.014,"wood_light")

func _fallen_column(width: float,height: float) -> void:
	var center:=Vector3(0,height*0.5,0)
	_tube(center-Vector3.RIGHT*width*0.5,center+Vector3.RIGHT*width*0.5,height*0.5,"stone",12)
	for side: float in [-1.0,1.0]:
		_box(center+Vector3(side*(width*0.5-0.23),0,0),Vector3(0.46,height,height),"trim")
		for shift: float in [-0.13,0.13]:
			_box(center+Vector3(side*(width*0.5-0.23)+shift,0,height*0.5+0.015),Vector3(0.035,height*0.75,0.028),"iron")
	# Incisão na coluna, sem brilho de poder/coletável.
	for x in [-width*0.22,0.0,width*0.22]:
		_ring(center+Vector3(x,0,height*0.5+0.01),0.12,0.016,"gold")

func _cargo(width: float,height: float,order: int) -> void:
	var count:=maxi(2,roundi(width/1.8))
	var step:=width/count
	var body_height:=height-0.17
	for i in count:
		var x:=-width*0.5+(i+0.5)*step
		_box(Vector3(x,body_height*0.5,0),Vector3(step-0.045,body_height,3.5),"wood" if i%2 else "wood_light")
		for y in [0.10,body_height-0.10]:
			_box(Vector3(x,y,1.79),Vector3(step-0.07,0.09,0.08),"iron")
			for side: float in [-1.0,1.0]:_bolt(Vector3(x+side*(step*0.5-0.13),y,1.85),0.027)
		for side: float in [-1.0,1.0]:
			_box(Vector3(x+side*(step*0.5-0.09),body_height*0.5,1.79),Vector3(0.09,body_height,0.08),"iron")
		_beam(Vector3(x-step*0.39,0.16,1.82),Vector3(x+step*0.39,body_height-0.16,1.82),0.085,"wood_dark")
		_ring(Vector3(x,body_height*0.55,1.88),0.075,0.025,"iron")
	_floor_boards(width,height)
	if order==9:
		# Minério pequeno sobre a fileira de trás, fora do plano de corrida Z=0.
		for i in 5:
			_box(Vector3(-width*0.28+i*width*0.14,height+0.11,-1.42),Vector3(0.26,0.22,0.27),"stone")

func _maintenance_walk(width: float,height: float) -> void:
	_floor_boards(width,height)
	_lower_art("desert_timber_bridge",width,0.32,height-0.07,1.96)
	var texture:=Assets.texture("desert_timber_bridge")
	var pixels:=width/texture.get_width()
	_house_sprite(texture,Vector3(0,height+(0.32-0.5)*texture.get_height()*pixels,-1.94),pixels)

func _floor_boards(width: float,height: float) -> void:
	var count:=ceili(width/0.36)
	var step:=width/count
	for i in count:
		_box(Vector3(-width*0.5+(i+0.5)*step,height-0.08,0),Vector3(step-0.015,0.16,3.8),"wood" if i%3 else "wood_light")
