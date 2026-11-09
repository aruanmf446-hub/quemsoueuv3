extends SceneTree
## T26: Criar sala — listas suspensas fechadas, galeria de decks e resumo ao vivo.
var failures := 0
var checks := 0
var screen: PlayerScreen


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func _frames(count := 6) -> void:
	for i in count: await process_frame


func _summary(label: String) -> String:
	var row := screen.find_child("Summary_" + label.replace(" ", "_"), true, false)
	return (row.find_child("Value", true, false) as Label).text if row != null else ""


func _pick(id: String, selected: bool) -> void:
	var card := screen.find_child("DeckChoice_" + id, true, false) as Button
	card.toggled.emit(selected)
	(card.find_child("AcceptSelection", true, false) as Button).pressed.emit()
	await _frames(3)


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var services := PlayerServices.new()
	root.add_child(services)
	await _frames(2)
	services.session.user = {"id": "00000000-0000-4000-8000-000000000926", "email": "fixture@example.invalid"}
	services.session.client.access_token = "fixture-token-sem-rede"
	services.session._expires_at = Time.get_unix_time_from_system() + 86400.0
	var fake: SupabaseClient = load("res://tests/duel_t26/fake_game.gd").new()
	root.add_child(fake)
	services.duel.client = fake
	screen = load("res://scenes/player/duel.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	await _frames(6)
	(screen.find_child("CreateRoom", true, false) as Button).pressed.emit()
	await _frames(10)
	check(screen.get("_view") == "form", "Criar sala abre o formulário")
	check(screen.find_child("ConfigPanel", true, false) != null and screen.find_child("DeckPanel", true, false) != null and screen.find_child("FormSummary", true, false) != null, "três áreas: configuração, decks e resumo")
	check(screen.find_children("*", "SpinBox", true, false).is_empty() and screen.find_children("*", "LineEdit", true, false).filter(func(n: LineEdit) -> bool: return n.name != "DeckSearch" and n.is_visible_in_tree() and not n.is_queued_for_deletion()).is_empty(), "sem campos numéricos digitáveis")
	# Listas suspensas.
	var expected := {"max_players": [2, 20], "cards_per_player": [1, 6], "turn_seconds": [15, 180], "selection_seconds": [10, 120], "tiebreak_base": [4, 12], "tiebreak_per_player": [1, 4]}
	for key: String in expected:
		var picker := screen.find_child("Pick_" + key, true, false) as OptionButton
		var ids: Array = range(picker.item_count).map(func(i: int) -> int: return picker.get_item_id(i))
		check(picker != null and ids.min() >= expected[key][0] and ids.max() <= expected[key][1], "%s: opções dentro do limite do servidor %s" % [key, ids])
	var players := screen.find_child("Pick_max_players", true, false) as OptionButton
	check(players.get_item_id(players.selected) == 8, "valor atual preservado ao abrir")
	players.show_popup()
	await _frames(2)
	check(players.get_popup().visible, "lista abre")
	players.get_popup().hide()
	players.select(players.get_item_index(12))
	players.item_selected.emit(players.get_item_index(12))
	await _frames(3)
	check(_summary("Jogadores máximos") == "12", "resumo atualiza ao escolher")
	screen.set_form_value("turn_seconds", 90)
	await _frames(3)
	check(_summary("Tempo por turno") == "90 s", "tempo por turno no resumo")
	# Valor fora da lista não entra.
	screen.set_form_value("turn_seconds", 77)
	check(int(screen.get("_form").values.turn_seconds) == 90, "valor fora da lista ignorado")
	# Decks.
	check((screen.get("_form").decks as Array).is_empty(), "nenhum deck pré-selecionado")
	await _pick("lendas_urbanas", true)
	var terror := screen.find_child("DeckChoice_demo_terror", true, false) as Button
	await _pick("demo_terror", true)
	await _frames(3)
	check((screen.get("_form").decks as Array) == ["lendas_urbanas", "demo_terror"], "seleção múltipla preservada")
	check((screen.find_child("SummaryDeckName", true, false) as Label).text.contains("2 decks"), "resumo com os dois decks")
	await _pick("lendas_urbanas", false)
	await _frames(3)
	check((screen.get("_form").decks as Array) == ["demo_terror"], "remover um deck")
	await _pick("demo_terror", false)
	await _frames(3)
	check((screen.get("_form").decks as Array).is_empty(), "seleção pode ficar vazia antes de enviar")
	var search := screen.find_child("DeckSearch", true, false) as LineEdit
	search.text = "folc"
	search.text_changed.emit("folc")
	await _frames(3)
	var grid := screen.find_child("DeckChoices", true, false)
	check(grid.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size() == 1, "busca de decks")
	search.text = ""
	search.text_changed.emit("")
	check(screen.find_child("DeckTab_Comprados", true, false) == null, "Comprados oculto enquanto comércio está inativo")
	(screen.find_child("DeckTab_Meus_decks", true, false) as Button).pressed.emit()
	await _frames(3)
	check(screen.find_child("DeckEmpty", true, false) != null, "Meus decks: aviso legível sem conteúdo inventado")
	(screen.find_child("DeckTab_Todos", true, false) as Button).pressed.emit()
	await _frames(3)
	check(int(screen.get("_form").values.max_players) == 12, "trocar categoria não descarta escolhas")
	# Criar: envia os mesmos valores do resumo.
	await _pick("demo_terror", true)
	(screen.find_child("SubmitRoom", true, false) as Button).pressed.emit()
	await _frames(8)
	var sent: Dictionary = fake.created.get("p_settings", {})
	check(sent.get("max_players") == 12 and sent.get("turn_seconds") == 90 and sent.get("deck_ids") == ["demo_terror"] and fake.created.get("p_name") == "Mata-Mata", "criar envia os valores do resumo (inteiros) e nome técnico")
	# Cancelar.
	(screen.find_child("CancelForm", true, false) as Button).pressed.emit()
	await _frames(6)
	check(screen.get("_view") == "browse", "Cancelar volta ao navegador")
	print("T26_CRIAR_SALA checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
