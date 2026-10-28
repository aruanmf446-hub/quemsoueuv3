class_name SessionService
extends Node

signal changed
var client: SupabaseClient
var user: Dictionary = {}
var _refresh_token := ""
var _expires_at := 0.0
var _refreshing := false


func authenticated() -> bool:
	return not user.is_empty() and not client.access_token.is_empty()


func sign_in(email: String, password: String) -> Dictionary:
	var result := await client.request("/auth/v1/token?grant_type=password", HTTPClient.METHOD_POST, {"email": email.strip_edges(), "password": password}, false)
	if result.ok:
		return _accept(result.data)
	return result


func sign_up(email: String, password: String) -> Dictionary:
	var result := await client.request("/auth/v1/signup", HTTPClient.METHOD_POST, {"email": email.strip_edges(), "password": password}, false)
	if result.ok and result.data is Dictionary and result.data.get("access_token", "") != "":
		return _accept(result.data)
	return result


func sign_out() -> Dictionary:
	var result := ServiceResult.success(null)
	if authenticated():
		result = await client.request("/auth/v1/logout", HTTPClient.METHOD_POST)
	_clear()
	return result


func _accept(data: Variant) -> Dictionary:
	if not data is Dictionary or not data.get("user") is Dictionary or str(data.get("access_token", "")).is_empty():
		return ServiceResult.failure("invalid_contract")
	if str(data.user.get("id", "")).is_empty():
		return ServiceResult.failure("invalid_contract")
	client.set_session(str(data.access_token))
	user = data.user
	_refresh_token = str(data.get("refresh_token", ""))
	_expires_at = Time.get_unix_time_from_system() + maxf(float(data.get("expires_in", 3600)) - 90.0, 1.0)
	changed.emit()
	return ServiceResult.success(user.duplicate(true))


func _process(_delta: float) -> void:
	if authenticated() and not _refreshing and Time.get_unix_time_from_system() >= _expires_at:
		_refreshing = true
		_refresh()


func _refresh() -> void:
	var result := await client.request("/auth/v1/token?grant_type=refresh_token", HTTPClient.METHOD_POST, {"refresh_token": _refresh_token}, false)
	if result.ok:
		_accept(result.data)
	elif result.code != "session_changed":
		_clear()
	_refreshing = false


func _clear() -> void:
	client.set_session("")
	user.clear()
	_refresh_token = ""
	_expires_at = 0.0
	changed.emit()
