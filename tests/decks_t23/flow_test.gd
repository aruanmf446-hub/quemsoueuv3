extends SceneTree
## T23: Biblioteca de Decks (5 abas, busca, filtros, ordenação, favoritos, Meus Decks) e Mata-Mata.
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


func _tiles() -> Array:
	var grid: Node = screen.find_child("DeckGrid", true, false)
	if grid == null: return []
	return grid.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Deck_"))


func _names() -> Array:
	return _tiles().map(func(n: Node) -> String: return str(n.name))


func _box(name: String) -> CheckBox:
	return screen.find_child(name, true, false) as CheckBox


func _run() -> void:
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await _frames(20)
	# Mata-Mata em toda a interface visível (PT); ids internos continuam duel_*.
	var visible_text: Array[String] = []
	for node in menu.find_children("*", "", true, false):
		for prop in ["text", "tooltip_text"]:
			if prop in node: visible_text.append(str(node.get(prop)))
	check(visible_text.filter(func(t: String) -> bool: return t.contains("Duelo")).is_empty(), "nenhum 'Duelo' visível no lobby PT")
	check(visible_text.any(func(t: String) -> bool: return t.contains("Mata-Mata")), "lobby mostra Modo Mata-Mata")
	for path in ["res://scripts/ui/screens/duel_screen.gd", "res://scripts/ui/screens/friends_screen.gd", "res://scripts/decks/card_frame_editor.gd", "res://scripts/menu/lobby_composition.gd", "res://scripts/services/duel_service.gd", "res://scripts/ui/nickname_onboarding.gd"]:
		var source := FileAccess.get_file_as_string(path)
		var quoted := RegEx.create_from_string("\"[^\"\\n]*Duelo[^\"\\n]*\"").search_all(source)
		check(quoted.is_empty(), "sem texto 'Duelo' em " + path.get_file())
	var en: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/en.json"))
	check(en is Dictionary and str(en).contains("Knockout"), "tradução EN de Mata-Mata")
	var nav: Node = menu.get_node("Navigation")
	if not nav.get("_history").is_empty() and nav.get("_history").back().route == "account":
		nav.back()
		await _frames(20)
	nav.open("deck_library", {})
	await _frames(20)
	screen = nav.get("_active")
	screen._demo_entries = load("res://tests/decks_t23/fixture.gd").entries()
	screen._render_library()
	await _frames()
	# Cabeçalho e abas.
	check(screen.find_child("DeckSearch", true, false) != null, "busca no cabeçalho")
	check(screen.find_child("LibraryTabs", true, false).get_child_count() == 5, "cinco abas")
	check(screen.find_child("FilterPanel", true, false) != null, "painel Filtrar decks")
	# Descobrir.
	check(screen.find_child("FeaturedBanner", true, false) != null and screen.find_child("ExploreFeatured", true, false) != null, "banner com Explorar coleção")
	check(screen.find_child("BannerDots", true, false) == null, "sem pontos com um único destaque real")
	check(screen.find_child("Collection_official", true, false) != null and screen.find_child("Collection_mine", true, false) != null, "coleções em destaque")
	check(_names().has("Deck_lendas_urbanas") and _names().size() == 9, "quatro oficiais + cinco fixtures")
	# Busca.
	screen._search.text = "mitologia"
	screen._search.text_changed.emit("mitologia")
	await _frames()
	check(_names() == ["Deck_demo_1"], "busca encontra por nome")
	screen._clear_filters()
	await _frames()
	# Filtros: Tipo e Temática.
	_box("Type_official").button_pressed = true
	await _frames()
	check(_names().size() == 4 and _names().has("Deck_lendas_urbanas") and _names().has("Deck_nostalgia_web") and _names().has("Deck_pinturas") and _names().has("Deck_sol_nascente"), "filtro quatro Oficiais")
	_box("Type_official").button_pressed = false
	_box("Type_community").button_pressed = true
	await _frames()
	check(_names().size() == 5 and not _names().has("Deck_lendas_urbanas"), "filtro Comunidade")
	_box("Theme_Terror").button_pressed = true
	await _frames()
	check(_names() == ["Deck_demo_4"], "filtro Temática a partir dos metadados")
	(screen.find_child("ClearFilters", true, false) as Button).pressed.emit()
	await _frames()
	check(_names().size() == 9 and not _box("Type_community").button_pressed, "Limpar filtros")
	# Ordenação A–Z.
	check(screen.find_child("SortBy", true, false) != null, "Ordenar por")
	# Populares/Recentes: sem métricas inventadas.
	for tab in ["Populares", "Recentes"]:
		screen._select_tab(tab)
		await _frames()
		check(screen.find_child("DataNotice", true, false) != null and _names().size() == 9, tab + " avisa que a métrica não existe")
	# Favoritos.
	var store: DeckDrafts = screen._store()
	store.set_favorite("lendas_urbanas", false)
	screen._select_tab("Favoritos")
	await _frames()
	check(screen.find_child("EmptyResults", true, false) != null and screen.find_child("ExploreDecks", true, false) != null, "Favoritos vazio com Explorar decks")
	screen._select_tab("Descobrir")
	await _frames()
	var heart := screen.find_child("Deck_lendas_urbanas", true, false).find_child("Favorite", true, false) as Button
	heart.button_pressed = true
	await _frames()
	screen._select_tab("Favoritos")
	await _frames()
	check(_names() == ["Deck_lendas_urbanas"], "coração adiciona aos Favoritos")
	(screen.find_child("Deck_lendas_urbanas", true, false).find_child("Favorite", true, false) as Button).button_pressed = false
	await _frames()
	check(screen.find_child("EmptyResults", true, false) != null, "remover favorito volta ao vazio")
	# Meus Decks.
	for d in store.list(): store.delete(str(d.id))
	screen._select_tab("Meus Decks")
	await _frames()
	check(screen.find_child("CreateDeckEmpty", true, false) != null or screen.find_child("CreateDeckTile", true, false) != null, "criar deck sem rascunhos")
	var draft := store.new_draft()
	draft.name = "Teste T23"
	store.save(draft)
	screen._render_library()
	await _frames()
	check(screen.find_child("CreateDeck", true, false) != null and screen.find_child("CreateDeckTile", true, false) != null, "+ Criar novo deck e bloco tracejado")
	check(_tiles().size() == 1 and _tiles()[0].find_child("DeckMenu", true, false) != null, "cartão próprio com menu ⋯")
	var entry: Dictionary = screen._entries().filter(func(e: Dictionary) -> bool: return e.origin == "mine")[0]
	screen._menu_action(1, entry)
	await _frames()
	check(store.list().size() == 2, "Duplicar cria cópia real")
	screen._menu_action(3, entry)
	await _frames()
	check(screen.find_child("ConfirmDeleteDraft", true, false) != null, "Excluir pede confirmação")
	for d in store.list(): store.delete(str(d.id))
	print("T23_LIBRARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
