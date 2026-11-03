extends SceneTree
## UI fixture T30: sem HTTP; todas as transições funcionais e dimensões reais.
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, explanation: String) -> void:
	checks += 1
	if not ok:
		push_error("T30_REWARDS_FAIL: " + explanation)
		quit(1)
		assert(ok, explanation)

func _make_offer(id: String, kind: String, item: String, claimed: bool, enabled: bool = true) -> Dictionary:
	return {"id": id, "kind": kind, "item_id": item, "title": item.capitalize(),
		"description": "Uma recompensa oficial do Quem Sou Eu.", "claimed": claimed, "claim_enabled": enabled, "price": 0}

func _frames(n: int = 3) -> void:
	for i in n: await process_frame

func _run() -> void:
	var services := PlayerServices.new()
	root.add_child(services)
	await _frames()
	services.session.user = {"id": "00000000-0000-4000-8000-000000000001"}
	services.client.access_token = "offline-fixture"
	services.session._expires_at = Time.get_unix_time_from_system() + 3600.0
	services.rewards.state = "success"
	services.rewards.campaign = {"id": "test_t30", "title": "Presentes Oficiais", "subtitle": "Coleções da equipe",
		"description": "Confira seus presentes com segurança."}
	services.rewards.offers = [
		_make_offer("deck_lendas_urbanas", "deck", "lendas_urbanas", true),
		_make_offer("deck_nostalgia_web", "deck", "nostalgia_web", true),
		_make_offer("deck_sol_nascente", "deck", "sol_nascente", true),
		_make_offer("deck_pinturas", "deck", "pinturas", false),
		_make_offer("skin_cowboy", "skin", "cowboy", true),
		_make_offer("skin_michelly", "skin", "michelly", true),
		_make_offer("skin_rodrigo", "skin", "rodrigo", true),
		_make_offer("skin_lorena", "skin", "lorena", true),
		_make_offer("skin_gus", "skin", "gus", true),
		_make_offer("skin_lana", "skin", "lana", true),
		_make_offer("skin_halloween", "skin", "halloween", true),
		_make_offer("skin_unreleased", "skin", "unreleased", false, false)
	]
	services.rewards.seen = true
	services.rewards.revealed = false
	var background := Button.new()
	background.name = "LobbyInputFixture"
	root.add_child(background)
	var overlay := NewsOverlay.new()
	overlay.name = "NewsOverlay"
	root.add_child(overlay)
	await _frames()
	check(overlay.find_child("RewardWindow", true, false) != null, "modal interativo existe")
	var shield := overlay.find_child("NewsInputShield", true, false) as ColorRect
	check(shield != null and shield.mouse_filter == Control.MOUSE_FILTER_STOP and shield.color.a < 1.0, "lobby protegido com fundo translúcido")
	check(overlay.find_child("CloseNews", true, false) != null, "fechar tem botão X")
	check(overlay.find_child("BackNews", true, false) == null, "sem botão Voltar visível")
	check(overlay.find_child("RewardBanner", true, false) != null, "banner da campanha existe")
	check(overlay.find_child("RewardOffers", true, false) != null, "grade nativa existe")
	var container := overlay.find_child("RewardOffers", true, false) as GridContainer
	check(container.get_child_count() == 4, "somente os quatro decks reais do fixture")
	check(overlay.find_child("CardCount", true, false) != null, "contador de cartas usa o catálogo local")
	var received := overlay.find_child("Claim_deck_lendas_urbanas", true, false) as Button
	check(received != null and received.disabled and received.text == "INCLUSO NO PACOTE", "item concedido sem revelação")
	var claim := overlay.find_child("Claim_deck_pinturas", true, false) as Button
	check(claim != null and not claim.disabled and claim.text == "RESGATAR GRÁTIS", "resgate individual disponível sem inventar posse")
	check(overlay.find_child("RedeemGiftBundle", true, false) != null, "pacote pode ser revelado uma vez")
	var skin := overlay.find_child("TabSkin", true, false) as Button
	skin.pressed.emit()
	await _frames()
	container = overlay.find_child("RewardOffers", true, false) as GridContainer
	check(container.get_child_count() == 8, "skin tab separa sete iniciais e futura indisponível")
	var future := overlay.find_child("Claim_skin_unreleased", true, false) as Button
	check(future != null and future.disabled and future.text == "EM BREVE", "skin não publicada não é resgatável")
	services.rewards.revealed = true
	services.rewards.changed.emit()
	await _frames()
	check(overlay.find_child("RedeemGiftBundle", true, false) == null, "pacote revelado não pede resgate novamente")
	check(overlay.find_child("GiftsReceived", true, false) != null, "estado resgatado acessível")
	var owned := overlay.find_child("Claim_skin_cowboy", true, false) as Button
	check(owned != null and owned.disabled and owned.text == "RESGATADO", "skin possuída confirmada")
	for resolution: Vector2i in [Vector2i(1920,1080), Vector2i(1672,941),
		Vector2i(1280,720), Vector2i(844,390), Vector2i(640,360)]:
		root.size = resolution
		overlay._layout()
		await _frames()
		var modal := overlay.find_child("RewardWindow", true, false) as Panel
		var viewport := Vector2(resolution)
		check(modal.position.x >= 0 and modal.position.y >= 0 and
			modal.position.x + modal.size.x <= viewport.x + 1 and
			modal.position.y + modal.size.y <= viewport.y + 1,
			"modal dentro do viewport " + str(resolution))
		check(modal.position.y > 0 and modal.position.y + modal.size.y < viewport.y,
			"cenário preservado acima e abaixo " + str(resolution))
		container = overlay.find_child("RewardOffers", true, false) as GridContainer
		check(container != null and container.columns >= 1 and container.columns <= 4,
			"grade responsiva " + str(resolution))
	var more := overlay.find_child("MoreNews", true, false) as Button
	more.pressed.emit()
	await _frames()
	check(overlay.find_child("OtherNews", true, false) != null, "carrossel legado abre sobre a janela")
	overlay._close_top()
	await _frames()
	check(overlay.find_child("OtherNews", true, false) == null and overlay.find_child("RewardWindow", true, false) != null,
		"ao fechar notícias, os presentes permanecem")
	services.rewards.state = "loading"
	services.rewards.changed.emit()
	await _frames()
	check(overlay.find_child("NewsMessage", true, false) != null, "carregamento tem estado real")
	services.rewards.state = "error"
	services.rewards.changed.emit()
	await _frames()
	check(overlay.find_child("RetryNews", true, false) != null, "erro oferece tentar novamente")
	services.rewards.clear()
	await _frames()
	check(services.rewards.offers.is_empty(), "troca de conta limpa as ofertas")
	overlay._close_top()
	await _frames()
	check(not is_instance_valid(overlay), "fechamento retorna sem alterar o menu")
	background.queue_free()
	services.queue_free()
	print("T30_REWARDS_PASS ", checks, " checks (offline Godot fixture)")
	quit(0)
