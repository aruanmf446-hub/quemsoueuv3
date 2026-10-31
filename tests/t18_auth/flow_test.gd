extends SceneTree
## Executa validacao das regras de Auth sem criar usuarios nem consumir limites SMTP.
var count := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, title: String) -> void:
	count += 1
	if not condition:
		failures += 1
		push_error("T18_AUTH_FAIL " + title)

func _run() -> void:
	check(SessionService.valid_email("alguem@exemplo.com"), "email valido")
	check(not SessionService.valid_email("semarroba"), "email invalido")
	check(SessionService.validate_email_password("x@foo.com", "12345", true) == "weak_password", "senha curta")
	check(SessionService.validate_email_password("x@foo.com", "", false) == "password_required", "senha vazia")
	check(SessionService.validate_email_password("x@foo.com", "segura123", true).is_empty(), "cadastro valido")
	check(ServiceResult.message(ServiceResult.failure("email_not_confirmed")).contains("Confirme"), "confirmacao pendente")
	check(ServiceResult.message(ServiceResult.failure("invalid_credentials")).contains("senha"), "login incorreto")
	check(ServiceResult.message(ServiceResult.failure("rate_limit")).contains("Limite"), "rate limit")
	check(ServiceResult.message(ServiceResult.failure("weak_password")).contains("6"), "mensagem senha")
	var mock := preload("res://tests/t18_auth/fake_client.gd").new()
	var session := SessionService.new()
	session.client = mock
	var invalid := await session.sign_up("errado", "12")
	check(not invalid.ok and mock.paths.is_empty(), "cadastro invalido nao faz HTTP")
	mock.response = ServiceResult.success({"user": {"id": "usuario-pendente"}})
	var pending := await session.sign_up("teste@exemplo.com", "segura123")
	check(pending.ok and pending.data.confirmation_pending and not session.authenticated(), "signup 200 sem JWT aguarda confirmacao")
	check(mock.paths.back().begins_with("/auth/v1/signup"), "rota de cadastro")
	mock.response = ServiceResult.failure("email_not_confirmed")
	var denied := await session.sign_in("teste@exemplo.com", "segura123")
	check(denied.code == "email_not_confirmed" and not session.authenticated(), "login pendente")
	mock.response = ServiceResult.success({"user":{"id":"jogador-1","email":"teste@exemplo.com"},"access_token":"token-de-fixture","refresh_token":"refresh-de-fixture","expires_in":3600})
	var change_count := [0]
	session.changed.connect(func() -> void: change_count[0] += 1)
	var entered := await session.sign_in("teste@exemplo.com", "segura123")
	check(entered.ok and session.authenticated() and change_count[0] == 1, "login com sessao")
	var renewed := session._accept({"user":{"id":"jogador-1","email":"teste@exemplo.com"},"access_token":"token-renovado","refresh_token":"refresh-renovado","expires_in":3600})
	check(renewed.ok and change_count[0] == 1, "refresh nao reinicia estado do jogador")
	var logout := await session.sign_out()
	check(logout.ok and not session.authenticated() and change_count[0] == 2, "logout local e remoto")
	check(mock.paths.back().begins_with("/auth/v1/logout"), "revoke sessao no servidor")
	mock.response = ServiceResult.success({})
	var recovery := await session.send_recovery("teste@exemplo.com")
	check(recovery.ok and mock.paths.back().begins_with("/auth/v1/recover"), "recuperacao rota oficial")
	check(not session.social_available("steam"), "steam nao declarado pronto")
	check(not session.social_available("google"), "oauth sem provedor nao habilitado")
	session.free()
	mock.free()
	print("T18_AUTH_RESULT checks=",count," failures=",failures," HTTP=fixture somente")
	quit(1 if failures > 0 else 0)
