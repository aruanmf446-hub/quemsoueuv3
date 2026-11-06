extends RefCounted
## Dancinha original, demonstrativa. Não é extraída de vídeo ou vendida.
## Usa as trilhas e a pose do FBX original; só a instância da prévia recebe o clipe.
const ALIAS := &"dance_preview"

static func install(slot: CharacterSlot) -> bool:
	if slot.has_animation(ALIAS): return true
	if not slot.has_animation(&"base"): return false
	var player: AnimationPlayer=slot.get("_anim_player")
	var source := player.get_animation(&"base")
	var clip := Animation.new()
	clip.length=4.0
	for track in source.get_track_count():
		var kind := source.track_get_type(track)
		if kind not in [Animation.TYPE_ROTATION_3D,Animation.TYPE_POSITION_3D,Animation.TYPE_SCALE_3D]: continue
		var target := clip.add_track(kind)
		var path := source.track_get_path(track)
		clip.track_set_path(target,path)
		if kind==Animation.TYPE_ROTATION_3D:
			var base := source.rotation_track_interpolate(track,0.0)
			for frame in 49:
				var t := frame/12.0
				clip.rotation_track_insert_key(target,t,(base*Quaternion.from_euler(_offset(str(path),t))).normalized())
		elif kind==Animation.TYPE_POSITION_3D:
			var value := source.position_track_interpolate(track,0.0)
			clip.position_track_insert_key(target,0.0,value)
			clip.position_track_insert_key(target,4.0,value)
		else:
			var value := source.scale_track_interpolate(track,0.0)
			clip.scale_track_insert_key(target,0.0,value)
			clip.scale_track_insert_key(target,4.0,value)
	player.get_animation_library(&"").add_animation(ALIAS,clip)
	return true


static func _offset(path: String,t: float) -> Vector3:
	var bone := path.get_slice(":",path.get_slice_count(":")-1).to_lower()
	var beat := TAU*2.0*t
	var sway := sin(beat*0.5)
	var side := 1.0 if "left" in bone else -1.0
	var angles := Vector3.ZERO
	if bone.ends_with("hips"): angles=Vector3(0,8*sway,4*sway)
	elif "spine" in bone: angles=Vector3(3*cos(beat),4*sway,-4*sway)
	elif bone.ends_with("head"): angles=Vector3(2*sin(beat),0,3*sway)
	elif bone.ends_with("forearm"): angles=Vector3(12+12*sin(beat+side*PI*0.5),0,0)
	elif bone.ends_with("arm"): angles=Vector3(18*sin(beat+side*PI*0.5),0,side*12*sway)
	elif bone.ends_with("upleg"): angles=Vector3(side*7*sin(beat),0,side*2*sway)
	elif bone.ends_with("leg"): angles=Vector3(4+4*sin(beat+side*PI*0.5),0,0)
	return angles*PI/180.0
