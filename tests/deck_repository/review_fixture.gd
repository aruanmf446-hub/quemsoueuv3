extends RefCounted
## Transporte local de interface; nunca faz HTTP.
var admin := true
var approve_calls := 0
var reject_calls := 0
var record: Dictionary
func _init(payload: Dictionary) -> void:
	record={"id":"a".repeat(32),"status":"pending_review","author":{"nickname":"Criador de teste"},"payload":payload,"review_note":""}
func request(path: String, _method := HTTPClient.METHOD_GET, body: Variant=null) -> Dictionary:
	if path=="/me": return ServiceResult.success({"is_moderator":admin})
	if path in ["/review","/submissions"]:
		return ServiceResult.success({"items":[{"id":record.id,"name":record.payload.name,"count":record.payload.cards.size(),"status":record.status}] if path=="/submissions" or record.status=="pending_review" else []})
	if path.ends_with("/reject"):
		if not admin: return ServiceResult.failure("forbidden")
		reject_calls+=1
		record.status="rejected"
		record.review_note=body.reason
		return ServiceResult.success({"submission":record})
	return ServiceResult.success({"submission":record})
func approve(_id: String) -> Dictionary:
	if not admin: return ServiceResult.failure("forbidden")
	approve_calls+=1
	await Engine.get_main_loop().create_timer(0.1).timeout
	record.status="approved"
	return ServiceResult.success({"submission":record})
