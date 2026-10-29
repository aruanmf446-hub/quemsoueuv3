extends RefCounted
## Progresso deste aparelho. Nunca concede recompensas, inventário ou conclusão online.
const SAVE_PATH := "user://desert_campaign_v1.cfg"
const TEMP_PATH := "user://desert_campaign_v1.cfg.tmp"
const VERSION := 1
const LAST_UPDATED_PHASE := 9

static func completed_orders() -> Array[int]:
	var result: Array[int] = []
	for order in range(1,_highest_completed()+1): result.append(order)
	return result

static func highest_unlocked() -> int:
	return mini(_highest_completed()+1,10)

static func is_unlocked(order: int) -> bool:
	return order >= 1 and order <= 10 and order <= highest_unlocked()

static func is_completed(order: int) -> bool:
	return order >= 1 and order <= LAST_UPDATED_PHASE and order <= _highest_completed()

static func complete(order: int) -> Error:
	if order < 1 or order > LAST_UPDATED_PHASE: return ERR_INVALID_PARAMETER
	var previous := _highest_completed()
	if order > previous+1: return ERR_UNAUTHORIZED
	if order <= previous: return OK
	var config := ConfigFile.new()
	config.set_value("campaign","version",VERSION)
	config.set_value("campaign","highest_completed",order)
	var result := config.save(TEMP_PATH)
	if result != OK: return result
	result = DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH),ProjectSettings.globalize_path(SAVE_PATH))
	if result != OK: DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
	return result

static func _highest_completed() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK: return 0
	if not config.has_section_key("campaign","version") or not config.has_section_key("campaign","highest_completed"): return 0
	var version: Variant = config.get_value("campaign","version")
	var highest: Variant = config.get_value("campaign","highest_completed")
	if typeof(version) != TYPE_INT or version != VERSION: return 0
	if typeof(highest) != TYPE_INT or highest < 0 or highest > LAST_UPDATED_PHASE: return 0
	return highest
