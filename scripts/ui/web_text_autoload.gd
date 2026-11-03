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
	if not _enabled:
		if not OS.has_feature("web"):
			set_process(false)
			return
		_enabled = WebTextBridge.enabled()
		if not _enabled: return
	var count := 0
	for node in get_tree().root.find_children("*", "LineEdit", true, false):
		var field := node as LineEdit
		if field.has_meta("qse_native_off"): continue
		if field.get_node_or_null("WebTextBridge") == null: WebTextBridge.attach(field)
		count += 1
	if count != _attached:
		_attached = count
		JavaScriptBridge.eval("window.qseBridgeFields = %d" % count, true)
