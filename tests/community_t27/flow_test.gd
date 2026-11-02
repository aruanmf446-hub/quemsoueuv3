extends SceneTree
## T27: Comunidade habilitada — vitrine, abrir deck publicado, denunciar, publicar com moderação,
## status no Meus Decks, edição bloqueada e retirada. GAME falso (sem rede).
var failures := 0
var checks := 0
const ME := "00000000-0000-4000-8000-0000000000a7"
var screen: Node


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func _frames(count := 8) -> void:
	for i in count: await process_frame


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CommunityService.CACHE))
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await _frames(20)
	var services := PlayerServices.current
	var fake: SupabaseClient = load("res://tests/community_t27/fake_game.gd").new()
	root.add_child(fake)
	fake.user = ME
	fake.access_token = "fixture-token-sem-rede"
	services.client = fake
	services.session.client = fake
	services.session.user = {"id": ME, "email": "fixture@example.invalid"}
	services.session._expires_at = Time.get_unix_time_from_system() + 86400.0
	var nav: Node = menu.get_node("Navigation")
	if not nav.get("_history").is_empty() and nav.get("_history").back().route == "account":
		nav.back()
		await _frames(20)
	CommunityService.items = []
	CommunityService.state = "idle"
	nav.open("deck_library", {})
	await _frames(30)
	screen = nav.get("_active")
	check(fake.rpc_calls.any(func(c: Array) -> bool: return c[0] == "qse_community_decks"), "vitrine buscada no GAME")
	var tile := screen.find_child("Deck_" + fake.PUBLISHED, true, false)
	check(tile != null, "deck da Comunidade aparece na Biblioteca")
	check(tile != null and (tile.find_child("Cover", true, false) as TextureRect).texture != null, "capa baixada (prévia autenticada)")
	screen._open_entry(screen._entries().filter(func(e: Dictionary) -> bool: return e.id == fake.PUBLISHED)[0])
	await _frames(20)
	var gallery := screen.find_child("CardGallery", true, false)
	check(screen._view == "deck" and gallery != null and gallery.get_child_count() == 5, "abrir deck publicado mostra as 5 cartas")
	check(screen.find_child("ReportDeck", true, false) != null, "botão Denunciar")
	screen._report_deck(fake.PUBLISHED)
	await _frames(3)
	var dialog := screen.find_child("ReportDialog", true, false) as ConfirmationDialog
	(dialog.find_child("ReportReason", true, false) as LineEdit).text = "Teste"
	dialog.confirmed.emit()
	await _frames(6)
	check(fake.reports.size() == 1, "denúncia enviada")
	# Publicar pelo Meus Decks.
	var store: DeckDrafts = screen._store()
	for d in store.list(): store.delete(str(d.id))
	var draft := store.new_draft()
	draft.name = "Meu deck publicável"
	draft.category = "Outros"
	for i in 5:
		var image := Image.create(400, 560, false, Image.FORMAT_RGB8)
		image.fill(Color.from_hsv(i / 5.0, 0.5, 0.6))
		var card := {"id": "k%d" % i, "name": "Carta %d" % i, "description": "", "crops": {}}
		card.image_file = store.store_original(str(draft.id), str(card.id), image.save_png_to_buffer(), "png")
		store.store_previews(str(draft.id), card, image)
		draft.cards.append(card)
	store.save(draft)
	screen._draft = draft
	screen._render_review()
	await _frames(4)
	var publish := screen.find_child("PublishDeck", true, false) as Button
	check(publish != null and not publish.disabled, "Publicar na Comunidade habilitado")
	publish.pressed.emit()
	await _frames(40)
	var saved := store.load_draft(str(draft.id))
	check(str(saved.get("server_status", "")) == "pending_review", "deck enviado para revisão")
	check(fake.db.qse_creator_decks.size() == 1 and fake.db.qse_creator_cards.size() == 5, "deck e cartas enviados antes do pedido")
	screen._select_tab("Meus Decks")
	await _frames(20)
	var mine := screen.find_child("Deck_draft_" + str(draft.id), true, false)
	check(mine != null and str(mine.find_child("SyncState", true, false).find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text) if mine.find_child("SyncState", true, false).find_children("*", "Label", true, false).size() > 0 else [mine.find_child("SyncState", true, false).text]).contains("REVISÃO"), "Meus Decks mostra EM REVISÃO")
	# Aprovação/recusa vêm do servidor.
	fake.db.qse_creator_decks[0].status = "rejected"
	fake.db.qse_creator_decks[0].review_note = "Imagem imprópria"
	screen._moderation_checked = false
	screen._render_library()
	await _frames(20)
	saved = store.load_draft(str(draft.id))
	check(saved.server_status == "rejected" and saved.review_note == "Imagem imprópria", "recusa e motivo atualizados do servidor")
	fake.db.qse_creator_decks[0].status = "published"
	saved.server_status = "published"
	store.save(saved)
	screen._draft = saved
	screen._render_editor()
	await _frames(4)
	check(screen.find_child("EditorLocked", true, false) != null and screen.find_child("DeckName", true, false) == null, "deck publicado não é editável")
	(screen.find_child("UnpublishDeck", true, false) as Button).pressed.emit()
	await _frames(20)
	check(store.load_draft(str(draft.id)).server_status == "draft" and screen.find_child("DeckName", true, false) != null, "retirar da Comunidade libera a edição")
	for d in store.list(): store.delete(str(d.id))
	print("T27_COMUNIDADE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
