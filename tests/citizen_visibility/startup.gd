extends SceneTree
## Entrada real das dez fases: sem teleporte, sem forçar a fila ou desativar streaming.
var failures:=0
var checks:=0
var output:=""
func _initialize() -> void:call_deferred("run")
func run() -> void:
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 var args:=OS.get_cmdline_user_args()
 if args.size()>0:
  output=args[0]
  DirAccess.make_dir_recursive_absolute(output)
  var dims: PackedStringArray=(args[1] if args.size()>1 else "844x390").split("x")
  root.size=Vector2i(int(dims[0]),int(dims[1]))
 var orders: Array=range(1,11)
 if args.size()>2:
  orders=[]
  for value in args[2].split(","):orders.append(clampi(int(value),1,10))
 for order: int in orders:
  preload("res://scripts/desert/t15d/campaign_run.gd").save("",preload("res://scripts/desert/t15d/campaign_run.gd").fresh(order),"start")
  var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
  root.add_child(phase)
  for i in 60:await physics_frame
  var species: Dictionary={}
  var count:=0
  for group in get_nodes_in_group("campaign_background_people"):
   for sprite in group.get_children():
    if sprite is Sprite3D and sprite.is_visible_in_tree() and phase._camera.is_position_in_frustum(sprite.global_position):
     species[str(sprite.get_meta("species"))]=true
     count+=1
  var ok: bool=species.has("human") and species.has("cactus")
  checks+=1
  if not ok:failures+=1
  print(("PASS " if ok else "FAIL ")+"NPC_ENTRY phase=%02d visible=%d species=%s player_x=%.2f queue=%d" % [order,count,species.keys(),phase._player.position.x,phase._build_queue.size()])
  if not output.is_empty():
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_jpg(output+"/phase_%02d.jpg" % order,0.94)
  phase.free()
  await process_frame
 await preload("res://tests/common/audio_cleanup.gd").finish(self)
 print("NPC_ENTRY checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)
