extends SceneTree
## Capturas reais (janela) da Biblioteca T21. A imagem da carta no editor é uma fixture
## de teste gerada a partir de uma carta oficial já distribuída no projeto.
## Uso: --script res://tests/decks_t21/capture.gd -- <pasta> <LxA>
func _initialize() -> void:
	call_deferred("_run")


func _shot(folder: String, name: String) -> void:
	for i in 24: await process_frame
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
	await _shot(folder, "biblioteca_" + tag)
	screen._select_tab("Meus Decks")
	await _shot(folder, "meus_decks_" + tag)
	(screen.find_child("CreateDeck", true, false) as Button).pressed.emit()
	var art := (load("res://assets/duel/decks/lendas_urbanas/momo.png") as Texture2D).get_image()
	screen._pending_card = -1
	screen._image_picked(art, art.save_png_to_buffer(), "png")
	await _shot(folder, "enquadrar_biblioteca_" + tag)
	var editor: Node = screen.find_child("CardFrameEditor", true, false)
	editor._select("duel")
	await _shot(folder, "enquadrar_duelo_" + tag)
	editor.find_child("ConfirmFrame", true, false).pressed.emit()
	await _shot(folder, "editor_" + tag)
	# Limpa o rascunho de captura (pasta do visitante).
	screen._store().delete(str(screen._draft.id))
	quit(0)
