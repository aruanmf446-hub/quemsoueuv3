extends SceneTree
## T24 cliente: Populares com qse_deck_stats, Recentes com published_at real e registro de partida.
var failures := 0
var checks := 0
var screen: Node


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func _frames(count := 6) -> void:
	for i in count: await process_frame


func _names() -> Array:
	var grid: Node = screen.find_child("DeckGrid", true, false)
	if grid == null: return []
	return grid.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Deck_")).map(func(n: Node) -> String: return str(n.name))


func _notice() -> String:
	var node := screen.find_child("DataNotice", true, false) as Label
	return node.text if node != null else ""


func _run() -> void:
	# Contrato do CATALOG: published_at válido entra; inválido é descartado.
	check(CatalogService._meta({"name": "X", "published_at": "2026-10-30T13:33:30Z"}).get("published_at") == "2026-10-30T13:33:30Z", "published_at do CATALOG aceito")
	check(not CatalogService._meta({"published_at": "ontem"}).has("published_at"), "published_at inválido descartado")
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await _frames(20)
	var nav: Node = menu.get_node("Navigation")
	if not nav.get("_history").is_empty() and nav.get("_history").back().route == "account":
		nav.back()
		await _frames(20)
	nav.open("deck_library", {})
	await _frames(20)
	screen = nav.get("_active")
	var fixture: Array[Dictionary] = load("res://tests/decks_t23/fixture.gd").entries()
	# Fixture com refs/datas: demo:0 mais popular; demo:2 mais recente.
	fixture[0].ref = "creator:demo0"
	fixture[1].ref = "creator:demo1"
	fixture[2].published = Time.get_unix_time_from_system() - 3600.0
	fixture[3].published = Time.get_unix_time_from_system() - 86400.0 * 4
	screen._demo_entries = fixture
	# Sem sessão: aviso honesto, ordem A–Z.
	screen._select_tab("Populares")
	await _frames()
	check(_notice().contains("Entre na sua conta"), "Populares sem sessão pede login")
	check(screen.find_child("Players30d", true, false) == null, "sem número inventado sem sessão")
	# Com sessão (cliente falso): ordena por score; score 0 no fim.
	var game: SupabaseClient = load("res://tests/decks_t24/fake_game.gd").new()
	root.add_child(game)
	game.stats = [
		{"deck_ref": "creator:demo0", "plays_30d": 9, "players_30d": 4, "favorites": 2, "score": 23},
		{"deck_ref": "creator:demo1", "plays_30d": 1, "players_30d": 1, "favorites": 0, "score": 3},
		{"deck_ref": "official:lendas_urbanas", "plays_30d": 0, "players_30d": 0, "favorites": 0, "score": 0}]
	screen._stats_client = game
	screen._stats_state = "idle"
	screen._render_library()
	await _frames(10)
	check(game.calls.any(func(c: Array) -> bool: return c[0] == "qse_deck_stats" and (c[1].p_refs as Array).has("official:lendas_urbanas")), "qse_deck_stats com official:<id>")
	var order := _names()
	check(order.slice(0, 2) == ["Deck_demo_0", "Deck_demo_1"], "Populares ordena por score")
	check(order.find("Deck_lendas_urbanas") > 1, "score 0 vai depois dos medidos")
	var players := screen.find_child("Deck_demo_0", true, false).find_child("Players30d", true, false) as Label
	check(players != null and players.text.contains("4"), "mostra jogadores em 30 dias")
	check(screen.find_child("Deck_demo_0", true, false).find_child("FavoritesCount", true, false) != null, "mostra favoritos reais")
	check(screen.find_child("Deck_lendas_urbanas", true, false).find_child("Players30d", true, false) == null, "deck sem dados não ganha número")
	var calls: int = game.calls.size()
	screen._render_library()
	await _frames(10)
	check(game.calls.size() == calls, "estatísticas em cache (sem nova consulta dentro do prazo)")
	# Todos zerados: aviso.
	game.stats = []
	screen._stats_state = "idle"
	screen._render_library()
	await _frames(10)
	check(_notice().contains("Ainda não há partidas"), "aviso quando nada foi medido")
	# Falha de rede: aviso de erro.
	game.fail = true
	screen._stats_state = "idle"
	screen._render_library()
	await _frames(10)
	check(_notice().contains("Não foi possível"), "falha de rede vira aviso")
	# Recentes.
	screen._select_tab("Recentes")
	await _frames()
	order = _names()
	check(order.slice(0, 2) == ["Deck_demo_2", "Deck_demo_3"], "Recentes ordena por published_at real")
	check(screen.find_child("Deck_demo_2", true, false).find_child("PublishedAgo", true, false) != null, "mostra Publicado há")
	check(screen.find_child("Deck_demo_4", true, false).find_child("PublishedAgo", true, false) == null, "sem data, sem rótulo")
	# Registro de partida (DuelService): uma vez por partida, só com sessão.
	game.fail = false
	game.calls.clear()
	var duel := DuelService.new()
	root.add_child(duel)
	duel.client = game
	game.access_token = "teste"
	var room := {"room": {"status": "in_match", "settings": {"deck_ids": ["lendas_urbanas"]}}, "match": {"id": "m1"}, "members": []}
	duel._apply(ServiceResult.success(room))
	duel._apply(ServiceResult.success(room.duplicate(true)))
	await _frames()
	var plays: Array = game.calls.filter(func(c: Array) -> bool: return c[0] == "qse_deck_record_play")
	check(plays.size() == 1 and plays[0][1].p_deck_ref == "official:lendas_urbanas", "uma participação por partida")
	game.access_token = ""
	var other := room.duplicate(true)
	other.match.id = "m2"
	duel._apply(ServiceResult.success(other))
	await _frames()
	check(game.calls.filter(func(c: Array) -> bool: return c[0] == "qse_deck_record_play").size() == 1, "sem sessão não registra")
	print("T24_LIBRARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
