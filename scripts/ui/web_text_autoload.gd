extends Node
## Liga o teclado/preenchimento nativo (WebTextBridge) em todos os campos de texto no
## iPhone e Android pelo navegador/PWA. Nas demais plataformas não faz nada.


func _ready() -> void:
	WebTextBridge.install(get_tree())
