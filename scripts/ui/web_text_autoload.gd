extends Node
## Liga o teclado/preenchimento nativo (WebTextBridge) em todos os campos de texto no
## iPhone e Android pelo navegador/PWA. Nas demais plataformas não faz nada.
## Varredura periódica (não depende só de node_added, que no iPhone real não ligava nada).

var _enabled := false
var _wait := 0.0
var _attached := 0


func _ready() -> void:
	# Perfil iPhone (área segura + base de design própria); demais aparelhos: nada muda.
	UIScale.apply_device_profile(get_tree().root)
	WebTextBridge.install(get_tree())
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0: return
	_wait = 0.4
	if not OS.has_feature("web"):
		set_process(false)
		return
	# Sem depender de enabled(): basta a página ter a ponte (web/shell.html só cria no celular).
	var has_bridge: Variant = JavaScriptBridge.eval("!!(window.qseNativeInput && window.qseNativeInput.open)", true)
	var count := 0
	var attached := 0
	if has_bridge == true:
		for node in get_tree().root.find_children("*", "LineEdit", true, false):
			var field := node as LineEdit
			if field.has_meta("qse_native_off") or not field.is_visible_in_tree(): continue
			count += 1
			if field.get_node_or_null("WebTextBridge") == null: WebTextBridge.attach(field, true)
			if field.get_node_or_null("WebTextBridge") != null: attached += 1
	# Diagnóstico: o que o jogo vê, sempre (inclusive zero).
	JavaScriptBridge.eval("window.qseBridgeFields = '%d/%d (ponte %s)'" % [attached, count, str(has_bridge)], true)
