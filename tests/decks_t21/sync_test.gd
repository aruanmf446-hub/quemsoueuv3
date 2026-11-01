extends SceneTree
## T21 integração: CreatorSync contra o GAME falso (fixture com regra de dono do RLS).
## Duas contas (A e B), falha de rede no meio do envio, reabertura e playlist individual.
var failures := 0
var checks := 0
const A := "00000000-0000-4000-8000-0000000000a1"
const B := "00000000-0000-4000-8000-0000000000b2"
var server: Node


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func _as(user: String) -> CreatorSync:
	server.user = user
	var store := DeckDrafts.new()
	store.owner = OwnerStorage.safe(user)
	var sync := CreatorSync.new()
	sync.client = server
	sync.user_id = user
	sync.store = store
	return sync


func _draft(sync: CreatorSync) -> Dictionary:
	var draft := sync.store.new_draft()
	draft.name = "Deck da conta A"
	draft.category = "Personagens"
	draft.visibility = "public"
	var image := Image.create(400, 560, false, Image.FORMAT_RGB8)
	image.fill(Color.DARK_SLATE_BLUE)
	var png := image.save_png_to_buffer()
	for i in 5:
		var card := {"id": "c%d" % i, "name": "Carta %d" % i, "description": "d", "crops": {"library": {"x": 0.4, "y": 0.6, "zoom": 2.0}, "duel": {"x": 0.5, "y": 0.3, "zoom": 1.5}}}
		card.image_file = sync.store.store_original(draft.id, card.id, png, "png")
		sync.store.store_previews(draft.id, card, image)
		draft.cards.append(card)
	return draft


func _run() -> void:
	server = load("res://tests/decks_t21/fake_game.gd").new()
	root.add_child(server)
	await process_frame
	_wipe()
	var a := _as(A)
	var draft := _draft(a)
	# Falha de rede no meio: nada local some, estado de erro, UUIDs já gravados.
	server.fail_after = 3
	var failed: Dictionary = await a.push(draft)
	var saved := a.store.load_draft(draft.id)
	check(not failed.ok and saved.sync_state == "error", "falha de rede marca erro sem apagar o rascunho")
	check(CreatorSync.is_uuid(str(saved.server_id)) and saved.cards.size() == 5, "UUID definitivo gravado antes do envio")
	var deck_id := str(saved.server_id)
	server.fail_after = -1
	server.calls = 0
	server.log.clear()
	var first_card := str(saved.cards[0].server_id)
	var ok: Dictionary = await a.push(saved)
	check(ok.ok and a.store.load_draft(draft.id).sync_state == "synced", "tentar novamente conclui o envio")
	check(server.db.qse_creator_decks.size() == 1 and server.db.qse_creator_cards.size() == 5, "repetir não duplica deck nem cartas")
	var deck: Dictionary = server.db.qse_creator_decks[0]
	check(deck.id == deck_id and deck.owner_id == A and deck.requested_visibility == "public" and not deck.has("visibility") and not deck.has("status"), "deck com owner da sessão; visibilidade só como pedido")
	var card: Dictionary = server.db.qse_creator_cards[0]
	check(is_equal_approx(card.portrait_zoom, 2.0) and is_equal_approx(card.portrait_center_x, 0.4) and is_equal_approx(card.duel_zoom, 1.5) and is_equal_approx(card.duel_center_y, 0.3), "crops.library/duel → colunas portrait_*/duel_*")
	check(str(card.image_original_path).begins_with("%s/%s/%s_original." % [A, deck_id, card.id]), "caminho do original <user>/<deck>/<card>_original")
	check(server.files.has("%s/%s/%s_library.png" % [A, deck_id, card.id]) and server.files.has("%s/%s/%s_duel.png" % [A, deck_id, card.id]), "prévias de Biblioteca e Duelo enviadas")
	var uploads: Array = server.log.filter(func(line: String) -> bool: return line.contains(first_card + "_original."))
	check(uploads.is_empty(), "original já confirmado não é reenviado na nova tentativa")
	# Conta B: não vê nem altera o deck da conta A.
	var b := _as(B)
	var pulled: Dictionary = await b.pull()
	check(pulled.ok and b.store.list().is_empty(), "conta B não recebe rascunhos da conta A")
	var stolen := saved.duplicate(true)
	stolen.name = "Invasão"
	var attempt: Dictionary = await b.push(stolen)
	check(not attempt.ok and server.db.qse_creator_decks[0].name == "Deck da conta A", "conta B não altera o deck da conta A")
	# Reabrir o jogo na conta A sem a cópia local: recupera do servidor.
	a = _as(A)
	a.store.delete(draft.id)
	pulled = await a.pull()
	var restored := a.store.list()
	check(pulled.ok and restored.size() == 1 and restored[0].server_id == deck_id and restored[0].cards.size() == 5, "reabrir recupera deck e cartas do servidor")
	var restored_card: Dictionary = restored[0].cards[0]
	check(is_equal_approx(float(restored_card.crops.library.zoom), 2.0) and is_equal_approx(float(restored_card.crops.duel.y), 0.3), "dois enquadramentos recuperados")
	check(a.store.original_image(restored[0].id, restored_card) != null and FileAccess.file_exists(a.store.preview_path(restored[0].id, restored_card, "duel")), "original baixado e prévias refeitas")
	# Favoritos: adicionar, remover, sem vazar para B.
	a.store.set_favorite("lendas_urbanas", true)
	var favs: Dictionary = await a.sync_favorites()
	check(favs.ok and server.db.qse_deck_favorites.size() == 1 and server.db.qse_deck_favorites[0].deck_ref == "official:lendas_urbanas", "favorito oficial sincronizado como official:<id>")
	check(CreatorSync.deck_ref(deck_id) == "creator:" + deck_id, "deck próprio vira creator:<uuid>")
	a.store.set_favorite("lendas_urbanas", false)
	favs = await a.sync_favorites()
	check(favs.ok and server.db.qse_deck_favorites.is_empty() and a.store.pending_favorite_removals().is_empty(), "remover favorito confirma no servidor")
	b = _as(B)
	favs = await b.sync_favorites()
	check(favs.ok and b.store.favorites().is_empty(), "favoritos de A não aparecem para B")
	# Playlist individual.
	a = _as(A)
	await a.push_music(["t1"], ["t2"])
	b = _as(B)
	var music_b: Dictionary = await b.pull_music()
	check(music_b.ok and music_b.data.is_empty(), "playlist de A não aparece para B")
	await b.push_music([], ["t9"])
	a = _as(A)
	var music_a: Dictionary = await a.pull_music()
	check(music_a.data.get("deselected_track_ids") == ["t2"], "playlist de A preservada após B salvar")
	# Excluir: servidor primeiro, depois local.
	var removed: Dictionary = await a.remove(a.store.list()[0])
	check(removed.ok and server.db.qse_creator_decks.is_empty() and server.db.qse_creator_cards.is_empty() and a.store.list().is_empty(), "excluir remove no servidor e depois aqui")
	check(server.files.keys().filter(func(k: String) -> bool: return k.begins_with(A + "/" + deck_id)).is_empty(), "imagens do deck removidas do Storage")
	_wipe()
	print("T21_SYNC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


func _wipe() -> void:
	for owner in [A, B]:
		var folder := OwnerStorage.folder(OwnerStorage.safe(owner))
		var drafts := folder + "/deck_drafts"
		if DirAccess.dir_exists_absolute(drafts):
			for draft in DirAccess.get_directories_at(drafts):
				for file in DirAccess.get_files_at(drafts + "/" + draft): DirAccess.remove_absolute(drafts + "/" + draft + "/" + file)
				DirAccess.remove_absolute(drafts + "/" + draft)
			DirAccess.remove_absolute(drafts)
		DirAccess.remove_absolute(folder + "/deck_favorites.cfg")
