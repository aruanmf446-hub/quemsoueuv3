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
static func paths(order: int) -> Array[String]:
	_read()
	var result: Array[String]=[]
	var ids: Array=PALETTES[order-1].duplicate()
	for slot: Dictionary in _plan.stages[order-1].slots: ids.append(slot.asset)
	if order==2: ids.append_array(["capital_house","capital_balcony_house","capital_merchant"])
	if order==4: ids.append("desert_aqueduct")
	if order in [7,10]: ids.append("desert_timber_bridge")
	for id: String in ids:
		var path := String(entry(id).get("texture",""))
		if not path.is_empty() and not result.has(path): result.append(path)
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
