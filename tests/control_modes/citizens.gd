extends SceneTree
const Layout=preload("res://scripts/desert/t15d/campaign_layout.gd")
var failures:=0
var checks:=0
var output:=""
var phase: Node3D
var contexts: Dictionary={}
var species: Dictionary={}
var captured: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1
 print(("PASS " if ok else "FAIL ")+label)
func shot(kind: String,group: Node3D) -> void:
 if output.is_empty() or captured.has(kind):return
 captured[kind]=true
 var body: Sprite3D=group.get_child(0)
 var x: float=body.global_position.x-2.4
 var floor:=Layout.floor_at(phase._phase,x)
 if floor.is_empty():return
 phase._player.position=Vector3(x,float(floor.height)+0.04,0)
 phase._player.velocity=Vector3.ZERO
 for i in 20:await physics_frame
 phase._player.set_physics_process(false)
 phase._player._model.show()
 for i in 3:phase._follow_camera(1.0)
 phase._scenery.follow(phase._camera,x)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_jpg(output+"/"+kind+".jpg",0.94)
 if kind in ["market","family"]:
  phase._player.velocity.x=6.0
  group._process(0.05)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_jpg(output+"/"+kind+"_reacao.jpg",0.94)
  phase._player.velocity=Vector3.ZERO
 phase._player.set_physics_process(true)
func run() -> void:
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 var args:=OS.get_cmdline_user_args()
 if args.size()>0:
  output=args[0]
  root.size=Vector2i(844,390)
  DirAccess.make_dir_recursive_absolute(output)
 var transparent:=true
 for asset in ["human_citizens","cactus_citizens"]:
  var texture: Texture2D=load("res://assets/desert/npc_citizens/"+asset+".png")
  var image:=texture.get_image()
  for row in 4:
   for col in 4:
    transparent=transparent and image.get_pixel(col*image.get_width()/4,row*image.get_height()/4).a<0.01
 check(transparent,"atlas de pessoas e cactos não têm caixas de fundo visíveis")
 var all_original:=true
 var stationary:=true
 var aligned:=true
 var reaction:=false
 var routine:=false
 for order in [1,3,5,8]:
  phase=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
  root.add_child(phase)
  phase.set_physics_process(false)
  for x in [55.0,225.0,410.0,610.0,810.0,1030.0,1210.0,1380.0]:
   phase._stream_world(x,true)
   for i in 2400:
    if phase._build_queue.is_empty():break
    phase._process(0)
   for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
   for group in get_nodes_in_group("campaign_background_people"):
    contexts[group.context]=true
    for member: Dictionary in group._members:
     var sprite: Sprite3D=member.sprite
     species[str(sprite.get_meta("species"))]=true
     all_original=all_original and sprite.texture.resource_path.begins_with("res://assets/desert/npc_citizens/") and not sprite.is_in_group("enemies")
     var before:=sprite.position
     phase._player.position.x=sprite.global_position.x-1
     phase._player.velocity.x=6.0
     group._process(0.1)
     if member.reacts:reaction=reaction or sprite.frame==int(member.neutral)+4
     else:routine=routine or sprite.frame==int(member.neutral)
     stationary=stationary and absf(before.x-sprite.position.x)<0.001 and absf(before.z-sprite.position.z)<0.001
     var key: String="human_citizens" if member.human else "cactus_citizens"
     var foot: float=group._feet[key].cells[sprite.frame].foot
     var sole: float=sprite.position.y+(0.5-foot)*float(member.height)
     aligned=aligned and absf(sole-float(member.ground))<0.002
     group._process(2.0)
    await shot(group.context,group)
  phase.free()
  await process_frame
 check(all_original,"nenhum figurante usa imagem de personagem jogável ou soldado de combate")
 check(species.has("human") and species.has("cactus"),"cidade inclui pessoas e cidadãos-cacto originais")
 check(contexts.has("market") and contexts.has("family") and contexts.has("alone"),"composição alterna comércio, família em jardim e cidadãos sozinhos")
 check(reaction and routine,"alguns cidadãos se assustam; outros mantêm a rotina")
 check(stationary,"reações não fazem cidadãos correr, girar ou mudar de lugar")
 check(aligned,"troca de pose conserva os pés na superfície")
 check(get_nodes_in_group("campaign_background_people").is_empty(),"figurantes descarregam com a fase")
 await preload("res://tests/common/audio_cleanup.gd").finish(self)
 print("ORIGINAL_CITIZENS checks=%d failures=%d contexts=%s species=%s" % [checks,failures,contexts.keys(),species.keys()])
 quit(1 if failures else 0)
