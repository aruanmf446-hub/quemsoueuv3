extends SupabaseClient
var report_code := ""
var calls := 0
var hold := false
var empty_confirmation := false
var user := ""
var target := {"user_id":"00000000-0000-4000-8000-000000000022","public_id":"QSE-FIXTURE-TARGET","nickname":"Jogador de teste","equipped_character_id":"","level":1}
func _ready() -> void: target.equipped_character_id=PlayerContracts.initial_ids()[0]
func configured() -> bool: return true
func request(_path: String,_method: HTTPClient.Method,_body: Dictionary={},_authenticated: bool=true,_token_override: String="") -> Dictionary:
	return ServiceResult.failure("not_configured")
func send(_path: String,_method: HTTPClient.Method=HTTPClient.METHOD_GET,_body: Variant=null,_extra: PackedStringArray=PackedStringArray(),_raw: PackedByteArray=PackedByteArray(),_type: String="application/json",_timeout: float=30.0) -> Dictionary:
	return ServiceResult.failure("not_configured")
func call_rpc(rpc: String,_params: Dictionary={}) -> Dictionary:
	if rpc=="qse_profile_public": return ServiceResult.success(target.duplicate())
	if rpc!="qse_player_report": return ServiceResult.failure("not_configured")
	calls+=1
	await get_tree().process_frame
	while hold: await get_tree().process_frame
	if report_code in ["network","PGRST202"]: return ServiceResult.failure(report_code)
	if not report_code.is_empty(): return ServiceResult.success({"error":report_code})
	return ServiceResult.success({} if empty_confirmation else {"reported":true})
