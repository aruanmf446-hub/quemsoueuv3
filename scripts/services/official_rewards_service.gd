class_name OfficialRewardsService
extends Node
## Campanha oficial GAME: resgates por conta, sem saldo e sem depender de cache local.
## Nenhum "claim" altera dados do cliente antes da confirmação do servidor.
signal changed

var client: SupabaseClient
var session: SessionService
var state := "empty"
var campaign: Dictionary = {}
var offers: Array[Dictionary] = []
var seen := true
var error: Dictionary = {}
var _sequence := 0
var _loading := false
var _claiming := false


func clear() -> void:
	_sequence += 1
	_loading = false
	_claiming = false
	state = "empty"
	campaign.clear()
	offers.clear()
	seen = true
	error.clear()
	changed.emit()


func refresh() -> Dictionary:
	if client == null or session == null or not session.authenticated():
		return ServiceResult.failure("not_authenticated", "unauthorized")
	if _loading: return ServiceResult.failure("loading")
	_loading = true
	_sequence += 1
	var sequence := _sequence
	var generation := client.generation
	state = "loading"
	changed.emit()
	var result: Dictionary = await client.call_rpc("qse_rewards_feed")
	if sequence != _sequence or generation != client.generation:
		return ServiceResult.failure("session_changed", "unauthorized")
	_loading = false
	if result.ok and result.data is Dictionary and result.data.get("ok", false) == true:
		state = "success"
		campaign = result.data.get("campaign", {}) if result.data.get("campaign") is Dictionary else {}
		seen = bool(result.data.get("seen", true))
		offers.clear()
		if result.data.get("offers") is Array:
			for item: Variant in result.data.offers:
				if item is Dictionary and item.get("id") is String and item.get("kind") in ["deck", "skin"]:
					offers.append(item)
		error.clear()
	else:
		state = "error"
		error = result
	changed.emit()
	return result


func is_deck_claimed(deck_id: String) -> bool:
	if state != "success": return false
	for item: Dictionary in offers:
		if str(item.get("kind", "")) == "deck" and str(item.get("item_id", "")) == deck_id:
			return bool(item.get("claimed", false))
	return false


func claim(offer_id: String) -> Dictionary:
	if _claiming: return ServiceResult.failure("busy")
	if client == null or session == null or not session.authenticated():
		return ServiceResult.failure("not_authenticated", "unauthorized")
	var known := false
	for item: Dictionary in offers:
		if str(item.get("id", "")) == offer_id and not bool(item.get("claimed", false)):
			known = true
			break
	if not known: return ServiceResult.failure("offer_unavailable")
	_claiming = true
	var generation := client.generation
	var result: Dictionary = await client.call_rpc("qse_rewards_claim", {"p_offer_id": offer_id})
	if generation != client.generation:
		_claiming = false
		return ServiceResult.failure("session_changed", "unauthorized")
	_claiming = false
	if result.ok and result.data is Dictionary and result.data.get("ok", false) == true:
		for index in offers.size():
			if str(offers[index].get("id", "")) == offer_id:
				offers[index]["claimed"] = true
				offers[index]["claimed_at"] = result.data.get("claimed_at")
				break
		changed.emit()
	return result


func mark_seen() -> Dictionary:
	if seen or campaign.is_empty(): return ServiceResult.success({"seen": seen})
	if client == null or session == null or not session.authenticated():
		return ServiceResult.failure("not_authenticated", "unauthorized")
	var campaign_id := str(campaign.get("id", ""))
	if campaign_id.is_empty(): return ServiceResult.failure("campaign_unavailable")
	var generation := client.generation
	var result: Dictionary = await client.call_rpc("qse_rewards_mark_seen", {"p_campaign_id": campaign_id})
	if generation != client.generation: return ServiceResult.failure("session_changed", "unauthorized")
	if result.ok and result.data is Dictionary and result.data.get("ok", false) == true:
		seen = true
		changed.emit()
	return result


func pending_count() -> int:
	if state != "success": return 0
	var count := 0
	for item: Dictionary in offers:
		if not bool(item.get("claimed", false)): count += 1
	return count
