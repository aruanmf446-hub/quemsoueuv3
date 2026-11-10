extends SceneTree
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok: bool,what: String)->void:
 print(("PASS " if ok else "FAIL ")+what)
 if not ok:failures+=1
func run()->void:
 var blades: Array[Node3D]=[]
 for i in 5:
  var blade:=preload("res://scripts/desert/malagueta/moving_file.gd").new()
  blade.position=Vector3(0,1.2+i*1.9,0);blade.sweep_index=i;root.add_child(blade);blade.set_physics_process(false);blades.append(blade)
 var counts_ok:=true
 var floors_ok:=true
 var ordered:=true
 var transfer_seen:=false
 for sample in 1200:
  var time: float=sample*blades[0].cycle_duration()*2.0/1200.0
  var visible_ids: Array[int]=[]
  for i in 5:
   blades[i].elapsed=time;blades[i]._physics_process(0.0)
   if blades[i].visible:visible_ids.append(i)
   if blades[i].visible!=(blades[i].collision_layer==1):floors_ok=false
  if visible_ids.size()>2:counts_ok=false
  if visible_ids.size()==2:
   transfer_seen=true
   if visible_ids[1]!=visible_ids[0]+1:ordered=false
 check(counts_ok and transfer_seen,"one saw, with only two consecutive saws during handoff")
 check(floors_ok,"waiting saws have neither a visible mesh nor an invisible floor")
 check(ordered,"handoffs follow the ascending route")
 for i in 4:
  var current=blades[i];var next=blades[i+1]
  var when: float=next.entry_interval()*(i+1)+next.handoff_seconds*0.5
  current.elapsed=when;next.elapsed=when
  var a: Vector3=current.future_position(0);var b: Vector3=next.future_position(0)
  check(absf(a.x-b.x)<0.01 and absf(a.x)<11,"handoff %d meets inside the walls"%i)
  var cutting_bottom:=INF
  for area in next._danger_areas:
   var shape: CollisionShape3D=area.get_child(0)
   cutting_bottom=minf(cutting_bottom,b.y+shape.position.y-shape.shape.size.y*0.5)
  check(cutting_bottom>a.y+SidePlayer.STAND_HEIGHT+0.025,"upper cutting edge clears the standing player %d"%i)
 for blade in blades:blade.queue_free()
 await process_frame
 print("HANDOFF_SEQUENCE failures=",failures)
 quit(1 if failures else 0)
