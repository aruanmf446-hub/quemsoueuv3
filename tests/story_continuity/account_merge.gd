extends SceneTree
const Local=preload("res://scripts/desert/t15d/campaign_progress.gd")
const A="11111111-1111-4111-8111-111111111111"
const B="22222222-2222-4222-8222-222222222222"
class FakeClient extends SupabaseClient:
 var cloud:={}
 var account:=""
 var fail_next:=false
 var delay:=1
 func call_rpc(_name: String,params: Dictionary={}) -> Dictionary:
  var captured:=account
  var fail:=fail_next
  fail_next=false
  var sent:=int(params.p_completed)
  for i in delay:await get_tree().process_frame
  if fail:return ServiceResult.failure("network","offline")
  var previous:=int(cloud.get(captured,0))
  var merged:=maxi(previous,sent)
  cloud[captured]=merged
  return ServiceResult.success({"schema_version":1,"highest_completed":merged,"previous_completed":previous,"revision":1})
class TestServices extends PlayerServices:
 func _ready() -> void:pass
var services: TestServices
var fake: FakeClient
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1
 print(("PASS " if ok else "FAIL ")+message)
func frames(n: int) -> void:
 for i in n:await process_frame
func login(owner: String) -> void:
 fake.account=owner
 fake.access_token="test-only"
 services.session.user={"id":owner}
 services.story_progress.set_scope()
func run() -> void:
 services=TestServices.new()
 root.add_child(services)
 fake=FakeClient.new()
 services.client=fake
 services.add_child(fake)
 services.session=SessionService.new()
 services.session.client=fake
 services.add_child(services.session)
 services.session.set_process(false)
 services.story_progress=StoryProgressService.new()
 services.story_progress.session=services.session
 services.story_progress.client=fake
 services.add_child(services.story_progress)
 check(Local.merge_highest("",5)==OK,"visitante guarda cinco conclusões")
 Local.store_carry(6,{"attack":2,"defense":3,"amber":1},"")
 var lessons:=ConfigFile.new()
 lessons.set_value("guest","amber",true)
 lessons.save("user://desert_first_use_v1.cfg")
 login(A)
 lessons.load("user://desert_first_use_v1.cfg")
 check(lessons.get_value(A,"amber",false),"login mantém a descoberta do poder mesmo sem carga")
 check(Local.highest_unlocked()==6,"login conserva imediatamente cinco fases do visitante")
 await frames(8)
 check(fake.cloud[A]==5,"conta nova recebe automaticamente as cinco fases")
 check(Local.carry_for(6,A).defense==3,"cargas acompanham a migração do visitante")
 services.session.user={}
 fake.access_token=""
 services.story_progress.set_scope()
 check(Local.highest_for("")==5,"cópia visitante não é apagada")
 fake.cloud[B]=7
 login(B)
 lessons.load("user://desert_first_use_v1.cfg")
 check(not lessons.get_value(B,"amber",false),"descobertas importadas não se espalham para outra conta")
 check(Local.highest_for(B)==0,"não importa novamente para outra conta o visitante já transferido")
 await frames(8)
 check(Local.highest_unlocked()==8,"conta existente recupera avanço maior")
 check(Local.highest_for(A)==5,"troca de conta preserva a primeira conta")
 check(not services.story_progress.notice.is_empty(),"recuperação tem aviso informativo")
 Local.merge_highest(A,2)
 login(A)
 fake.cloud[A]=7
 await frames(8)
 check(Local.highest_for(A)==7 and fake.cloud[A]==7,"diferença local/nuvem escolhe automaticamente o maior avanço")
 check("automaticamente" in services.story_progress.notice,"conflito avisa sem escolha de substituição")
 fake.fail_next=true
 check(Local.complete(8)==OK,"vitória salva localmente antes de consultar a nuvem")
 await frames(8)
 check(Local.highest_for(A)==8 and services.story_progress.state=="offline","sem rede mantém avanço e sinaliza pendência")
 await services.story_progress.sync()
 check(fake.cloud[A]==8,"reconexão envia avanço pendente")
 fake.delay=10
 login(A)
 await frames(2)
 login(B)
 await frames(26)
 check(Local.highest_for(B)==7 and Local.highest_for(A)==8,"resposta atrasada não mistura contas")
 check(not services.story_progress._busy,"sincronização sempre libera estado ocupado")
 services.story_progress.dismiss_toast()
 Engine.time_scale=100.0
 await create_timer(0.12,true,false,true).timeout
 Engine.time_scale=1.0
 check(not is_instance_valid(services.story_progress._toast),"aviso removido não deixa callback para um objeto liberado")
 services.free()
 print("ACCOUNT_MERGE checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)
