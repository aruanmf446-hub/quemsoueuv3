class_name CommunityService
extends RefCounted
## Comunidade (T24, validada ponta a ponta com contas reais): vitrine de decks publicados por
## outros jogadores, publicação com moderação, retirada e denúncia. Só com sessão do GAME.
## As imagens vêm do bucket privado por download autenticado (somente prévias e capa;
## o original nunca é público) e ficam em cache no aparelho.

const BUCKET := "qse-deck-originals"
const CACHE := "user://community_cache"
const LIST_TTL := 120.0
const ERRORS := {
	"min_cards": "O deck precisa de pelo menos 5 cartas com imagem e nome.",
	"missing_images_or_previews": "Envie o deck para a sua conta (com todas as imagens) antes de publicar.",
	"invalid_status": "Este deck já está em revisão ou publicado.",
	"deck_not_found": "Deck não encontrado ou não está mais publicado.",
	"removed": "Este deck foi removido pela moderação.",
	"already_reported": "Você já denunciou este deck.",
	"cannot_report_own": "Você não pode denunciar o próprio deck.",
	"invalid_reason": "Escreva o motivo (até 280 caracteres).",
	"deck_not_published": "Este deck não está publicado.",
	"unauthorized": "Entre na conta para usar a Comunidade.",
}

## Itens da última vitrine (compartilhados entre telas) e quando foram buscados.
static var items: Array = []
static var loaded_at := -1000.0
static var state := "idle"
var client: SupabaseClient


static func for_current() -> CommunityService:
	var service := CommunityService.new()
	var services := PlayerServices.current
	if services != null and services.session != null and services.session.authenticated(): service.client = services.client
	return service


func available() -> bool:
	return client != null and client.configured() and not client.access_token.is_empty()


static func message(code: String) -> String:
	return ERRORS.get(code, "Não foi possível concluir agora. Tente novamente.")


## Resposta de RPC jsonb: {"error": ...} vira falha com o código.
static func _unwrap(result: Dictionary) -> Dictionary:
	if not result.ok: return result
	if result.data is Dictionary and (result.data as Dictionary).has("error"): return ServiceResult.failure(str(result.data.error))
	return result


func refresh(force := false) -> Dictionary:
	if not available():
		state = "offline"
		return ServiceResult.failure("unauthorized")
	if not force and state == "ok" and Time.get_ticks_msec() / 1000.0 - loaded_at < LIST_TTL: return ServiceResult.success(items)
	state = "loading"
	var result := _unwrap(await client.call_rpc("qse_community_decks", {"p_query": null, "p_theme": null, "p_sort": "recent", "p_limit": 48, "p_cursor": null}))
	if not result.ok or not result.data is Dictionary:
		state = "error"
		return result if not result.ok else ServiceResult.failure("invalid_contract")
	var valid: Array = []
	for row: Variant in result.data.get("items", []):
		if row is Dictionary and CreatorSync.is_uuid(str(row.get("id", ""))): valid.append(row)
	items = valid
	loaded_at = Time.get_ticks_msec() / 1000.0
	state = "ok"
	return ServiceResult.success(items)


## Arquivo local de uma imagem do bucket (baixa uma vez; caminho do objeto vira nome de cache).
func image(path: String) -> String:
	if path.is_empty() or path.contains(".."): return ""
	var local := "%s/%s.png" % [CACHE, path.sha256_text()]
	if FileAccess.file_exists(local): return local
	if not available(): return ""
	var result := await client.send("/storage/v1/object/authenticated/%s/%s" % [BUCKET, path], HTTPClient.METHOD_GET, null, PackedStringArray(), PackedByteArray(), "application/octet-stream", 60.0)
	if not result.ok or not result.data is Dictionary or (result.data.bytes as PackedByteArray).is_empty(): return ""
	DirAccess.make_dir_recursive_absolute(CACHE)
	var file := FileAccess.open(local, FileAccess.WRITE)
	if file == null: return ""
	file.store_buffer(result.data.bytes)
	file.close()
	return local


static func cached_image(path: String) -> String:
	if path.is_empty(): return ""
	var local := "%s/%s.png" % [CACHE, path.sha256_text()]
	return local if FileAccess.file_exists(local) else ""


## Deck publicado no formato do catálogo (cartas com prévias locais) para a galeria/leitor.
func open_deck(deck_id: String) -> Dictionary:
	var result := _unwrap(await client.call_rpc("qse_community_deck", {"p_deck": deck_id}))
	if not result.ok or not result.data is Dictionary: return result if not result.ok else ServiceResult.failure("invalid_contract")
	var deck: Dictionary = result.data.get("deck", {})
	var cards: Array[Dictionary] = []
	var index := 0
	for card: Variant in result.data.get("cards", []):
		if not card is Dictionary: continue
		var local := await image(str(card.get("preview_library_path", "")))
		cards.append({"id": "%s/%d" % [deck_id, index], "name": str(card.get("name", "")), "description": str(card.get("description", "")) if card.get("description") != null else "", "image": local})
		index += 1
	var creator: Dictionary = deck.get("creator", {}) if deck.get("creator") is Dictionary else {}
	return ServiceResult.success({"id": deck_id, "name": str(deck.get("name", "")), "official": false, "community": true,
		"creator": str(creator.get("nickname", "")) if creator.get("nickname") != null else "", "category": str(deck.get("category", "")) if deck.get("category") != null else "",
		"description": str(deck.get("description", "")) if deck.get("description") != null else "", "tags": [], "age_rating": "",
		"content_warnings": [], "cards": cards, "count": cards.size(), "origin": "community", "visibility": "public"})


func publish_request(server_id: String) -> Dictionary:
	return _unwrap(await client.call_rpc("qse_deck_publish_request", {"p_deck": server_id}))


func unpublish(server_id: String) -> Dictionary:
	return _unwrap(await client.call_rpc("qse_deck_unpublish", {"p_deck": server_id}))


func report(deck_id: String, reason: String) -> Dictionary:
	return _unwrap(await client.call_rpc("qse_deck_report", {"p_deck": deck_id, "p_reason": reason.strip_edges().left(280)}))


## Situação de moderação dos decks do dono (status/review_note), sem baixar cartas.
func statuses() -> Dictionary:
	var result := await client.send("/rest/v1/qse_creator_decks?select=id,status,review_note", HTTPClient.METHOD_GET)
	if not result.ok: return result
	var rows: Variant = result.data.data if result.data is Dictionary else null
	var map := {}
	for row: Variant in rows if rows is Array else []:
		if row is Dictionary: map[str(row.get("id", ""))] = {"status": str(row.get("status", "draft")), "review_note": str(row.get("review_note", "")) if row.get("review_note") != null else ""}
	return ServiceResult.success(map)
