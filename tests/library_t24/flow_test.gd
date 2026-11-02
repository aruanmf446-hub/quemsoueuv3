extends SceneTree
## T24 Biblioteca premium: destaques, header cinematográfico, capas e enquadramento.
## FIXTURES DE TESTE: imagens geradas aqui (várias proporções) e decks [DEMO].
var failures := 0
var checks := 0
const DIR := "user://t24_fixture_images"
const ASPECTS := {"vertical": Vector2i(500, 900), "horizontal": Vector2i(1000, 520), "square": Vector2i(700, 700), "odd": Vector2i(320, 1100), "card": Vector2i(500, 700)}


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func _frames(count := 6) -> void:
	for i in count: await process_frame


func _image(size: Vector2i, seed: int) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	image.fill(Color.from_hsv(rng.randf(), 0.5, 0.35))
	# "Rosto" contrastado no terço superior para a escolha automática ter o que medir.
	var face := Rect2i(size.x / 3, size.y / 6, size.x / 3, size.y / 5)
	if seed % 3 == 0: image.fill_rect(face, Color(0.95, 0.85, 0.7))
	return image


func _paths(count: int) -> Array:
	DirAccess.make_dir_recursive_absolute(DIR)
	var keys := ASPECTS.keys()
	var result: Array = []
	for i in count:
		var path := "%s/img_%d_%d.png" % [DIR, count, i]
		_image(ASPECTS[keys[i % keys.size()]], i).save_png(path)
		result.append(ProjectSettings.globalize_path(path))
	return result


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_picker()
	await _banner()
	_framer()
	await _framer_editor()
	_covers()
	await _library()
	print("T24_PREMIUM checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


# --- Destaques ---------------------------------------------------------------------------
func _picker() -> void:
	var dec := float(Time.get_unix_time_from_datetime_string("2026-12-10T12:00:00"))
	var jan := float(Time.get_unix_time_from_datetime_string("2027-03-20T12:00:00"))
	var entries := [
		{"id": "lendas", "ref": "official:lendas", "origin": "official", "name": "Lendas", "category": "Terror"},
		{"id": "natal", "ref": "official:natal", "origin": "official", "name": "Natal", "category": "Natal", "tags": ["natal"]},
		{"id": "c1", "ref": "creator:c1", "origin": "community", "name": "Comunidade 1", "category": "Heróis", "published": dec - 86400.0},
		{"id": "c2", "ref": "creator:c2", "origin": "community", "name": "Comunidade 2", "category": "Heróis"},
		{"id": "m", "ref": "creator:m", "origin": "mine", "name": "Meu", "category": "Natal", "published": dec}]
	var campaign := {"kind": "campaign", "theme": "Natal", "title": "Especial de Natal", "starts_at": "2026-12-01T00:00:00Z", "ends_at": "2026-12-31T23:59:59Z"}
	var pin := {"kind": "pin", "deck_ref": "official:lendas", "title": "Escolha da equipe", "priority": 10}
	var stats := {"creator:c2": {"score": 12}}
	var slides := FeaturedPicker.pick(entries, [campaign, pin], stats, dec)
	var reasons: Array = slides.map(func(s: Dictionary) -> String: return str(s.reason))
	check(reasons == ["pin", "campaign", "popular", "recent"], "prioridade pin > campanha > popular > lançamento (%s)" % [reasons])
	check(slides[1].entry.id == "natal" and slides[1].label == "Especial de Natal", "campanha por temática usa o título configurado")
	check(not slides.any(func(s: Dictionary) -> bool: return s.entry.origin == "mine"), "rascunho próprio nunca vira destaque")
	slides = FeaturedPicker.pick(entries, [campaign], {}, jan)
	check(slides.size() == 1 and slides[0].reason == "default" and slides[0].entry.id == "lendas", "campanha encerrada sai; sem dados volta ao oficial padrão")
	check(not FeaturedPicker.active({"kind": "campaign", "theme": "x", "starts_at": "amanhã"}, dec), "data inválida invalida a regra")
	check(not FeaturedPicker.active({"kind": "pin", "deck_ref": "official:lendas", "active": false}, dec), "regra desativada é ignorada")
	slides = FeaturedPicker.pick(entries, [{"kind": "pin", "deck_ref": "creator:c1"}], {}, jan)
	check(slides[0].reason != "pin", "fixar só vale para deck oficial")
	slides = FeaturedPicker.pick(entries, [], {"creator:c1": {"score": 0}}, jan)
	check(slides[0].reason == "default", "score 0 não conta como popular")


# --- Header cinematográfico --------------------------------------------------------------
func _banner() -> void:
	for count in [1, 2, 3, 5, 6, 10, 30]:
		var paths := _paths(count)
		var banner := CinematicBanner.new()
		root.add_child(banner)
		banner.size = Vector2(1500, 236)
		var started := Time.get_ticks_usec()
		banner.setup(paths)
		var built := (Time.get_ticks_usec() - started) / 1000.0
		await _frames(2)
		var layers := banner.layers()
		check(layers.size() == mini(count, 6), "%d imagens → %d personagens" % [count, layers.size()])
		var ok := true
		for layer in layers:
			var atlas := layer.texture as AtlasTexture
			if atlas == null or absf(atlas.region.size.x / atlas.region.size.y - CinematicBanner.FIGURE_ASPECT) > 0.01: ok = false
			if absf(layer.size.x / layer.size.y - CinematicBanner.FIGURE_ASPECT) > 0.01: ok = false
			if layer.position.x + layer.size.x < 0.0 or layer.position.x > banner.size.x: ok = false
		check(ok, "%d imagens: proporção preservada e dentro do banner" % count)
		var main := layers.filter(func(l: TextureRect) -> bool: return int(l.get_meta("slot")) == 0)
		check(main.size() == 1 and main[0].get_index() == banner.get_child_count() - 2, "%d imagens: principal na frente" % count)
		check(banner.find_child("Backdrop", false, false) != null and banner.find_child("Overlay", false, false) != null, "%d imagens: fundo desfocado e gradiente" % count)
		if count == 30: check(built < 1500.0, "30 imagens montadas em %.0f ms" % built)
		banner.queue_free()
	var reuse := CinematicBanner.new()
	root.add_child(reuse)
	reuse.size = Vector2(1500, 236)
	var again := Time.get_ticks_usec()
	reuse.setup(_paths_cached(30))
	check((Time.get_ticks_usec() - again) / 1000.0 < 400.0, "reabrir usa o cache (%.0f ms)" % ((Time.get_ticks_usec() - again) / 1000.0))
	reuse.queue_free()


func _paths_cached(count: int) -> Array:
	var result: Array = []
	for i in count: result.append(ProjectSettings.globalize_path("%s/img_%d_%d.png" % [DIR, count, i]))
	return result


# --- Enquadramento -----------------------------------------------------------------------
func _framer() -> void:
	for key: String in ASPECTS:
		var size := Vector2(ASPECTS[key])
		for aspect in [CardFramer.LIBRARY_ASPECT, CardFramer.DUEL_ASPECT]:
			var low := CardFramer.min_zoom(size, aspect)
			var whole := CardFramer.region(size, aspect, {"zoom": low})
			check(low <= 1.0 and whole.grow(0.5).encloses(Rect2(Vector2.ZERO, size)) or is_equal_approx(low, CardFramer.MIN_ZOOM), "%s %.2f: zoom mínimo mostra a imagem inteira" % [key, aspect])
			check(absf(whole.size.x / whole.size.y - aspect) < 0.001, "%s %.2f: moldura nunca deformada" % [key, aspect])
			var image := _image(ASPECTS[key], 3)
			var preview := CardFramer.preview(image, aspect, {"zoom": low, "x": 0.3, "y": 0.7}, 320)
			check(absf(float(preview.get_width()) / preview.get_height() - aspect) < 0.03 and preview.get_width() <= 320, "%s %.2f: prévia fiel com zoom reduzido" % [key, aspect])
	# Carta 5:7 na moldura 5:7: antes não dava para mover; com zoom reduzido, move.
	var card := Vector2(500, 700)
	var a := CardFramer.region(card, CardFramer.LIBRARY_ASPECT, {"zoom": 0.6, "y": 0.2})
	var b := CardFramer.region(card, CardFramer.LIBRARY_ASPECT, {"zoom": 0.6, "y": 0.8})
	check(not is_equal_approx(a.position.y, b.position.y), "imagem do mesmo formato da carta pode subir e descer")
	check(CardFramer.normalized({"zoom": 0.1}).zoom == CardFramer.MIN_ZOOM and CardFramer.normalized({"zoom": -1}).zoom == 1.0, "limites de zoom")
	var row := CreatorSync.card_row("d", 0, {"server_id": "s", "name": "n", "crops": {"library": {"x": 0.3, "y": 0.6, "zoom": 0.6}, "duel": {"x": 0.5, "y": 0.2, "zoom": 2.0}}}, "")
	check(is_equal_approx(float(row.portrait_zoom), 0.6) and is_equal_approx(float(row.duel_zoom), 2.0) and is_equal_approx(float(row.duel_center_y), 0.2), "retrato e Mata-Mata seguem separados nas colunas portrait_*/duel_*")


func _framer_editor() -> void:
	var editor := CardFrameEditor.new()
	root.add_child(editor)
	editor.open(_image(ASPECTS.card, 3))
	await _frames(3)
	var framer := editor.framer
	var slider := editor.find_child("ZoomSlider", true, false) as HSlider
	check(slider != null and slider.min_value < 1.0 and is_equal_approx(float(framer.crop.zoom), 1.0), "controle de zoom abre sem alterar o enquadramento")
	slider.value = slider.min_value
	await _frames(1)
	check(is_equal_approx(float(framer.crop.zoom), framer.minimum_zoom()), "reduzir o zoom pelo controle")
	var before := float(framer.crop.y)
	(editor.find_child("NudgeDown", true, false) as Button).pressed.emit()
	check(not is_equal_approx(float(framer.crop.y), before), "botão ↓ move a imagem (toque)")
	(editor.find_child("NudgeLeft", true, false) as Button).pressed.emit()
	(editor.find_child("ZoomIn", true, false) as Button).pressed.emit()
	check(float(framer.crop.zoom) > framer.minimum_zoom() and editor.find_child("ZoomValue", true, false).text.ends_with("%"), "ampliar e ver o valor")
	(editor.find_child("ResetFrame", true, false) as Button).pressed.emit()
	check(is_equal_approx(float(framer.crop.zoom), 1.0) and is_equal_approx(float(framer.crop.x), 0.5), "Restaurar volta ao original")
	var touch := InputEventScreenDrag.new()
	touch.relative = Vector2(0, -40)
	slider.value = slider.min_value
	var y := float(framer.crop.y)
	framer._gui_input(touch)
	check(not is_equal_approx(float(framer.crop.y), y), "arrastar com o dedo move a imagem")
	editor.queue_free()


# --- Capas -------------------------------------------------------------------------------
func _covers() -> void:
	var store := DeckDrafts.new()
	store.owner = OwnerStorage.safe("t24-cover-test")
	for count in [0, 1, 2, 3, 5, 6, 10, 30]:
		var draft := store.new_draft()
		draft.id = "t24_cover_%d" % count
		draft.name = "Deck %d" % count
		for i in count:
			var card := {"id": "c%d" % i, "name": "Carta %d" % i, "crops": {}}
			store.store_previews(str(draft.id), card, _image(ASPECTS.values()[i % ASPECTS.size()], i))
			draft.cards.append(card)
		store.save(draft)
		var auto := DeckCover.resolve_draft(store, draft)
		check((count == 0 and str(auto.path).is_empty()) or (count > 0 and FileAccess.file_exists(str(auto.path)) and auto.mode == "auto"), "%d cartas: capa automática" % count)
		if count < 3: continue
		draft.cover = {"mode": "card", "card_id": "c2"}
		var chosen := DeckCover.resolve_draft(store, draft)
		check(chosen.mode == "card" and chosen.card_id == "c2", "%d cartas: escolher carta" % count)
		draft.cards.remove_at(2)
		check(DeckCover.resolve_draft(store, draft).mode == "auto", "%d cartas: carta da capa excluída → automática" % count)
		var cover_image := _image(ASPECTS.horizontal, 5)
		check(store.store_cover(str(draft.id), cover_image, {}), "%d cartas: enviar capa" % count)
		draft.cover = {"mode": "upload"}
		var uploaded := DeckCover.resolve_draft(store, draft)
		var stored := Image.load_from_file(str(uploaded.path))
		check(uploaded.mode == "upload" and absf(float(stored.get_width()) / stored.get_height() - DeckCover.ASPECT) < 0.02, "%d cartas: capa enviada em 16:10" % count)
		var first := DeckCover.framed(str(uploaded.path))
		store.store_cover(str(draft.id), _image(ASPECTS.square, 6), {})
		check(DeckCover.framed(str(uploaded.path)) != first, "%d cartas: substituir capa atualiza a imagem" % count)
		store.remove_cover(str(draft.id))
		check(DeckCover.resolve_draft(store, draft).mode == "auto", "%d cartas: arquivo da capa apagado → automática" % count)
	for count in [0, 1, 2, 3, 5, 6, 10, 30]: store.delete("t24_cover_%d" % count)


# --- Biblioteca integrada ------------------------------------------------------------------
func _library() -> void:
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
	var screen: Node = nav.get("_active")
	var banner := screen.find_child("FeaturedBanner", true, false)
	check(banner != null and str(banner.get_meta("reason")) == "default" and banner.find_child("Cinematic", true, false) != null, "sem regras nem dados: oficial padrão com composição")
	check(banner.find_child("Cinematic", true, false).layers().size() == 6, "Lendas Urbanas (9 cartas) → 6 personagens")
	var fixture: Array[Dictionary] = load("res://tests/decks_t23/fixture.gd").entries()
	for entry in fixture: entry.images = [entry.cover]
	fixture[1].ref = "creator:demo1"
	screen._demo_entries = fixture
	screen._stats = {"creator:demo1": {"score": 40, "players_30d": 9, "favorites": 3}}
	screen._stats_state = "ok"
	screen._stats_at = Time.get_ticks_msec() / 1000.0
	screen._clock = float(Time.get_unix_time_from_datetime_string("2026-12-10T12:00:00"))
	screen._demo_rules = [{"kind": "campaign", "theme": "Terror", "title": "Noite de Terror", "starts_at": "2026-12-01T00:00:00Z", "ends_at": "2026-12-31T00:00:00Z"}]
	screen._render_library()
	await _frames(6)
	banner = screen.find_child("FeaturedBanner", true, false)
	check(str(banner.get_meta("reason")) == "campaign", "campanha ativa assume o header")
	check(screen.find_child("BannerDots", true, false) != null and screen._slides.size() >= 2, "vários destaques reais → pontos")
	screen._show_slide(1)
	await _frames(2)
	banner = screen.find_child("FeaturedBanner", true, false)
	check(str(banner.get_meta("reason")) == "popular" and str(banner.get_meta("deck")) == "creator:demo1", "troca de destaque (popularidade real)")
	screen._demo_rules = [{"kind": "pin", "deck_ref": "official:lendas_urbanas", "title": "Escolha da equipe"}]
	screen._render_library()
	await _frames(6)
	check(str(screen.find_child("FeaturedBanner", true, false).get_meta("reason")) == "pin", "deck oficial fixado vem primeiro")
	# Cartões maiores e colunas pela largura.
	var grid := screen.find_child("DeckGrid", true, false) as GridContainer
	var tile := grid.get_child(0) as Control
	check(grid.columns >= 2 and grid.columns <= 5 and tile.custom_minimum_size.x >= 320.0, "1920: %d colunas, cartão %.0f px" % [grid.columns, tile.custom_minimum_size.x])
	check(absf((tile.custom_minimum_size.y - 74.0) * DeckCover.ASPECT - tile.custom_minimum_size.x) < 2.0, "capa 16:10 sem compressão")
	var cover := tile.find_child("Cover", true, false) as TextureRect
	var first_texture := cover.texture
	screen._select_tab("Populares")
	await _frames(3)
	screen._select_tab("Descobrir")
	await _frames(3)
	var again := screen.find_child("DeckGrid", true, false).get_child(0).find_child("Cover", true, false) as TextureRect
	check(again.texture == first_texture, "trocar de aba reaproveita a capa em cache")
	root.size = Vector2i(844, 390)
	await _frames(8)
	screen._render_library()
	await _frames(8)
	grid = screen.find_child("DeckGrid", true, false) as GridContainer
	check(grid.columns >= 1 and (grid.get_child(0) as Control).custom_minimum_size.x >= 200.0, "844×390: %d colunas legíveis" % grid.columns)
	# Editor: seção de capa real.
	var store: DeckDrafts = screen._store()
	var draft := store.new_draft()
	draft.name = "Capa T24"
	for i in 3:
		var card := {"id": "k%d" % i, "name": "Carta %d" % i, "crops": {}}
		store.store_previews(str(draft.id), card, _image(ASPECTS.card, i))
		draft.cards.append(card)
	store.save(draft)
	screen._draft = draft
	screen._render_editor()
	await _frames(4)
	check(screen.find_child("CoverSection", true, false) != null and screen.find_child("CoverPreview", true, false).texture != null, "editor mostra a capa automática")
	(screen.find_child("CoverCardPick", true, false) as OptionButton).item_selected.emit(2)
	await _frames(3)
	check(str(store.load_draft(str(draft.id)).cover.card_id) == "k1" and screen.find_child("CoverMode", true, false).get_meta("mode") == "card", "escolher carta grava a capa")
	(screen.find_child("CoverAuto", true, false) as Button).pressed.emit()
	await _frames(3)
	check(str(store.load_draft(str(draft.id)).cover.mode) == "auto", "voltar para automática")
	store.delete(str(draft.id))
