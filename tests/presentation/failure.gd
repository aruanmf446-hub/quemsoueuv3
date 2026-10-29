extends SceneTree
## Falha intencional: confirma que o jogador pode tentar novamente ou voltar.

var failures := 0
var cancelled := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func wait_for_error(loading: CampaignLoading) -> void:
	for i in range(30):
		if loading._error_panel.visible: return
		await process_frame

func run() -> void:
	var loading := CampaignLoading.new()
	loading.name = "CampaignLoading"
	root.add_child(loading)
	loading.cancelled.connect(func() -> void: cancelled = true)
	loading.begin("res://scenes/menu/nao_existe.tscn", func(_packed: PackedScene) -> void: failures += 1)
	await wait_for_error(loading)
	check(loading._error_panel.visible and loading._retry_button.visible, "erro oferece nova tentativa")
	loading._retry_button.pressed.emit()
	await wait_for_error(loading)
	check(loading._error_panel.visible, "nova tentativa mantém retorno disponível")
	loading._cancel()
	await process_frame
	check(cancelled and not is_instance_valid(loading), "voltar encerra a apresentação")
	var result := {"skipped": false}
	var opening := CampaignLoading.new()
	opening.opening = true
	root.add_child(opening)
	opening.begin("res://scenes/menu/main_menu.tscn", func(_packed: PackedScene) -> void: result.skipped = true, true)
	for i in range(30):
		if opening._can_skip: break
		await process_frame
	opening._skip()
	await process_frame
	check(result.skipped, "pular abertura entra assim que o menu está pronto")
	print("PRESENTATION_FAILURE_RESULT failures=", failures)
	quit(1 if failures else 0)
