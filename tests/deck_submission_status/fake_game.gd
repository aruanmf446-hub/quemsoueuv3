extends "res://tests/community_t27/fake_game.gd"
## Backend em memória; reproduz a trava existente de escrita fora de draft.
var fail_status := false
var fail_publish := false
var hold_status := false
var status_started := false
var status_reads := 0
func send(path: String, method: HTTPClient.Method, body: Variant=null, headers:=PackedStringArray(), raw:=PackedByteArray(), type:="", timeout:=30.0) -> Dictionary:
	if path.begins_with("/rest/v1/qse_creator_decks?select=id,status,review_note"):
		status_reads+=1
		status_started=true
		if fail_status: return ServiceResult.failure("network")
		var snapshot: Dictionary=await super.send(path,method,body,headers,raw,type,timeout)
		while hold_status: await get_tree().process_frame
		return snapshot
	# O trigger do GAME recusa upsert/edição de decks que não estejam em draft.
	if path.begins_with("/rest/v1/qse_creator_decks?on_conflict=") and method==HTTPClient.METHOD_POST:
		for row: Dictionary in db.qse_creator_decks:
			if body[0].id==row.id and row.get("status","draft")!="draft": return ServiceResult.failure("deck_locked")
	return await super.send(path,method,body,headers,raw,type,timeout)
func call_rpc(name: String, params: Dictionary={}) -> Dictionary:
	if name=="qse_deck_publish_request" and fail_publish:
		await get_tree().process_frame
		return ServiceResult.failure("network")
	var result: Dictionary=await super.call_rpc(name,params)
	if name=="qse_deck_publish_request" and result.ok and not result.data.has("error"):
		for row: Dictionary in db.qse_creator_decks:
			if row.id==params.p_deck: row.review_note=null
	return result
