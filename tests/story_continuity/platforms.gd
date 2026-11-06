extends SceneTree
const Supports=preload("res://scripts/desert/t15d/prop_landings.gd")
var checks:=0
var failures:=0
var output:=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
 checks+=1
 if not ok:failures+=1
 print(("PASS " if ok else "FAIL ")+text)
func ticks(n: int) -> void:
 for i in n:await physics_frame
func run() -> void:
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 var args:=OS.get_cmdline_user_args()
 var orders: Array=range(1,11)
 if args.size()>=2:
  output=args[0]
  DirAccess.make_dir_recursive_absolute(output)
  root.size=Vector2i(844,390)
  orders=[int(args[1])]
 for order in orders:
  var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
  root.add_child(phase)
  current_scene=phase
  phase.set_physics_process(false)
  var player: CharacterBody3D=phase._player
  player._invulnerable=999
  for i in 2400:
   if phase._build_queue.is_empty():break
   phase._process(0)
  for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
  if order==2:
   await ticks(15)
   check(player.is_on_floor(),"fase 2 conserva seus telhados físicos")
   Input.action_press("jump")
   await ticks(2)
   Input.action_release("jump")
   await ticks(95)
   check(player.is_on_floor(),"fase 2 salta e pousa no teto")
  else:
   var candidates:=get_nodes_in_group(Supports.GROUP).filter(func(n: Node) -> bool:return n.has_meta("source_floor") and float(n.get_meta("one_way_top"))-float(n.get_meta("source_floor"))<3.0)
   check(not candidates.is_empty(),"fase %d tem objetos próximos alcançáveis por cima" % order)
   if not candidates.is_empty():
    var ledge: Node3D=candidates[0]
    var top:=float(ledge.get_meta("one_way_top"))
    var floor_top:=float(ledge.get_meta("source_floor"))
    player.position=Vector3(ledge.position.x,floor_top+0.04,0)
    player.velocity=Vector3.ZERO
    await ticks(15)
    Input.action_press("jump")
    await ticks(2)
    Input.action_release("jump")
    var ceiling:=false
    if top-floor_top>1.4:
     await ticks(18)
     Input.action_press("jump")
     await ticks(2)
     Input.action_release("jump")
    var landed:=false
    for i in 120:
     await physics_frame
     ceiling=ceiling or player.is_on_ceiling()
     if player.is_on_floor() and player.position.y>=top-0.04:
      landed=true
      break
    check(not ceiling,"fase %d não prende a cabeça ao subir pelo objeto" % order)
    check(landed,"fase %d permite pousar por cima com salto real" % order)
    await ticks(18)
  if not output.is_empty():
   paused=true
   player._model.show()
   phase._follow_camera(1.0)
   phase._scenery.follow(phase._camera,player.position.x)
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_jpg(output+"/apoio_fase_%02d.jpg" % order,0.94)
   paused=false
  phase.free()
  await process_frame
 check(get_nodes_in_group(Supports.GROUP).is_empty(),"sair remove os apoios sem referências antigas")
 print("STORY_PLATFORMS checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)
