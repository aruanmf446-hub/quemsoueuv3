class_name RemoteDataService
extends Node

signal changed
var client: SupabaseClient
var state := "empty"
var error: Dictionary = {}
var data: Dictionary = {}
var _request_sequence := 0


func clear() -> void:
	_request_sequence += 1
	data.clear()
	error.clear()
	state = "unauthorized" if client.configured() else "offline"
	changed.emit()


func load_rpc(name: String, params: Dictionary = {}) -> Dictionary:
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
	changed.emit()
	return result


func valid_data(value: Variant) -> bool:
	return value is Dictionary
