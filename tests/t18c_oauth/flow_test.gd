extends SceneTree
## Testes offline, nao criam contas, nao tocam nos limites de Auth.
var checks := 0
var failures := 0

func check(value: bool, title: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("T18C_OAUTH_FAIL " + title)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rfc := "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
	check(OAuthPkce.challenge(rfc) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "RFC7636 SHA256")
	var verifier := OAuthPkce.make_verifier()
	check(verifier.length() == 43, "verifier 32 bytes")
	check(not verifier.contains("+") and not verifier.contains("=") and not verifier.contains("/"), "base64url")
	check(OAuthPkce.challenge(verifier).length() == 43, "challenge S256")
	for provider: String in ["google", "discord"]:
		var url := OAuthPkce.authorize_path(provider, "https://aruanmf446-hub.github.io/quemsoueuv3/?invite=token", OAuthPkce.challenge(rfc))
		check(url.begins_with("/auth/v1/authorize?provider=" + provider), provider + " auth path")
		check(url.contains("code_challenge_method=s256"), provider + " pkce method")
		check(url.contains("invite%3Dtoken"), provider + " invite")
		check(not url.contains(rfc), provider + " verifier not exposed")
	check(OAuthPkce.authorize_path("steam", "", "challenge").is_empty(), "steam not available")
	check(not OAuthPkce.valid_callback(""), "empty callback rejected")
	check(not OAuthPkce.valid_callback("hello\nworld"), "injected newline rejected")
	check(OAuthPkce.valid_callback("code-placeholder"), "synthetic callback code valid")
	var params := OAuthDesktopLoopback._parse_query("code=a%2Bb%2Fc&error=access_denied&bad=ignored")
	check(params.get("code") == "a+b/c", "loopback URL decoding")
	check(params.get("error") == "access_denied", "loopback cancellation")
	check(not params.has("bad"), "ignore unexpected query keys")
	var loop := OAuthDesktopLoopback.new()
	root.add_child(loop)
	check(loop.start(), "loopback binds localhost only")
	var received: Array[Dictionary] = []
	loop.callback_received.connect(func(code: String, error: String) -> void:
		received.append({"code": code, "error": error}))
	var peer := StreamPeerTCP.new()
	check(peer.connect_to_host("127.0.0.1", OAuthDesktopLoopback.PORT) == OK, "loopback connection")
	for attempt in range(80):
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		await process_frame
	var connected := peer.get_status() == StreamPeerTCP.STATUS_CONNECTED
	check(connected, "local TCP connection established")
	if connected:
		var request := "GET /oauth/callback?code=fixture123 HTTP/1.1\r\nHost: 127.0.0.1:49173\r\nConnection: close\r\n\r\n"
		peer.put_data(request.to_utf8_buffer())
		for attempt in range(80):
			await process_frame
			if not received.is_empty():
				break
	check(received.size() == 1, "loopback emits one code")
	if received.size() == 1:
		check(received[0].code == "fixture123" and received[0].error.is_empty(), "callback has correct code")
	else:
		check(false, "callback has correct code")
	loop.close()
	loop.queue_free()
	var session := SessionService.new()
	var fake := preload("res://tests/t18_auth/fake_client.gd").new()
	session.client = fake
	check(not session.social_available("steam"), "steam disabled")
	check(not session.social_available("google"), "native OAuth disabled until configured")
	check(ServiceResult.message(ServiceResult.failure("oauth_missing_verifier")).contains("sessão"), "error text")
	print("T18C_OAUTH_RESULT checks=", checks, " failures=", failures, " fixtures_only=true")
	quit(1 if failures > 0 else 0)
