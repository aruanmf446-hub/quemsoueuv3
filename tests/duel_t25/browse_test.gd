extends SceneTree
## T25: navegador de servidores do Mata-Mata (código, jogadores, deck, status, Entrar).
## Cliente FALSO com salas de demonstração; sem rede e sem Supabase.
var failures := 0
var checks := 0
const Fake := preload("res://tests/duel_t25/fake_rooms.gd")


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func _frames(count := 6) -> void:
	for i in count: await process_frame


func _codes(screen: Node) -> Array:
	var rows := screen.find_child("Rows", true, false)
	return rows.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Room_") and not n.is_queued_for_deletion()).map(func(n: Node) -> String: return str(n.get_meta("code")))


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var services := PlayerServices.new()
	root.add_child(services)
	await _frames(2)
	services.session.user = {"id": "00000000-0000-4000-8000-000000000925", "email": "fixture@example.invalid"}
	services.session.client.access_token = "fixture-token-sem-rede"
	services.session._expires_at = Time.get_unix_time_from_system() + 86400.0
	var fake: SupabaseClient = Fake.new()
	root.add_child(fake)
	services.duel.client = fake
	fake.rooms = [Fake.room("QSE482", 7, 10, ["Lendas Urbanas"]), Fake.room("QSE915", 4, 10, ["Deck de demonstração", "Outro"]),
		Fake.room("QSE578", 2, 8, ["Deck de demonstração"]), Fake.room("QSE206", 10, 10, ["Cheia"])]
	var screen := load("res://scenes/player/duel.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	await _frames(10)
	# Cabeçalho e ações.
	check(screen.heading.text == "Mata-Mata" and screen.find_child("ModeIcon", true, false).visible and screen.find_child("ModeTag", true, false).visible, "cabeçalho: espadas, título e SERVIDORES ONLINE")
	check(screen.find_child("CreateRoom", true, false) != null and screen.find_child("LocalMatch", true, false) != null, "Criar sala e Partida local")
	check(screen.find_child("InviteCode", true, false) == null, "campo grande 'Código do convite' removido")
	check((screen.find_child("RoomSearch", true, false) as LineEdit).placeholder_text.contains("código"), "busca pelo código")
	check(screen.find_child("OnlyOpen", true, false) != null and screen.find_child("RefreshRooms", true, false) != null, "Só com vaga e Atualizar")
	check(fake.calls.any(func(c: Array) -> bool: return c[0] == "qse_duel_list" and c[1].p_only_open == true), "lista pede só salas com vaga")
	# Linhas.
	check(screen.find_child("ServerColumns", true, false) != null, "cabeçalho das colunas")
	check(_codes(screen) == ["QSE482", "QSE915", "QSE578"], "sala cheia (10/10) não aparece")
	var row := screen.find_child("Room_QSE482", true, false)
	check((row.find_child("Code", true, false) as Label).text == "QSE482", "código é o título da linha")
	check(not str(row.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)).contains("nome técnico"), "nome técnico nunca aparece")
	check((row.find_child("Players", true, false).find_child("Value", true, false) as Label).text == "7/10", "jogadores reais")
	check((screen.find_child("Room_QSE578", true, false).find_child("Players", true, false).find_child("Value", true, false) as Label).text == "2/8", "capacidade real da sala (não fixa em 10)")
	check((screen.find_child("Room_QSE915", true, false).find_child("Deck", true, false).find_child("Value", true, false) as Label).text.ends_with("+1"), "vários decks: nome principal +N")
	check((row.find_child("Status", true, false).find_child("Value", true, false) as Label).text == "Aguardando", "status neutro")
	check(screen._selected_code == "QSE482", "primeira sala selecionada")
	# Seleção.
	var other := screen.find_child("Room_QSE915", true, false) as Control
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	other.gui_input.emit(click)
	await _frames(3)
	check(screen._selected_code == "QSE915", "clique seleciona outra sala (uma por vez)")
	# Busca pelo código (local, sem nova consulta).
	var before: int = fake.calls.size()
	var search := screen.find_child("RoomSearch", true, false) as LineEdit
	search.text = "qse5"
	search.text_changed.emit("qse5")
	await _frames(3)
	check(_codes(screen) == ["QSE578"] and fake.calls.size() == before, "busca parcial pelo código, sem consulta extra")
	search.text = "ZZZ999"
	search.text_changed.emit("ZZZ999")
	await _frames(3)
	check(screen.find_child("ListMessage", true, false) != null and screen.find_child("DirectJoin", true, false) != null, "sem resultado: entrar pelo código (salas privadas)")
	search.text = ""
	search.text_changed.emit("")
	await _frames(3)
	# Entrar: sala ficou cheia → erro e lista atualizada; sem cliques duplicados.
	var lists: int = fake.calls.filter(func(c: Array) -> bool: return c[0] == "qse_duel_list").size()
	var join := screen.find_child("Room_QSE482", true, false).find_child("JoinRoom", true, false) as Button
	join.pressed.emit()
	join.pressed.emit()
	await _frames(10)
	check(fake.joins == 1, "clique repetido não duplica a entrada")
	check(fake.calls.filter(func(c: Array) -> bool: return c[0] == "qse_duel_list").size() > lists, "sala indisponível: lista atualizada")
	# Atualizar e vazio.
	fake.rooms = []
	(screen.find_child("RefreshRooms", true, false) as Button).pressed.emit()
	await _frames(8)
	var message := screen.find_child("ListMessage", true, false)
	check(message != null and (message.get_child(0) as Label).text == "Nenhuma sala disponível no momento.", "estado sem salas")
	fake.fail = true
	(screen.find_child("RefreshRooms", true, false) as Button).pressed.emit()
	await _frames(8)
	check(screen.find_child("RetryRooms", true, false) != null, "falha de rede: tentar novamente")
	fake.fail = false
	# Android landscape.
	fake.rooms = [Fake.room("QSE482", 7, 10, ["Lendas Urbanas"])]
	root.size = Vector2i(844, 390)
	await _frames(10)
	screen._load_rooms(true)
	await _frames(10)
	var compact_row := screen.find_child("Room_QSE482", true, false) as Control
	var enter := compact_row.find_child("JoinRoom", true, false) as Control
	check(compact_row != null and enter.get_global_rect().end.x <= screen.get_global_rect().end.x + 1, "844×390: código e Entrar visíveis sem rolagem lateral")
	# Layout padrão: o mesmo cabeçalho em qualquer tela (só escala por igual).
	check(screen.find_child("ModeTag", true, false).visible and not screen._compact(), "844×390: mesmo layout do desktop (escala padrão)")
	# Sem conta: partida local continua disponível.
	services.session.user = {}
	screen.render()
	await _frames(3)
	check(screen.find_child("LocalMatch", true, false) != null and screen.find_child("Rows", true, false) == null, "sem conta: só partida local")
	print("T25_MATA_MATA checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
