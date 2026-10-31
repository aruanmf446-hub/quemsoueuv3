class_name SessionService
extends Node

signal changed
signal providers_changed
signal oauth_notice(code: String)
var client: SupabaseClient
var user: Dictionary = {}
var providers := {"google": false, "apple": false, "discord": false}
var needs_password_reset := false
var _refresh_token := ""
var _expires_at := 0.0
var _refreshing := false
var _desktop: OAuthDesktopLoopback
var _native_verifier := ""
var _oauth_pending_native := ""
var _persist_web := false


func _ready() -> void:
	if OS.get_cmdline_args().has("--script"): return
	# Only the GAME refresh token is persisted on the Web origin; never a provider secret.
	_persist_web = OS.has_feature("web") and bool(PlayerContracts.read_json("res://data/backend/client.json").get("persist_session", false))
	load_providers.call_deferred()
	_restore_web_redirect.call_deferred()
	if OS.has_feature("windows"):
		_desktop = OAuthDesktopLoopback.new()
		add_child(_desktop)
		_desktop.callback_received.connect(_native_callback)
		_desktop.callback_timeout.connect(_native_timeout)


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
	if not bool(providers.get(provider, false)):
		return false
	if OS.has_feature("web"):
		return true
	# Both native callbacks require configuration outside Godot and remain opt-in.
	var settings := PlayerContracts.read_json("res://data/backend/client.json")
	if OS.has_feature("windows"):
		return bool(settings.get("oauth_windows_loopback_ready", false))
	if OS.has_feature("android"):
		return bool(settings.get("oauth_android_deeplink_ready", false)) and Engine.has_singleton("AndroidRuntime")
	return false


func social_authorize(provider: String) -> Dictionary:
	if not social_available(provider) or not provider in ["google", "discord"]:
		return ServiceResult.failure("provider_unavailable")
	var verifier := OAuthPkce.make_verifier()
	var target := OAuthPkce.challenge(verifier)
	if verifier.is_empty() or target.is_empty():
		return ServiceResult.failure("oauth_unavailable")
	var destination := ""
	if OS.has_feature("web"):
		destination = _web_redirect_url()
		var pending := JSON.stringify({"provider": provider, "verifier": verifier, "created": Time.get_unix_time_from_system()})
		var js := "(function(){try{sessionStorage.setItem(" + JSON.stringify(OAuthPkce.PENDING_KEY) + "," + JSON.stringify(pending) + ");return true;}catch(e){return false;}})()"
		if JavaScriptBridge.eval(js) != true:
			return ServiceResult.failure("oauth_storage_unavailable")
	elif OS.has_feature("windows"):
		if _desktop == null or not _desktop.start():
			return ServiceResult.failure("oauth_loopback_unavailable")
		destination = OAuthPkce.REDIRECT_WINDOWS
		_native_verifier = verifier
		_oauth_pending_native = provider
	elif OS.has_feature("android"):
		destination = OAuthPkce.REDIRECT_ANDROID
		_native_verifier = verifier
		_oauth_pending_native = provider
	if destination.is_empty():
		return ServiceResult.failure("oauth_unavailable")
	var url := client.endpoint + OAuthPkce.authorize_path(provider, destination, target)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.assign(" + JSON.stringify(url) + ")")
	else:
		if OS.shell_open(url) != OK:
			if _desktop != null:
				_desktop.close()
			_native_verifier = ""
			_oauth_pending_native = ""
			return ServiceResult.failure("oauth_browser_failed")
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
	# Remove sensitive codes/fragments from the address bar before any HTTP request.
	var js := "(function(){var u=new URL(window.location.href);var h=new URLSearchParams(u.hash.slice(1));var q=u.searchParams;var o={code:q.get('code')||'',error:q.get('error')||h.get('error')||'',access_token:h.get('access_token')||'',refresh_token:h.get('refresh_token')||'',expires_in:Number(h.get('expires_in')||3600),type:h.get('type')||''};if(o.code||o.error||o.access_token){q.delete('code');q.delete('error');q.delete('error_description');u.hash='';history.replaceState({},document.title,u.pathname+u.search);}return JSON.stringify(o);})()"
	var raw: Variant = JavaScriptBridge.eval(js)
	var data: Variant = JSON.parse_string(str(raw))
	if not data is Dictionary:
		return
	var code := str(data.get("code", ""))
	if not code.is_empty():
		await _exchange_web_code(code)
		return
	if not str(data.get("error", "")).is_empty():
		_clear_pending_web()
		oauth_notice.emit("oauth_access_denied" if str(data.error) == "access_denied" else "oauth_exchange_failed")
		return
	if not str(data.get("access_token", "")).is_empty():
		# Keep recovery/email confirmations using the legacy implicit links.
		var verified := await client.request("/auth/v1/user", HTTPClient.METHOD_GET, {}, false, str(data.access_token))
		if verified.ok and verified.data is Dictionary:
			data["user"] = verified.data
			needs_password_reset = str(data.get("type", "")) == "recovery"
			_accept(data)
		return
	await _restore_saved_web_session()


func _exchange_web_code(code: String) -> void:
	var pending_raw: Variant = JavaScriptBridge.eval("(function(){try{var k=" + JSON.stringify(OAuthPkce.PENDING_KEY) + ";var v=sessionStorage.getItem(k)||'';sessionStorage.removeItem(k);return v;}catch(e){return '';}})()")
	var pending: Variant = JSON.parse_string(str(pending_raw))
	if not pending is Dictionary or not str(pending.get("provider", "")) in ["google", "discord"]:
		oauth_notice.emit("oauth_missing_verifier")
		return
	if Time.get_unix_time_from_system() - float(pending.get("created", 0.0)) > OAuthPkce.MAX_PENDING_SECONDS:
		oauth_notice.emit("oauth_expired")
		return
	var verifier := str(pending.get("verifier", ""))
	if verifier.length() < 43 or not OAuthPkce.valid_callback(code):
		oauth_notice.emit("oauth_missing_verifier")
		return
	await _exchange_code(code, verifier)


func _exchange_code(code: String, verifier: String) -> void:
	var response := await client.request("/auth/v1/token?grant_type=pkce", HTTPClient.METHOD_POST, {"auth_code": code, "code_verifier": verifier}, false)
	# Do not log the code, verifier or tokens.
	if not response.ok:
		oauth_notice.emit("oauth_exchange_failed")
		return
	if not response.data is Dictionary:
		oauth_notice.emit("oauth_exchange_failed")
		return
	var token := str(response.data.get("access_token", ""))
	var verified := await client.request("/auth/v1/user", HTTPClient.METHOD_GET, {}, false, token)
	if not verified.ok or not verified.data is Dictionary:
		oauth_notice.emit("oauth_exchange_failed")
		return
	var payload: Dictionary = response.data.duplicate()
	payload["user"] = verified.data
	if not _accept(payload).ok:
		oauth_notice.emit("oauth_exchange_failed")


func _clear_pending_web() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{sessionStorage.removeItem(" + JSON.stringify(OAuthPkce.PENDING_KEY) + ");}catch(e){}})()")


func _store_web_refresh() -> void:
	if not _persist_web or _refresh_token.is_empty():
		return
	JavaScriptBridge.eval("(function(){try{localStorage.setItem(" + JSON.stringify(OAuthPkce.REFRESH_KEY) + "," + JSON.stringify(_refresh_token) + ");return true;}catch(e){return false;}})()")


func _clear_web_refresh() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{localStorage.removeItem(" + JSON.stringify(OAuthPkce.REFRESH_KEY) + ");}catch(e){}})()")


func _restore_saved_web_session() -> void:
	if not _persist_web or authenticated():
		return
	var js := "(function(){try{return localStorage.getItem(" + JSON.stringify(OAuthPkce.REFRESH_KEY) + ")||'';}catch(e){return '';}})()"
	var saved := str(JavaScriptBridge.eval(js))
	if saved.is_empty():
		return
	var response := await client.request("/auth/v1/token?grant_type=refresh_token", HTTPClient.METHOD_POST, {"refresh_token": saved}, false)
	saved = ""
	if response.ok and response.data is Dictionary:
		var accepted := _accept(response.data)
		if accepted.ok:
			return
	if response.code not in ["network", "rate_limit", "session_changed"]:
		_clear_web_refresh()


func _native_callback(code: String, error: String) -> void:
	var verifier := _native_verifier
	_native_verifier = ""
	_oauth_pending_native = ""
	if not error.is_empty():
		oauth_notice.emit("oauth_access_denied" if error == "access_denied" else "oauth_exchange_failed")
		return
	if verifier.is_empty() or not OAuthPkce.valid_callback(code):
		oauth_notice.emit("oauth_missing_verifier")
		return
	_exchange_code(code, verifier)


func _native_timeout() -> void:
	_native_verifier = ""
	_oauth_pending_native = ""
	oauth_notice.emit("oauth_expired")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and OS.has_feature("android") and not _native_verifier.is_empty():
		_check_android_link.call_deferred()


func _check_android_link() -> void:
	# Requires a verified Android intent filter and AndroidRuntime enabled.
	if not Engine.has_singleton("AndroidRuntime"):
		return
	var runtime := Engine.get_singleton("AndroidRuntime")
	var activity = runtime.getActivity()
	if activity == null:
		return
	var intent = activity.getIntent()
	if intent == null:
		return
	var url := str(intent.getDataString())
	if not url.begins_with(OAuthPkce.REDIRECT_ANDROID + "?"):
		return
	# Prevent reusing the same intent after another focus event.
	intent.setData(null)
	var parsed := OAuthDesktopLoopback._parse_query(url.get_slice("?", 1))
	_native_callback(str(parsed.get("code", "")), str(parsed.get("error", "")))


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
	_clear_pending_web()
	if _desktop != null:
		_desktop.close()
	_native_verifier = ""
	_oauth_pending_native = ""
	client.set_session("")
	user.clear()
	_refresh_token = ""
	_expires_at = 0.0
	needs_password_reset = false
	changed.emit()
