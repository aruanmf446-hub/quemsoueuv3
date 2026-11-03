extends Node
## Liga o teclado/preenchimento nativo (WebTextBridge) em todos os campos de texto no
## iPhone e Android pelo navegador/PWA. Nas demais plataformas não faz nada.


func _ready() -> void:
	# Perfil iPhone (área segura + base de design própria); demais aparelhos: nada muda.
	UIScale.apply_device_profile(get_tree().root)
	WebTextBridge.install(get_tree())
