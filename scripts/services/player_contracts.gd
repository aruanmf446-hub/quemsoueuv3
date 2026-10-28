class_name PlayerContracts
extends RefCounted

const RULES_PATH := "res://data/progression/rules.v2.json"
const ACHIEVEMENT := "desert_campaign_completed"


static func read_json(path: String) -> Dictionary:
	var source := FileAccess.open(path, FileAccess.READ)
	if source == null:
		return {}
	var data: Variant = JSON.parse_string(source.get_as_text())
	return data if data is Dictionary else {}


static func initial_ids() -> Array:
	return read_json(RULES_PATH).get("classifications", {}).get("playable_heroes", [])


static func valid_snapshot(data: Variant, owner: String) -> bool:
	if not data is Dictionary or owner.is_empty():
		return false
	var rules := read_json(RULES_PATH)
	var keys := ["schema_version", "rules_version", "player_id", "revision",
		"completed_phase_ids", "active_phase_id", "checkpoint", "achievement_ids",
		"unlocked_character_ids", "equipped_character_id"]
	if data.size() != keys.size():
		return false
	for key: String in keys:
		if not data.has(key):
			return false
	if data.schema_version != 2 or data.rules_version != rules.get("rules_version"):
		return false
	if data.player_id != owner or not _integer(data.revision) or data.revision < 0:
		return false
	if data.revision > 9007199254740991:
		return false
	var completed: Variant = data.completed_phase_ids
	if not completed is Array or completed.size() > 10:
		return false
	for index in completed.size():
		if completed[index] != rules.phases[index].id:
			return false
	var expected := initial_ids().duplicate()
	var achievements: Array = []
	if completed.size() == 10:
		expected.append("el_fuego")
		achievements.append(ACHIEVEMENT)
	if not _same_set(data.unlocked_character_ids, expected):
		return false
	if not _same_set(data.achievement_ids, achievements):
		return false
	if not data.equipped_character_id in expected:
		return false
	var active: Variant = data.active_phase_id
	if active != null:
		var active_index := _phase_index(active, rules)
		if active_index < 0 or active_index > completed.size():
			return false
	if data.checkpoint != null:
		var checkpoint: Variant = data.checkpoint
		if not checkpoint is Dictionary or checkpoint.size() != 2 or active == null:
			return false
		if checkpoint.get("phase_id") != active:
			return false
		var phase: Dictionary = rules.phases[_phase_index(active, rules)]
		if not checkpoint.get("checkpoint_id") in phase.checkpoint_ids:
			return false
	return true


static func _same_set(value: Variant, expected: Array) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	var seen := {}
	for item: Variant in value:
		if not item is String or not item in expected or seen.has(item):
			return false
		seen[item] = true
	return true


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


static func _phase_index(value: Variant, rules: Dictionary) -> int:
	for index in rules.phases.size():
		if rules.phases[index].id == value:
			return index
	return -1


static func uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20)]


static func valid_public_profile(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 5:
		return false
	for key: String in ["user_id", "public_id", "nickname", "equipped_character_id"]:
		if not value.get(key) is String:
			return false
	if not value.has("level") or (value.level != null and (not _integer(value.level) or value.level < 0)):
		return false
	var ids := initial_ids().duplicate()
	ids.append("el_fuego")
	return value.equipped_character_id in ids and value.public_id.begins_with("QSE-") and value.nickname.length() >= 3


static func valid_profile(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 8 or not value.get("discoverable") is bool or not value.get("statistics") is Dictionary:
		return false
	var public_part: Dictionary = value.duplicate(true)
	for key: String in ["experience", "statistics", "discoverable"]:
		public_part.erase(key)
	if not valid_public_profile(public_part):
		return false
	if not value.has("experience") or (value.experience != null and not _unsigned_string(value.experience)):
		return false
	for stat: Variant in value.statistics.values():
		if not (stat is int or stat is float) or not is_finite(float(stat)) or stat < 0:
			return false
	return true


static func valid_players(value: Variant) -> bool:
	if not value is Array:
		return false
	var owners := {}
	for player: Variant in value:
		if not valid_public_profile(player) or owners.has(player.user_id):
			return false
		owners[player.user_id] = true
	return true


static func valid_wallet(value: Variant, history_only: bool = false) -> bool:
	if not value is Dictionary or value.size() != (2 if history_only else 5):
		return false
	if not history_only:
		for key: String in ["coins", "gems", "revision"]:
			if not _unsigned_string(value.get(key)):
				return false
	if not value.get("transactions") is Array or not value.has("next_cursor"):
		return false
	if value.next_cursor != null and not _unsigned_string(value.next_cursor):
		return false
	for transaction: Variant in value.transactions:
		if not transaction is Dictionary or transaction.size() != 7:
			return false
		for key: String in ["transaction_id", "created_at", "reason", "currency", "amount", "sequence", "balance_after"]:
			if not transaction.get(key) is String:
				return false
		if not transaction.currency in ["coins", "gems"] or not transaction.amount.is_valid_int():
			return false
		if not _unsigned_string(transaction.balance_after) or not _unsigned_string(transaction.sequence):
			return false
	return true


static func _unsigned_string(value: Variant) -> bool:
	if not value is String or value.is_empty():
		return false
	for digit: String in value:
		if digit < "0" or digit > "9":
			return false
	return true
