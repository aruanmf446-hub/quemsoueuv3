class_name SessionService
extends Node

signal changed
signal providers_changed
signal initial_restore_finished
var client: SupabaseClient
var user: Dictionary = {}
var providers := {"google": false, "apple": false, "discord": false}
var needs_password_reset := false
var _refresh_token := ""
var _expires_at := 0.0
var _refreshing := false
var _persist_web := false
var initial_restore_complete := false
const WEB_REFRESH_KEY := "qse-v3:game:refresh"


func _ready() -> void:
	if OS.get_cmdline_args().has("--script"): return
	# Web: restore using a rotating GAME refresh token scoped to the Pages origin.
	# Native builds stay in-memory until a platform keystore is integrated.
	_persist_web = OS.has_feature("web") and bool(PlayerContracts.read_json("res://data/backend/client.json").get("persist_session", false))
	load_providers.call_deferred()
	_initialize_initial_session.call_deferred()


## O lobby so decide qual tela mostrar depois de restaurar a sessao GAME.
func _initialize_initial_session() -> void:
	if OS.has_feature("web") and client.configured():
		await _restore_web_redirect()
	initial_restore_complete = true
	initial_restore_finished.emit()


func authenticated() -> bool:
	return not user.is_empty() and not client.access_token.is_empty()


static func valid_email(email: String) -> bool:
	email = email.strip_edges()
	var at := email.find("@")
	var dot := email.rfind(".")
	return at > 0 and dot > at + 1 and dot < email.length() - 1 and not email.contains(" ") and email.length() <= 254


static func validate_email_password(email: String, password: String, signup := false) -> String:
	if not valid_email(email):
		return "email_address_invalid"
	if password.is_empty():
		return "password_required"
	if signup and password.length() < 6:
		return "weak_password"
	return ""


func sign_in(email: String, password: String) -> Dictionary:
	var failure := validate_email_password(email, password)
	if not failure.is_empty():
		return ServiceResult.failure(failure)
	var result := await client.request("/auth/v1/token?grant_type=password", HTTPClient.METHOD_POST, {"email": email.strip_edges(), "password": password}, false)
	if result.ok:
		return _accept(result.data)
	return result


func sign_up(email: String, password: String) -> Dictionary:
	var failure := validate_email_password(email, password, true)
	if not failure.is_empty():
		return ServiceResult.failure(failure)
	var path := "/auth/v1/signup"
	var destination := _web_redirect_url()
	if not destination.is_empty():
		path += "?redirect_to=" + destination.uri_encode()
	var result := await client.request(path, HTTPClient.METHOD_POST, {"email": email.strip_edges(), "password": password}, false)
	if not result.ok:
		return result
	if not result.data is Dictionary:
		return ServiceResult.failure("invalid_contract")
	if not str(result.data.get("access_token", "")).is_empty():
		return _accept(result.data)
	# Confirmacao de e-mail habilitada retorna user sem access_token. Nao tratar como erro.
	if result.data.get("user") is Dictionary or result.data.has("id"):
		return ServiceResult.success({"confirmation_pending": true})
	return ServiceResult.failure("invalid_contract")


func send_recovery(email: String) -> Dictionary:
	if not valid_email(email):
		return ServiceResult.failure("email_address_invalid")
	var path := "/auth/v1/recover"
	var destination := _web_redirect_url()
	if not destination.is_empty():
		path += "?redirect_to=" + destination.uri_encode()
	return await client.request(path, HTTPClient.METHOD_POST, {"email": email.strip_edges()}, false)


func resend_confirmation(email: String) -> Dictionary:
	if not valid_email(email):
		return ServiceResult.failure("email_address_invalid")
	return await client.request("/auth/v1/resend", HTTPClient.METHOD_POST, {"type": "signup", "email": email.strip_edges()}, false)


func update_password(password: String) -> Dictionary:
	if not authenticated() or not needs_password_reset:
		return ServiceResult.failure("not_authenticated", "unauthorized")
	if password.length() < 6:
		return ServiceResult.failure("weak_password")
	var result := await client.request("/auth/v1/user", HTTPClient.METHOD_PUT, {"password": password})
	if result.ok:
		needs_password_reset = false
		changed.emit()
	return result


func sign_out() -> Dictionary:
	var token := client.access_token
	_clear()
	if token.is_empty():
		return ServiceResult.success(null)
	return await client.request("/auth/v1/logout?scope=local", HTTPClient.METHOD_POST, {}, false, token)


func load_providers() -> void:
	var result := await client.request("/auth/v1/settings", HTTPClient.METHOD_GET, {}, false)
	if not result.ok or not result.data is Dictionary:
		return
	var external: Variant = result.data.get("external", {})
	if not external is Dictionary:
		return
	for name: String in providers:
		providers[name] = external.get(name, false) == true
	providers_changed.emit()


func social_available(provider: String) -> bool:
	return OS.has_feature("web") and bool(providers.get(provider, false))


func social_authorize(provider: String) -> Dictionary:
	if not social_available(provider):
		return ServiceResult.failure("provider_unavailable")
	var destination := _web_redirect_url()
	if destination.is_empty():
		return ServiceResult.failure("provider_unavailable")
	var url := client.endpoint + "/auth/v1/authorize?provider=" + provider.uri_encode() + "&redirect_to=" + destination.uri_encode()
	# A autorizacao acontece no navegador. Nenhum client_secret fica no Godot.
	JavaScriptBridge.eval("window.location.assign(" + JSON.stringify(url) + ")")
	return ServiceResult.success(null)


func _web_redirect_url() -> String:
	if not OS.has_feature("web"):
		return ""
	# Mantem somente o parametro invite e o caminho da pagina (sem fragmentos JWT).
	var value: Variant = JavaScriptBridge.eval("(function(){var u=new URL(window.location.href);u.hash='';var t=u.searchParams.get('invite');u.search='';if(t&&/^[A-Za-z0-9_-]{32,256}$/.test(t))u.searchParams.set('invite',t);return u.href;})()")
	return str(value) if value != null else ""


func _restore_web_redirect() -> void:
	if not OS.has_feature("web") or not client.configured():
		return
	# Le token do fragmento (retorno do GoTrue), remove-o da barra/historico
	# imediatamente e valida identidade no endpoint GAME antes de aceitar a sessao.
	var json: Variant = JavaScriptBridge.eval("(function(){var h=new URLSearchParams(window.location.hash.slice(1));if(!h.has('access_token'))return '';var o={access_token:h.get('access_token'),refresh_token:h.get('refresh_token'),expires_in:Number(h.get('expires_in')||3600),type:h.get('type')||''};history.replaceState({},document.title,window.location.pathname+window.location.search);return JSON.stringify(o);})()")
	if json == null or str(json).is_empty():
		await _restore_saved_web_session()
		return
	var payload: Variant = JSON.parse_string(str(json))
	if not payload is Dictionary or str(payload.get("access_token", "")).is_empty():
		return
	var verified := await client.request("/auth/v1/user", HTTPClient.METHOD_GET, {}, false, str(payload.access_token))
	if not verified.ok or not verified.data is Dictionary:
		return
	payload["user"] = verified.data
	needs_password_reset = str(payload.get("type", "")) == "recovery"
	_accept(payload)


func _store_web_refresh() -> void:
	if not _persist_web or _refresh_token.is_empty():
		return
	JavaScriptBridge.eval("(function(){try{localStorage.setItem(" + JSON.stringify(WEB_REFRESH_KEY) + "," + JSON.stringify(_refresh_token) + ");return true;}catch(e){return false;}})()")


func _clear_web_refresh() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{localStorage.removeItem(" + JSON.stringify(WEB_REFRESH_KEY) + ");}catch(e){}})()")


func _restore_saved_web_session() -> void:
	if not _persist_web or authenticated():
		return
	var script := "(function(){try{return localStorage.getItem(" + JSON.stringify(WEB_REFRESH_KEY) + ")||'';}catch(e){return '';}})()"
	var token := str(JavaScriptBridge.eval(script))
	if token.is_empty():
		return
	var result := await client.request("/auth/v1/token?grant_type=refresh_token", HTTPClient.METHOD_POST, {"refresh_token": token}, false)
	token = ""
	if result.ok:
		var accepted := _accept(result.data)
		if accepted.ok:
			return
	if result.code not in ["network", "rate_limit", "session_changed"]:
		_clear_web_refresh()


func _accept(data: Variant) -> Dictionary:
	if not data is Dictionary or not data.get("user") is Dictionary or str(data.get("access_token", "")).is_empty():
		return ServiceResult.failure("invalid_contract")
	var incoming: Dictionary = data.user
	if str(incoming.get("id", "")).is_empty():
		return ServiceResult.failure("invalid_contract")
	var old_id := str(user.get("id", ""))
	client.set_session(str(data.access_token))
	user = incoming
	_refresh_token = str(data.get("refresh_token", ""))
	_store_web_refresh()
	_expires_at = Time.get_unix_time_from_system() + maxf(float(data.get("expires_in", 3600)) - 90.0, 1.0)
	# Renovar JWT nao limpa perfil/inventario/amizades/duelo como nova conta.
	if old_id != str(user.id):
		changed.emit()
	return ServiceResult.success(user.duplicate(true))


func _process(_delta: float) -> void:
	if authenticated() and not _refreshing and Time.get_unix_time_from_system() >= _expires_at:
		_refreshing = true
		_refresh()


func _refresh() -> void:
	if _refresh_token.is_empty():
		_clear()
		_refreshing = false
		return
	var result := await client.request("/auth/v1/token?grant_type=refresh_token", HTTPClient.METHOD_POST, {"refresh_token": _refresh_token}, false)
	if result.ok:
		_accept(result.data)
	elif result.code in ["network", "rate_limit", "auth_request_failed"]:
		# Oscilacao de rede ou limite nao equivale a logout. Retry controlado.
		_expires_at = Time.get_unix_time_from_system() + 45.0
	elif result.code != "session_changed":
		_clear()
	_refreshing = false


func _clear() -> void:
	_clear_web_refresh()
	client.set_session("")
	user.clear()
	_refresh_token = ""
	_expires_at = 0.0
	needs_password_reset = false
	changed.emit()
