extends SceneTree
## Retoma saves locais reais em todos os checkpoints; não força streaming nem teleporta o ator.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 var run=preload("res://scripts/desert/t15d/campaign_run.gd")
 var layout=preload("res://scripts/desert/t15d/campaign_layout.gd")
 var failures:=0
 var checks:=0
 for order in range(1,11):
  var stage: Dictionary=layout.build(order)
  for checkpoint in range(7):
   var saved: Dictionary=run.fresh(order)
   saved.checkpoint=checkpoint
   saved.position=[stage.checkpoints[checkpoint].pos[0],stage.checkpoints[checkpoint].pos[1]]
   run.save("",saved,"start")
   var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
   root.add_child(phase)
   for i in 60:await physics_frame
   var species: Dictionary={}
   for group in get_nodes_in_group("campaign_background_people"):
    for sprite in group.get_children():
     if sprite is Sprite3D and sprite.is_visible_in_tree() and phase._camera.is_position_in_frustum(sprite.global_position):species[str(sprite.get_meta("species"))]=true
   var ok: bool=species.has("human") and species.has("cactus") and absf(phase._player.position.x-float(saved.position[0]))<0.1
   checks+=1
   if not ok:failures+=1
   print(("PASS " if ok else "FAIL ")+"NPC_RESUME phase=%02d checkpoint=%d species=%s x=%.2f" % [order,checkpoint,species.keys(),phase._player.position.x])
   phase.free()
   await process_frame
 await preload("res://tests/common/audio_cleanup.gd").finish(self)
 print("NPC_RESUME checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)
