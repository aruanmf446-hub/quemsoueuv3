extends "res://scripts/desert/t15d/actor_slot.gd"
## One visible rig/material set from Idle. Motion-only FBXs contribute bone tracks only.
const ROOT := "res://assets/characters/malagueta/"
const MOTIONS := {"base":"Idle.fbx","throw":"Throw.fbx","carry":"Standing Walk Forward.fbx","hurt":"Standing Block End.fbx","dizzy":"Dizzy Idle.fbx","retreat":"Strut Walking.fbx","morte":"morte.fbx"}
var rejected_tracks := 0
func load_entry(entry: Dictionary)->void:
 var spec:=entry.duplicate(true)
 spec.id="malagueta_arena_idle_rig"
 spec.model=ROOT+"Idle.fbx"
 spec.idle="base"
 spec.animations={}
 for key: String in MOTIONS:spec.animations[key]=ROOT+MOTIONS[key]
 super.load_entry(spec)
 if _anim_player==null or _skeleton==null:return
 var base_y:=_model_root.position.y
 for key: String in MOTIONS:
  if not _anim_player.has_animation(key):continue
  _anim_player.play(key);_anim_player.seek(0.0,true)
  _skeleton.force_update_all_bone_transforms()
  var feet:=INF
  for bone in _skeleton.get_bone_count():
   if "ToeBase" in str(_skeleton.get_bone_name(bone)) or str(_skeleton.get_bone_name(bone)).ends_with("Foot"):
    feet=minf(feet,to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(bone).origin)).y)
  _ground_offsets[key]=base_y+0.035-feet if is_finite(feet) else base_y
 _model_root.position.y=float(_ground_offsets.get("base",base_y))
 play_animation("base",true,0.0)
func _merge_animations(entry: Dictionary)->void:
 var library:=AnimationLibrary.new()
 for key: String in MOTIONS:
  var temporary: Node
  var source_skeleton: Skeleton3D
  var source: Animation
  if key=="base":
   source=_first_animation_of(_anim_player)
   source_skeleton=_skeleton
  else:
   var packed:=prepared_scene(ROOT+MOTIONS[key])
   if packed==null:push_error("Missing boss motion: "+key);continue
   temporary=packed.instantiate()
   source_skeleton=_find_node_of_type(temporary,Skeleton3D) as Skeleton3D
   var player:=_find_node_of_type(temporary,AnimationPlayer) as AnimationPlayer
   if player!=null:source=_first_animation_of(player)
  if source!=null and source_skeleton!=null:
   var clip:=_adapt(source,source_skeleton)
   if clip.get_track_count()>0:library.add_animation(key,clip)
  if temporary!=null:temporary.free()
 if _anim_player.has_animation_library(&""):_anim_player.remove_animation_library(&"")
 _anim_player.add_animation_library(&"",library)
func _adapt(source: Animation,from: Skeleton3D)->Animation:
 var clip:=source.duplicate(true) as Animation
 var root:=_anim_player.get_node(_anim_player.root_node)
 var skeleton_path:=str(root.get_path_to(_skeleton))
 for track in range(clip.get_track_count()-1,-1,-1):
  var type:=clip.track_get_type(track)
  var path:=clip.track_get_path(track)
  if type not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D] or path.get_subname_count()!=1:
   clip.remove_track(track);continue
  var name:=str(path.get_subname(0))
  var target:=_skeleton.find_bone(name)
  var original:=from.find_bone(name)
  if target<0 or original<0:
   rejected_tracks+=1;clip.remove_track(track);continue
  var a:=from.get_bone_rest(original)
  var b:=_skeleton.get_bone_rest(target)
  clip.track_set_path(track,NodePath(skeleton_path+":"+name))
  var ratio:=b.origin.length()/a.origin.length() if a.origin.length()>0.00001 else 1.0
  for key in clip.track_get_key_count(track):
   if type==Animation.TYPE_POSITION_3D:
    var value: Vector3=clip.track_get_key_value(track,key)
    value=b.origin+(value-a.origin)*ratio
    if "Hips" in name:value.x=b.origin.x;value.z=b.origin.z
    clip.track_set_key_value(track,key,value)
   elif type==Animation.TYPE_ROTATION_3D:
    var value: Quaternion=clip.track_get_key_value(track,key)
    clip.track_set_key_value(track,key,(b.basis.get_rotation_quaternion()*a.basis.get_rotation_quaternion().inverse()*value).normalized())
 clip.loop_mode=Animation.LOOP_NONE
 return clip
func clip_speed(name: StringName)->float:
 match String(name):
  "throw":return 1.4
  "hurt":return 2.6
 return 1.0
