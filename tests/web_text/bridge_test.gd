extends SceneTree
## Teste do WebTextBridge fora do navegador: tipos dos campos de login e ponte desligada no desktop.
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func _initialize() -> void:
	var email := LineEdit.new()
	email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	check(WebTextBridge.kind_of(email) == "email", "teclado de e-mail vira campo de e-mail")
	var password := LineEdit.new()
	password.secret = true
	check(WebTextBridge.kind_of(password) == "password", "campo secreto vira senha")
	PremiumUI.reveal_toggle(password)
	password.secret = false
	check(WebTextBridge.kind_of(password) == "password", "senha visível (olho) continua sendo senha")
	var confirm := LineEdit.new()
	confirm.secret = true
	confirm.set_meta("qse_kind", "confirm")
	check(WebTextBridge.kind_of(confirm) == "confirm", "confirmação não mistura com a senha do login")
	check(WebTextBridge.kind_of(LineEdit.new()) == "text", "campo comum continua texto")
	check(not WebTextBridge.enabled(), "fora do navegador a ponte fica desligada")
	check(WebTextBridge.attach(LineEdit.new()) == null, "attach não faz nada no desktop")
	for node in [email, password, confirm]: node.free()
	print("WEB_TEXT_TEST failures=%d" % failures)
	quit(1 if failures else 0)
