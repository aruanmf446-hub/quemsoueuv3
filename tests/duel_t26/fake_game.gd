extends "res://tests/duel_t25/fake_rooms.gd"
## FIXTURE DE TESTE (T26): qse_duel_decks/qse_duel_create sem rede. Decks [DEMO] só aqui.
const ART := "res://assets/duel/decks/oficial/lendas_urbanas/%s.png"
var created: Dictionary = {}


func call_rpc(name: String, params: Dictionary = {}) -> Dictionary:
	if name == "qse_duel_decks":
		await get_tree().process_frame
		calls.append([name, params.duplicate()])
		return ServiceResult.success({"decks": [
			{"id": "lendas_urbanas", "name": "Lendas Urbanas", "size": 9},
			{"id": "demo_terror", "name": "[DEMO] Terror", "size": 8, "cover": ART % "dama_de_branco"},
			{"id": "demo_folclore", "name": "[DEMO] Folclore", "size": 9, "cover": ART % "cobra_grande"},
			{"id": "demo_classico", "name": "[DEMO] Clássico", "size": 10, "cover": ART % "slender_man"},
			{"id": "demo_misterio", "name": "[DEMO] Mistério", "size": 8, "cover": ART % "momo"}],
			"defaults": {"max_players": 8, "cards_per_player": 3, "turn_seconds": 60, "selection_seconds": 30, "tiebreak_base": 7, "tiebreak_per_player": 2, "bots_allowed": true, "deck_ids": ["lendas_urbanas"]}})
	if name == "qse_duel_create":
		await get_tree().process_frame
		calls.append([name, params.duplicate(true)])
		created = params.duplicate(true)
		return ServiceResult.failure("network")
	return await super.call_rpc(name, params)
