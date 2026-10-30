class_name SupabaseClient
extends Node

## HTTP real. Chave pública externa; sessão apenas em memória; uma requisição por nó.
##
## Três conexões independentes (cada uma com URL e chave publicável próprias):
## - "game": a conexão atual (autenticação, perfis e demais serviços já existentes).
## - "chat" e "catalog": URLs publicas configuradas, sem JWT compartilhado.
## Cada nó fala com uma só conexão. A sessão (JWT) só existe na "game": set_session é
## recusado nas outras, para nenhum token de um projeto ir a outro.
##
## Configuração por conexão (a última vence): data/backend/client.json, user://backend.cfg
## (seção [supabase] para "game", [supabase_chat] e [supabase_catalog]), variáveis de
## ambiente QSE_SUPABASE_<CONEXÃO>_URL / _PUBLISHABLE_KEY e, na Web, QSE_PUBLIC_CONFIG.
## A URL de "game" aponta para o projeto GAME. GAME, CHAT e CATALOG nao compartilham tokens.
const CONNECTIONS := ["game", "chat", "catalog"]
const GAME_URL := "https://shuzporktifgiotvnpbz.supabase.co"
var connection := "game"
var endpoint := ""
var publishable_key := ""
var access_token := ""
var generation := 0


func _ready() -> void:
	if not CONNECTIONS.has(connection):
		push_error("Conexão Supabase desconhecida: %s" % connection)
		connection = ""
		return
	var config := PlayerContracts.read_json("res://data/backend/client.json")
	var game := connection == "game"
	var entry: Dictionary = config if game else config.get("connections", {}).get(connection, {})
	endpoint = str(entry.get("url", "")).trim_suffix("/")
	publishable_key = str(entry.get("publishable_key", ""))
	var section := "supabase" if game else "supabase_" + connection
	var prefix := "QSE_SUPABASE_" + connection.to_upper() + "_"
	var external := ConfigFile.new()
	if external.load("user://backend.cfg") == OK:
		publishable_key = str(external.get_value(section, "publishable_key", publishable_key))
		if not game: endpoint = str(external.get_value(section, "url", endpoint)).trim_suffix("/")
	if game and OS.has_environment("QSE_SUPABASE_PUBLISHABLE_KEY"):
		publishable_key = OS.get_environment("QSE_SUPABASE_PUBLISHABLE_KEY")
	if OS.has_environment(prefix + "PUBLISHABLE_KEY"):
		publishable_key = OS.get_environment(prefix + "PUBLISHABLE_KEY")
	if not game and OS.has_environment(prefix + "URL"):
		endpoint = OS.get_environment(prefix + "URL").trim_suffix("/")
	if OS.has_feature("web"):
		var browser_config: Variant = JavaScriptBridge.get_interface("QSE_PUBLIC_CONFIG")
		if browser_config != null:
			if game and browser_config.publishable_key != null:
				publishable_key = str(browser_config.publishable_key)
			elif not game and browser_config.connections != null and browser_config.connections[connection] != null:
				var web_entry: Variant = browser_config.connections[connection]
				publishable_key = str(web_entry.publishable_key)
				endpoint = str(web_entry.url).trim_suffix("/")
	if not _public_key_only(publishable_key):
		publishable_key = ""
	if not game and not _supabase_url(endpoint):
		endpoint = ""


func configured() -> bool:
	if connection == "game":
		return endpoint == GAME_URL and not publishable_key.is_empty()
	return _supabase_url(endpoint) and endpoint != GAME_URL and not publishable_key.is_empty()


## Só HTTPS de um projeto Supabase (https://<ref>.supabase.co), sem caminho.
static func _supabase_url(url: String) -> bool:
	var found := RegEx.create_from_string("^https://[a-z0-9]{20}\\.supabase\\.co$").search(url)
	return found != null


func set_session(token: String) -> void:
	if connection != "game" and not token.is_empty():
		push_warning("Sessão só pertence à conexão game; recusada em %s." % connection)
		return
	access_token = token
	generation += 1


func call_rpc(name: String, params: Dictionary = {}) -> Dictionary:
	return await request("/rest/v1/rpc/" + name, HTTPClient.METHOD_POST, params)


func request(path: String, method: HTTPClient.Method, body: Dictionary = {}, authenticated: bool = true, token_override: String = "") -> Dictionary:
	if not configured():
		return ServiceResult.failure("not_configured", "offline")
	if authenticated and access_token.is_empty():
		return ServiceResult.failure("not_authenticated", "unauthorized")
	var epoch := generation
	var http := HTTPRequest.new()
	http.timeout = 15.0
	http.body_size_limit = 2097152
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + publishable_key])
	if authenticated:
		headers.append("Authorization: Bearer " + access_token)
	elif not token_override.is_empty():
		headers.append("Authorization: Bearer " + token_override)
	var error := http.request(endpoint + path, headers, method, JSON.stringify(body) if method != HTTPClient.METHOD_GET else "")
	if error != OK:
		http.queue_free()
		return ServiceResult.failure("network", "offline")
	var response: Array = await http.request_completed
	http.queue_free()
	if epoch != generation:
		return ServiceResult.failure("session_changed", "unauthorized")
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return ServiceResult.failure("network", "offline")
	var status := int(response[1])
	if status == 401 or status == 403:
		return ServiceResult.failure("not_authenticated", "unauthorized")
	if status == 429:
		return ServiceResult.failure("rate_limit")
	var data: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	if status < 200 or status >= 300:
		return ServiceResult.failure("invalid_credentials" if path.begins_with("/auth/") else "request_failed")
	if data is Dictionary and data.has("error"):
		return ServiceResult.failure(str(data.error))
	return ServiceResult.success(data)


static func _public_key_only(key: String) -> bool:
	if key.begins_with("sb_publishable_"):
		return true
	var parts := key.split(".")
	if parts.size() != 3:
		return false
	var payload := parts[1].replace("-", "+").replace("_", "/")
	while payload.length() % 4 != 0:
		payload += "="
	var decoded: Variant = JSON.parse_string(Marshalls.base64_to_utf8(payload))
	return decoded is Dictionary and decoded.get("role") == "anon"
