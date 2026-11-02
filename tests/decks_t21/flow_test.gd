extends SceneTree
## T21: enquadramento (dois formatos), rascunhos, favoritos por dono e o fluxo na tela real.
## Imagens geradas aqui são fixtures de teste. Sem rede, sem Supabase.
var failures := 0
var checks := 0
const A := "00000000-0000-4000-8000-0000000000a1"
const B := "00000000-0000-4000-8000-0000000000b2"


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func _fixture(width: int, height: int) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color(0.2, 0.3, 0.4))
	image.fill_rect(Rect2i(width / 2 - 20, height / 2 - 20, 40, 40), Color.RED)
	return image


func _run() -> void:
	await process_frame
	_framer_math()
	await _editor_component()
	_drafts_and_favorites()
	await _screen_flow()
	print("T21_DECKS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


func _framer_math() -> void:
	var size := Vector2(1200, 800)
	for aspect: float in [CardFramer.LIBRARY_ASPECT, CardFramer.DUEL_ASPECT]:
		for crop: Dictionary in [{}, {"x": 0.0, "y": 0.0, "zoom": 1.0}, {"x": 1.0, "y": 1.0, "zoom": 3.0}, {"x": 0.3, "y": 0.8, "zoom": 99.0}]:
			var rect := CardFramer.region(size, aspect, crop)
			check(is_equal_approx(rect.size.x / rect.size.y, aspect), "recorte mantém a proporção da moldura (sem esticar) %.2f %s" % [aspect, crop])
			check(Rect2(Vector2.ZERO, size).encloses(rect.grow(-0.01)), "recorte sempre dentro do original %s" % [crop])
	var full := CardFramer.region(size, CardFramer.DUEL_ASPECT, {})
	check(is_equal_approx(full.size.x, 1200.0), "zoom 1 usa a maior área possível")
	check(CardFramer.normalized({"zoom": -4, "x": "a"}).zoom == 1.0, "parâmetros inválidos voltam ao padrão")
	var image := _fixture(1200, 800)
	var preview := CardFramer.preview(image, CardFramer.LIBRARY_ASPECT, {}, 360)
	check(preview.get_width() <= 360 and absf(float(preview.get_width()) / preview.get_height() - CardFramer.LIBRARY_ASPECT) < 0.02, "prévia leve e sem distorção")
	check(image.get_size() == Vector2i(1200, 800), "original não é alterado")


func _editor_component() -> void:
	root.size = Vector2i(1280, 720)
	var editor := CardFrameEditor.new()
	root.add_child(editor)
	editor.open(_fixture(1600, 900), {"duel": {"x": 0.2, "y": 0.5, "zoom": 2.0}})
	await process_frame
	await process_frame
	var framer := editor.framer
	check(is_equal_approx(framer.aspect, CardFramer.LIBRARY_ASPECT), "editor abre no formato Biblioteca")
	var before: Dictionary = framer.crop.duplicate()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = framer.size * 0.5
	framer._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-60, 0)
	framer._gui_input(motion)
	check(float(framer.crop.x) > float(before.x), "arrastar reposiciona")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = framer.size * 0.5
	framer._gui_input(wheel)
	check(float(framer.crop.zoom) > 1.0, "roda do mouse amplia")
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1.5
	pinch.position = framer.size * 0.5
	framer._gui_input(pinch)
	check(float(framer.crop.zoom) > 1.2, "gesto de pinça amplia")
	var library_crop: Dictionary = framer.crop.duplicate()
	editor._select("duel")
	check(is_equal_approx(framer.aspect, CardFramer.DUEL_ASPECT) and is_equal_approx(float(framer.crop.zoom), 2.0), "formato Duelo tem enquadramento próprio")
	editor.find_child("ResetFrame", true, false).pressed.emit()
	var crops := editor.crops()
	check(is_equal_approx(float(crops.duel.zoom), 1.0) and is_equal_approx(float(crops.library.zoom), float(library_crop.zoom)), "restaurar um formato não mexe no outro")
	var result := []
	editor.confirmed.connect(func(value: Dictionary) -> void: result.append(value))
	editor.find_child("ConfirmFrame", true, false).pressed.emit()
	check(result.size() == 1 and result[0].has("library") and result[0].has("duel"), "confirmar devolve os dois recortes")
	editor.queue_free()


func _drafts_and_favorites() -> void:
	var a := DeckDrafts.new()
	a.owner = A
	var b := DeckDrafts.new()
	b.owner = B
	var draft := a.new_draft()
	draft.name = "Teste"
	check(not DeckDrafts.problems(draft).is_empty(), "rascunho incompleto lista pendências")
	draft.category = DeckDrafts.CATEGORIES[0]
	var png := _fixture(400, 560).save_png_to_buffer()
	for i in 5:
		var card := {"id": "c%d" % i, "name": "Carta %d" % i, "description": "", "crops": {}}
		card.image_file = a.store_original(draft.id, card.id, png, "png")
		draft.cards.append(card)
	check(DeckDrafts.problems(draft).is_empty(), "rascunho completo fica pronto para revisão")
	check(a.save(draft).ok, "salva rascunho do dono A")
	check(a.list().size() >= 1 and b.load_draft(draft.id).is_empty(), "dono B não vê rascunho do dono A")
	check(a.original_image(draft.id, draft.cards[0]).get_size() == Vector2i(400, 560), "original preservado para reeditar")
	check(not a.has_method("publish") and CommunityService.message("min_cards").contains("5 cartas"), "publicação real pela Comunidade (sem stub local)")
	check(a.set_favorite("lendas_urbanas", true) and a.is_favorite("lendas_urbanas"), "favorito do dono A")
	check(not b.is_favorite("lendas_urbanas"), "favorito não vaza para o dono B")
	check(a.set_favorite("lendas_urbanas", false) and not a.is_favorite("lendas_urbanas"), "desfavoritar")
	check(a.delete(draft.id) and a.load_draft(draft.id).is_empty(), "excluir apaga só o rascunho do dono")
	for owner in [A, B]: _cleanup(owner)


func _screen_flow() -> void:
	var services := PlayerServices.new()
	root.add_child(services)
	await process_frame
	var screen := load("res://scenes/player/deck_library.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	await process_frame
	var card := screen.find_child("Deck_lendas_urbanas", true, false)
	var heart := card.find_child("Favorite", true, false) as Button if card != null else null
	check(heart != null, "deck oficial tem botão de favorito")
	heart.button_pressed = true
	screen._select_tab("Favoritos")
	await process_frame
	check(screen.find_child("Deck_lendas_urbanas", true, false) != null, "aba Favoritos mostra o deck salvo")
	screen._select_tab("Meus Decks")
	await process_frame
	var create := screen.find_child("CreateDeck", true, false) as Button
	check(create != null, "Meus Decks oferece Criar deck")
	create.pressed.emit()
	await process_frame
	check(screen._view == "editor" and screen.find_child("DeckName", true, false) != null, "abre o editor de deck")
	var png := _fixture(900, 1200)
	screen._pending_card = -1
	screen._image_picked(png, png.save_png_to_buffer(), "png")
	await process_frame
	var overlay := screen.find_child("CardFrameEditor", true, false)
	check(overlay != null, "importar imagem abre o enquadramento")
	overlay.find_child("ConfirmFrame", true, false).pressed.emit()
	for i in 4: await process_frame
	check(screen.find_child("DraftCard_0", true, false) != null, "carta entra no rascunho com prévia")
	check(FileAccess.file_exists(screen._store().preview_path(screen._draft.id, screen._draft.cards[0], "duel")), "prévia do Duelo gerada")
	screen._render_review()
	await process_frame
	var publish := screen.find_child("PublishDeck", true, false) as Button
	check(publish != null and publish.disabled, "revisão bloqueia publicar com pendências")
	heart = null
	screen._store().set_favorite("lendas_urbanas", false)
	screen.queue_free()
	services.queue_free()
	_cleanup("")


func _cleanup(owner: String) -> void:
	var folder := OwnerStorage.folder(owner)
	var drafts := folder + "/deck_drafts"
	if not DirAccess.dir_exists_absolute(drafts): return
	for draft in DirAccess.get_directories_at(drafts):
		for file in DirAccess.get_files_at(drafts + "/" + draft): DirAccess.remove_absolute(drafts + "/" + draft + "/" + file)
		DirAccess.remove_absolute(drafts + "/" + draft)
	DirAccess.remove_absolute(drafts)
	DirAccess.remove_absolute(folder + "/deck_favorites.cfg")
