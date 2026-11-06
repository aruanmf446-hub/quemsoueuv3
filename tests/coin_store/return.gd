extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value: failures+=1
func run() -> void:
	var boot: Node=load("res://scenes/menu/menu_boot.tscn").instantiate()
	root.add_child(boot)
	for i in 30:
		await process_frame
		if current_scene!=null and current_scene.name=="MainMenu": break
	var menu: Control=current_scene
	var services: PlayerServices=menu.get_node("Services")
	var nav: NavigationManager=menu.get_node("Navigation")
	nav.back();await create_timer(0.25).timeout
	menu._coin_return_order="00000000-0000-4000-8000-0000000000aa"
	menu._resume_coin_checkout()
	check(nav._history.is_empty() and not menu._coin_return_order.is_empty(),"retorno de pagamento aguarda login")
	var fake := preload("res://tests/skin_emotes/fake_game.gd").new();root.add_child(fake)
	fake.access_token="fixture-not-real"
	services.session.client=fake
	services.session.user={"id":"00000000-0000-4000-8000-000000000091"}
	services.session._expires_at=Time.get_unix_time_from_system()+86400
	services.session.set_process(false)
	services.wallet.client=fake;services.coin_store.client=fake
	menu._resume_coin_checkout()
	check(nav._history.is_empty(),"retorno aguarda nickname próprio")
	services.profile.data={"user_id":services.session.user.id,"nickname":"Fixture Stripe"}
	services.session.needs_password_reset=true
	menu._resume_coin_checkout()
	check(nav._history.is_empty(),"recovery tem prioridade sobre a carteira")
	services.session.needs_password_reset=false
	menu._web_invite_intent.capture(true)
	menu._resume_coin_checkout()
	check(nav._history.is_empty(),"convite pendente mantém prioridade")
	menu._web_invite_intent=WebInviteIntent.new()
	menu._resume_coin_checkout();await create_timer(0.6).timeout
	check(not nav._history.is_empty() and nav._history.back().route=="wallet" and nav._history.back().params.tab=="coins","retorno abre a carteira sem declarar pagamento aprovado")
	check(fake.coins==250 and menu._coin_return_order.is_empty(),"parâmetro de retorno não credita moedas")
	print("STRIPE_RETURN checks=",checks," failures=",failures)
	quit(1 if failures else 0)
