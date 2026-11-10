extends SceneTree
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok: bool,what: String)->void:
 print(("PASS " if ok else "FAIL ")+what)
 if not ok:failures+=1
func run()->void:
 var model=preload("res://scripts/desert/malagueta/model.gd").new();root.add_child(model)
 var entry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/desert_enemies.json")).enemies.malagueta
 model.load_entry(entry)
 check(model._model_root.scene_file_path.ends_with("/Idle.fbx"),"Idle is the only visible model")
 check(model._meshes.size()==1,"no meshes from motion-only FBXs")
 var material: StandardMaterial3D=model._meshes[0].get_active_material(0)
 check(material.albedo_texture!=null and material.albedo_texture.resource_path.ends_with("/Idle_0.png"),"original Idle uniform texture retained")
 for key: String in model.MOTIONS:
  check(model.has_animation(key),"imported "+key)
  var clip: Animation=model._anim_player.get_animation(key)
  var valid:=true
  for track in clip.get_track_count():
   var path:=clip.track_get_path(track)
   valid=valid and path.get_subname_count()==1 and model._skeleton.find_bone(path.get_subname(0))>=0
  check(valid,"all tracks resolve on Idle rig: "+key)
  model.play_animation(key,key in ["base","carry","dizzy","retreat"],0.0)
  for step in range(9):
   model._anim_player.seek(clip.length*step/9.0,true);model._skeleton.force_update_all_bone_transforms()
   for bone in model._skeleton.get_bone_count():
    var point: Vector3=model.to_local(model._skeleton.to_global(model._skeleton.get_bone_global_pose(bone).origin))
    if not point.is_finite() or point.length()>5.0:valid=false
  check(valid,"sampled deformation remains bounded: "+key)
 print("BOSS_MOTIONS failures=",failures," rejected legacy-only tracks=",model.rejected_tracks)
 model.free();quit(1 if failures else 0)
