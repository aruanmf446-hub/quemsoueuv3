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

var field: Control
var _id := ""
var _bridge: JavaScriptObject
var _callbacks: Array = []
var _last := ""
var _receiving := false


## Liga o campo ao teclado nativo no iOS; devolve null nas demais plataformas.
static func attach(line_edit: Control, force := false) -> WebTextBridge:
	if not force and not enabled(): return null
	if not line_edit is LineEdit and not line_edit is TextEdit: return null
	var existing := line_edit.get_node_or_null("WebTextBridge") as WebTextBridge
	if existing!=null: return existing
	var bridge := WebTextBridge.new()
	bridge.name = "WebTextBridge"
	bridge.field = line_edit
	line_edit.add_child(bridge)
	return bridge


## Liga automaticamente todo LineEdit que entrar na árvore (chamado por um autoload).
static func install(tree: SceneTree) -> void:
	if not enabled(): return
	tree.node_added.connect(func(node: Node) -> void:
		if (node is LineEdit or node is TextEdit) and not node.has_meta("qse_native_off"):
			(func() -> void:
				if is_instance_valid(node) and node.get_node_or_null("WebTextBridge") == null: attach(node)).call_deferred())


## Login aceito: o navegador oferece salvar e-mail e senha.
static func remember_login() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.qseNativeInput && window.qseNativeInput.remember && window.qseNativeInput.remember()", true)


static func kind_of(line_edit: Control) -> String:
	if line_edit.has_meta("qse_kind"): return str(line_edit.get_meta("qse_kind"))
	if line_edit is TextEdit: return "multiline"
	if not line_edit is LineEdit: return "text"
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
	field.set("virtual_keyboard_enabled",false)
	_bridge = JavaScriptBridge.get_interface("qseNativeInput")
	if _bridge == null:
		set_process(false)
		return
	_callbacks = [JavaScriptBridge.create_callback(_on_input), JavaScriptBridge.create_callback(_on_submit), JavaScriptBridge.create_callback(_on_close)]
	_bridge.bind(_id, _callbacks[0], _callbacks[1], _callbacks[2])
	if field is LineEdit: field.text_changed.connect(func(_text: String) -> void: _sync_to_native())
	else: field.text_changed.connect(_sync_to_native)
	# Toque/foco no campo do jogo abre a caixa de digitação nativa (web/shell.html).
	field.focus_entered.connect(_open_native)
	field.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			_open_native())


func _open_native() -> void:
	if _bridge == null or not field.get("editable") or not field.is_visible_in_tree(): return
	_publish(true)
	_bridge.open(_id)


func _publish(force: bool) -> void:
	if force: _last = ""
	_process(0.0)


func _process(_delta: float) -> void:
	if _bridge == null: return
	var rect := visible_control_rect(field)
	if rect.size==Vector2.ZERO or not field.get("editable"):
		if _last != "off":
			_bridge.clearRegion(_id)
			_last = "off"
		return
	# Retângulo em pixels da janela/canvas (já com a escala do stretch e da tela).
	var to_window := field.get_viewport().get_final_transform() * field.get_canvas_transform()
	var top_left := to_window * rect.position
	var bottom_right := to_window * rect.end
	# O botão de mostrar senha fica de fora: o toque nele continua sendo do jogo.
	var eye := field.get_node_or_null("RevealPassword") as Control
	if eye != null and eye.visible:
		bottom_right.x = minf(bottom_right.x, (to_window * eye.get_global_rect().position).x)
	var kind := kind_of(field)
	var value := str(field.get("text"))
	var placeholder := str(TranslationServer.translate(str(field.get("placeholder_text"))))
	var secret: bool=field.secret if field is LineEdit else false
	var maximum: int=field.max_length if field is LineEdit else int(field.get_meta("qse_max_length",10000))
	var key := "%d,%d,%d,%d,%s,%s,%s,%s" % [top_left.x, top_left.y, bottom_right.x, bottom_right.y, value, kind, secret, placeholder]
	if key == _last: return
	_last = key
	# clearRegion remove também os callbacks. Perfil carregando, rolagem ou um
	# modal podem ocultar o campo temporariamente: religar antes de republicá-lo.
	_bridge.bind(_id,_callbacks[0],_callbacks[1],_callbacks[2])
	_bridge.setRegion(_id, top_left.x, top_left.y, bottom_right.x - top_left.x, bottom_right.y - top_left.y, value, placeholder, maximum,
		kind, str(field.get_meta("qse_autocomplete", "")), secret)

static func visible_control_rect(control: Control) -> Rect2:
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return Rect2()
	for window: Window in control.get_tree().root.get_embedded_subwindows():
		if window.visible and window!=control.get_window(): return Rect2()
	for modal: Node in control.get_tree().get_nodes_in_group("qse_web_input_modal"):
		if modal is Control and modal.is_visible_in_tree() and modal!=control and not modal.is_ancestor_of(control): return Rect2()
	var rect := control.get_global_rect()
	var visible := rect.intersection(control.get_viewport().get_visible_rect())
	var parent := control.get_parent()
	while parent!=null:
		if parent is Control and parent.clip_contents: visible=visible.intersection(parent.get_global_rect())
		parent=parent.get_parent()
	if visible.size.x<rect.size.x-1 or visible.size.y<rect.size.y-1: return Rect2()
	return rect

func _sync_to_native() -> void:
	if not _receiving and _bridge!=null: _bridge.setText(_id,str(field.get("text")))

func _apply_text(value: String) -> void:
	if not is_instance_valid(field): return
	var maximum: int=field.max_length if field is LineEdit else int(field.get_meta("qse_max_length",10000))
	var text := value.left(maximum if maximum>0 else 10000)
	if str(field.get("text"))==text: return
	_receiving=true
	field.set("text",text)
	if field is LineEdit:
		field.caret_column=text.length()
		field.text_changed.emit(text)
	elif field is TextEdit:
		field.set_caret_line(field.get_line_count()-1)
		field.set_caret_column(field.get_line(field.get_line_count()-1).length())
		field.text_changed.emit()
	_receiving=false


func _on_input(args: Array) -> void:
	if not args.is_empty(): _apply_text(str(args[0]))


func _on_submit(args: Array) -> void:
	if not is_instance_valid(field): return
	if args.is_empty(): return
	_apply_text(str(args[0]))
	if field is LineEdit: field.text_submitted.emit(field.text)


func _on_close(args: Array) -> void:
	if not is_instance_valid(field): return
	if not args.is_empty(): _apply_text(str(args[0]))
	if field.is_inside_tree(): field.release_focus()


func _exit_tree() -> void:
	if _bridge != null: _bridge.clearRegion(_id)
