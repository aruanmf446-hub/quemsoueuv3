extends SceneTree
## O runner deve fornecer XDG_DATA_HOME isolado; este teste recusa save preexistente.
const Progress = preload("res://scripts/desert/t15d/campaign_progress.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ")+text)
	if not value: failures += 1
func write_config(highest: Variant, version: Variant = 1) -> void:
	var config := ConfigFile.new()
	config.set_value("campaign","version",version)
	config.set_value("campaign","highest_completed",highest)
	assert(config.save(Progress.SAVE_PATH) == OK)
func remove_saves() -> void:
	for path in [Progress.SAVE_PATH,Progress.TEMP_PATH]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
func run() -> void:
	if FileAccess.file_exists(Progress.SAVE_PATH) or FileAccess.file_exists(Progress.TEMP_PATH):
		push_error("Este teste requer user:// isolado e vazio; nenhum save foi alterado.")
		quit(2)
		return
	check(Progress.is_unlocked(1),"instalação nova libera fase 01")
	check(not Progress.is_unlocked(2) and not Progress.is_unlocked(10),"fases seguintes começam bloqueadas")
	check(not Progress.is_unlocked(0) and not Progress.is_unlocked(11),"ordens inválidas não ficam disponíveis")
	check(Progress.completed_orders().is_empty(),"instalação nova não inventa conclusões")
	check(Progress.complete(9) == ERR_UNAUTHORIZED,"não aceita pular diretamente para fase 09")
	check(not FileAccess.file_exists(Progress.SAVE_PATH),"tentativa bloqueada não cria progresso")
	check(Progress.complete(0) == ERR_INVALID_PARAMETER and Progress.complete(10) == ERR_INVALID_PARAMETER,"escopo de conclusão aceita somente fases 01–09")
	check(Progress.complete(1) == OK,"concluir fase 01 salva em disco")
	check(Progress.is_unlocked(2) and not Progress.is_unlocked(3),"vitória libera exatamente a próxima fase")
	var saved := ConfigFile.new()
	check(saved.load(Progress.SAVE_PATH) == OK and saved.get_value("campaign","highest_completed") == 1,"novo leitor recupera o progresso persistido")
	var previous := FileAccess.get_file_as_bytes(Progress.SAVE_PATH)
	check(Progress.complete(1) == OK and FileAccess.get_file_as_bytes(Progress.SAVE_PATH) == previous,"replay de fase concluída é idempotente")
	for order in range(2,10):
		check(Progress.complete(order) == OK and Progress.is_unlocked(order+1),"conclusão sequencial %02d libera %02d" % [order,order+1])
	check(Progress.completed_orders() == [1,2,3,4,5,6,7,8,9],"histórico contém somente nove conclusões válidas")
	check(Progress.highest_unlocked() == 10 and not Progress.is_completed(10),"fase 10 é liberada sem forjar sua conclusão")
	check(not FileAccess.file_exists(Progress.TEMP_PATH),"save atômico não deixa arquivo temporário")
	for value in [-1,10,"9",1.0,null]:
		write_config(value)
		check(Progress.highest_unlocked() == 1 and Progress.completed_orders().is_empty(),"save inválido %s volta ao início sem liberar fases" % str(value))
	write_config(9,99)
	check(Progress.highest_unlocked() == 1,"schema desconhecido não é interpretado como vitória")
	write_config(2)
	var temporary := ConfigFile.new()
	temporary.set_value("campaign","version",1)
	temporary.set_value("campaign","highest_completed",9)
	temporary.save(Progress.TEMP_PATH)
	check(Progress.highest_unlocked() == 3,"temporário interrompido não substitui o último save confirmado")
	remove_saves()
	print("LOCAL_PROGRESS_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
