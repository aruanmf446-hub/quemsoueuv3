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
	var header_title := overlay.find_child("HeaderTitle", true, false) as Label
	check(header_title != null and header_title.size.x > 150 and header_title.size.y > 18, "texto do cabeçalho legível e com dimensões reais")
	var heading_row := overlay.find_child("RewardHeader", true, false) as HBoxContainer
	check(heading_row != null and heading_row.size.y < 100, "cabeçalho não pode ocupar a janela inteira")
	check(header_title.size.y < 80, "título horizontal sem letras empilhadas")
	var banner_frame := overlay.find_child("RewardBanner", true, false) as Panel
	check(banner_frame != null and banner_frame.get_global_rect().end.y < 430, "banner situado acima dos cards em desktop")
	var headline := overlay.find_child("CampaignHeadline", true, false) as Label
	check(headline != null and headline.size.x > 100 and headline.size.y > 16, "texto do banner com área visível")
	var first_title := overlay.find_child("RewardTitle", true, false) as Label
	check(first_title != null and first_title.size.x > 75 and first_title.size.y > 13, "nome da recompensa renderizável")
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
		DisplayServer.window_set_size(resolution)
		root.content_scale_size = resolution
		root.size = resolution
		await _frames()
		overlay._layout()
		await _frames()
		var modal := overlay.find_child("RewardWindow", true, false) as Panel
		var viewport := Vector2(root.get_visible_rect().size)
		print("T30_VIEWPORT ", resolution, " actual=", viewport, " modal=", modal.position, " ", modal.size)
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
	# T30 leitura histórica: 4 decks + 7 skins da T29, somados ao Diva Pop atual.
	services.rewards.offers.clear()
	for item_id: String in ["lendas_urbanas", "nostalgia_web", "sol_nascente", "pinturas", "diva_pop"]:
		var record := _make_offer("deck_" + item_id, "deck", item_id, true)
		record["campaign_id"] = "diva_pop_2026" if item_id == "diva_pop" else "decks_oficiais_2026"
		record["created_at"] = "2026-11-03T10:00:00Z" if item_id == "diva_pop" else "2026-10-20T10:00:00Z"
		record["revealed"] = false
		services.rewards.offers.append(record)
	for skin_id: String in ["cowboy", "michelly", "rodrigo", "lorena", "gus", "lana", "halloween"]:
		var record := _make_offer("skin_" + skin_id, "skin", skin_id, true)
		record["campaign_id"] = "decks_oficiais_2026"
		record["created_at"] = "2026-10-20T10:00:00Z"
		record["revealed"] = false
		services.rewards.offers.append(record)
	services.rewards.campaign = {"id": "diva_pop_2026", "title": "Diva Pop", "subtitle":"Oficial"}
	services.rewards.revealed = false
	services.rewards.inventory_state = "success"
	services.rewards.state = "success"
	overlay._tab = "deck"
	services.rewards.changed.emit()
	await _frames()
	container = overlay.find_child("RewardOffers", true, false) as GridContainer
	check(container.get_child_count() == 5, "catálogo real: cinco decks, incluindo Diva Pop")
	var past_claim := overlay.find_child("Claim_deck_lendas_urbanas", true, false) as Button
	check(past_claim != null and past_claim.disabled and past_claim.text == "RESGATADO", "presente de campanha anterior mantém posse")
	var new_claim := overlay.find_child("Claim_deck_diva_pop", true, false) as Button
	check(new_claim != null and new_claim.disabled and new_claim.text == "INCLUSO NO PACOTE", "campanha atual preserva ação de revelação")
	check(container.get_child(0).name == "Offer_deck_diva_pop", "ordenação inicial por data real mais recente")
	var sorter := overlay.find_child("RewardSort", true, false) as OptionButton
	check(sorter != null, "ordenar somente quando datas reais disponíveis")
	sorter.item_selected.emit(1)
	await _frames()
	container = overlay.find_child("RewardOffers", true, false) as GridContainer
	check(container.get_child(0).name != "Offer_deck_diva_pop", "ordenação mais antiga funcional")
	skin = overlay.find_child("TabSkin", true, false) as Button
	skin.pressed.emit()
	await _frames()
	container = overlay.find_child("RewardOffers", true, false) as GridContainer
	check(container.get_child_count() == 7, "sete skins iniciais presentes no inventário real")
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
