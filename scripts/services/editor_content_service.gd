class_name EditorContentService
extends Node
## Atualizações editoriais em produção: GAME Supabase, dados públicos com RLS.
## Nunca usa service_role, e nunca escreve no cliente. Offline mantém as artes locais.
signal changed

const PUBLIC_CONTENT := "/rest/v1/qse_editor_content?select=id,kind,title,subtitle,description,cover_path,active,priority,starts_at,ends_at&active=eq.true&order=priority.desc"
const BASE_URL := "https://shuzporktifgiotvnpbz.supabase.co/storage/v1/object/public/qse-editor-media/"
const CACHE_SECONDS := 45.0
const MAX_IMAGE_BYTES := 8 * 1024 * 1024

var client: SupabaseClient
var state := "local"
var entries: Dictionary = {}
var last_refresh := 0.0
var _requesting := false
var _textures: Dictionary = {}

func refresh(force := false) -> Dictionary:
	if _requesting: return ServiceResult.failure("busy")
	var now := Time.get_unix_time_from_system()
	if not force and state == "remote" and now - last_refresh < CACHE_SECONDS:
		return ServiceResult.success({"cache": true})
	if client == null or not client.configured():
		return ServiceResult.failure("offline")
	_requesting = true
	var res: Dictionary = await client.request(PUBLIC_CONTENT, HTTPClient.METHOD_GET, {}, false)
	_requesting = false
	if not res.ok or not res.data is Array:
		# Preserva conteúdo confirmado nesta sessão; sem rede, o jogo original continua.
		return res
	var result := {}
	for item: Variant in res.data:
		if not item is Dictionary: continue
		var record: Dictionary = item
		var id := str(record.get("id", ""))
		var kind := str(record.get("kind", ""))
		if kind not in ["deck", "news"] or not id.begins_with(kind + ":"):
			continue
		if not bool(record.get("active", false)): continue
		result[id] = record.duplicate(true)
	entries = result
	state = "remote"
	last_refresh = Time.get_unix_time_from_system()
	changed.emit()
	return ServiceResult.success({"count": entries.size()})

func deck(id: String) -> Dictionary:
	return entries.get("deck:" + id, {}) if state == "remote" else {}

func news_item(id: String) -> Dictionary:
	return entries.get("news:" + id, {}) if state == "remote" else {}

func news_cards() -> Array:
	var ordered := []
	if state != "remote": return ordered
	for key: String in entries:
		var record: Dictionary = entries[key]
		if record.get("kind") != "news": continue
		ordered.append(record)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	var cards := []
	for entry: Dictionary in ordered:
		cards.append({
			"image": "res://assets/processed/backgrounds/bg_lobby_fantasia.png",
			"eyebrow": str(entry.get("subtitle", "NOVIDADES")),
			"title": str(entry.get("title", "Quem Sou Eu")),
			"message": str(entry.get("description", "")),
			"cover_path": str(entry.get("cover_path", "")),
		})
	return cards

static func _valid_path(path: String) -> bool:
	if path.length() > 160 or not path.begins_with("covers/"): return false
	var re := RegEx.create_from_string("^covers/[a-zA-Z0-9_/-]{1,120}\\.(webp|png|jpg|jpeg)$")
	return re.search(path) != null

## Atualiza uma TextureRect sem bloquear a interface; respeita a destruição de telas.
func attach_cover(picture: TextureRect, path: String) -> void:
	if not is_instance_valid(picture) or not _valid_path(path): return
	if _textures.has(path):
		if _textures[path] is Texture2D: picture.texture = _textures[path]
		return
	_download_cover.call_deferred(picture, path)

func _download_cover(picture: TextureRect, path: String) -> void:
	if not _valid_path(path): return
	if _textures.has(path):
		if is_instance_valid(picture) and _textures[path] is Texture2D: picture.texture = _textures[path]
		return
	var req := HTTPRequest.new()
	req.timeout = 12.0
	req.body_size_limit = MAX_IMAGE_BYTES
	add_child(req)
	var started := req.request(BASE_URL + path)
	if started != OK:
		req.queue_free()
		return
	var response: Array = await req.request_completed
	req.queue_free()
	if response.size() < 4 or int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
		return
	var bytes: PackedByteArray = response[3]
	if bytes.is_empty() or bytes.size() > MAX_IMAGE_BYTES: return
	var picture_data := Image.new()
	var code := ERR_FILE_UNRECOGNIZED
	if path.ends_with(".png"): code = picture_data.load_png_from_buffer(bytes)
	elif path.ends_with(".webp"): code = picture_data.load_webp_from_buffer(bytes)
	elif path.ends_with(".jpg") or path.ends_with(".jpeg"): code = picture_data.load_jpg_from_buffer(bytes)
	if code != OK or picture_data.is_empty(): return
	if max(picture_data.get_width(),picture_data.get_height()) > 2048:
		var scale := 2048.0 / maxf(float(picture_data.get_width()),float(picture_data.get_height()))
		picture_data.resize(maxi(1,roundi(picture_data.get_width()*scale)), maxi(1,roundi(picture_data.get_height()*scale)), Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(picture_data)
	_textures[path] = texture
	if is_instance_valid(picture):
		picture.texture = texture
