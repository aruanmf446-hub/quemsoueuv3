extends Control
## Entrada do Quem Sou Eu V3. A tela de login e a primeira tela navegavel.
## Os cartoes de historia continuam nas transicoes do modo Historia, nao no boot.
const LOGIN_SCENE := "res://scenes/menu/main_menu.tscn"
const BOOT_ART := preload("res://assets/auth/login_cinematic_bg.webp")


func _ready() -> void:
	var backdrop := TextureRect.new()
	backdrop.name = "AuthLoadingArt"
	backdrop.texture = BOOT_ART
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_enter_auth.call_deferred()


func _enter_auth() -> void:
	# Renderiza o mesmo fundo ao carregar o lobby, sem mostrar cartoes antes
	# do login. A primeira tela interativa sera NavigationManager.account.
	var packed := load(LOGIN_SCENE) as PackedScene
	if packed == null:
		push_error("Nao foi possivel abrir a autenticacao inicial.")
		return
	get_tree().change_scene_to_packed(packed)
