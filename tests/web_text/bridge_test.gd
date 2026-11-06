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
	var common := LineEdit.new()
	check(WebTextBridge.kind_of(common) == "text", "campo comum continua texto")
	check(not WebTextBridge.enabled(), "fora do navegador a ponte fica desligada")
	check(WebTextBridge.attach(common) == null, "attach não faz nada no desktop")
	var edited := LineEdit.new()
	var model := {"value":""}
	edited.text_changed.connect(func(value: String)->void:model.value=value)
	var bridge := WebTextBridge.new()
	bridge.field=edited
	bridge._on_input(["ABC"])
	check(model.value=="ABC","evento nativo atualiza o modelo do formulário")
	bridge._on_close([""])
	check(edited.text.is_empty() and model.value.is_empty(),"apagar e fechar o campo também emite a alteração")
	var multiline := TextEdit.new()
	multiline.set_meta("qse_max_length",400)
	multiline.text_changed.connect(func()->void:model.value=multiline.text)
	bridge.field=multiline
	bridge._on_input(["Linha 1\nLinha 2"])
	check(model.value=="Linha 1\nLinha 2" and WebTextBridge.kind_of(multiline)=="multiline","descrição preserva linhas no campo nativo")
	bridge._on_close(["Final"])
	check(model.value=="Final","fechar textarea salva a última edição")
	bridge.free()
	edited.free()
	multiline.free()
	for node in [email, password, confirm, common]: node.free()
	print("WEB_TEXT_TEST failures=%d" % failures)
	quit(1 if failures else 0)
