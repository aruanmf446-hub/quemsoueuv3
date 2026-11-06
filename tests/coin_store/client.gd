extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value: failures+=1
func settle() -> void:
	for i in 8: await process_frame
func run() -> void:
	root.size=Vector2i(1672,941)
	var services := PlayerServices.new();root.add_child(services)
	var fake := preload("res://tests/coin_store/fake_game.gd").new();root.add_child(fake)
	fake.access_token="fixture-not-real"
	services.client=fake;services.session.client=fake;services.wallet.client=fake
	services.coin_store.client=fake
	services.session.user={"id":"00000000-0000-4000-8000-000000000091"}
	services.session._expires_at=Time.get_unix_time_from_system()+86400
	services.session.set_process(false)
	var store := services.coin_store
	check((await store.refresh()).ok,"catálogo confirmado pelo servidor")
	var pack: Dictionary=store.data.packages[0]
	check(not store.valid_data({"enabled":true,"live_mode":true,"packages":[{"id":"x","name":"x","coins":"1","price_brl_cents":99.5}],"orders":[]}),"preço com fração de centavo recusado")
	check(not CoinStoreService.safe_checkout("https://checkout.stripe.com.evil.example/c/pay/x"),"domínio parecido com Stripe recusado")
	fake.checkout_error="network"
	check((await store.create_checkout(pack)).code=="network","falha de rede não inventa sucesso")
	fake.checkout_error=""
	var result := await store.create_checkout(pack)
	check(result.ok and fake.checkout_calls[0].request_id==fake.checkout_calls[1].request_id,"retentativa reutiliza a intenção persistida")
	check(fake.coins==250,"gerar checkout não credita moedas")
	fake.checkout_url="https://evil.example/pay"
	check((await store.create_checkout(pack)).code=="invalid_contract","URL insegura recusada pelo cliente")
	fake.checkout_url="https://checkout.stripe.com/c/pay/fixture"
	var first_request: String=fake.checkout_calls[0].request_id
	fake.orders=[{"id":"00000000-0000-4000-8000-0000000000aa","request_id":first_request,"coins":"500","amount":990,"status":"test_paid","live_mode":false,"created_at":"2026-11-07T10:00:00Z"}]
	await store.refresh();await store.create_checkout(store.data.packages[0])
	check(fake.checkout_calls.back().request_id!=first_request,"compra consumível concluída permite uma nova intenção")
	fake.enabled=false;await store.refresh()
	check((await store.create_checkout(pack)).code=="payments_unavailable","loja desativada não inicia cobrança")
	fake.enabled=true;await store.refresh()
	var wallet: Control=load("res://scenes/player/wallet.tscn").instantiate();root.add_child(wallet)
	wallet.show_screen({"tab":"coins"});await settle()
	check(wallet.find_child("CoinPack_fixture_pack",true,false)!=null,"pacote do servidor aparece na carteira")
	wallet.find_child("CoinPack_fixture_pack",true,false).pressed.emit();await settle()
	check(wallet.find_child("OpenStripeCheckout",true,false)!=null and not wallet.find_child("OpenStripeCheckout",true,false).disabled,"Stripe abre só por gesto direto após checkout pronto")
	check(wallet.find_child("CoinCheckoutFeedback",true,false).text.contains("volte ao jogo"),"orientação para voltar sem fingir confirmação")
	check(wallet.handle_back() and wallet.find_child("CoinCheckoutPanel",true,false).is_queued_for_deletion(),"voltar fecha somente o pagamento")
	await settle()
	fake.checkout_hold=true
	wallet.find_child("CoinPack_fixture_pack",true,false).pressed.emit();await settle()
	check((await store.create_checkout(pack)).code=="request_in_progress","duplo toque durante HTTP bloqueado")
	services.session.user={"id":"00000000-0000-4000-8000-000000000092"}
	fake.generation+=1
	services.session.changed.emit()
	fake.checkout_hold=false;await settle()
	check(wallet.find_child("CoinCheckoutPanel",true,false)==null,"troca de conta descarta checkout anterior")
	check(fake.coins==250,"UI e troca de conta não alteram saldo")
	var cfg := ConfigFile.new();cfg.load(CoinStoreService.INTENTS)
	for owner in ["00000000-0000-4000-8000-000000000091","00000000-0000-4000-8000-000000000092"]:
		if cfg.has_section(owner): cfg.erase_section(owner)
	cfg.save(CoinStoreService.INTENTS)
	wallet.queue_free();services.queue_free();fake.queue_free();await settle()
	print("STRIPE_CLIENT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
