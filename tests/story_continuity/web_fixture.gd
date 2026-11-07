extends Node
## TEST ONLY. RPC simulada no navegador; backend real validado separadamente em backend.sql.
const Fixture=preload("res://tests/story_continuity/account_merge.gd")
const Local=preload("res://scripts/desert/t15d/campaign_progress.gd")
class WebSession extends SessionService:
 func _ready() -> void:set_process(false)
var services: PlayerServices
var client: SupabaseClient
var screen: PlayerScreen
var phase: Node3D
var loading: CampaignLoading
var callback: JavaScriptObject
var obstacle: Dictionary={}
var motion_samples: Dictionary={}
func _physics_process(_delta: float) -> void:
 # Registra eventos de física que um navegador com GPU emulada pode deixar
 # passar entre duas consultas JS. Não altera velocidade, entrada ou colisão.
 if not is_instance_valid(phase) or obstacle.is_empty():return
 var actor: CharacterBody3D=phase._player
 var on_canopy:=actor.is_on_floor() and absf(actor.position.y-float(obstacle.top))<0.04
 if on_canopy and actor.velocity.x>0.1 and not motion_samples.has("walking"):
  motion_samples.walking={"x":actor.position.x,"y":actor.position.y,"floor":true,"vx":actor.velocity.x}
 if actor.position.x>float(obstacle.right)+0.4 and actor.position.y<float(obstacle.top)-0.2 and not motion_samples.has("edge"):
  motion_samples.edge={"x":actor.position.x,"y":actor.position.y,"floor":actor.is_on_floor(),"vx":actor.velocity.x}
func _ready() -> void:
 if not OS.has_feature("story_continuity_fixture"):return
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 services=Fixture.TestServices.new()
 add_child(services)
 client=Fixture.FakeClient.new()
 services.client=client
 services.add_child(client)
 services.session=WebSession.new()
 services.session.client=client
 services.add_child(services.session)
 services.progression=ProgressionService.new()
 services.progression.client=client
 services.progression.session=services.session
 services.add_child(services.progression)
 services.story_progress=StoryProgressService.new()
 services.story_progress.client=client
 services.story_progress.session=services.session
 services.add_child(services.story_progress)
 screen=load("res://scenes/player/story.tscn").instantiate()
 add_child(screen)
 screen.show_screen()
 callback=JavaScriptBridge.create_callback(probe)
 JavaScriptBridge.get_interface("window").qseContinuityProbe=callback
func launch(packed: PackedScene) -> void:
 if is_instance_valid(phase):phase.free()
 obstacle={}
 motion_samples={}
 phase=packed.instantiate()
 get_tree().root.add_child(phase)
 get_tree().current_scene=phase
func probe(args: Array) -> void:
 var command:=str(args[0]) if args.size()>0 else "state"
 if command.begins_with("guest:"):
  Local.merge_highest("",int(command.get_slice(":",1)))
  screen.render()
 if command.begins_with("cloud:"):
  client.cloud[Fixture.A if command.get_slice(":",1)=="a" else Fixture.B]=int(command.get_slice(":",2))
 if command.begins_with("login:"):
  client.account=Fixture.A if command.ends_with("a") else Fixture.B
  client.access_token="fixture-only"
  services.session.user={"id":client.account}
  services.story_progress.set_scope()
 if command=="logout":
  services.session.user={}
  client.access_token=""
  services.story_progress.set_scope()
 if command.begins_with("phase:"):
  var order:=int(command.get_slice(":",1))
  PhaseStory.mark_read(order)
  screen.hide()
  loading=CampaignLoading.new()
  get_tree().root.add_child(loading)
  loading.begin("res://scenes/desert/phase_%02d.tscn" % order,launch)
 if not is_instance_valid(phase):
  for node in get_tree().root.get_children():
   if node.get_script()==load("res://scripts/desert/t15d/phase.gd"):phase=node
 if command=="feedback-controls" and is_instance_valid(phase):
  phase.set_physics_process(false)
  phase._player.set_physics_process(true)
  phase._player._invulnerable=999
  phase._player.attack_charges=2
  phase._player.defense_charges=2
  for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
 if command=="charges" and is_instance_valid(phase):
  phase._player.attack_charges=2
  phase._player.defense_charges=3
  phase._sync_resources()
 if command=="complete-tasks" and is_instance_valid(phase):
  for task: Dictionary in phase._phase.tasks:phase._raised_bridges[str(task.id)]=true
 if command=="save-run" and is_instance_valid(phase):
  phase.set_physics_process(false)
  phase._player.set_physics_process(false)
  phase._checkpoint_index=4
  phase._checkpoint=phase._vec3(phase._phase.checkpoints[4].pos)
  var at: float=phase._checkpoint.x+2.0
  var floor:=preload("res://scripts/desert/t15d/campaign_layout.gd").floor_at(phase._phase,at)
  phase._player.position=Vector3(at,float(floor.height)+0.04,0)
  phase._safe_position=phase._player.position
  phase._player.health=2
  phase._player.attack_charges=2
  phase._player.defense_charges=0
  phase._player.abilities={"amber":1,"dash":0,"rupture":2}
  phase._raised_bridges[str(phase._phase.tasks[0].id)]=true
  phase._task_steps[str(phase._phase.tasks[1].id)]=1
  phase._collected_ids[str(phase._phase.pickups[0].id)]=true
  phase._defeated_ids[str(phase._phase.enemies[0].id)]=true
  phase._elapsed=123.0
  phase._save_active_run()
  phase._sync_resources()
  phase._stream_world(at,true)
  for i in 2400:
   if phase._build_queue.is_empty():break
   phase._process(0)
  for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
  for i in 3:phase._follow_camera(1.0)
  phase._scenery.follow(phase._camera,phase._player.position.x)
 if command=="goal" and is_instance_valid(phase):phase._on_goal_entered(phase._player)
 if command=="next" and is_instance_valid(phase):
  PhaseStory.mark_read(phase._order+1)
  phase._session.next_requested.emit()
 if command in ["obstacle","canopy","near-canopy","task-canopy"] and is_instance_valid(phase):
  motion_samples={}
  if command in ["near-canopy","task-canopy"]:
   var at: float
   if command=="task-canopy":
    var gate: Dictionary=phase._phase.tasks.filter(func(t: Dictionary) -> bool:return t.task_kind=="gate")[0]
    at=(float(gate.start)+float(gate.end))*0.5
   else:
    at=preload("res://scripts/desert/t15d/kingdom_assets.gd").placements(phase._order).filter(func(p: Dictionary) -> bool:return p.asset=="capital_merchant")[0].x
   phase._player.position.x=at
   phase._stream_world(at,true)
   for i in 2400:
    if phase._build_queue.is_empty():break
    phase._process(0)
  if command!="obstacle":
   var roofs:=get_tree().get_nodes_in_group("campaign_one_way").filter(func(n: Node) -> bool:
    if not n.get_meta("canopy",false):return false
    if command=="task-canopy":return n.has_meta("prop_art") and n.get_node(n.get_meta("prop_art")).get_meta("task_canopy",false)
    return n.get_meta("prop_asset","")=="capital_merchant" and n.position.x>float(phase._phase.player_spawn[0])+1 and (command!="near-canopy" or n.get_node(n.get_meta("prop_art")).global_position.z>=-8.0))
   roofs.sort_custom(func(a: Node3D,b: Node3D) -> bool:return a.position.x<b.position.x)
   var roof: Node3D=roofs[0]
   var span: Vector2=roof.get_meta("landing_span")
   obstacle={"left":span.x,"right":span.y,"base":roof.get_meta("source_floor"),"top":roof.get_meta("one_way_top"),"asset":roof.get_meta("prop_asset")}
  else:
   var spec: Dictionary=phase._phase.platforms.filter(func(p: Dictionary) -> bool:return p.get("parkour_route",false))[0]
   obstacle={"left":spec.span_start,"right":spec.span_end,"base":spec.surface_top,"top":spec.pos[1]+spec.size[1]*0.5}
  phase.set_physics_process(false)
  phase._player.position=Vector3((obstacle.left+obstacle.right)*0.5 if command!="obstacle" else obstacle.left-1.4,obstacle.base+0.04,0)
  phase._player.velocity=Vector3.ZERO
  phase._player._invulnerable=0
  phase._stream_world((obstacle.left+obstacle.right)*0.5,true)
  for i in 2400:
   if phase._build_queue.is_empty():break
   phase._process(0)
  for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
  for i in 3:phase._follow_camera(1.0)
  phase._scenery.follow(phase._camera,phase._player.position.x)
 if command=="view" and is_instance_valid(phase):
  for i in 3:phase._follow_camera(1.0)
  phase._scenery.follow(phase._camera,phase._player.position.x)
 if command=="ground" and is_instance_valid(phase):
  phase.set_physics_process(false)
  phase._player.set_physics_process(false)
  for i in 2400:
   if phase._build_queue.is_empty():break
   phase._process(0)
  for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
  phase._player._model.show()
  for i in 3:phase._follow_camera(1.0)
  phase._scenery.follow(phase._camera,phase._player.position.x)
 var state:={"highest":Local.highest_unlocked(),"completed":Local._highest_completed(),"notice":services.story_progress.notice,"sync":services.story_progress.state,"cloud_mock":true,"stage":"menu"}
 if is_instance_valid(phase):
  state.stage="play"
  state.order=phase._order
  state.attack=phase._player.attack_charges
  state.defense=phase._player.defense_charges
  state.actor_feedback={"floor":phase._player.is_on_floor(),"defending":phase._player.is_defending,"jumps":phase._player.jumps_used,"dust":get_tree().get_nodes_in_group("campaign_double_jump_dust").size()}
  state.run={"checkpoint":phase._checkpoint_index,"health":phase._player.health,"x":phase._player.position.x,"charges":phase._charge_snapshot(),"tasks":phase._raised_bridges.size(),"steps":phase._task_steps.duplicate(),"collected":phase._collected_ids.size(),"defeated":phase._defeated_ids.size()}
  if not obstacle.is_empty():
   state.motion=motion_samples
   var actor: CharacterBody3D=phase._player
   state.obstacle=obstacle
   state.actor={"x":actor.position.x,"y":actor.position.y,"floor":actor.is_on_floor(),"vx":actor.velocity.x,"vy":actor.velocity.y,"jumps":actor.jumps_used}
   var jump: Vector2=phase._touch_pad._buttons["jump"][0]
   var size:=get_viewport().get_visible_rect().size
   state.jump=[jump.x/size.x,jump.y/size.y]
 elif is_instance_valid(loading):
  state.stage="loading"
  state.reads=loading._completed_reads
  state.total=loading._total_reads
  state.value=loading._progress.value
 JavaScriptBridge.eval("window.qseContinuityState="+JSON.stringify(state))
