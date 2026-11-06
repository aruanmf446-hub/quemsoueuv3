extends SceneTree
## Fixtures explícitas: login simulado; telas e carregamento reais do jogo.
const Fixture=preload("res://tests/story_continuity/account_merge.gd")
const Local=preload("res://scripts/desert/t15d/campaign_progress.gd")
var finished:=false
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
 for i in n:await process_frame
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 var output:=args[0]
 var size:=args[1].split("x")
 root.size=Vector2i(int(size[0]),int(size[1]))
 DirAccess.make_dir_recursive_absolute(output)
 PhaseStory.mark_read(4)
 var loading:=CampaignLoading.new()
 root.add_child(loading)
 loading.begin("res://scenes/desert/phase_04.tscn",func(_packed: PackedScene) -> void:finished=true)
 for i in 240:
  await process_frame
  if loading._completed_reads>=3:break
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_jpg(output+"/carregamento_real.jpg",0.94)
 while not finished:await process_frame
 await frames(2)
 var services:=Fixture.TestServices.new()
 root.add_child(services)
 var client:=Fixture.FakeClient.new()
 services.client=client
 services.add_child(client)
 services.session=SessionService.new()
 services.session.client=client
 services.add_child(services.session)
 services.session.set_process(false)
 services.progression=ProgressionService.new()
 services.progression.client=client
 services.progression.session=services.session
 services.add_child(services.progression)
 services.story_progress=StoryProgressService.new()
 services.story_progress.client=client
 services.story_progress.session=services.session
 services.add_child(services.story_progress)
 Local.merge_highest("",2)
 client.account=Fixture.A
 client.access_token="fixture-only"
 client.cloud[Fixture.A]=5
 services.session.user={"id":Fixture.A}
 services.story_progress.set_scope()
 await frames(8)
 var screen: PlayerScreen=load("res://scenes/player/story.tscn").instantiate()
 root.add_child(screen)
 screen.show_screen()
 await frames(8)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_jpg(output+"/progresso_conciliado.jpg",0.94)
 assert(Local.highest_unlocked()==6)
 assert(not services.story_progress.notice.is_empty())
 screen.free()
 services.free()
 print("STORY_CAPTURE real_loading=true fixture_login=true resolution=",args[1])
 quit()
