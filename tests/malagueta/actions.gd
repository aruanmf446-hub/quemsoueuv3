extends SceneTree
const Chemical=preload("res://scripts/desert/malagueta/chemical.gd")
var failures:=0
func _initialize()->void:call_deferred("run")
func tick(n: int)->void:
 for i in n:await physics_frame
func check(ok: bool,what: String)->void:
 print(("PASS " if ok else "FAIL ")+what)
 if not ok:failures+=1
func run()->void:
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 var phase=load("res://scenes/desert/phase_10.tscn").instantiate();root.add_child(phase);current_scene=phase
 phase._player._invulnerable=999;phase.encounter.suspended=true
 await tick(4)
 var boss: Node3D=phase._boss
 check(boss._model.current_clip()=="base","actual boss starts with Idle")
 var skeleton: Skeleton3D=boss._model._skeleton
 var index: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_RightHandIndex2")).origin)
 var thumb: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_RightHandThumb2")).origin)
 check(boss._held.to_global(Vector3(0,0.16,0)).distance_to((index+thumb)*0.5)<0.04,"flask neck stays between index and thumb")
 phase._launch_chemical("red");await tick(3)
 check(boss.throwing() and boss._model.current_clip()=="throw","attack request plays Throw")
 var projectiles=phase.arena.get_children().filter(func(n: Node)->bool:return n is Chemical)
 check(projectiles.size()==1 and not projectiles[0]._visual.visible,"flask stays in hand during windup")
 await tick(42)
 check(is_instance_valid(projectiles[0]) and projectiles[0]._visual.visible,"flask releases after actual windup")
 boss.take_damage(1);await tick(2)
 check(boss._model.current_clip()=="hurt","hit plays Standing Block End")
 await tick(40)
 phase._launch_chemical("green");await tick(3)
 boss.take_damage(1);await tick(3)
 check(not phase.arena.get_children().any(func(n: Node)->bool:return n is Chemical and n.kind=="green"),"hit interrupts a flask not yet released")
 phase.encounter.suspended=false;phase.encounter.hit(4);await tick(2)
 check(boss.stunned and boss._model.current_clip()=="dizzy","stun plays Dizzy Idle")
 check(not boss._held.visible,"stunned boss has no floating bottle")
 phase.encounter.tick(6);phase.encounter.suspended=true;await tick(2)
 check(not boss.stunned,"stun expiry restores movement")
 phase._player.position=Vector3(7.8,8.85,0);boss._time=3.5
 await tick(4)
 check(boss._model.current_clip()=="retreat","near player selects Strut Walking")
 phase._player.position=Vector3(-10.5,0.1,0);boss._time=3.5
 await tick(4)
 check(boss._model.current_clip()=="carry","distant player selects Standing Walk Forward")
 boss.defeat();await tick(2)
 check(boss._model.current_clip()=="morte","defeat preserves adapted original death")
 print("BOSS_ACTIONS failures=",failures)
 phase.queue_free();await tick(4);quit(1 if failures else 0)
