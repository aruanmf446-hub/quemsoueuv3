class_name ProfileService
extends RemoteDataService

var session: SessionService
var _nickname_saving := false

static func valid_nickname(value: Variant) -> bool:
	if not value is String: return false
	var clean: String=value.strip_edges()
	if clean.length()<3 or clean.length()>24: return false
	if clean.to_lower() in ["jogador local","sem nickname","você","<null>","null"]: return false
	for index in clean.length():
		var point := clean.unicode_at(index)
		if point<32 or point==127 or point in range(0x200b,0x2010) or point in range(0x202a,0x202f) or point in range(0x2066,0x206a) or point==0xfeff: return false
	return true

func has_nickname() -> bool:
	return session!=null and data.get("user_id","")==session.user.get("id","") and valid_nickname(data.get("nickname"))



func refresh() -> Dictionary:
	return await load_rpc("qse_profile_self")


func update_nickname(nickname: String) -> Dictionary:
	if session==null or not session.authenticated(): return ServiceResult.failure("not_authenticated")
	if has_nickname(): return ServiceResult.failure("nickname_locked")
	if _nickname_saving: return ServiceResult.failure("request_in_progress")
	nickname=nickname.strip_edges()
	if not valid_nickname(nickname): return ServiceResult.failure("invalid_nickname")
	var owner := str(session.user.get("id",""))
	_nickname_saving=true
	var result := await client.call_rpc("qse_profile_update", {"p_nickname":nickname})
	if owner!=str(session.user.get("id","")):
		_nickname_saving=false
		return ServiceResult.failure("session_changed")
	if result.ok: result=await refresh()
	_nickname_saving=false
	if owner!=str(session.user.get("id","")): return ServiceResult.failure("session_changed")
	if result.code=="23505": return ServiceResult.failure("nickname_taken")
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
