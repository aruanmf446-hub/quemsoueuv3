extends SceneTree
const OWNER="00000000-0000-4000-8000-000000000091"
var checks := 0
var failures := 0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run() -> void:
 var cfg:=ConfigFile.new();cfg.load(AbilityRefillService.FILE)
 if cfg.has_section(OWNER):cfg.erase_section(OWNER);cfg.save(AbilityRefillService.FILE)
 var services:=PlayerServices.new();root.add_child(services)
 var fake:=preload("res://tests/ability_refills/fake_game.gd").new();root.add_child(fake)
 fake.access_token="fixture-not-real";services.session.client=fake;services.ability_refills.client=fake
 services.session.user={"id":OWNER};services.session._expires_at=Time.get_unix_time_from_system()+86400;services.session.set_process(false)
 var stock:=services.ability_refills
 var player:=preload("res://scripts/desert/t15d/player.gd").new()
 player.discovered={"attack":true,"defense":true,"amber":true,"dash":true,"rupture":true}
 await stock.refresh()
 check(stock.count()==2,"recargas guardadas vêm da conta")
 player.defense_charges=3
 var calls:=fake.refill_calls.size()
 check((await stock.use_full(player,"defense",5,func()->bool:return true)).code=="ability_full" and fake.refill_calls.size()==calls and fake.quantity==2,"poka-yoke em 3/3: nem RPC nem consumo")
 check(AbilityRefillService.message("ability_full","defense").contains("Defesa está cheia"),"aviso identifica a habilidade cheia")
 player.defense_charges=0
 check((await stock.use_full(player,"defense",5,func()->bool:return true)).ok and player.defense_charges==3 and fake.quantity==1,"defesa 0/3 vira 3/3 usando uma recarga")
 player.defense_charges=1
 check((await stock.use_full(player,"defense",5,func()->bool:return true)).ok and player.defense_charges==3 and fake.quantity==0,"defesa 1/3 vira 3/3, não 2/3")
 check(player.attack_charges==1 and player.abilities.amber==0,"outras habilidades não recebem cargas")
 check((await stock.use_full(player,"amber",2,func()->bool:return true)).code=="ability_locked","não desbloqueia poderes antes da fase")
 player.defense_charges=0
 check((await stock.use_full(player,"defense",5,func()->bool:return true)).code=="no_refills" and player.defense_charges==0,"sem estoque não fabrica recarga")
 fake.quantity=1;player.defense_charges=2
 check((await stock.use_full(player,"defense",5,func()->bool:return true)).ok and player.defense_charges==3 and fake.quantity==0,"2/3 também completa até o limite 3/3")
 player.defense_charges=0
 fake.quantity=1;fake.lose_reserve=true
 var r:=await stock.use_full(player,"defense",5,func()->bool:return true)
 check(not r.ok and fake.quantity==0 and player.defense_charges==0,"resposta perdida deixa uma entrega pendente")
 check((await stock.use_full(player,"defense",5,func()->bool:return true)).ok and player.defense_charges==3 and fake.quantity==0,"retentativa recupera a mesma recarga sem novo consumo")
 fake.quantity=1;fake.fail_ack=true;player.defense_charges=0
 check((await stock.use_full(player,"defense",5,func()->bool:return true)).ok and player.defense_charges==3,"falha de confirmação não desfaz a habilidade aplicada")
 player.defense_charges=0
 check((await stock.use_full(player,"defense",5,func()->bool:return true)).code=="refill_already_used" and player.defense_charges==0,"recibo aplicado não recarrega outra vez")
 fake.fail_ack=false;await stock.refresh()
 check(stock.count()==0,"confirmação pendente é reconciliada sem reaplicar")
 fake.quantity=1;fake.on_reserve=func()->void:services.session.user={"id":"00000000-0000-4000-8000-000000000092"};fake.generation+=1
 check((await stock.use_full(player,"defense",5,func()->bool:return true)).code=="refill_context_changed" and player.defense_charges==0 and stock.count()==null,"troca de conta impede entrega ao jogador errado")
 fake.on_reserve=Callable();services.session.user={"id":OWNER}
 check((await stock.use_full(player,"defense",5,func()->bool:return true)).ok and player.defense_charges==3,"a conta original recupera a entrega")
 await stock.refresh();var before:=fake.coins;fake.lose_buy=true
 check(not (await stock.buy(10)).ok,"compra sem resposta não inventa sucesso")
 check((await stock.buy(10)).ok and fake.coins==before-10 and stock.count()==1,"retentativa de compra não duplica débito nem estoque")
 player.defense_charges=0;paused=true
 check((await stock.use_full(player,"defense",5,func()->bool:return true)).ok and player.defense_charges==3,"uso funciona com o jogo pausado")
 paused=false
 player.free();services.queue_free();fake.queue_free()
 for i in 4:await process_frame
 cfg=ConfigFile.new();cfg.load(AbilityRefillService.FILE)
 if cfg.has_section(OWNER):cfg.erase_section(OWNER);cfg.save(AbilityRefillService.FILE)
 print("ABILITY_REFILLS_CLIENT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
