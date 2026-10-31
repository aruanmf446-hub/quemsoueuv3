extends SceneTree
## Testes de contratos sem conta real e sem mutacoes no GAME.
const Campaign = preload("res://scripts/desert/t15d/campaign_progress.gd")
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, name: String) -> void:
	count += 1
	if not ok:
		failed += 1
		push_error("PERSISTENCE_FAIL " + name)
func _run() -> void:
	var account := load("res://scripts/ui/screens/account_screen.gd") as GDScript
	var src := account.source_code
	check(src.contains('{"id":"google"'), "Google visible")
	check(src.contains('{"id":"discord"'), "Discord visible")
	check(not src.contains('{"id":"steam"'), "Steam removed")
	check(not src.contains('{"id":"apple"'), "Apple removed")
	var session := SessionService.new()
	var fake := preload("res://tests/t18_auth/fake_client.gd").new()
	session.client = fake
	check(bool(PlayerContracts.read_json("res://data/backend/client.json").get("persist_session", false)), "Web persistence enabled")
	check(not session.authenticated(), "no artificial account")
	var local := Campaign.highest_unlocked()
	check(local >= 1 and local <= 10, "local progress contract")
	var script := load("res://scripts/services/progression_service.gd") as GDScript
	check(script.source_code.contains('"type": "record_checkpoint"') == false, "checkpoints originate from scene, not spoofed")
	check(script.source_code.contains("qse_progression_command"), "server RPC exists")
	var phase := load("res://scripts/desert/t15d/phase.gd") as GDScript
	check(phase.source_code.contains("func _restore_game_checkpoint"), "checkpoint restores on phase load")
	check(phase.source_code.contains("func _sync_game_checkpoint"), "checkpoint sends to GAME")
	session.free()
	fake.free()
	print("PERSISTENCE_RESULT checks=",count," failures=",failed)
	quit(1 if failed > 0 else 0)
