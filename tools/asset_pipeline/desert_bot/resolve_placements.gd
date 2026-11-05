extends SceneTree
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
func _initialize() -> void:
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/desert/modular/phase_asset_plan.json"))
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/desert/modular/city_assets.json"))
	var resources := {}
	for item: Dictionary in catalog.assets: resources[item.id]=item
	var failures := 0
	var count := 0
	var output: Array=[]
	for stage_info: Dictionary in plan.stages:
		var stage := Layout.build(int(stage_info.order))
		var placements: Array=[]
		for slot: Dictionary in stage_info.slots:
			if not resources.has(slot.asset):
				failures += 1
				continue
			var item: Dictionary=resources[slot.asset]
			var texture := load(String(item.texture)) as Texture2D
			if texture == null:
				failures += 1
				continue
			var width := float(item.suggested_width_metres)
			var height := width*texture.get_height()/texture.get_width()
			var wanted := float(stage.player_spawn[0])+float(stage.length)*float(slot.fraction)
			var x := wanted
			var best := INF
			var surface: Dictionary={}
			for candidate: Dictionary in stage.surfaces:
				var first := float(candidate.left)+width*0.5+0.3
				var last := float(candidate.right)-width*0.5-0.3
				if first>last: continue
				var resolved := clampf(wanted,first,last)
				var distance := absf(resolved-wanted)
				if distance<best:
					best=distance
					x=resolved
					surface=candidate
			if surface.is_empty():
				failures += 1
				continue
			var y := float(surface.height)
			var center := y+height*0.5
			if slot.anchor in ["facade","under_surface"]: center=y-0.25-height*0.5
			if slot.anchor=="street_below": center=y-8.0+height*0.5
			if int(stage_info.order)==2 and y<8.0: failures += 1
			if slot.asset=="desert_mine_entrance" and (int(stage_info.order)!=9 or float(slot.fraction)!=1.0 or absf(x-float(stage.goal.pos[0]))>0.01): failures += 1
			placements.append({"asset":slot.asset,"section":slot.section,"fraction":slot.fraction,"world_center":[x,center,slot.z],"supported_floor_y":y,"surface":surface.index,"width":width,"height":height,"shift_to_safe_surface":x-wanted,"anchor":slot.anchor,"note":slot.note,"status":"planned_not_installed","clip_to_physical_floor_pieces":slot.anchor in ["facade","under_surface"]})
			count += 1
		output.append({"order":stage_info.order,"name":stage_info.name,"placements":placements})
	if plan.ability_progression.freeze_back!=Layout.ABILITY_PHASE.amber or plan.ability_progression.electric_run!=Layout.ABILITY_PHASE.dash or plan.ability_progression.rupture_back!=Layout.ABILITY_PHASE.rupture: failures += 1
	if output.size()!=10: failures += 1
	var args := OS.get_cmdline_user_args()
	var path: String=args[0] if not args.is_empty() else "/tmp/desert_asset_positions.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: failures += 1
	else: file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"failures":failures,"positions":count,"status":"planned_not_installed","stages":output},"\t"))
	print("ASSET_PLACEMENTS stages=",output.size()," positions=",count," failures=",failures)
	quit.call_deferred(1 if failures else 0)
