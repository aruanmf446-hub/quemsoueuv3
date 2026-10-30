class_name RemoteDataService
extends Node

signal changed
var client: SupabaseClient
var state := "empty"
var error: Dictionary = {}
var data: Dictionary = {}
var _request_sequence := 0
## Momento (s, relógio do motor) da última resposta válida; -1 = nunca.
var fetched_at := -1.0
var _inflight := false
signal _loaded(result: Dictionary)


func clear() -> void:
	_request_sequence += 1
	data.clear()
	error.clear()
	fetched_at = -1.0
	state = "unauthorized" if client.configured() else "offline"
	changed.emit()


## Atualiza só se os dados tiverem mais de max_age segundos (ou nunca vieram).
func refresh_if_stale(max_age: float) -> Dictionary:
	if fetched_at >= 0.0 and age() < max_age: return ServiceResult.success(data)
	return await call("refresh")


func age() -> float:
	return INF if fetched_at < 0.0 else Time.get_ticks_msec() / 1000.0 - fetched_at


## Leituras simultâneas da mesma tela/poller compartilham uma só requisição.
func load_rpc(name: String, params: Dictionary = {}) -> Dictionary:
	if _inflight and params.is_empty():
		return await _loaded
	_inflight = params.is_empty()
	var result := await _load_rpc(name, params)
	if params.is_empty():
		_inflight = false
		_loaded.emit(result)
	return result


func _load_rpc(name: String, params: Dictionary) -> Dictionary:
	_request_sequence += 1
	var sequence := _request_sequence
	state = "loading"
	changed.emit()
	var result := await client.call_rpc(name, params)
	if result.code == "session_changed" or sequence != _request_sequence:
		return result
	error = {} if result.ok else result
	state = "success" if result.ok else result.state
	if result.ok:
		if not valid_data(result.data):
			result = ServiceResult.failure("invalid_contract")
			error = result
			state = "error"
		else:
			data = result.data
			fetched_at = Time.get_ticks_msec() / 1000.0
	changed.emit()
	return result


func valid_data(value: Variant) -> bool:
	return value is Dictionary
