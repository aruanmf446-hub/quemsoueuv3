extends RefCounted
## Apoios opcionais alinhados à arte aprovada. Fundo distante e lacunas de Tasks excluídos.
const LAYER:=64
const GROUP:=&"campaign_one_way"
const Support=preload("res://scripts/desert/t15d/one_way_support.gd")
# Frações do recorte visível: esquerda, direita, altura desde o topo da imagem.
const LEDGES:={
 "capital_market_stall":[[0.10,0.89,0.115],[0.12,0.88,0.705]],
 "capital_merchant":[[0.07,0.93,0.135],[0.105,0.475,0.575],[0.145,0.445,0.815]],
 "capital_house":[[0.07,0.93,0.105]],
 "capital_balcony_house":[[0.06,0.94,0.145],[0.645,0.915,0.405],[0.12,0.46,0.525]],
 "desert_oasis_fountain":[[0.095,0.905,0.65],[0.34,0.67,0.305]],
 "desert_ancient_ruins":[[0.13,0.79,0.185],[0.79,0.93,0.67]],
 "desert_mining_gantry":[[0.12,0.89,0.115],[0.375,0.645,0.72],[0.43,0.62,0.52]],
 "city_supplies_context":[[0.595,0.84,0.30]],
 "ore_cart_context":[[0.10,0.90,0.25]]}
static func attach(art: Sprite3D,id: String,order: int,left: float,right: float,base_y: float) -> void:
	if art==null or not LEDGES.has(id) or order==2:return
	# A cidade distante é cenário. Só objetos próximos ao caminho oferecem apoio.
	if art.position.z < -8.0 or art.position.y<base_y-0.1:return
	var width:=art.texture.get_width()*art.pixel_size
	var height:=art.texture.get_height()*art.pixel_size
	var lower:=art.position.y-height*0.5
	var projection:=-art.position.z*(1.0/14.0)
	var index:=0
	for ledge: Array in LEDGES[id]:
		var u0:=1.0-float(ledge[1]) if art.flip_h else float(ledge[0])
		var u1:=1.0-float(ledge[0]) if art.flip_h else float(ledge[1])
		var a:=maxf(left+0.12,art.position.x+(u0-0.5)*width)
		var b:=minf(right-0.12,art.position.x+(u1-0.5)*width)
		if b-a<0.30:continue
		var top:=lower+(1.0-float(ledge[2]))*height+projection
		if top<base_y+0.35:continue
		var body:=Support.new()
		body.name="PropLanding%d" % index
		body.collision_layer=LAYER
		body.collision_mask=0
		body.position=Vector3((a+b)*0.5,top-0.04,0)
		body.set_meta("one_way_top",top)
		body.set_meta("prop_asset",id)
		body.set_meta("prop_art",art.get_path())
		body.set_meta("prop_ledge",index)
		body.set_meta("landing_span",Vector2(a,b))
		body.set_meta("source_floor",base_y)
		var collider:=CollisionShape3D.new()
		var box:=BoxShape3D.new()
		box.size=Vector3(b-a,0.08,1.6)
		collider.shape=box
		body.add_child(collider)
		art.get_parent().add_child(body)
		body.add_to_group(GROUP)
		index+=1
static func sync(actor: CharacterBody3D) -> void:
	var exceptions:=actor.get_collision_exceptions()
	for platform: StaticBody3D in actor.get_tree().get_nodes_in_group(GROUP):
		var top:=float(platform.get_meta("one_way_top"))
		# Comparação com os pés, nunca com a cabeça: de baixo não bloqueia nem prende.
		var support:=actor.velocity.y<=0.0 and actor.global_position.y>=top-0.025
		if support and exceptions.has(platform):actor.remove_collision_exception_with(platform)
		elif not support and not exceptions.has(platform):actor.add_collision_exception_with(platform)
