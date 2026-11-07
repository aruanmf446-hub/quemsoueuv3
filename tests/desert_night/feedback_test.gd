extends SceneTree
## Teclas reais, contato de lona, patrulha e efeitos. Reposicionamento de início explícito.
const Layout=preload("res://scripts/desert/t15d/campaign_layout.gd")
const Run=preload("res://scripts/desert/t15d/campaign_run.gd")
var phase: Node3D
var checks:=0
var failures:=0
var output:=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1
 print(("PASS " if ok else "FAIL ")+label)
func ticks(n: int) -> void:
 for i in n:await physics_frame
func key(code: Key,pressed: bool) -> void:
 var event:=InputEventKey.new()
 event.physical_keycode=code
 event.keycode=code
 event.shift_pressed=code==KEY_SHIFT and pressed
 event.pressed=pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 await process_frame
 await ticks(2)
func shot(label: String) -> void:
 if output.is_empty():return
 paused=true
 phase._player._model.show()
 for i in 3:phase._follow_camera(1.0)
 phase._scenery.follow(phase._camera,phase._player.position.x)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_jpg(output+"/"+label+".jpg",0.94)
 paused=false
func drain() -> void:
 for i in 2400:
  if phase._build_queue.is_empty():break
  phase._process(0)
 for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
func start(order: int) -> void:
 Run.save("",Run.fresh(order),"start")
 phase=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
 root.add_child(phase)
 phase.set_physics_process(false)
 phase._player._invulnerable=999
 drain()
 await ticks(20)
func run() -> void:
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 var args:=OS.get_cmdline_user_args()
 if args.size()>0:
  output=args[0]
  DirAccess.make_dir_recursive_absolute(output)
  root.size=Vector2i(844,390)
 await start(1)
 var player: CharacterBody3D=phase._player
 player.attack_charges=2
 player.defense_charges=2
 root.gui_release_focus()
 await key(KEY_K,true)
 check(player.is_defending and player.defense_charges==1 and player.attack_charges==2,"K defende sem consumir ataque hp=%d atk=%d def=%d floor=%s key=%s" % [player.health,player.attack_charges,player.defense_charges,player.is_on_floor(),Input.is_action_pressed("defend")])
 await key(KEY_K,false)
 await ticks(80)
 await key(KEY_J,true)
 check(player.attack_charges==1 and player.defense_charges==1 and not player.is_defending,"J ataca sem acionar defesa")
 await key(KEY_J,false)
 await ticks(30)
 await key(KEY_SHIFT,true)
 check(player.is_defending and player.defense_charges==0,"Shift continua sendo alternativa real de defesa")
 await key(KEY_SHIFT,false)
 await ticks(80)
 await key(KEY_SPACE,true)
 await key(KEY_SPACE,false)
 await ticks(8)
 await key(KEY_SPACE,true)
 check(player.jumps_used==2 and get_nodes_in_group("campaign_double_jump_dust").size()==1,"pulo duplo por teclado solta areia dos pés")
 await shot("01_areia_pulo_duplo")
 await key(KEY_SPACE,false)
 await ticks(75)
 check(get_nodes_in_group("campaign_double_jump_dust").is_empty(),"areia termina e não deixa emissores no cenário")
 var camera: Camera3D=phase._camera
 camera.position.x=200
 phase._scenery.follow(camera,200)
 var horizon: Vector3=phase._scenery._panorama.global_position-camera.global_position
 var palace: Vector3=phase._scenery._skyline._palaces[1].global_position-camera.global_position
 camera.position.x=190
 phase._scenery.follow(camera,190)
 check(horizon.is_equal_approx(phase._scenery._panorama.global_position-camera.global_position) and palace.is_equal_approx(phase._scenery._skyline._palaces[1].global_position-camera.global_position),"voltar não desliza panorama nem palácios distantes")
 var cp: Dictionary=phase._phase.checkpoints[0]
 player.position=phase._vec3(cp.pos)+Vector3(-0.8,0.04,0)
 player.velocity=Vector3.ZERO
 phase._stream_world(player.position.x,true)
 drain()
 await ticks(15)
 phase._check_checkpoints()
 check(phase._checkpoint_index==-1,"aproximar do marco ainda não ativa o checkpoint")
 var marker: Node3D=get_nodes_in_group("campaign_checkpoints")[0]
 check(marker._caption.text=="CHECKPOINT 1/7" and marker._flame.material_override.albedo_color.r>0.8,"marco grande identifica o checkpoint antes de salvar")
 await shot("02_checkpoint_antes")
 Input.action_press("move_right")
 for i in 35:
  await physics_frame
  phase._check_checkpoints()
  if phase._checkpoint_index==0:break
 Input.action_release("move_right")
 await ticks(3)
 check(phase._checkpoint_index==0 and marker._caption.text=="SALVO 1/7" and int(Run.read("").state.checkpoint)==0,"passar pelo marco salva e muda identificação para SALVO")
 await shot("03_checkpoint_salvo")
 check(not get_nodes_in_group("campaign_background_people").is_empty(),"trechos possuem figurantes fora do combate")
 phase._stream_world(30,true)
 drain()
 var people: Node3D=get_nodes_in_group("campaign_background_people")[0]
 var person: Sprite3D=people.get_child(0)
 var photo_x: float=person.global_position.x-2.5
 var floor:=Layout.floor_at(phase._phase,photo_x)
 player.position=Vector3(photo_x,float(floor.height)+0.04,0)
 player.velocity=Vector3.ZERO
 await ticks(20)
 await shot("04_civis_fundo")
 phase.free()
 await process_frame
 check(get_nodes_in_group("campaign_background_people").is_empty(),"descarregar a fase remove os figurantes")
 for order in range(1,10):
  var stage:=Layout.build(order)
  var spears: Array=stage.enemies.filter(func(e: Dictionary) -> bool:return e.get("spear",false))
  var expected: int={1:3,4:2,5:2,6:3,7:2,8:4,9:3}.get(order,0)
  check(spears.size()==expected and (spears.is_empty() or float(spears[-1].pos[0])-float(spears[0].pos[0])>stage.length*0.65),"fase%d distribui %d lanceiros pelo percurso" % [order,expected])
 await start(3)
 player=phase._player
 var roofs:=get_nodes_in_group("campaign_one_way").filter(func(n: Node) -> bool:return n.get_meta("canopy",false) and n.get_meta("prop_asset","")=="capital_merchant")
 check(not roofs.is_empty(),"lona real disponível para a patrulha")
 var roof: Node3D=roofs[0]
 var span: Vector2=roof.get_meta("landing_span")
 var x: float=span.x+(span.y-span.x)*0.5
 var base: float=roof.get_meta("source_floor")
 player.position=Vector3(x,float(roof.get_meta("one_way_top"))+0.04,0)
 player.velocity=Vector3.ZERO
 await ticks(15)
 check(player.is_on_floor(),"jogador apoiado na lona real")
 phase._spawn_enemy(phase._world,{"id":"qa.canopy.patrol","pos":[x-1.5,base+0.04,0],"patrol":[x-2,x+2],"troop":true})
 var guard: CharacterBody3D=phase._enemy_live["qa.canopy.patrol"]
 await ticks(10)
 var directions: Dictionary={}
 var lateral:=true
 var no_jump:=true
 for i in 360:
  await physics_frame
  if absf(guard.velocity.x)>0.1:directions[signf(guard.velocity.x)]=true
  lateral=lateral and absf(guard.position.z)<0.001 and absf(absf(guard._model.rotation.y)-PI*0.5)<0.01
  no_jump=no_jump and guard.velocity.y<=0.1
 check(directions.size()==2 and lateral and no_jump,"sob lona o guarda patrulha nos dois sentidos, sem pular nem girar para o fundo")
 await shot("05_patrulha_sob_lona")
 phase.free()
 print("GAMEPLAY_FEEDBACK checks=%d failures=%d" % [checks,failures])
 await preload("res://tests/common/audio_cleanup.gd").finish(self)
 quit(1 if failures else 0)
