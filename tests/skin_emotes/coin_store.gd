extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value: failures+=1
func settle() -> void:
	for i in 6: await process_frame
func run() -> void:
	root.size=Vector2i(1672,941)
	var services := PlayerServices.new()
	root.add_child(services)
	var fake := preload("res://tests/skin_emotes/fake_game.gd").new()
	root.add_child(fake)
	fake.access_token="fixture-not-real";fake.coins=50
	services.client=fake;services.session.client=fake
	services.wallet.client=fake;services.emote_shop.client=fake
	services.coin_store.client=fake
	services.session.user={"id":"00000000-0000-4000-8000-000000000011"}
	services.session._expires_at=Time.get_unix_time_from_system()+86400
	services.session.set_process(false)
	await services.wallet.refresh()
	var wallet: Control=load("res://scenes/player/wallet.tscn").instantiate()
	root.add_child(wallet);wallet.show_screen();await settle()
	check(wallet.find_child("BuyCoins",true,false)!=null,"carteira oferece Comprar moedas")
	wallet.find_child("BuyCoins",true,false).pressed.emit();await settle()
	check(wallet.heading.text=="Comprar moedas" and wallet.find_child("CoinStoreBalance",true,false).text.contains("50"),"recarga mostra saldo da conta")
	check(wallet.find_child("CoinPackagesPending",true,false)!=null,"pacotes ainda não definidos não ganham preços fictícios")
	check(wallet.handle_back() and wallet.heading.text=="Minha carteira","voltar da seção interna retorna à carteira")
	wallet.show_screen({"tab":"coins"});await settle()
	check(not wallet.handle_back(),"entrada direta permite voltar à loja anterior")
	wallet.queue_free();await settle()
	var skins: Control=load("res://scenes/skins/skins_panel.tscn").instantiate()
	root.add_child(skins);skins._generating=true;skins.open("cowboy")
	skins._choose_cosmetic_mode("shop");await settle()
	skins.find_child("PreviewDanceMovement",true,false).pressed.emit()
	skins.find_child("BuyEmotePreview",true,false).pressed.emit();await settle()
	check(skins.find_child("ConfirmEmotePurchase",true,false).disabled,"saldo insuficiente bloqueia compra do item")
	var routes: Array=[]
	skins.navigate_requested.connect(func(route: String,params: Dictionary)->void:routes.append([route,params]))
	skins.find_child("BuyCoinsFromEmote",true,false).pressed.emit();await settle()
	check(routes==[["wallet",{"tab":"coins"}]],"comprar moedas abre a recarga, separada da compra de emotes")
	check(fake.coins==50 and fake.purchase_calls.is_empty(),"abrir recarga não credita nem debita moedas")
	skins.queue_free();services.queue_free();fake.queue_free();await settle()
	print("COIN_STORE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
