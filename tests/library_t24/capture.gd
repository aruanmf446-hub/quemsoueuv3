extends SceneTree
## Capturas T24 (Biblioteca premium). FIXTURES DE TESTE: decks [DEMO], uma campanha de
## demonstração e um rascunho [DEMO] montado com artes oficiais já distribuídas no jogo.
## Uso: --script res://tests/library_t24/capture.gd -- <pasta> <LxA>
const ART := "res://assets/duel/decks/oficial/lendas_urbanas/%s.png"
const NAMES := ["momo", "slender_man", "dama_de_branco", "cobra_grande", "homem_sorridente", "loira_do_banheiro"]


func _initialize() -> void:
	call_deferred("_run")


func _shot(folder: String, name: String) -> void:
	for i in 26: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/" + name + ".png")
	print("CAPTURED ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0]
	var dims := args[1].split("x")
	var tag := args[1]
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dims[0]), int(dims[1]))
	await process_frame
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for i in 20: await process_frame
	var nav: Node = menu.get_node("Navigation")
	if not nav.get("_history").is_empty() and nav.get("_history").back().route == "account":
		nav.back()
		for i in 30: await process_frame
	nav.open("deck_library", {})
	for i in 30: await process_frame
	var screen: Node = nav.get("_active")
	# Real: header escolhido sozinho (sem regras: deck oficial padrão) com a composição.
	await _shot(folder, "t24_descobrir_" + tag)
	var store: DeckDrafts = screen._store()
	var draft := store.new_draft()
	draft.name = "[DEMO] Lendas do Bairro"
	draft.category = "Lendas e terror"
	for i in NAMES.size():
		var image := (load(ART % NAMES[i]) as Texture2D).get_image()
		var card := {"id": "demo_%d" % i, "name": NAMES[i].capitalize(), "description": "", "crops": {"library": {"x": 0.5, "y": 0.45, "zoom": 1.0}}}
		card.image_file = store.store_original(str(draft.id), str(card.id), image.save_png_to_buffer(), "png")
		store.store_previews(str(draft.id), card, image)
		draft.cards.append(card)
	draft.cover = {"mode": "card", "card_id": "demo_2"}
	store.save(draft)
	var empty := store.new_draft()
	empty.name = "[DEMO] Novo deck"
	store.save(empty)
	var fixture: Array[Dictionary] = load("res://tests/decks_t23/fixture.gd").entries()
	for entry in fixture: entry.images = [entry.cover]
	screen._demo_entries = fixture
	screen._clock = float(Time.get_unix_time_from_datetime_string("2026-12-10T12:00:00"))
	screen._demo_rules = [{"kind": "campaign", "theme": "Terror", "title": "[DEMO] Noite de Terror", "starts_at": "2026-12-01T00:00:00Z", "ends_at": "2026-12-31T00:00:00Z"}]
	screen._demo_entries[4].images = NAMES.map(func(n: String) -> String: return ART % n)
	screen._render_library()
	await _shot(folder, "t24_descobrir_campanha_" + tag)
	screen._select_tab("Meus Decks")
	await _shot(folder, "t24_meus_decks_" + tag)
	screen._draft = draft
	screen._render_editor()
	await _shot(folder, "t24_editor_capa_" + tag)
	screen._open_framer(1)
	var editor: CardFrameEditor = screen.find_child("CardFrameEditor", true, false)
	for i in 4: await process_frame
	editor.framer.set_zoom(0.62)
	editor.framer.nudge(Vector2.DOWN)
	editor.framer.nudge(Vector2.DOWN)
	await _shot(folder, "t24_enquadramento_" + tag)
	screen._close_framer()
	store.delete(str(draft.id))
	store.delete(str(empty.id))
	quit(0)
