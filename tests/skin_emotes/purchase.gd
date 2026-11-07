extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value: failures+=1
func settle() -> void:
	for i in 10: await process_frame
func run() -> void:
	root.size=Vector2i(1672,941)
	var services := PlayerServices.new()
	root.add_child(services)
	var fake := preload("res://tests/skin_emotes/fake_game.gd").new()
	root.add_child(fake)
	fake.access_token="fixture-not-real"
	services.client=fake;services.session.client=fake
	services.emote_shop.client=fake;services.wallet.client=fake
	services.session.set_process(false)
	services.session.user={"id":"00000000-0000-4000-8000-000000000011"}
	services.session._expires_at=Time.get_unix_time_from_system()+86400
	var shop := services.emote_shop
	var result := await shop.refresh()
	check(result.ok and shop.product("dance_01").price_coins=="100","preço vem do catálogo do servidor")
	fake.purchase_code="insufficient_funds"
	result=await shop.buy("dance_01",100)
	check(not result.ok and result.code=="insufficient_funds" and not shop.product("dance_01").owned,"saldo insuficiente não confirma posse")
	fake.purchase_code="";fake.lose_response=true
	result=await shop.buy("dance_01",100)
	check(not result.ok and not shop.product("dance_01").owned,"resposta perdida não exibe compra confirmada")
	var request: String=fake.purchase_calls.back().p_request
	result=await shop.buy("dance_01",100)
	check(result.ok and result.data.already_owned and fake.coins==150,"repetir após perda da resposta não cobra novamente")
	check(fake.purchase_calls.back().p_request==request,"nova tentativa reutiliza a chave de idempotência")
	check(shop.product("dance_01").owned,"catálogo confirma emote adquirido na conta")
	fake.owned=false;fake.coins=250;shop.clear()
	await shop.refresh()
	fake.shop_code="network"
	result=await shop.buy("dance_01",100)
	check(result.ok and shop.product("dance_01").owned,"recibo confirmado preserva a posse se a releitura falhar")
	fake.shop_code=""
	fake.owned=false;fake.coins=250;shop.clear()
	var screen: Control=load("res://scenes/skins/skins_panel.tscn").instantiate()
	root.add_child(screen);screen._shop_item="dance_01";screen._generating=true;screen.open("cowboy")
	screen._choose_cosmetic_mode("shop");await settle()
	screen.find_child("PreviewDanceMovement",true,false).pressed.emit()
	screen.find_child("BuyEmotePreview",true,false).pressed.emit();await settle()
	var confirm: Button=screen.find_child("ConfirmEmotePurchase",true,false)
	check(not confirm.disabled and confirm.text.contains("100"),"confirmação mostra preço de 100 moedas e saldo suficiente")
	var count := fake.purchase_calls.size()
	fake.hold_purchase=true
	confirm.pressed.emit();confirm.pressed.emit();await settle()
	check(fake.purchase_calls.size()==count+1 and confirm.disabled,"dois cliques geram uma compra em andamento")
	fake.hold_purchase=false;await settle()
	check(services.wallet.data.coins=="150" and shop.product("dance_01").owned,"sucesso atualiza carteira e posse com leituras do servidor")
	check(confirm.disabled and confirm.text=="ADQUIRIDO","sucesso não permite repetir a cobrança")
	check(not screen.find_child("BuyEmotePreview",true,false).disabled and screen.find_child("BuyEmotePreview",true,false).text=="USAR EMOTE","item adquirido oferece usar, sem nova compra")
	screen._close_purchase();await settle()
	fake.owned=false;fake.available=false;shop.clear()
	screen._rebuild_gallery()
	screen.find_child("BuyEmotePreview",true,false).pressed.emit();await settle()
	check(screen.find_child("ConfirmEmotePurchase",true,false).disabled,"produto sem movimento real permanece fora de venda")
	services.session.user={};services.session.changed.emit();await settle()
	check(screen.find_child("EmotePurchasePreview",true,false)==null and shop.data.is_empty(),"troca de sessão fecha a confirmação e limpa a coleção")
	screen.queue_free();services.queue_free();fake.queue_free();await settle()
	print("EMOTE_PURCHASE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
