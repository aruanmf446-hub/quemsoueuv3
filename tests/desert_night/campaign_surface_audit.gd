extends SceneTree
## Auditoria integral por chunks; aproximação por fixture, saltos por entradas reais.
const Layout=preload("res://scripts/desert/t15d/campaign_layout.gd")
const Assets=preload("res://scripts/desert/t15d/kingdom_assets.gd")
const Landings=preload("res://scripts/desert/t15d/prop_landings.gd")
var checks:=0
var failures:=0
var records: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1
 print(("PASS " if ok else "FAIL ")+label)
func ticks(n: int) -> void:
 for i in n:await physics_frame
func jump() -> void:
 Input.action_press("jump")
 await ticks(2)
 Input.action_release("jump")
func check_landing(phase: Node3D,body: StaticBody3D,label: String) -> void:
 var player: CharacterBody3D=phase._player
 var top: float=body.get_meta("one_way_top")
 var base: float=body.get_meta("source_floor")
 player.position=Vector3(body.position.x,base+0.04,0)
 player.velocity=Vector3.ZERO
 player._invulnerable=999
 player.set_physics_process(true)
 await ticks(15)
 await jump()
 await ticks(20)
 await jump()
 var ceiling:=false
 var landed:=false
 for i in 150:
  await physics_frame
  ceiling=ceiling or player.is_on_ceiling()
  if player.is_on_floor() and absf(player.position.y-top)<0.04:
   landed=true
   break
 check(landed and not ceiling,label+": salta de baixo e pousa na lona real")
 await ticks(10)
 var before: float=player.position.x
 Input.action_press("move_right")
 await ticks(4)
 Input.action_release("move_right")
 await ticks(2)
 check(player.is_on_floor() and absf(player.position.y-top)<0.04 and player.position.x>before+0.1,label+": caminha apoiado, sem flutuar/atravessar")
 player.set_physics_process(false)
func flat_floor(order: int,stage: Dictionary) -> void:
 if order==2:return # Contato com os telhados pintados: roof_contact_render.gd.
 var art:=preload("res://scripts/desert/t15d/modular_architecture.gd").new()
 root.add_child(art)
 art.build_surface(stage.platforms[0],order)
 var flat:=true
 var count:=0
 var top: float=stage.surfaces[0].height
 for mesh: Node in art.get_children():
  if not mesh is MeshInstance3D or String(mesh.name) not in ["City_stone","City_wood"]:continue
  var data: Array=mesh.mesh.surface_get_arrays(0)
  var vertices: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
  var normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
  for i in range(0,vertices.size(),3):
   if absf(vertices[i].y-top)>0.001:continue
   var normal: Vector3=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
   if absf(normal.y)<0.999:continue
   count+=1
   for j in 3:
    if absf(normals[i+j].y)<0.999:flat=false
 check(count>0 and flat,"fase%d: topo plano sem iluminação inclinada nas emendas" % order)
 art.free()
func gate_from_canopy(phase: Node3D,roof: Node3D) -> void:
 var gate: Dictionary=phase._phase.tasks.filter(func(t: Dictionary) -> bool:return t.task_kind=="gate")[0]
 var player: CharacterBody3D=phase._player
 player.position=Vector3(roof.position.x,float(roof.get_meta("one_way_top"))+0.02,0)
 player.velocity=Vector3.ZERO
 player.set_physics_process(true)
 await ticks(15)
 Input.action_press("move_right")
 await jump()
 await ticks(20)
 await jump()
 await ticks(180)
 Input.action_release("move_right")
 check(player.is_on_floor() and not player.is_dead and player.position.x>float(gate.start)-2.0 and player.position.x<float(gate.start) and not phase._raised_bridges.has(str(gate.id)),"fase3: saltar da nova lona não dispensa acionar o portão")
 player.set_physics_process(false)
func run() -> void:
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 for order in range(1,10):
  var stage:=Layout.build(order)
  flat_floor(order,stage)
  var textures_ok:=true
  var ids:=Assets.composition_ids(order)
  for point: Dictionary in Assets.placements(order):
   if not ids.has(point.asset):ids.append(point.asset)
  for id: String in ids:
   var texture:=Assets.texture(id)
   if texture==null:textures_ok=false;continue
   var base:=texture
   if base is AtlasTexture:
    if not base.filter_clip or base.atlas is AtlasTexture:textures_ok=false
    base=base.atlas
   if maxi(base.get_width(),base.get_height())>1024 or not base.get_image().has_mipmaps():textures_ok=false
  check(textures_ok,"fase%d: catálogo sem atlas aninhado, texturas limitadas e com mipmaps" % order)
  var safe:=true
  for item: Dictionary in stage.pickups:
   var floor:=Layout.floor_at(stage,float(item.pos[0]))
   if floor.is_empty() or floor.get("task_void",false) or absf(float(item.pos[1])-float(floor.get("height",INF)))>0.01:safe=false
   if Layout.ABILITY_PHASE.has(item.kind) and order<int(Layout.ABILITY_PHASE[item.kind]):safe=false
  check(safe,"fase%d: todas as recargas apoiadas e poderes na fase correta" % order)
  var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
  root.add_child(phase)
  phase.set_physics_process(false)
  phase._player.set_physics_process(false)
  var seen: Dictionary={}
  var exercised: Dictionary={}
  var below_route:=0
  var canopies:=0
  var issues: Array=[]
  for x in range(0,1453,64):
   phase._player.position.x=x
   phase._stream_world(x,true)
   for i in 2400:
    if phase._build_queue.is_empty():break
    phase._process(0)
   for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
   await ticks(2)
   for art: Node in get_nodes_in_group("kingdom_art"):
    if not phase._world.is_ancestor_of(art) or art.is_in_group("playable_house_roofs"):continue
    var id:=str(art.get_meta("asset_id",""))
    if id not in ["capital_house","capital_merchant","capital_balcony_house","capital_market_stall"] or art.global_position.z< -12.5:continue
    var key: String="%s:%.3f:%.3f" % [id,art.global_position.x,art.global_position.z]
    if seen.has(key):continue
    seen[key]=true
    var floor:=Layout.floor_at(stage,art.global_position.x)
    if floor.is_empty() or floor.get("task_void",false):issues.append(key+": fora do piso");continue
    if order==2 and art.global_position.y<float(floor.height)-1:
     below_route+=1
     continue # Rua inferior é cenário; o percurso físico continua no teto da casa.
    var roofs:=get_nodes_in_group(Landings.GROUP).filter(func(n: Node) -> bool:return n.get_meta("canopy",false) and n.get_meta("prop_art",NodePath())==art.get_path())
    if roofs.size()!=1:issues.append(key+": sem apoio único");continue
    canopies+=1
    var roof: StaticBody3D=roofs[0]
    var span: Vector2=roof.get_meta("landing_span")
    for other: Node in get_nodes_in_group(Landings.GROUP):
     if other==roof or other.get_meta("prop_art",NodePath())!=art.get_path():continue
     var extent: Vector2=other.get_meta("landing_span")
     if minf(span.y,extent.y)-maxf(span.x,extent.x)>0.30 and absf(float(other.get_meta("one_way_top"))-float(roof.get_meta("one_way_top")))<0.45:issues.append(key+": dois apoios sobre o mesmo tecido")
    var variant:=id+("_fachada" if art.position.z< -8 else "_proxima")
    if art.get_meta("task_canopy",false):variant+="_mecanismo"
    if not exercised.has(variant):
     exercised[variant]=true
     await check_landing(phase,roof,"fase%d %s" % [order,variant])
     if art.get_meta("task_canopy",false):await gate_from_canopy(phase,roof)
   if phase._loaded_chunks.size()>5:issues.append("stream sem limite de chunks")
  for issue: String in issues:print("CANOPY_ISSUE fase",order," ",issue)
  check(issues.is_empty(),"fase%d: %d lonas inspecionadas em todo o percurso, %d fachadas abaixo da rota" % [order,canopies,below_route])
  records.append({"order":order,"canopies":canopies,"street_below":below_route,"variants_exercised":exercised.keys(),"issues":issues})
  phase.free()
  await process_frame
  check(get_nodes_in_group(Landings.GROUP).is_empty(),"fase%d: apoios descarregados sem resíduos" % order)
 var args:=OS.get_cmdline_user_args()
 if not args.is_empty():FileAccess.open(args[0],FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records,"fixture_teleport":true,"physical_device":false},"\t"))
 print("CAMPAIGN_SURFACE_AUDIT checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)
