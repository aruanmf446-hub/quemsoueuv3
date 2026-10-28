class_name PlayerProgress
extends RefCounted

## Progresso local do jogador, usado apenas para desbloqueios em ambiente de
## desenvolvimento. NÃO é autenticação e NÃO é confiável: o cliente pode editar este
## arquivo. Em produção, o desbloqueio deve ser validado no servidor (ver
## data/progress_contract.json) antes de qualquer equipamento ser liberado.

const SAVE_PATH := "user://progress_dev.cfg"
const SECTION := "flags"


static func is_flag_set(flag: String) -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	return config.get_value(SECTION, flag, false)


static func set_flag(flag: String, value: bool = true) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value(SECTION, flag, value)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Não foi possível salvar o progresso local (erro %d)." % err)


## Personagem sem bloqueio (unlock == null) está sempre liberado.
static func is_unlocked(entry: Dictionary) -> bool:
	var unlock: Variant = entry.get("unlock")
	if unlock == null:
		return true
	if unlock.get("type", "") == "flag":
		return is_flag_set(unlock.get("flag", ""))
	return false


static func lock_label(entry: Dictionary) -> String:
	var unlock: Variant = entry.get("unlock")
	if unlock == null:
		return ""
	return unlock.get("label", "Bloqueado")
