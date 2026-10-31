extends SceneTree
## Testes offline deterministas de OAuth Google. Sem usuarios reais.
var total := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, name: String) -> void:
	total += 1
	if not value:
		failures += 1
		push_error("T18B_GOOGLE_FAIL " + name)

func _run() -> void:
	# Vetor oficial RFC 7636, nao e um token de usuario.
	var rfc_verifier := "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
	check(OAuthPkce.challenge(rfc_verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "desafio RFC7636 s256")
	var fresh := OAuthPkce.generate_verifier()
	check(fresh.length() >= 43 and fresh.length() <= 128, "verificador com entropia suficiente")
	check(not fresh.contains("=") and not fresh.contains("+") and not fresh.contains("/"), "base64url sem padding")
	check(OAuthPkce.challenge(fresh).length() == 43, "desafio sem padding")
	var destination := "https://aruanmf446-hub.github.io/quemsoueuv3/?invite=abcdef"
	var url_path := OAuthPkce.google_authorize_path(destination, OAuthPkce.challenge(rfc_verifier))
	check(url_path.begins_with("/auth/v1/authorize?provider=google&redirect_to="), "provedor correto")
	check(url_path.contains("code_challenge_method=s256"), "metodo s256 solicitado")
	check(url_path.contains("code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"), "desafio no URL")
	check(url_path.contains("invite%3Dabcdef"), "destino conserva convite")
	check(not url_path.contains(rfc_verifier), "verificador jamais exposto na URL")
	check(ServiceResult.message(ServiceResult.failure("oauth_access_denied")).contains("cancelada"), "erro consentimento")
	check(ServiceResult.message(ServiceResult.failure("oauth_missing_verifier")).contains("outra aba"), "erro retorno aba errada")
	var session := SessionService.new()
	check(not session.social_available("google"), "Google desabilitado no editor/desktop")
	check(not session.social_available("steam"), "Steam nao habilitado")
	print("T18B_GOOGLE_RESULT checks=",total," failures=",failures," sem rede/credenciais")
	quit(1 if failures > 0 else 0)
