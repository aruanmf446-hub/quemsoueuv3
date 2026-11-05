extends SupabaseClient
## Fixture local: nenhuma requisição real, nem acesso ao Supabase.
var nickname: Variant=null
var canonical_nickname := ""
var user_id := "00000000-0000-4000-8000-000000000011"
var update_calls := 0
var next_code := ""
var delay := 0.0
var during_update: Callable
func _ready() -> void: pass
func configured() -> bool: return true
func profile() -> Dictionary:
	return {"user_id":user_id,"public_id":"QSE-FIXTURE","nickname":nickname,"equipped_character_id":PlayerContracts.initial_ids()[0],"level":1,"experience":"0","statistics":{},"discoverable":true}
func request(_path: String, _method: HTTPClient.Method, _body: Dictionary={}, _authenticated: bool=true, _token_override: String="") -> Dictionary:
	return ServiceResult.failure("not_configured")
func call_rpc(rpc: String, params: Dictionary={}) -> Dictionary:
	if rpc=="qse_profile_self": return ServiceResult.success(profile())
	if rpc!="qse_profile_update": return ServiceResult.failure("not_configured")
	update_calls+=1
	if delay>0: await get_tree().create_timer(delay).timeout
	if during_update.is_valid(): during_update.call()
	if not next_code.is_empty(): return ServiceResult.failure(next_code)
	if str(params.get("p_nickname","")).strip_edges().to_lower()=="ocupado": return ServiceResult.failure("nickname_taken")
	nickname=canonical_nickname if not canonical_nickname.is_empty() else params.p_nickname
	return ServiceResult.success(profile())
