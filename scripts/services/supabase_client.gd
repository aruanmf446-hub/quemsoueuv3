class_name SupabaseClient
extends Node

## HTTP real. Chave pública externa; sessão apenas em memória; uma requisição por nó.
var endpoint := ""
var publishable_key := ""
var access_token := ""
var generation := 0


func _ready() -> void:
	var config := PlayerContracts.read_json("res://data/backend/client.json")
	endpoint = str(config.get("url", "")).trim_suffix("/")
	publishable_key = str(config.get("publishable_key", ""))
	var external := ConfigFile.new()
	if external.load("user://backend.cfg") == OK:
		publishable_key = str(external.get_value("supabase", "publishable_key", publishable_key))
	if OS.has_environment("QSE_SUPABASE_PUBLISHABLE_KEY"):
		publishable_key = OS.get_environment("QSE_SUPABASE_PUBLISHABLE_KEY")
	if OS.has_feature("web"):
		var browser_config: Variant = JavaScriptBridge.get_interface("QSE_PUBLIC_CONFIG")
		if browser_config != null:
			publishable_key = str(browser_config.publishable_key)
	if not _public_key_only(publishable_key):
		publishable_key = ""


func configured() -> bool:
	return endpoint == "https://xgmlphejalzakucllsmw.supabase.co" and not publishable_key.is_empty()


func set_session(token: String) -> void:
	access_token = token
	generation += 1


func rpc(name: String, params: Dictionary = {}) -> Dictionary:
	return await request("/rest/v1/rpc/" + name, HTTPClient.METHOD_POST, params)


func request(path: String, method: HTTPClient.Method, body: Dictionary = {}, authenticated: bool = true) -> Dictionary:
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
