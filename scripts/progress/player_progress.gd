class_name PlayerProgress
extends RefCounted

## Fachada de compatibilidade. Arquivos DEV antigos são preservados, sem autoridade.
static func is_unlocked(entry: Dictionary) -> bool:
	if PlayerServices.current != null and PlayerServices.current.inventory != null:
		return PlayerServices.current.inventory.is_unlocked(str(entry.get("id", "")))
	return str(entry.get("id", "")) in PlayerContracts.initial_ids()


static func is_flag_set(flag: String) -> bool:
	if flag != PlayerContracts.ACHIEVEMENT or PlayerServices.current == null:
		return false
	var progress := PlayerServices.current.progression
	return progress != null and progress.state == "success" and flag in progress.data.get("achievement_ids", [])


static func set_flag(_flag: String, _value: bool = true) -> void:
	push_warning("Flags locais não concedem conquistas. Use a progressão v2 validada no servidor.")


static func lock_label(entry: Dictionary) -> String:
	var unlock: Variant = entry.get("unlock")
	return str(unlock.get("label", "Bloqueado")) if unlock is Dictionary else ""
