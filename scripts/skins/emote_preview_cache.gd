extends RefCounted
## Miniaturas do próprio modelo 3D. Um palco temporário captura três poses;
## os cartões reutilizam texturas estáticas, sem três avatares animados extras.
var _cache: Dictionary = {}

func capture(host: Control,entry: Dictionary,watch: Control,dance := false) -> Dictionary:
	var id := str(entry.id)+("_dance" if dance else "")
	var emotes: Array=[{"id":"dance","animation":"dance_preview"}] if dance else CharacterCatalog.emotes_for(entry)
	if _cache.get(id,{}).size()==emotes.size(): return _cache[id]
	if DisplayServer.get_name()=="headless": return {}
	var stage: LobbyStage=preload("res://scenes/lobby/lobby_stage.tscn").instantiate()
	stage.position=Vector2(-4000,0)
	stage.size=Vector2(192,240)
	host.add_child(stage)
	stage.apply_profile("medio")
	stage.show_character(entry)
	if dance: preload("res://scripts/skins/dance_preview.gd").install(stage.character)
	stage.set_zoom(1.08)
	var viewport: SubViewport=stage.get_node("Viewport")
	viewport.size=Vector2i(384,480)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	if not _cache.has(id): _cache[id]={}
	var textures: Dictionary=_cache[id]
	for emote: Dictionary in emotes:
		if not is_instance_valid(watch) or watch.is_queued_for_deletion() or not watch.is_visible_in_tree(): break
		if textures.has(emote.id): continue
		var clip := StringName(emote.animation)
		stage.character.set_pose(clip,minf(1.2,stage.character.animation_length(clip)*0.45))
		_fit_pose(stage)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if not is_instance_valid(stage): return textures
		var image := viewport.get_texture().get_image()
		if image!=null and not image.is_empty() and image.get_used_rect().has_area():
			image.generate_mipmaps()
			textures[emote.id]=ImageTexture.create_from_image(image)
	_cache[id]=textures
	if is_instance_valid(stage): stage.queue_free()
	return textures


func _fit_pose(stage: LobbyStage) -> void:
	var skeleton: Skeleton3D=stage.character.get("_skeleton")
	if skeleton==null: return
	skeleton.force_update_all_bone_transforms()
	var low := Vector3(INF,INF,INF)
	var high := Vector3(-INF,-INF,-INF)
	for bone in skeleton.get_bone_count():
		var point := stage.character.to_local(skeleton.to_global(skeleton.get_bone_global_pose(bone).origin))
		low=low.min(point);high=high.max(point)
	if not is_finite(low.y): return
	var height := maxf(high.y-low.y,float(stage.character.get_framing().height))*1.2
	var width := maxf(high.x-low.x,0.8)*1.2
	stage._target_y=(high.y+low.y)*0.5
	stage._base_distance=maxf(height,width/0.8)/(2.0*tan(deg_to_rad(LobbyStage.CAMERA_FOV*0.5)))
	stage.set_zoom(1.0)
