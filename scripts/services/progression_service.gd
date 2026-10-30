class_name ProgressionService
extends RemoteDataService

var session: SessionService


func refresh() -> Dictionary:
	if _inflight: return await _loaded
	_inflight = true
	var result := await _refresh()
	_inflight = false
	_loaded.emit(result)
	return result


func _refresh() -> Dictionary:
	_request_sequence += 1
	var sequence := _request_sequence
	state = "loading"
	changed.emit()
	var result := await client.call_rpc("qse_progression_snapshot")
	if result.code == "session_changed" or sequence != _request_sequence:
		return result
	if result.ok and not PlayerContracts.valid_snapshot(result.data, str(session.user.get("id", ""))):
		result = ServiceResult.failure("invalid_contract")
	if result.ok:
		if data.is_empty() or result.data.revision > data.revision:
			data = result.data
		elif result.data.revision == data.revision and result.data != data:
			result = ServiceResult.failure("invalid_contract")
	error = {} if result.ok else result
	state = "success" if result.ok else result.state
	if result.ok: fetched_at = Time.get_ticks_msec() / 1000.0
	changed.emit()
	return result


func equip(character_id: String) -> Dictionary:
	if state != "success" or not session.authenticated():
		return ServiceResult.failure("not_authenticated", "unauthorized")
	if not character_id in data.unlocked_character_ids:
		return ServiceResult.failure("locked_character", "unauthorized")
	var request := {"protocol_version": 2, "rules_version": data.rules_version,
		"request_id": PlayerContracts.uuid(), "expected_revision": data.revision,
		"operation": {"type": "equip_character", "character_id": character_id}}
	var result := await client.call_rpc("qse_progression_command", {"p_request": request})
	if not result.ok:
		return result
	var response: Variant = result.data
	if not response is Dictionary or response.size() != 6 or response.get("request_id") != request.request_id:
		return ServiceResult.failure("invalid_contract")
	if response.get("protocol_version") != 2 or response.get("rules_version") != request.rules_version:
		return ServiceResult.failure("invalid_contract")
	if response.get("status") not in ["applied", "noop", "conflict", "rejected"] or not response.has("code"):
		return ServiceResult.failure("invalid_contract")
	if (response.status in ["applied", "noop"] and response.code != null) or (response.status in ["conflict", "rejected"] and not response.code is String):
		return ServiceResult.failure("invalid_contract")
	if not PlayerContracts.valid_snapshot(response.get("snapshot"), str(session.user.get("id", ""))):
		return ServiceResult.failure("invalid_contract")
	# Nunca aceite rollback ou una desbloqueios locais ao snapshot autenticado.
	if response.snapshot.revision == data.revision and response.snapshot != data:
		return ServiceResult.failure("invalid_contract")
	if response.snapshot.revision >= data.revision:
		if response.snapshot.completed_phase_ids.size() < data.completed_phase_ids.size():
			return ServiceResult.failure("invalid_contract")
		data = response.snapshot
		changed.emit()
	if response.get("status") not in ["applied", "noop"]:
		return ServiceResult.failure(str(response.get("code", "request_failed")))
	return ServiceResult.success(data)
