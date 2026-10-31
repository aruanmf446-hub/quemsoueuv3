extends SceneTree
## T17: estado de navegação de convites e parsing. Sem HTTP e sem contas reais.
## godot --headless --path . --script res://tests/t17_web_invites/flow_test.gd
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		push_error("T17_WEB_INVITE_FAIL " + title)
		quit(1)
		assert(ok, title)

func _run() -> void:
	var intent := WebInviteIntent.new()
	check(intent.next_route(false) == "", "sem convite nao navega")
	intent.capture(true)
	check(intent.next_route(false) == "account", "sem sessao vai ao login")
	intent.mark_opened("account")
	check(intent.next_route(false) == "account", "aguarda login sem consumir")
	check(intent.next_route(true) == "duel", "sessao autenticada vai ao Duelo")
	intent.mark_opened("duel")
	check(intent.next_route(true) == "", "convite consumido apenas uma vez")
	intent.capture(true)
	check(intent.next_route(true) == "", "nenhum segundo ingresso automatico")

	var token := "ab".repeat(24)
	check(DuelService.invite_token(token) == token, "token valido")
	check(DuelService.invite_token("https://exemplo.test/play?invite=" + token) == token, "token em URL")
	check(DuelService.invite_token("invalido") == "", "token malformado")
	check(DuelService.invite_token("ABCDEF") == "", "codigo curto nao e token")
	check(DuelService.message("invalid_invite").contains("expirado"), "convite expirado sinalizado")
	check(DuelService.message("room_closed").contains("encerrada"), "sala encerrada sinalizada")
	print("T17_WEB_INVITE_OK checks=", checks, " (sem teste HTTP/browser)")
	quit(0)
