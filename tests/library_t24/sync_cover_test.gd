extends SceneTree
## T24: capa sincronizada com o GAME falso (FK de cover_card_id, caminho exato e outro aparelho).
var failures := 0
var checks := 0
const A := "00000000-0000-4000-8000-0000000000c1"
var server: Node


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func _device(name: String) -> CreatorSync:
	server.user = A
	var store := DeckDrafts.new()
	store.owner = OwnerStorage.safe(A + name)
	var sync := CreatorSync.new()
	sync.client = server
	sync.user_id = A
	sync.store = store
	return sync


func _run() -> void:
	server = load("res://tests/decks_t21/fake_game.gd").new()
	root.add_child(server)
	await process_frame
	var a := _device("")
	_wipe(a.store)
	var draft := a.store.new_draft()
	draft.name = "Capa sincronizada"
	draft.category = "Personagens"
	for i in 5:
		var image := Image.create(400, 560, false, Image.FORMAT_RGB8)
		image.fill(Color.from_hsv(i / 5.0, 0.6, 0.6))
		var card := {"id": "c%d" % i, "name": "Carta %d" % i, "description": "", "crops": {"library": {"x": 0.5, "y": 0.4, "zoom": 0.6}}}
		card.image_file = a.store.store_original(draft.id, card.id, image.save_png_to_buffer(), "png")
		a.store.store_previews(draft.id, card, image)
		draft.cards.append(card)
	draft.cover = {"mode": "card", "card_id": "c3"}
	var pushed: Dictionary = await a.push(draft)
	var deck: Dictionary = server.db.qse_creator_decks[0] if not server.db.qse_creator_decks.is_empty() else {}
	check(pushed.ok, "envio com capa por carta passa pela FK (PATCH depois das cartas)")
	check(deck.get("cover_mode") == "card" and str(deck.get("cover_card_id")) == str(draft.cards[3].server_id), "cover_card_id = UUID da carta no servidor")
	check(is_equal_approx(float(server.db.qse_creator_cards[0].portrait_zoom), 0.6), "zoom reduzido (0.6) enviado")
	# Capa enviada.
	var cover := Image.create(1200, 750, false, Image.FORMAT_RGB8)
	cover.fill(Color.DARK_ORANGE)
	a.store.store_cover(draft.id, cover, {})
	draft.cover = {"mode": "upload"}
	pushed = await a.push(a.store.load_draft(draft.id).merged({"cover": {"mode": "upload"}}, true))
	deck = server.db.qse_creator_decks[0]
	var path := "%s/%s/deck_cover.png" % [A, deck.id]
	check(pushed.ok and deck.cover_mode == "upload" and deck.cover_image_path == path and server.files.has(path), "capa enviada: caminho exato <owner>/<deck>/deck_cover.png")
	# Outro aparelho recupera a escolha e o arquivo.
	# Outro aparelho = mesma conta sem nenhuma cópia local.
	var b := _device("")
	_wipe(b.store)
	var pulled: Dictionary = await b.pull()
	var restored: Dictionary = b.store.list()[0] if not b.store.list().is_empty() else {}
	check(pulled.ok and restored.get("cover", {}).get("mode") == "upload" and FileAccess.file_exists(b.store.cover_path(str(restored.get("id", "")))), "outro aparelho recupera a capa enviada")
	check(DeckCover.resolve_draft(b.store, restored).mode == "upload", "outro aparelho mostra a mesma capa")
	check(is_equal_approx(float(restored.cards[0].crops.library.zoom), 0.6), "enquadramento reduzido recuperado")
	# Carta da capa excluída → automática no servidor.
	a = _device("")
	var current := a.store.list()[0]
	current.cover = {"mode": "card", "card_id": str(current.cards[3].id)}
	current.cards.remove_at(3)
	pushed = await a.push(current)
	deck = server.db.qse_creator_decks[0]
	check(pushed.ok and deck.cover_mode == "auto" and deck.cover_card_id == null, "carta da capa excluída → automática no servidor")
	_wipe(a.store)
	_wipe(b.store)
	print("T24_COVER_SYNC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


func _wipe(store: DeckDrafts) -> void:
	for d in store.list(): store.delete(str(d.id))
