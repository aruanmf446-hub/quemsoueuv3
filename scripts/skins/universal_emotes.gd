extends RefCounted
## One account product, with shared or per-rig motion assets. No prices/ownership here.
const PATH := "res://data/emotes.json"

static func install(slot: CharacterSlot,key: String) -> bool:
	return install_from_catalog(slot,key,PlayerContracts.read_json(PATH))

static func install_from_catalog(slot: CharacterSlot,key: String,catalog: Dictionary) -> bool:
	if not is_instance_valid(slot) or key.is_empty(): return false
	if slot.has_animation(StringName(key)): return true
	var source := ""
	for item: Dictionary in catalog.get("items",[]):
		if item.get("animation_key")==key and item.get("scope")=="account":
			source=str(item.get("clips",{}).get(str(slot.character_id),item.get("shared_clip","")))
			break
	if not source.begins_with("res://") or not ResourceLoader.exists(source): return false
	var player: AnimationPlayer=slot.get("_anim_player")
	var skeleton: Skeleton3D=slot.get("_skeleton")
	if player==null or skeleton==null: return false
	var clip: Animation=slot.call("_extract_clip",source)
	if clip==null: return false
	var adapted := adapt(clip,player,skeleton)
	if adapted==null: return false
	if not player.has_animation_library(&""): player.add_animation_library(&"",AnimationLibrary.new())
	return player.get_animation_library(&"").add_animation(StringName(key),adapted)==OK

static func adapt(source: Animation,player: AnimationPlayer,skeleton: Skeleton3D) -> Animation:
	var root := player.get_node_or_null(player.root_node)
	if root==null: return null
	var result := source.duplicate() as Animation
	var target := str(root.get_path_to(skeleton))
	for index in range(result.get_track_count()-1,-1,-1):
		var path := result.track_get_path(index)
		# Imported motion cannot run methods/audio or move the gameplay scene root.
		if result.track_get_type(index) not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D] or path.get_subname_count()!=1:
			result.remove_track(index)
			continue
		var bone := str(path.get_subname(0))
		if skeleton.find_bone(bone)<0: return null
		result.track_set_path(index,NodePath(target+":"+bone))
	if result.get_track_count()==0: return null
	result.loop_mode=Animation.LOOP_NONE
	return result

static func universal_assets_ready(key: String) -> bool:
	var catalog := PlayerContracts.read_json(PATH)
	for item: Dictionary in catalog.get("items",[]):
		if item.get("animation_key")!=key or item.get("scope")!="account": continue
		for entry: Dictionary in CharacterCatalog.load_entries():
			var path := str(item.get("clips",{}).get(str(entry.id),item.get("shared_clip","")))
			if not path.begins_with("res://") or not ResourceLoader.exists(path): return false
		return true
	return false
