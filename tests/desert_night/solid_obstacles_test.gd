extends SceneTree
## Aproximação por fixture. Caminhada, salto, contato e queda usam a física real.
const Layout=preload("res://scripts/desert/t15d/campaign_layout.gd")
var checks:=0
var failures:=0
var output:=""
var phase: Node3D
var player: CharacterBody3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1
 print(("PASS " if ok else "FAIL ")+label)
func ticks(n: int) -> void:
 for i in n:await physics_frame
func release() -> void:
 for action in ["move_left","move_right","jump","crouch"]:
  if InputMap.has_action(action):Input.action_release(action)
func snap(label: String) -> void:
 if output.is_empty():return
 paused=true
 player._model.show()
 for i in 3:phase._follow_camera(1.0)
 phase._scenery.follow(phase._camera,player.position.x)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_jpg(output+"/"+label+".jpg",0.94)
 paused=false
func approach(x: float,y: float) -> void:
 release()
 player.position=Vector3(x,y+0.04,0)
 player.velocity=Vector3.ZERO
 player._invulnerable=0
 await ticks(15)
func leap(direction: String,left: float,right: float,top: float) -> bool:
 Input.action_press(direction)
 Input.action_press("jump")
 await ticks(2)
 Input.action_release("jump")
 var landed:=false
 for i in 110:
  await physics_frame
  if player.is_on_floor() and absf(player.position.y-top)<0.04 and player.position.x>left and player.position.x<right:
   landed=true
   break
 Input.action_release(direction)
 await ticks(18)
 return landed
func run() -> void:
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 var args:=OS.get_cmdline_user_args()
 var orders: Array=range(1,11)
 if args.size()>=2:
  output=args[0]
  DirAccess.make_dir_recursive_absolute(output)
  var size:=args[1].split("x")
  root.size=Vector2i(int(size[0]),int(size[1]))
  orders=[1]
 for order in orders:
  phase=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
  root.add_child(phase)
  current_scene=phase
  phase.set_physics_process(false)
  player=phase._player
  var routes: Array=phase._phase.platforms.filter(func(p: Dictionary) -> bool:return p.get("parkour_route",false))
  if order==2:
   check(routes.is_empty(),"fase2 conserva a rota pelos tetos sem obstáculo sobreposto")
   phase.free()
   await process_frame
   continue
  check(not routes.is_empty(),"fase%d tem obstáculo de parkour" % order)
  var spec: Dictionary=routes[0]
  var left: float=spec.span_start
  var right: float=spec.span_end
  var base: float=spec.surface_top
  var top: float=spec.pos[1]+spec.size[1]*0.5
  player.position=Vector3(left-1.4,base+0.04,0)
  phase._stream_world((left+right)*0.5,true)
  for i in 2400:
   if phase._build_queue.is_empty():break
   phase._process(0)
  for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
  var bodies: Array=get_nodes_in_group("campaign_solid_obstacles").filter(func(n: Node) -> bool:return n.get_meta("obstacle_id","")==str(spec.id))
  check(not bodies.is_empty() and bodies.all(func(n: Node) -> bool:return not n.is_in_group("campaign_one_way") and absf(n.get_child(0).shape.size.y-(top-base))<0.001),"fase%d tem colisão inteira do chão ao topo" % order)
  await approach(left-1.4,base)
  Input.action_press("move_right")
  await ticks(65)
  check(player.position.x<=left-0.25 and absf(player.position.y-base)<0.08,"fase%d bloqueia caminhada pela esquerda sem atravessar a arte" % order)
  await snap("01_lateral_solida")
  Input.action_press("crouch")
  await ticks(20)
  check(player.position.x<=left-0.25,"fase%d agachar não atravessa o volume sólido" % order)
  release()
  await ticks(5)
  check(await leap("move_right",left,right,top),"fase%d salto real pousa no topo pela esquerda" % order)
  await snap("02_em_cima_do_obstaculo")
  var start: float=player.position.x
  Input.action_press("move_right")
  await ticks(8)
  Input.action_release("move_right")
  check(player.position.x>start+0.2 and player.is_on_floor() and absf(player.position.y-top)<0.04,"fase%d corre sobre o obstáculo apoiado" % order)
  await approach(right+1.4,base)
  Input.action_press("move_left")
  await ticks(65)
  check(player.position.x>=right+0.25,"fase%d bloqueia caminhada pela direita" % order)
  Input.action_release("move_left")
  check(await leap("move_left",left,right,top),"fase%d salto real pousa no topo pela direita" % order)
  await snap("03_salto_vindo_da_direita")
  Input.action_press("move_left")
  for i in 150:
   await physics_frame
   if player.position.x<left-0.6:break
  Input.action_release("move_left")
  await ticks(30)
  check(player.is_on_floor() and absf(player.position.y-base)<0.06 and not player.is_dead,"fase%d desce pela borda sem grudar ou cair através do piso" % order)
  if order==1:
   phase._spawn_enemy(phase._world,{"id":"qa.solid.npc","pos":[(left+right)*0.5,base+0.02,0],"patrol":[left-2.0,right+2.0],"troop":true})
   var enemy: CharacterBody3D=phase._enemy_live.get("qa.solid.npc")
   await ticks(20)
   check(is_instance_valid(enemy) and (enemy.position.y>=top-0.04 or enemy.position.x<left-0.3 or enemy.position.x>right+0.3),"soldado não permanece dentro do volume do obstáculo")
   phase._stream_world(right+512,true)
   await ticks(3)
   check(get_nodes_in_group("campaign_solid_obstacles").all(func(n: Node) -> bool:return n.get_meta("obstacle_id","")!=str(spec.id)),"descarregar trecho remove a colisão do obstáculo")
   phase._stream_world((left+right)*0.5,true)
   await ticks(3)
   var restored:=get_nodes_in_group("campaign_solid_obstacles").filter(func(n: Node) -> bool:return n.get_meta("obstacle_id","")==str(spec.id))
   check(restored.size()==bodies.size() and restored.all(func(n: Node) -> bool:return not n.is_in_group("campaign_one_way") and absf(n.get_child(0).shape.size.y-(top-base))<0.001),"retornar ao trecho recria o corpo inteiro sem duplicar")
  release()
  phase.free()
  await process_frame
 check(get_nodes_in_group("campaign_solid_obstacles").is_empty(),"descarregamento remove todos os corpos sólidos")
 print("SOLID_OBSTACLES checks=%d failures=%d" % [checks,failures])
 if not output.is_empty():FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"fixture_teleport":true,"physics_jump":true,"physical_device":false},"\t"))
 quit(1 if failures else 0)
