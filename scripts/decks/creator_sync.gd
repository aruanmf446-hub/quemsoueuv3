class_name CreatorSync
extends RefCounted
## Integração dos rascunhos, favoritos e playlist com o GAME (Data API + Storage, JWT da conta).
## O rascunho local continua sendo a cópia de segurança: nada local é apagado por falha de rede,
## e o UUID definitivo é gravado no rascunho ANTES do envio, então repetir nunca duplica.
## Nomes de tabelas/colunas ficam só aqui (SCHEMA); ver docs/contracts/T21_DECKS.md.
const SCHEMA := {
	"decks": "qse_creator_decks",
	"cards": "qse_creator_cards",
	"favorites": "qse_deck_favorites",
	"music": "qse_user_music_selection",
	"bucket": "qse-deck-originals",
	# Colunas confirmadas no pedido T21.
	"deck_visibility": "requested_visibility",
	"card_image": "image_original_path",
	# Colunas presumidas (confirmar com o backend): vínculo e ordem da carta.
	"card_deck": "deck_id",
	"card_order": "position",
}
## T24: escolha de capa (cover_mode, cover_card_id, cover_image_path) em qse_creator_decks.
## Colunas confirmadas no GAME (docs/contracts/T24_BACKEND_GAME_CATALOG_RESULT.md). Enviadas num
## PATCH depois das cartas, porque cover_card_id tem FK para qse_creator_cards.
const COVER_COLUMNS := true
const EXT_TYPES := {"png": "image/png", "jpg": "image/jpeg", "webp": "image/webp"}

var client: SupabaseClient
var store: DeckDrafts
var user_id := ""


static func for_current(drafts: DeckDrafts) -> CreatorSync:
	var sync := CreatorSync.new()
	var services := PlayerServices.current
	sync.store = drafts
	if services != null and services.session != null and services.session.authenticated():
		sync.client = services.client
		sync.user_id = str(services.session.user.get("id", ""))
	return sync


func available() -> bool:
	return client != null and client.configured() and not user_id.is_empty() and OwnerStorage.safe(user_id) == store.owner


static func uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]


static func is_uuid(value: String) -> bool:
	return RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$").search(value) != null


## O servidor só aceita decks com nome e categoria válidos; antes disso o rascunho fica só aqui.
static func deck_ready(draft: Dictionary) -> String:
	var name := str(draft.get("name", "")).strip_edges()
	if name.length() < DeckDrafts.NAME_MIN or name.length() > DeckDrafts.NAME_MAX: return "Dê um nome de %d a %d caracteres para salvar na conta." % [DeckDrafts.NAME_MIN, DeckDrafts.NAME_MAX]
	if not str(draft.get("category", "")) in DeckDrafts.CATEGORIES: return "Escolha a categoria para salvar na conta."
	if (draft.get("cards", []) as Array).size() > 30: return "Máximo de 30 cartas."
	return ""


func storage_path(deck_id: String, card_id: String, suffix: String) -> String:
	return "%s/%s/%s_%s" % [user_id, deck_id, card_id, suffix]


func _rest(table: String) -> String:
	return "/rest/v1/" + table


## Envia um rascunho (deck, imagens, cartas). Atualiza e salva o rascunho local a cada
## etapa confirmada. Em falha, marca sync_state = "error" e mantém tudo local.
func push(draft: Dictionary) -> Dictionary:
	if draft.get("publication_backend","")=="repository": return ServiceResult.failure("repository_only")
	if not available(): return ServiceResult.failure("not_authenticated", "unauthorized")
	var blocked := deck_ready(draft)
	if not blocked.is_empty():
		draft.sync_state = "local"
		store.save(draft)
		return ServiceResult.failure("deck_incomplete")
	# 1. UUIDs definitivos gravados antes do envio (mapeamento local → servidor).
	if not is_uuid(str(draft.get("server_id", ""))): draft.server_id = uuid_v4()
	for card: Dictionary in draft.cards:
		if not is_uuid(str(card.get("server_id", ""))): card.server_id = uuid_v4()
	draft.sync_state = "pending"
	store.save(draft)
	var deck_id := str(draft.server_id)
	# 2. Deck: upsert pelo id. owner_id é sempre o da sessão (RLS recusa qualquer outro).
	var deck := {"id": deck_id, "owner_id": user_id, "name": str(draft.name).strip_edges(),
		"description": str(draft.get("description", "")).left(DeckDrafts.DESCRIPTION_MAX),
		"category": str(draft.category), SCHEMA.deck_visibility: str(draft.get("visibility", "private"))}
	var result := await client.send(_rest(SCHEMA.decks) + "?on_conflict=id", HTTPClient.METHOD_POST, [deck],
		PackedStringArray(["Prefer: resolution=merge-duplicates,return=minimal"]))
	if not result.ok: return _failed(draft, result)
	# 3. Imagens: original intacto (bytes do arquivo importado) e as duas prévias.
	var rows: Array = []
	for index in range(draft.cards.size()):
		var card: Dictionary = draft.cards[index]
		var card_id := str(card.server_id)
		var image_path := ""
		if not str(card.get("image_file", "")).is_empty():
			var extension := str(card.image_file).get_extension().to_lower()
			image_path = storage_path(deck_id, card_id, "original." + extension)
			if str(card.get("uploaded_original", "")) != image_path:
				result = await _upload(image_path, store.file_bytes(str(draft.id), str(card.image_file)), EXT_TYPES.get(extension, "image/png"))
				if not result.ok: return _failed(draft, result)
				card.uploaded_original = image_path
				store.save(draft)
			var crop_key := JSON.stringify(card.get("crops", {}))
			if str(card.get("uploaded_crops", "")) != crop_key:
				for format: String in ["library", "duel"]:
					var bytes := store.preview_bytes(str(draft.id), card, format)
					if bytes.is_empty(): continue
					result = await _upload(storage_path(deck_id, card_id, format + ".png"), bytes, "image/png")
					if not result.ok: return _failed(draft, result)
				card.uploaded_crops = crop_key
				store.save(draft)
		rows.append(card_row(deck_id, index, card, image_path))
	# 4. Cartas: upsert de todas e remoção das que saíram do rascunho.
	if not rows.is_empty():
		result = await client.send(_rest(SCHEMA.cards) + "?on_conflict=id", HTTPClient.METHOD_POST, rows,
			PackedStringArray(["Prefer: resolution=merge-duplicates,return=minimal"]))
		if not result.ok: return _failed(draft, result)
	var keep := []
	for card: Dictionary in draft.cards: keep.append(str(card.server_id))
	var filter := "?%s=eq.%s" % [SCHEMA.card_deck, deck_id] + ("&id=not.in.(%s)" % ",".join(keep) if not keep.is_empty() else "")
	result = await client.send(_rest(SCHEMA.cards) + filter, HTTPClient.METHOD_DELETE)
	if not result.ok: return _failed(draft, result)
	if COVER_COLUMNS:
		var cover := {}
		_cover_fields(draft, cover)
		if str(cover.cover_mode) == "upload" and str(draft.get("uploaded_cover", "")) != DeckCover.stamp(store.cover_path(str(draft.id))):
			result = await _upload(str(cover.cover_image_path), FileAccess.get_file_as_bytes(store.cover_path(str(draft.id))), "image/png")
			if not result.ok: return _failed(draft, result)
			draft.uploaded_cover = DeckCover.stamp(store.cover_path(str(draft.id)))
		result = await client.send(_rest(SCHEMA.decks) + "?id=eq." + deck_id, HTTPClient.METHOD_PATCH, cover, PackedStringArray(["Prefer: return=minimal"]))
		if not result.ok: return _failed(draft, result)
	draft.sync_state = "synced"
	draft.synced_at = int(Time.get_unix_time_from_system())
	store.save(draft)
	return ServiceResult.success(draft)


## Colunas de capa: modo, carta escolhida (UUID do servidor) e caminho da capa enviada.
func _cover_fields(draft: Dictionary, deck: Dictionary) -> void:
	var choice: Dictionary = draft.get("cover", {}) if draft.get("cover") is Dictionary else {}
	var mode := str(choice.get("mode", "auto"))
	deck.cover_mode = mode if mode in ["auto", "card", "upload"] else "auto"
	deck.cover_card_id = null
	deck.cover_image_path = null
	if mode == "card":
		for card: Dictionary in draft.cards:
			if str(card.id) == str(choice.get("card_id", "")): deck.cover_card_id = str(card.server_id)
		# Carta escolhida foi excluída: o servidor recebe a automática (como o aparelho mostra).
		if deck.cover_card_id == null: deck.cover_mode = "auto"
	elif mode == "upload" and FileAccess.file_exists(store.cover_path(str(draft.id))):
		deck.cover_image_path = "%s/%s/deck_cover.png" % [user_id, str(draft.server_id)]
	else:
		deck.cover_mode = "auto" if mode == "upload" else deck.cover_mode


static func card_row(deck_id: String, index: int, card: Dictionary, image_path: String) -> Dictionary:
	var crops: Dictionary = card.get("crops", {})
	var portrait := CardFramer.normalized(crops.get("library", {}) if crops.get("library") is Dictionary else {})
	var duel := CardFramer.normalized(crops.get("duel", {}) if crops.get("duel") is Dictionary else {})
	var row := {"id": str(card.server_id), SCHEMA.card_deck: deck_id, SCHEMA.card_order: index,
		"name": str(card.get("name", "")).strip_edges().left(DeckDrafts.CARD_NAME_MAX),
		"description": str(card.get("description", "")).left(DeckDrafts.CARD_DESCRIPTION_MAX),
		"portrait_center_x": portrait.x, "portrait_center_y": portrait.y, "portrait_zoom": portrait.zoom,
		"duel_center_x": duel.x, "duel_center_y": duel.y, "duel_zoom": duel.zoom}
	row[SCHEMA.card_image] = image_path if not image_path.is_empty() else null
	return row


func _upload(path: String, bytes: PackedByteArray, mime: String) -> Dictionary:
	if bytes.is_empty(): return ServiceResult.failure("missing_image")
	if bytes.size() > ImagePicker.MAX_BYTES: return ServiceResult.failure("payload_too_large")
	return await client.send("/storage/v1/object/%s/%s" % [SCHEMA.bucket, path], HTTPClient.METHOD_POST, null,
		PackedStringArray(["x-upsert: true"]), bytes, mime, 120.0)


func _failed(draft: Dictionary, result: Dictionary) -> Dictionary:
	draft.sync_state = "error"
	draft.sync_error = str(result.get("code", "request_failed"))
	store.save(draft)
	return result


## Rascunhos do servidor que ainda não existem neste aparelho (ex.: outro dispositivo).
## Baixa original e prévias para continuar editando. Nunca sobrescreve rascunho local pendente.
func pull() -> Dictionary:
	if not available(): return ServiceResult.failure("not_authenticated", "unauthorized")
	var result := await client.send(_rest(SCHEMA.decks) + "?select=*&owner_id=eq." + user_id, HTTPClient.METHOD_GET)
	if not result.ok: return result
	var decks: Array = result.data.data if result.data.data is Array else []
	var local := {}
	for draft: Dictionary in store.list():
		if is_uuid(str(draft.get("server_id", ""))): local[str(draft.server_id)] = draft
	var added := 0
	for deck: Dictionary in decks:
		var deck_id := str(deck.get("id", ""))
		if not is_uuid(deck_id) or str(deck.get("owner_id", "")) != user_id: continue
		var existing: Dictionary = local.get(deck_id, {})
		if not existing.is_empty() and str(existing.get("sync_state", "")) != "synced": continue
		var cards_result := await client.send(_rest(SCHEMA.cards) + "?select=*&%s=eq.%s&order=%s.asc" % [SCHEMA.card_deck, deck_id, SCHEMA.card_order], HTTPClient.METHOD_GET)
		if not cards_result.ok: return cards_result
		var draft := existing if not existing.is_empty() else store.new_draft()
		draft.publication_backend = "game"
		draft.server_id = deck_id
		draft.name = str(deck.get("name", ""))
		draft.description = str(deck.get("description", "")) if deck.get("description") != null else ""
		draft.category = str(deck.get("category", ""))
		draft.visibility = str(deck.get(SCHEMA.deck_visibility, "private"))
		draft.server_status = str(deck.get("status", "draft")) if deck.get("status") != null else "draft"
		draft.review_note = str(deck.get("review_note", "")) if deck.get("review_note") != null else ""
		var cards: Array = []
		for row: Dictionary in (cards_result.data.data if cards_result.data.data is Array else []):
			var card := {"id": "card_" + str(row.id).left(8), "server_id": str(row.id), "name": str(row.get("name", "")),
				"description": str(row.get("description", "")) if row.get("description") != null else "",
				"crops": {"library": {"x": row.get("portrait_center_x", 0.5), "y": row.get("portrait_center_y", 0.5), "zoom": row.get("portrait_zoom", 1.0)},
					"duel": {"x": row.get("duel_center_x", 0.5), "y": row.get("duel_center_y", 0.5), "zoom": row.get("duel_zoom", 1.0)}},
				"image_file": ""}
			var image_path := str(row.get(SCHEMA.card_image, "")) if row.get(SCHEMA.card_image) != null else ""
			if not image_path.is_empty() and image_path.begins_with(user_id + "/"):
				var download := await client.send("/storage/v1/object/authenticated/%s/%s" % [SCHEMA.bucket, image_path], HTTPClient.METHOD_GET, null, PackedStringArray(), PackedByteArray(), "application/octet-stream", 120.0)
				if download.ok:
					var extension := image_path.get_extension().to_lower()
					card.image_file = store.store_original(str(draft.id), str(card.id), download.data.bytes, extension)
					card.uploaded_original = image_path
					var image := Image.new()
					var bytes: PackedByteArray = download.data.bytes
					if (image.load_png_from_buffer(bytes) if extension == "png" else (image.load_webp_from_buffer(bytes) if extension == "webp" else image.load_jpg_from_buffer(bytes))) == OK:
						store.store_previews(str(draft.id), card, image)
						card.uploaded_crops = JSON.stringify(card.crops)
			cards.append(card)
		draft.cards = cards
		if COVER_COLUMNS and deck.get("cover_mode") is String:
			draft.cover = {"mode": str(deck.cover_mode)}
			for card: Dictionary in cards:
				if str(card.server_id) == str(deck.get("cover_card_id", "")): draft.cover.card_id = str(card.id)
			var cover_path := str(deck.get("cover_image_path", "")) if deck.get("cover_image_path") != null else ""
			if deck.cover_mode == "upload" and cover_path.begins_with(user_id + "/"):
				var cover := await client.send("/storage/v1/object/authenticated/%s/%s" % [SCHEMA.bucket, cover_path], HTTPClient.METHOD_GET, null, PackedStringArray(), PackedByteArray(), "application/octet-stream", 60.0)
				var image := Image.new()
				if cover.ok and image.load_png_from_buffer(cover.data.bytes) == OK:
					store.store_cover(str(draft.id), image, {})
					draft.uploaded_cover = DeckCover.stamp(store.cover_path(str(draft.id)))
		draft.sync_state = "synced"
		store.save(draft)
		added += 1
	return ServiceResult.success({"updated": added})


## Exclui no servidor (deck + cartas + imagens) e só depois apaga a cópia local.
func remove(draft: Dictionary) -> Dictionary:
	var deck_id := str(draft.get("server_id", ""))
	if is_uuid(deck_id) and available():
		var paths: Array = []
		for card: Dictionary in draft.get("cards", []):
			if is_uuid(str(card.get("server_id", ""))):
				for suffix in ["library.png", "duel.png"]: paths.append(storage_path(deck_id, str(card.server_id), suffix))
				if not str(card.get("uploaded_original", "")).is_empty(): paths.append(str(card.uploaded_original))
		var result := await client.send(_rest(SCHEMA.cards) + "?%s=eq.%s" % [SCHEMA.card_deck, deck_id], HTTPClient.METHOD_DELETE)
		if result.ok: result = await client.send(_rest(SCHEMA.decks) + "?id=eq." + deck_id, HTTPClient.METHOD_DELETE)
		if result.ok and not paths.is_empty():
			result = await client.send("/storage/v1/object/" + SCHEMA.bucket, HTTPClient.METHOD_DELETE, {"prefixes": paths})
		if not result.ok: return result
	store.delete(str(draft.id))
	return ServiceResult.success({})


# --- Favoritos -------------------------------------------------------------------------

static func deck_ref(deck_id: String) -> String:
	return ("creator:" if is_uuid(deck_id) else "official:") + deck_id


static func deck_id_from_ref(ref: String) -> String:
	return ref.trim_prefix("official:").trim_prefix("creator:")


## Junta favoritos locais e do servidor; envia ao servidor os que só existiam aqui.
func sync_favorites() -> Dictionary:
	if not available(): return ServiceResult.failure("not_authenticated", "unauthorized")
	var result := await client.send(_rest(SCHEMA.favorites) + "?select=deck_ref&user_id=eq." + user_id, HTTPClient.METHOD_GET)
	if not result.ok: return result
	var remote: Array[String] = []
	for row: Dictionary in (result.data.data if result.data.data is Array else []): remote.append(deck_id_from_ref(str(row.get("deck_ref", ""))))
	var pending_removals := store.pending_favorite_removals()
	for id: String in remote:
		if not pending_removals.has(id) and not store.is_favorite(id): store.set_favorite(id, true)
	for id: String in pending_removals:
		if id.begins_with("repo_"):
			store.clear_pending_favorite(id)
			continue
		result = await set_remote_favorite(id, false)
		if result.ok: store.clear_pending_favorite(id)
	for id: String in store.favorites():
		if id.begins_with("repo_"): continue
		if not remote.has(id):
			result = await set_remote_favorite(id, true)
			if not result.ok: return result
	return ServiceResult.success({"favorites": store.favorites()})


func set_remote_favorite(deck_id: String, value: bool) -> Dictionary:
	if not available(): return ServiceResult.failure("not_authenticated", "unauthorized")
	var ref := deck_ref(deck_id)
	if value:
		return await client.send(_rest(SCHEMA.favorites) + "?on_conflict=user_id,deck_ref", HTTPClient.METHOD_POST,
			[{"user_id": user_id, "deck_ref": ref}], PackedStringArray(["Prefer: resolution=ignore-duplicates,return=minimal"]))
	return await client.send(_rest(SCHEMA.favorites) + "?user_id=eq.%s&deck_ref=eq.%s" % [user_id, ref.uri_encode()], HTTPClient.METHOD_DELETE)


# --- Playlist pessoal ------------------------------------------------------------------

func pull_music() -> Dictionary:
	if client == null or not client.configured() or user_id.is_empty(): return ServiceResult.failure("not_authenticated", "unauthorized")
	var result := await client.send(_rest(SCHEMA.music) + "?select=hidden_track_ids,deselected_track_ids&user_id=eq." + user_id, HTTPClient.METHOD_GET)
	if not result.ok: return result
	var rows: Array = result.data.data if result.data.data is Array else []
	return ServiceResult.success(rows[0] if not rows.is_empty() else {})


func push_music(hidden: Array, deselected: Array) -> Dictionary:
	if client == null or not client.configured() or user_id.is_empty(): return ServiceResult.failure("not_authenticated", "unauthorized")
	return await client.send(_rest(SCHEMA.music) + "?on_conflict=user_id", HTTPClient.METHOD_POST,
		[{"user_id": user_id, "hidden_track_ids": hidden, "deselected_track_ids": deselected}],
		PackedStringArray(["Prefer: resolution=merge-duplicates,return=minimal"]))
