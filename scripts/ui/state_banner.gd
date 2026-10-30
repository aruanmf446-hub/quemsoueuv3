class_name StateBanner
extends PanelContainer

const STATES := ["loading", "success", "empty", "offline", "error", "unauthorized"]
var _message: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_message = PlayerUI.label("", 16)
	add_child(_message)
	show_state("empty")


func show_state(state: String, detail: String = "") -> void:
	if _message == null:
		return
	if not state in STATES:
		state = "error"
	var defaults := {"loading": "Carregando…", "success": "Atualizado",
		"empty": "Ainda não há dados para mostrar.", "offline": "Sem conexão. Seus dados online não estão disponíveis.",
		"error": "Não foi possível carregar. Tente novamente.", "unauthorized": "Entre na sua conta para acessar estes dados."}
	_message.text = tr(detail if not detail.is_empty() else defaults[state])
	_message.add_theme_color_override("font_color", Color("#ffb8a6") if state == "error" else (PlayerUI.GOLD if state == "loading" else PlayerUI.MUTED))
	visible = state != "success" or not detail.is_empty()
