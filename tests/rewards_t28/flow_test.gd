extends SceneTree
## T28: a central de resgates renderiza estado gratuito/resgatado/skins sem rede.
## godot --headless --path . --script res://tests/rewards_t28/flow_test.gd
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error("T28_REWARDS_FAIL " + message)
		quit(1)
		assert(value, message)


func _run() -> void:
	var services := PlayerServices.new()
	root.add_child(services)
	await process_frame
	# Sessão sintética apenas neste runner headless. Nenhuma requisição é feita.
	services.session.user = {"id": "00000000-0000-4000-8000-000000000001"}
	services.client.access_token = "fixture-not-a-real-token"
	# Evita o _process() da sessão invalidar imediatamente o token sintético.
	services.session._expires_at = Time.get_unix_time_from_system() + 3600.0
	services.rewards.campaign = {"id": "fixture_campaign", "title": "OFICIAIS GRÁTIS", "subtitle": "4 decks",
		"description": "Uma campanha para todos os jogadores."}
	services.rewards.offers = [
		{"id": "deck_nostalgia_web", "kind": "deck", "item_id": "nostalgia_web",
			"title": "Nostalgia Web", "description": "Dez cartas novas para resgatar.", "claimed": false, "price": 0},
		{"id": "deck_pinturas", "kind": "deck", "item_id": "pinturas",
			"title": "Pinturas", "description": "Arte em cartas.", "claimed": true, "price": 0},
		{"id": "skin_future_test", "kind": "skin", "item_id": "skin_future_test",
			"title": "Skin de teste", "description": "Oferta futura sem desbloqueio.", "claimed": false, "price": 0}]
	services.rewards.state = "success"
	services.rewards.seen = true
	check(not services.rewards.is_deck_claimed("nostalgia_web"), "não resgatado antes de confirmar")
	check(services.rewards.is_deck_claimed("pinturas"), "resgate de outra carta preservado")
	check(services.rewards.pending_count() == 2, "dois itens pendentes, incluindo futura skin")
	var overlay := NewsOverlay.new()
	root.add_child(overlay)
	await process_frame
	var claim := overlay.find_child("Claim_deck_nostalgia_web", true, false) as Button
	var owned := overlay.find_child("Claim_deck_pinturas", true, false) as Button
	check(claim != null and not claim.disabled and claim.text == "RESGATAR GRÁTIS", "botão gratuito ativo")
	check(owned != null and owned.disabled and owned.text.contains("RESGATADO"), "resgatado sem novo clique")
	# T29: presentes já garantidos e uma única abertura cerimonial.
	services.rewards.revealed = false
	services.rewards.changed.emit()
	await process_frame
	var gift_button := overlay.find_child("RedeemGiftBundle", true, false) as Button
	check(gift_button != null and not gift_button.disabled, "primeira entrada permite resgatar o pacote uma vez")
	owned = overlay.find_child("Claim_deck_pinturas", true, false) as Button
	check(owned != null and owned.disabled and owned.text == "INCLUSO NO PACOTE", "item já pertence à conta antes de abrir")
	services.rewards.revealed = true
	services.rewards.changed.emit()
	await process_frame
	check(overlay.find_child("RedeemGiftBundle", true, false) == null, "nunca pedir resgate de novo após abrir")
	owned = overlay.find_child("Claim_deck_pinturas", true, false) as Button
	check(owned != null and owned.disabled and owned.text.contains("RESGATADO"), "reabertura mostra posse permanente")
	check(overlay.find_child("CloseNews", true, false) != null, "botão fechar acessível")
	var skin := overlay.find_child("TabSkin", true, false) as Button
	check(skin != null, "aba skins preparada")
	skin.pressed.emit()
	await process_frame
	var grid := overlay.find_child("RewardOffers", true, false) as GridContainer
	check(grid != null and grid.get_child_count() == 1, "uma skin futura listada")
	var future_claim := overlay.find_child("Claim_skin_future_test", true, false) as Button
	check(future_claim != null and future_claim.disabled and future_claim.text == "EM BREVE", "skin futura sem resgate prematuro")
	var decks := overlay.find_child("TabDeck", true, false) as Button
	check(decks != null, "voltar para decks")
	decks.pressed.emit()
	await process_frame
	check(overlay.find_child("Claim_deck_nostalgia_web", true, false) != null, "deck ainda resgatável")
	services.rewards.offers[0]["claimed"] = true
	services.rewards.changed.emit()
	await process_frame
	claim = overlay.find_child("Claim_deck_nostalgia_web", true, false) as Button
	check(claim != null and claim.disabled and services.rewards.is_deck_claimed("nostalgia_web"), "posse confirmada altera visual")
	services.rewards.clear()
	check(not services.rewards.is_deck_claimed("nostalgia_web"), "troca de conta limpa a posse em memória")
	overlay.queue_free()
	services.queue_free()
	await process_frame
	print("T28_REWARDS_PASS ", checks, " verificações (fixture local sem HTTP)")
	quit(0)
