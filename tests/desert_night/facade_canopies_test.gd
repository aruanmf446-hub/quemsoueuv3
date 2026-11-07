extends SceneTree
## A lona é escolhida pela arte, nunca pela existência prévia de um colisor.
const Landings=preload("res://scripts/desert/t15d/prop_landings.gd")
var checks:=0
var failures:=0
var phase: Node3D
var output:=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1
 print(("PASS " if ok else "FAIL ")+label)
func ticks(n: int) -> void:
 for i in n:await physics_frame
func release() -> void:
 for action in ["jump","move_left","move_right"]:Input.action_release(action)
func snap(label: String) -> void:
 if output.is_empty():return
 paused=true
 phase._player._model.show()
 for i in 3:phase._follow_camera(1.0)
 phase._scenery.follow(phase._camera,phase._player.position.x)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_jpg(output+"/"+label+".jpg",0.94)
 paused=false
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
  var player: CharacterBody3D=phase._player
  player._invulnerable=999
  for i in 2400:
   if phase._build_queue.is_empty():break
   phase._process(0)
  for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
  var arts: Array=get_nodes_in_group("kingdom_art").filter(func(n: Node) -> bool:return n.get_meta("asset_id","") in ["capital_house","capital_merchant","capital_balcony_house"] and n.position.z>=-12.5 and n.position.z< -8 and n.position.x>=float(phase._phase.player_spawn[0])+1)
  arts.sort_custom(func(a: Node3D,b: Node3D) -> bool:return a.position.x<b.position.x)
  if order==2:
   check(arts.all(func(n: Node3D) -> bool:return n.position.y<float(phase._phase.player_spawn[1])-1),"fase2: lonas da rua inferior permanecem abaixo da rota dos tetos")
   check(not get_nodes_in_group("playable_house_roofs").is_empty(),"fase2: tetos reais continuam sendo o caminho")
   arts.clear()
  var seen: Dictionary={}
  for art: Sprite3D in arts:
   var id:=str(art.get_meta("asset_id"))
   if seen.has(id):continue
   seen[id]=true
   var roofs:=get_nodes_in_group(Landings.GROUP).filter(func(n: Node) -> bool:return n.get_meta("canopy",false) and n.get_meta("prop_art",NodePath())==art.get_path())
   check(roofs.size()==1,"fase%d %s: lona visível da fachada tem exatamente um apoio" % [order,id])
   if roofs.is_empty():continue
   var roof: StaticBody3D=roofs[0]
   var top: float=roof.get_meta("one_way_top")
   var base: float=roof.get_meta("source_floor")
   var span: Vector2=roof.get_meta("landing_span")
   print("CANOPY ",order," ",id," rise=",top-base," x=",roof.position.x)
   release()
   player.position=Vector3(roof.position.x,base+0.04,0)
   player.velocity=Vector3.ZERO
   await ticks(15)
   Input.action_press("jump")
   await ticks(2)
   Input.action_release("jump")
   await ticks(20)
   Input.action_press("jump")
   await ticks(2)
   Input.action_release("jump")
   var crossed:=false
   var landed:=false
   var ceiling:=false
   var peak: float=player.position.y
   for i in 120:
    await physics_frame
    peak=maxf(peak,player.position.y)
    crossed=crossed or player.position.y>=top
    ceiling=ceiling or player.is_on_ceiling()
    if crossed and player.is_on_floor() and absf(player.position.y-top)<0.04:
     landed=true
     break
   check(not ceiling,"fase%d %s: salto de baixo não bate a cabeça" % [order,id])
   check(landed,"fase%d %s: pousa na lona sem atravessar (pico %.2f, lona %.2f)" % [order,id,peak-base,top-base])
   await ticks(12)
   if order==1:await snap(id+"_em_cima_da_lona")
   var x: float=player.position.x
   Input.action_press("move_right")
   await ticks(8)
   Input.action_release("move_right")
   await ticks(3)
   check(player.position.x>x+0.15 and player.is_on_floor() and absf(player.position.y-top)<0.04,"fase%d %s: anda apoiado no tecido (dx=%.3f, y=%.3f, topo=%.3f, apoio=%s)" % [order,id,player.position.x-x,player.position.y,top,player.is_on_floor()])
   Input.action_press("jump")
   await ticks(4)
   Input.action_release("jump")
   check(player.position.y>top+0.3,"fase%d %s: salta novamente da lona" % [order,id])
   release()
  check(order not in [1,3,8] or not seen.is_empty(),"fase%d: fachadas presentes na rota examinadas pela arte" % order)
  phase.free()
  await process_frame
 check(get_nodes_in_group(Landings.GROUP).is_empty(),"sair remove os apoios das lonas")
 print("FACADE_CANOPIES checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)
