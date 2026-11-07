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
 if command=="charges" and is_instance_valid(phase):
  phase._player.attack_charges=2
  phase._player.defense_charges=3
  phase._sync_resources()
 if command=="goal" and is_instance_valid(phase):phase._on_goal_entered(phase._player)
 if command=="next" and is_instance_valid(phase):
  PhaseStory.mark_read(phase._order+1)
  phase._session.next_requested.emit()
 if command=="obstacle" and is_instance_valid(phase):
  var spec: Dictionary=phase._phase.platforms.filter(func(p: Dictionary) -> bool:return p.get("parkour_route",false))[0]
  obstacle={"left":spec.span_start,"right":spec.span_end,"base":spec.surface_top,"top":spec.pos[1]+spec.size[1]*0.5}
  phase.set_physics_process(false)
  phase._player.position=Vector3(obstacle.left-1.4,obstacle.base+0.04,0)
  phase._player.velocity=Vector3.ZERO
  phase._player._invulnerable=0
  phase._stream_world((obstacle.left+obstacle.right)*0.5,true)
  for i in 2400:
   if phase._build_queue.is_empty():break
   phase._process(0)
  for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
  for i in 3:phase._follow_camera(1.0)
  phase._scenery.follow(phase._camera,phase._player.position.x)
 var state:={"highest":Local.highest_unlocked(),"completed":Local._highest_completed(),"notice":services.story_progress.notice,"sync":services.story_progress.state,"cloud_mock":true,"stage":"menu"}
 if is_instance_valid(phase):
  state.stage="play"
  state.order=phase._order
  state.attack=phase._player.attack_charges
  state.defense=phase._player.defense_charges
  if not obstacle.is_empty():
   var actor: CharacterBody3D=phase._player
   state.obstacle=obstacle
   state.actor={"x":actor.position.x,"y":actor.position.y,"floor":actor.is_on_floor(),"vx":actor.velocity.x}
   var jump: Vector2=phase._touch_pad._buttons["jump"][0]
   var size:=get_viewport().get_visible_rect().size
   state.jump=[jump.x/size.x,jump.y/size.y]
 elif is_instance_valid(loading):
  state.stage="loading"
  state.reads=loading._completed_reads
  state.total=loading._total_reads
  state.value=loading._progress.value
 JavaScriptBridge.eval("window.qseContinuityState="+JSON.stringify(state))
