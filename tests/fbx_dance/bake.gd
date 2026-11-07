extends SceneTree
const SOURCE="res://tests/fbx_dance/source.fbx"
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if not ResourceLoader.exists(SOURCE):
  print("SKIP FBX dance: prepare the external sample in an isolated stage first.")
  quit();return
 var scene: Node=load(SOURCE).instantiate();root.add_child(scene)
 var source: Skeleton3D=scene.find_children("*","Skeleton3D",true,false)[0]
 var player: AnimationPlayer=scene.find_children("*","AnimationPlayer",true,false)[0]
 var clip_name := ""
 for name: StringName in player.get_animation_list():
  print("SOURCE_CLIP ",name," seconds=",player.get_animation(name).length)
  if clip_name.is_empty() or player.get_animation(name).length>player.get_animation(clip_name).length:clip_name=name
 var duration := minf(player.get_animation(clip_name).length,12.0)
 var report := {"source":SOURCE,"clip":clip_name,"source_duration":player.get_animation(clip_name).length,"test_duration":duration,"avatars":[]}
 DirAccess.make_dir_recursive_absolute("res://tests/fbx_dance/generated")
 for entry: Dictionary in CharacterCatalog.load_entries():
  var slot := CharacterSlot.new();root.add_child(slot);slot.load_entry(entry)
  var target: Skeleton3D=slot.get("_skeleton")
  target.reset_bone_poses();target.force_update_all_bone_transforms()
  var target_player: AnimationPlayer=slot.get("_anim_player")
  target_player.stop()
  var skeleton_path := str(target_player.get_node(target_player.root_node).get_path_to(target))
  var result := Animation.new();result.length=duration;result.loop_mode=Animation.LOOP_LINEAR
  var rotation_tracks: Array[int]=[];var mapping: Array[int]=[]
  var feet: Array[int]=[];var floor_y := INF
  for bone in target.get_bone_count():
   var name := target.get_bone_name(bone)
   mapping.append(source.find_bone(name))
   var track := result.add_track(Animation.TYPE_ROTATION_3D)
   result.track_set_path(track,NodePath(skeleton_path+":"+name));rotation_tracks.append(track)
   if name!="mixamorig_Hips":
    var position_track := result.add_track(Animation.TYPE_POSITION_3D)
    result.track_set_path(position_track,NodePath(skeleton_path+":"+name))
    result.position_track_insert_key(position_track,0.0,target.get_bone_rest(bone).origin)
   var scale_track := result.add_track(Animation.TYPE_SCALE_3D)
   result.track_set_path(scale_track,NodePath(skeleton_path+":"+name))
   result.scale_track_insert_key(scale_track,0.0,target.get_bone_rest(bone).basis.get_scale())
   if name in ["mixamorig_LeftFoot","mixamorig_RightFoot","mixamorig_LeftToeBase","mixamorig_RightToeBase"]:
    feet.append(bone);floor_y=minf(floor_y,target.get_bone_global_rest(bone).origin.y)
  var hips := target.find_bone("mixamorig_Hips");var source_hips := source.find_bone("mixamorig_Hips")
  assert(hips>=0 and source_hips>=0)
  var hip_rest := target.get_bone_rest(hips).origin
  var scale_ratio := hip_rest.y/source.get_bone_rest(source_hips).origin.y
  var hip_track := result.add_track(Animation.TYPE_POSITION_3D)
  result.track_set_path(hip_track,NodePath(skeleton_path+":"+target.get_bone_name(hips)))
  player.play(clip_name)
  var max_floor_error := 0.0
  var low_bounds := Vector3(-0.5,0,-0.5)
  var high_bounds := Vector3(0.5,float(entry.height),0.5)
  for frame in int(ceil(duration*30))+1:
   var time := minf(float(frame)/30.0,duration)
   player.seek(time,true);source.force_update_all_bone_transforms()
   var desired: Array[Quaternion]=[]
   for bone in target.get_bone_count():
    var global_rotation := target.get_bone_global_rest(bone).basis.orthonormalized().get_rotation_quaternion()
    var from := mapping[bone]
    if from>=0:
     var source_pose := source.get_bone_global_pose(from).basis.orthonormalized().get_rotation_quaternion()
     var source_rest := source.get_bone_global_rest(from).basis.orthonormalized().get_rotation_quaternion()
     global_rotation=(source_pose*source_rest.inverse()*global_rotation).normalized()
    desired.append(global_rotation)
    var parent := target.get_bone_parent(bone)
    var local := global_rotation if parent<0 else (desired[parent].inverse()*global_rotation).normalized()
    target.set_bone_pose_rotation(bone,local)
    result.rotation_track_insert_key(rotation_tracks[bone],time,local)
   var hip := hip_rest
   hip.y+=(source.get_bone_pose_position(source_hips).y-source.get_bone_rest(source_hips).origin.y)*scale_ratio
   target.set_bone_pose_position(hips,hip);target.force_update_all_bone_transforms()
   var low := INF
   for foot in feet:low=minf(low,target.get_bone_global_pose(foot).origin.y)
   if is_finite(low):hip.y+=floor_y-low
   target.set_bone_pose_position(hips,hip);target.force_update_all_bone_transforms()
   var corrected := INF
   for foot in feet:corrected=minf(corrected,target.get_bone_global_pose(foot).origin.y)
   max_floor_error=maxf(max_floor_error,absf(corrected-floor_y))
   result.position_track_insert_key(hip_track,time,hip)
   for bone in target.get_bone_count():
    var point := slot.to_local(target.to_global(target.get_bone_global_pose(bone).origin))
    low_bounds=low_bounds.min(point);high_bounds=high_bounds.max(point)
  var path := "res://tests/fbx_dance/generated/"+str(entry.id)+".res"
  assert(ResourceSaver.save(result,path)==OK)
  var matched := mapping.filter(func(i:int)->bool:return i>=0).size()
  assert(matched>=30 and max_floor_error<0.00001)
  report.avatars.append({"id":entry.id,"bones_matched":matched,"bones":target.get_bone_count(),"tracks":result.get_track_count(),"ground_error_local":max_floor_error,"path":path,"bounds_min":[low_bounds.x,low_bounds.y,low_bounds.z],"bounds_max":[high_bounds.x,high_bounds.y,high_bounds.z]})
  print("BAKED ",entry.id," ",matched,"/",target.get_bone_count()," ground_error=",max_floor_error)
  slot.free()
 var file := FileAccess.open("res://tests/fbx_dance/generated/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
 scene.free();print("FBX_BAKE failures=0 avatars=",report.avatars.size());quit()
