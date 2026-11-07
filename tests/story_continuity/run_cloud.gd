extends SceneTree
const Fixture=preload("res://tests/story_continuity/account_merge.gd")
const Run=preload("res://scripts/desert/t15d/campaign_run.gd")
const Local=preload("res://scripts/desert/t15d/campaign_progress.gd")
var failures:=0
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1
 print(("PASS " if ok else "FAIL ")+label)
func run() -> void:
 var services:=Fixture.TestServices.new()
 root.add_child(services)
 var fake:=Fixture.FakeClient.new()
 services.client=fake
 services.add_child(fake)
 services.session=SessionService.new()
 services.session.client=fake
 services.add_child(services.session)
 services.session.set_process(false)
 fake.account=Fixture.A
 fake.access_token="fixture-only"
 services.session.user={"id":Fixture.A}
 services.story_progress=StoryProgressService.new()
 services.story_progress.client=fake
 services.story_progress.session=services.session
 services.add_child(services.story_progress)
 Local.merge_highest(Fixture.A,4)
 var state:=Run.fresh(5,{"attack":2,"defense":0,"amber":1,"dash":2,"rupture":3})
 state.checkpoint=6
 state.health=2
 Run.save(Fixture.A,state,"start")
 services.story_progress.set_scope()
 await services.story_progress.prepare_run()
 check(fake.runs.has(Fixture.A) and fake.runs[Fixture.A].state.charges==state.charges,"conta envia todos os recursos e checkpoint 7")
 DirAccess.remove_absolute(OwnerStorage.path(Fixture.A,"story_run_v1.cfg"))
 await services.story_progress.sync()
 check(Run.read(Fixture.A).state.charges==state.charges and int(Run.read(Fixture.A).state.checkpoint)==6,"outro aparelho recupera inventário e checkpoint completos")
 var old:=Run.read(Fixture.A)
 var spent: Dictionary=old.state.duplicate(true)
 spent.charges.attack=0
 Run.save(Fixture.A,spent)
 await services.story_progress.sync()
 old.state.change_id=PlayerContracts.uuid()
 old.pending=true
 old.intent="save"
 Run._write(Fixture.A,old)
 await services.story_progress.sync()
 check(int(Run.read(Fixture.A).state.charges.attack)==0,"resposta de aparelho antigo não recria cargas gastas")
 var sent_old: Dictionary=Run.read(Fixture.A).state.duplicate(true)
 var remote: Dictionary=sent_old.duplicate(true)
 remote.position[0]=float(remote.position[0])+20.0
 remote.change_id=PlayerContracts.uuid()
 Run.save(Fixture.A,sent_old)
 Run.accept(Fixture.A,{"schema_version":1,"state":remote,"revision":int(Run.read(Fixture.A).revision)+1,"applied":false},sent_old)
 check(float(Run.read(Fixture.A).state.position[0])==float(remote.position[0]) and not Run.read(Fixture.A).pending,"autossalvamento durante conflito não recua o avanço do outro aparelho")
 sent_old=Run.read(Fixture.A).state.duplicate(true)
 remote=sent_old.duplicate(true)
 remote.charges.rupture=0
 remote.change_id=PlayerContracts.uuid()
 Run.save(Fixture.A,sent_old)
 Run.accept(Fixture.A,{"schema_version":1,"state":remote,"revision":int(Run.read(Fixture.A).revision)+1,"applied":false},sent_old)
 check(int(Run.read(Fixture.A).state.charges.rupture)==0 and not Run.read(Fixture.A).pending,"autossalvamento simultâneo não recria carga rejeitada pela nuvem")
 var in_flight: Dictionary=Run.read(Fixture.A).state.duplicate(true)
 var next:=Run.fresh(6,in_flight.charges)
 Run.save(Fixture.A,next,"start")
 Run.accept(Fixture.A,{"schema_version":1,"state":in_flight,"revision":4},in_flight)
 check(int(Run.read(Fixture.A).state.phase)==6 and Run.read(Fixture.A).pending,"resposta atrasada da fase anterior não apaga o inventário da próxima")
 fake.account=Fixture.B
 services.session.user={"id":Fixture.B}
 services.story_progress.set_scope()
 await services.story_progress.prepare_run()
 check(Run.read(Fixture.B).state.is_empty(),"trocar de conta não mistura a partida anterior")
 services.free()
 print("RUN_CLOUD checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)
