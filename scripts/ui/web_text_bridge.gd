class_name WebTextBridge
extends Node
## Teclado do iPhone (Safari e PWA): o Safari só abre o teclado se um campo HTML receber foco
## DENTRO do toque, e o Godot processa o toque no quadro seguinte. Este nó publica a área do
## LineEdit para o shell (web/shell.html → window.qseNativeInput); o toque nessa área foca um
## <input> real logo acima do teclado, e o texto volta para o LineEdit (mesmo envio do jogo).
## Fora do iOS Web não faz nada: Android, Windows e desktop continuam com o LineEdit normal.

var field: LineEdit
var _id := ""
var _bridge: JavaScriptObject
var _callbacks: Array = []
var _last := ""


## Liga o campo ao teclado nativo no iOS; devolve null nas demais plataformas.
static func attach(line_edit: LineEdit) -> WebTextBridge:
	if not enabled(): return null
	var bridge := WebTextBridge.new()
	bridge.name = "WebTextBridge"
	bridge.field = line_edit
	line_edit.add_child(bridge)
	return bridge


static func enabled() -> bool:
	if not OS.has_feature("web"): return false
	var value: Variant = JavaScriptBridge.eval("!!(window.qseNativeInput && window.qseNativeInput.enabled())", true)
	return value == true


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
	var key := "%d,%d,%d,%d,%s" % [top_left.x, top_left.y, bottom_right.x, bottom_right.y, field.text]
	if key == _last: return
	_last = key
	_bridge.setRegion(_id, top_left.x, top_left.y, bottom_right.x - top_left.x, bottom_right.y - top_left.y, field.text, field.placeholder_text, field.max_length)


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
