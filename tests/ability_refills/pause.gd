extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,text: String) -> void:
 checks+=1;print("PASS " if ok else "FAIL ",text)
 if not ok:failures+=1
func frames(n: int) -> void:
 for i in n:await process_frame
func run() -> void:
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 var services:=PlayerServices.new();root.add_child(services)
 var fake:=preload("res://tests/ability_refills/fake_game.gd").new();root.add_child(fake)
 fake.access_token="fixture-not-real";services.session.client=fake;services.ability_refills.client=fake
 services.session.user={"id":"00000000-0000-4000-8000-000000000081"};services.session._expires_at=Time.get_unix_time_from_system()+86400;services.session.set_process(false)
 var phase: Node3D=load("res://scenes/desert/phase_05.tscn").instantiate();root.add_child(phase);current_scene=phase
 phase._player.defense_charges=0
 phase._pause()
 check(paused and phase._paused,"a fase real pausa antes de abrir configurações")
 phase._session.show_settings();phase._session.show_refills();await frames(15)
 var panel: Control=phase._session._column.find_child("AbilityRefillPanel",true,false)
 var use: Button=panel.find_child("UseRefill_defense",true,false)
 check(use!=null and not use.disabled,"configurações oferecem defesa vazia e recarga guardada")
 use.pressed.emit();await frames(30)
 check(phase._player.defense_charges==3 and fake.quantity==1,"usar pela configuração completa a defesa até 3/3")
 check(phase._charge_snapshot().defense==3,"a carga cheia participa da continuidade existente entre fases")
 check(use.disabled and use.text=="ESTÁ CHEIA","defesa cheia fica bloqueada e identificada")
 var calls:=fake.refill_calls.size()
 use.pressed.emit();await frames(4)
 check(fake.refill_calls.size()==calls and panel.find_child("RefillFeedback",true,false).text.contains("Defesa está cheia"),"não há consumo nem RPC ao repetir a habilidade cheia")
 check(phase._hud.find_child("StoredRefills",true,false)==null,"estoque comprado não aparece no HUD")
 phase._resume()
 check(not paused and not phase._session.visible,"retorno fecha as configurações e retoma o jogo")
 phase.queue_free();await frames(4);services.queue_free();fake.queue_free();await frames(4)
 print("ABILITY_REFILLS_PAUSE checks=",checks," failures=",failures)
 quit(1 if failures else 0)
