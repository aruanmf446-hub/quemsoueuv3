extends RefCounted
## Catálogo aprovado e âncoras resolvidas sobre o mesmo piso usado pela física.
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
static var _catalog := {}
static var _plan := {}
static var _textures := {}
static var _resolved := {}
static var _surfaces := {}
const PALETTES := [
 ["capital_house","capital_merchant","capital_balcony_house","capital_watchtower"],
 ["capital_balcony_house","capital_house","capital_merchant"],
 ["capital_market_stall","capital_merchant","capital_market_stall","capital_palm_garden"],
 ["capital_archway","desert_oasis_fountain"],
 ["capital_palm_garden","desert_oasis_fountain","capital_palm_garden"],
 ["desert_ancient_ruins","desert_mine_crystals"],
 ["desert_mining_gantry","desert_mine_crystals"],
 ["capital_watchtower","capital_archway"],
 ["desert_mining_gantry","desert_mine_crystals"],
 ["desert_mine_crystals","desert_mining_gantry"]]
static func _read() -> void:
	if not _catalog.is_empty(): return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/desert/modular/city_assets.json"))
	for entry: Dictionary in data.assets: _catalog[entry.id]=entry
	_plan=JSON.parse_string(FileAccess.get_file_as_string("res://assets/desert/modular/phase_asset_plan.json"))
static func entry(id: String) -> Dictionary:
	_read()
	return _catalog.get(id,{})
static func texture(id: String) -> Texture2D:
	if not _textures.has(id):
		var item := entry(id)
		if item.is_empty(): return null
		var base := load(String(item.texture)) as Texture2D
		if item.has("content_uv_rect"):
			var box: Array=item.content_uv_rect
			var clipped := AtlasTexture.new()
			clipped.atlas=base
			clipped.region=Rect2(float(box[0])*base.get_width(),float(box[1])*base.get_height(),float(box[2])*base.get_width(),float(box[3])*base.get_height())
			clipped.filter_clip=true
			_textures[id]=clipped
		else: _textures[id]=base
	return _textures[id] as Texture2D
## Recortes de Sprite3D sempre apontam para a imagem base. Atlas aninhado perde
## deslocamento UV no Compatibility, afastando a arte de seu apoio físico.
static func crop(source: Texture2D,region: Rect2) -> AtlasTexture:
	var base:=source
	while base is AtlasTexture:
		region.position+=(base as AtlasTexture).region.position
		base=(base as AtlasTexture).atlas
	var result:=AtlasTexture.new()
	result.atlas=base
	result.region=region
	result.filter_clip=true
	return result
static func paths(order: int) -> Array[String]:
	_read()
	var result: Array[String]=[]
	var ids: Array=PALETTES[order-1].duplicate()
	for slot: Dictionary in _plan.stages[order-1].slots: ids.append(slot.asset)
	ids.append_array(composition_ids(order))
	ids.append("capital_archway") # Moldura das tarefas de portão, inclusive nas ruínas.
	ids.append("desert_timber_bridge") # Madeira e módulos das Tasks; recurso compartilhado.
	if order in [1,3,7,8,9,10]:ids.append("capital_market_stall") # Tecido só nos mecanismos que o usam.
	if order in [2,7,9,10]:ids.append("desert_mining_gantry")
	if order not in [6,10]: ids.append_array(["capital_house","capital_merchant","capital_watchtower","capital_archway"])
	if order==2: ids.append_array(["capital_house","capital_balcony_house","capital_merchant"])
	if order in [4,6]: ids.append("desert_aqueduct")
	for id: String in ids:
		var path := String(entry(id).get("texture",""))
		if not path.is_empty() and not result.has(path): result.append(path)
	if order in [4,5]:result.append("res://assets/desert/modular/riverbank_context.res")
	if order==5:result.append("res://assets/desert/modular/oasis_water_surface.png")
	if order in [1,3]:result.append("res://assets/desert/modular/city_supplies_context.res")
	if order in [1,6,8]:result.append("res://assets/desert/weapons/cactus_spear.res")
	if order==1:result.append("res://assets/desert/tutorial/defense.res")
	for lesson: String in ["amber","dash","rupture"]:
		if order>=int(Layout.ABILITY_PHASE[lesson]):
			result.append("res://assets/desert/tutorial/"+lesson+".res")
	return result
static func surface(order: int,index: int) -> Dictionary:
	if not _surfaces.has(order): placements(order)
	return _surfaces[order][index]
static func placements(order: int) -> Array:
	if _resolved.has(order): return _resolved[order]
	_read()
	var stage := Layout.build(order)
	_surfaces[order]=stage.surfaces
	var result: Array=[]
	for index in range(_plan.stages[order-1].slots.size()):
		var slot: Dictionary=_plan.stages[order-1].slots[index]
		var width := float(entry(slot.asset).suggested_width_metres)
		var desired := float(stage.player_spawn[0])+float(stage.length)*float(slot.fraction)
		var best := INF
		var chosen: Dictionary={}
		var x := desired
		for floor: Dictionary in stage.surfaces:
			if floor.get("task_void",false):continue
			var left := float(floor.left)+width*0.5+0.3
			var right := float(floor.right)-width*0.5-0.3
			if left>right: continue
			var point := clampf(desired,left,right)
			if absf(point-desired)<best:
				best=absf(point-desired)
				x=point
				chosen=floor
		if chosen.is_empty(): continue
		result.append({"id":"p%02d.art.%02d" % [order,index],"asset":slot.asset,"x":x,"y":float(chosen.height),"width":width,"anchor":slot.anchor,"surface":chosen.index})
	_resolved[order]=result
	return result

## Conjuntos decorativos ancorados em uma laje real. Nunca alteram a física.
## Posições relativas e duas profundidades formam ruas e praças, em vez de uma grade.
static func composition(order: int, slot: int, left: float, right: float, top: float) -> Array[Dictionary]:
	if surface(order,slot).get("task_void",false):return []
	var variants: Array
	match order:
		1:
			variants = [
				[["capital_house",0.18,7.0,-11.0],["capital_balcony_house",0.49,7.0,-11.6],["capital_merchant",0.80,6.6,-10.4],["capital_palm_garden",0.34,3.5,-6.2]],
				[["capital_merchant",0.21,7.2,-10.5],["capital_house",0.78,7.0,-11.2],["capital_palm_garden",0.53,4.4,-6.3]],
				[["capital_balcony_house",0.20,7.0,-11.0],["capital_house",0.53,6.8,-11.7],["capital_watchtower",0.86,3.4,-8.0],["capital_palm_garden",0.72,3.2,-6.0]]]
		2:
			variants = [
				[["capital_house",0.19,7.4,-11.0],["capital_balcony_house",0.50,7.0,-10.3],["capital_merchant",0.82,6.8,-11.8]],
				[["capital_balcony_house",0.24,7.0,-10.8],["capital_house",0.76,7.5,-11.6]],
				[["capital_merchant",0.20,7.2,-11.4],["capital_house",0.53,7.0,-10.5],["capital_balcony_house",0.82,7.0,-11.7]]]
		3:
			variants = [
				[["capital_merchant",0.19,7.0,-10.5],["capital_house",0.49,6.8,-11.5],["capital_merchant",0.81,6.5,-10.0],["capital_market_stall",0.34,3.5,-5.6],["capital_market_stall",0.68,3.2,-6.1]],
				[["capital_house",0.19,6.8,-10.5],["capital_merchant",0.80,7.0,-10.2],["capital_palm_garden",0.52,4.5,-7.0],["capital_market_stall",0.26,3.3,-5.8],["capital_market_stall",0.76,3.4,-5.7]],
				[["capital_merchant",0.28,7.0,-10.8],["capital_merchant",0.73,6.8,-10.0],["capital_market_stall",0.45,3.5,-5.9],["capital_palm_garden",0.84,3.8,-6.3]]]
		4:
			variants = [
				[["capital_archway",0.18,5.4,-10.0],["capital_archway",0.78,5.4,-11.0],["desert_oasis_fountain",0.46,3.2,-6.6]],
				[["capital_archway",0.30,5.6,-10.5],["capital_archway",0.70,5.4,-11.2],["capital_palm_garden",0.85,3.8,-6.5]],
				[["capital_palm_garden",0.18,4.2,-8.0],["capital_archway",0.51,5.8,-11.0],["capital_palm_garden",0.81,4.0,-7.0]]]
		5:
			variants = [
				[["capital_palm_garden",0.18,4.4,-5.5],["desert_oasis_fountain",0.51,3.6,-5.4],["capital_palm_garden",0.83,3.6,-20.0]],
				[["capital_palm_garden",0.27,4.4,-5.5],["capital_palm_garden",0.76,3.8,-20.0],["desert_oasis_fountain",0.66,3.2,-5.4]],
				[["capital_palm_garden",0.16,3.6,-20.0],["capital_archway",0.55,4.2,-20.0],["capital_palm_garden",0.84,4.5,-5.5]]]
		6:
			variants = [
				[["desert_ancient_ruins",0.24,6.5,-10.8],["desert_ancient_ruins",0.77,5.4,-11.8],["desert_mine_crystals",0.47,3.0,-6.8]],
				[["desert_ancient_ruins",0.55,7.0,-10.2],["desert_mine_crystals",0.17,3.4,-7.0],["desert_mine_crystals",0.83,2.8,-8.5]],
				[["desert_ancient_ruins",0.22,5.6,-11.4],["desert_mine_crystals",0.67,4.0,-8.2]]]
		7,9:
			variants = [
				[["desert_mining_gantry",0.24,5.8,-10.2],["desert_mining_gantry",0.75,5.2,-11.5],["desert_mine_crystals",0.47,3.2,-6.5]],
				[["desert_mining_gantry",0.52,6.5,-10.5],["desert_mine_crystals",0.17,3.5,-7.8],["desert_mine_crystals",0.85,3.0,-7.0]],
				[["desert_mining_gantry",0.22,5.6,-11.3],["desert_mine_crystals",0.71,3.5,-7.5]]]
		8:
			variants = [
				[["capital_house",0.25,6.2,-11.2],["capital_house",0.74,6.0,-12.0],["capital_watchtower",0.13,3.0,-6.7],["capital_archway",0.53,4.8,-7.5],["capital_watchtower",0.87,3.0,-6.5]],
				[["capital_merchant",0.25,6.5,-11.0],["capital_house",0.75,6.0,-11.8],["capital_watchtower",0.54,3.8,-7.0]],
				[["capital_house",0.26,6.5,-11.8],["capital_watchtower",0.76,3.8,-7.0],["capital_archway",0.22,4.8,-7.8]]]
		_:
			variants = [
				[["desert_mining_gantry",0.28,5.8,-10.5],["desert_mine_crystals",0.65,3.8,-7.0],["desert_mine_crystals",0.85,2.5,-8.5]],
				[["desert_mining_gantry",0.68,5.4,-11.2],["desert_mine_crystals",0.19,3.8,-7.0]],
				[["desert_mine_crystals",0.22,3.5,-8.0],["desert_mine_crystals",0.76,3.8,-7.0]]]
	# Arena silenciosa: nenhum guindaste novo atrás da luta contra Malagueta.
	if order == 10 and slot == 47:
		variants = [[["desert_mine_crystals",0.12,3.0,-9.0],["desert_mine_crystals",0.88,3.0,-9.0]]]
	var result: Array[Dictionary] = []
	for part: Array in variants[posmod(slot,variants.size())]:
		var width := float(part[2])
		if right-left < width+1.2: continue
		var fraction := float(part[1])
		# Jardins e instalações formam núcleos próximos, com respiro nas aproximações.
		# A arena conserva os cristais laterais e seu centro livre.
		if order in [4,5,6,7,9,10] and not (order == 10 and slot == 47):
			fraction = 0.48 + (fraction-0.5)*0.55 + (0.035 if slot%3==1 else -0.02)
		var x := clampf(lerpf(left,right,fraction),left+0.6+width*0.5,right-0.6-width*0.5)
		result.append({"asset":String(part[0]),"x":x,"y":top-9.0 if order == 2 else (top-0.6 if float(part[3]) < -9.0 and order!=5 else top),"z":float(part[3]),"width":width})
	return result

## Aquecimento restrito à região atual, incluindo todas as variantes dos conjuntos.
static func composition_ids(order: int) -> Array[String]:
	var result: Array[String] = []
	for variant in 3:
		for part: Dictionary in composition(order,variant,0,40,0):
			if not result.has(part.asset): result.append(part.asset)
	return result
