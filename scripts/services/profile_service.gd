class_name ProfileService
extends RemoteDataService

var session: SessionService


func refresh() -> Dictionary:
	return await load_rpc("qse_profile_self")


func update_nickname(nickname: String) -> Dictionary:
	nickname = nickname.strip_edges()
	if nickname.length() < 3 or nickname.length() > 24:
		return ServiceResult.failure("invalid_nickname")
	var result := await client.call_rpc("qse_profile_update", {"p_nickname": nickname})
	if result.ok:
		await refresh()
	return result


func public_profile(public_id: String) -> Dictionary:
	var result := await client.call_rpc("qse_profile_public", {"p_public_id": public_id})
	if result.ok and not (result.data is Dictionary and result.data.is_empty()) and not PlayerContracts.valid_public_profile(result.data):
		return ServiceResult.failure("invalid_contract")
	return result


func valid_data(value: Variant) -> bool:
	return PlayerContracts.valid_profile(value) and value.user_id == session.user.get("id")


func set_discoverable(value: bool) -> Dictionary:
	var result := await client.call_rpc("qse_account_preferences", {"p_discoverable": value})
	if result.ok and (not result.data is Dictionary or result.data.get("discoverable") != value):
		return ServiceResult.failure("invalid_contract")
	if result.ok:
		await refresh()
	return result
