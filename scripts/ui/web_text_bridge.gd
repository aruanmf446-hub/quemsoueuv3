class_name WebTextBridge
extends Node
## Teclado do iPhone (Safari e PWA): o Safari só abre o teclado se um campo HTML receber foco
## DENTRO do toque, e o Godot processa o toque no quadro seguinte. Este nó publica a área do
## LineEdit para o shell (web/shell.html → window.qseNativeInput); o toque nessa área foca um
## <input> real logo acima do teclado, e o texto volta para o LineEdit (mesmo envio do jogo).
## Vale para iPhone e Android no navegador/PWA; Windows e desktop continuam com o LineEdit normal.
## Campos de e-mail/senha usam <input> de um formulário real (type email/password + autocomplete)
## para o Chaves do iCloud e o Google sugerirem e salvarem as contas.
## Todo LineEdit do jogo é ligado sozinho (install()); meta "qse_autocomplete" ajusta a dica
## (ex.: "new-password" no cadastro) e meta "qse_native_off" desliga a ponte num campo.

var field: LineEdit
var _id := ""
var _bridge: JavaScriptObject
var _callbacks: Array = []
var _last := ""


## Liga o campo ao teclado nativo no iOS; devolve null nas demais plataformas.
static func attach(line_edit: LineEdit, force := false) -> WebTextBridge:
	if not force and not enabled(): return null
	var bridge := WebTextBridge.new()
	bridge.name = "WebTextBridge"
	bridge.field = line_edit
	line_edit.add_child(bridge)
	return bridge


## Liga automaticamente todo LineEdit que entrar na árvore (chamado por um autoload).
static func install(tree: SceneTree) -> void:
	if not enabled(): return
	tree.node_added.connect(func(node: Node) -> void:
		if node is LineEdit and not node.has_meta("qse_native_off"):
			(func() -> void:
				if is_instance_valid(node) and node.get_node_or_null("WebTextBridge") == null: attach(node)).call_deferred())


## Login aceito: o navegador oferece salvar e-mail e senha.
static func remember_login() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.qseNativeInput && window.qseNativeInput.remember && window.qseNativeInput.remember()", true)


static func kind_of(line_edit: LineEdit) -> String:
	if line_edit.has_meta("qse_kind"): return str(line_edit.get_meta("qse_kind"))
	if line_edit.secret or line_edit.get_node_or_null("RevealPassword") != null: return "password"
	if line_edit.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS: return "email"
	return "text"


static func enabled() -> bool:
	if not OS.has_feature("web"): return false
	var value: Variant = JavaScriptBridge.eval("!!(window.qseNativeInput && window.qseNativeInput.enabled())", true)
	return UIScale.js_true(value)


func _ready() -> void:
	_id = "f%d" % get_instance_id()
	# O teclado próprio do Godot no Web tentaria focar outro campo fora do toque e roubaria o foco.
	field.virtual_keyboard_enabled = false
	_bridge = JavaScriptBridge.get_interface("qseNativeInput")
	if _bridge == null:
		set_process(false)
		return
	_callbacks = [JavaScriptBridge.create_callback(_on_input), JavaScriptBridge.create_callback(_on_submit), JavaScriptBridge.create_callback(_on_close)]
	_bridge.bind(_id, _callbacks[0], _callbacks[1], _callbacks[2])
	field.text_changed.connect(func(text: String) -> void: if _bridge != null: _bridge.setText(_id, text))
	# Toque/foco no campo do jogo abre a caixa de digitação nativa (web/shell.html).
	field.focus_entered.connect(_open_native)
	field.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			_open_native())


func _open_native() -> void:
	if _bridge == null or not field.editable or not field.is_visible_in_tree(): return
	_publish(true)
	_bridge.open(_id)


func _publish(force: bool) -> void:
	if force: _last = ""
	_process(0.0)


func _process(_delta: float) -> void:
	if _bridge == null: return
	if not is_instance_valid(field) or not field.is_visible_in_tree() or not field.editable:
		if _last != "off":
			_bridge.clearRegion(_id)
			_last = "off"
		return
	# Retângulo em pixels da janela/canvas (já com a escala do stretch e da tela).
	var rect := field.get_global_rect()
	var to_window := field.get_viewport().get_final_transform() * field.get_canvas_transform()
	var top_left := to_window * rect.position
	var bottom_right := to_window * rect.end
	# O botão de mostrar senha fica de fora: o toque nele continua sendo do jogo.
	var eye := field.get_node_or_null("RevealPassword") as Control
	if eye != null and eye.visible:
		bottom_right.x = minf(bottom_right.x, (to_window * eye.get_global_rect().position).x)
	var kind := kind_of(field)
	var key := "%d,%d,%d,%d,%s,%s,%s" % [top_left.x, top_left.y, bottom_right.x, bottom_right.y, field.text, kind, field.secret]
	if key == _last: return
	_last = key
	_bridge.setRegion(_id, top_left.x, top_left.y, bottom_right.x - top_left.x, bottom_right.y - top_left.y, field.text, field.placeholder_text, field.max_length,
		kind, str(field.get_meta("qse_autocomplete", "")), field.secret)


func _on_input(args: Array) -> void:
	if not is_instance_valid(field): return
	field.text = str(args[0]).left(field.max_length if field.max_length > 0 else 10000)
	field.caret_column = field.text.length()
	field.text_changed.emit(field.text)


func _on_submit(args: Array) -> void:
	if not is_instance_valid(field): return
	field.text = str(args[0])
	field.text_submitted.emit(field.text)


func _on_close(args: Array) -> void:
	if not is_instance_valid(field): return
	if field.text != str(args[0]): field.text = str(args[0])
	field.release_focus()


func _exit_tree() -> void:
	if _bridge != null: _bridge.clearRegion(_id)
