extends SupabaseClient
const OWNER := "00000000-0000-4000-8000-00000000c001"
const DECK := "00000000-0000-4000-8000-00000000c002"
const VERSION := "00000000-0000-4000-8000-00000000c003"
const REF := "community_0000000000004000800000000000c003"
var claimed := false
var hold_claim := false
var hold_inventory := false
var claim_calls := 0
var manifests := 0
var signed_host := CommunityDecksService.SIGNED_ROOT
func configured() -> bool: return true
func manifest() -> Dictionary:
	var result := {"id":REF,"deck_id":DECK,"version_id":VERSION,"name":"[TESTE] Deck resgatado","creator":"Criador de teste","description":"Fixture local, sem rede.","category":"Personagens","available":true,"cards":[],"size":5}
	for i in 5:
		var id := "00000000-0000-4000-8000-00000000c01"+str(i)
		result.cards.append({"id":REF+"/"+id,"name":"Carta "+str(i),"description":"","library_path":VERSION+"/"+id+"_library.png","duel_path":VERSION+"/"+id+"_duel.png"})
	return result
func call_rpc(name: String,params: Dictionary={}) -> Dictionary:
	if name=="qse_community_inventory":
		var snapshot := [manifest()] if claimed else []
		while hold_inventory: await get_tree().process_frame
		return ServiceResult.success({"items":snapshot})
	return ServiceResult.failure("unknown_rpc")
func send(path: String,method: HTTPClient.Method,body: Variant=null,headers: PackedStringArray=PackedStringArray(),raw:=PackedByteArray(),content_type:="application/json",timeout:=30.0) -> Dictionary:
	if path!=CommunityDecksService.PATH: return ServiceResult.failure("unknown_rpc")
	if body.action=="claim":
		claim_calls+=1
		while hold_claim: await get_tree().process_frame
		claimed=true
		return ServiceResult.success({"data":{"claimed":true,"deck_id":DECK,"version_id":VERSION,"deck_ref":REF,"already_owned":claim_calls>1}})
	if body.action=="manifests":
		manifests+=1
		var item := manifest()
		for card: Dictionary in item.cards:
			for format in ["library","duel"]: card[format+"_url"]=signed_host+card[format+"_path"]+"?token=fixture"
		return ServiceResult.success({"data":{"items":[item]}})
	return ServiceResult.failure("invalid_contract")
