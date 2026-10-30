extends Control

signal option_selected(option_id: StringName)
@onready var _menu_buttons: Control = $MenuButtons
@onready var _navigation: NavigationManager = $Navigation
@onready var _services: PlayerServices = $Services
var _mode_label: Label
var _news_button: Button


func _ready() -> void:
	for child in _menu_buttons.get_children():
		if child is MenuCardButton:
			child.activated.connect(_on_menu_button_activated)
	_navigation.register_screen("skins", $SkinsPanel)
	$TopBar/FriendsButton.pressed.connect(_navigation.open.bind("friends", {}))
	$TopBar/MailButton.pressed.connect(_navigation.open.bind("friends", {"tab": "incoming"}))
	$TopBar/SettingsButton.pressed.connect(_navigation.open.bind("settings", {}))
	$FriendsPanel/Margin/Content/ViewAllButton.pressed.connect(_navigation.open.bind("friends", {}))
	for target: Button in [$TopBar/FriendsButton, $TopBar/MailButton, $TopBar/SettingsButton, $FriendsPanel/Margin/Content/ViewAllButton]:
		target.focus_mode = Control.FOCUS_ALL
	_hotspot($ProfileCard, "profile")
	_hotspot($TopBar/CoinPill, "wallet")
	_hotspot($TopBar/GemPill, "wallet")
	_mode_label = PlayerUI.label("", 18, PlayerUI.GOLD)
	_mode_label.position = Vector2(42, 198)
	_mode_label.size = Vector2(620, 44)
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mode_label)
	move_child(_mode_label, 2)
	_services.profile.changed.connect(_refresh_profile)
	_services.inventory.changed.connect(_refresh_profile)
	_services.wallet.changed.connect(_refresh_wallet)
	_services.friends.changed.connect(_refresh_friends)
	_services.session.changed.connect(_refresh_profile)
	_services.preferences.changed.connect(_refresh_wallet)
	_navigation.route_changed.connect(_route_changed)
	_refresh_profile()
	_refresh_wallet()
	_refresh_friends()
	$MenuButtons/BtnDuel.tooltip_text = "Duelo: partida local contra bots ou salas online"
	get_tree().auto_accept_quit = false
	var composition := preload("res://scripts/menu/lobby_composition.gd").new()
	composition.name = "LobbyComposition"
	add_child(composition)
	# Mini player das músicas do menu: no celular é o único controle (sem F6–F9).
	add_child(preload("res://scripts/audio/now_playing.gd").new())
	_news_button = Button.new()
	_news_button.name = "NewsButton"
	_news_button.text = "NOVIDADES"
	_news_button.tooltip_text = "Notícias e próximos capítulos"
	_news_button.focus_mode = Control.FOCUS_ALL
	_news_button.pressed.connect(_open_news)
	PlayerUI.style_button(_news_button, false)
	add_child(_news_button)
	resized.connect(_layout_news_button)
	_layout_news_button.call_deferred()

func _layout_news_button() -> void:
	if not is_instance_valid(_news_button): return
	var unit := size.y / maxf(float(get_window().size.y) / UIScale.device_scale(), 1.0)
	var pad := 24.0 if UIScale.is_compact() else 40.0
	_news_button.size = Vector2(140, 38) * unit
	_news_button.position = Vector2(pad * unit, size.y - 54 * unit)
	_news_button.add_theme_font_size_override("font_size", roundi(12 * unit))
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.06) if state == "hover" else Color.TRANSPARENT
		_news_button.add_theme_stylebox_override(state, style)

func _open_news() -> void:
	if get_node_or_null("NewsOverlay") != null: return
	var overlay := NewsOverlay.new()
	overlay.name = "NewsOverlay"
	add_child(overlay)


func _on_menu_button_activated(button_id: StringName) -> void:
	option_selected.emit(button_id)
	_navigation.open(String(button_id))


func _hotspot(target: Control, route: String) -> void:
	var button := Button.new()
	button.tooltip_text = {"profile": "Meu perfil", "wallet": "Minha carteira"}.get(route, route)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(_navigation.open.bind(route, {}))
	target.add_child(button)


func _refresh_profile() -> void:
	var profile := _services.profile.data
	$ProfileCard/Content/Info/Name.text = str(profile.get("nickname", "Minha conta") if profile.get("nickname") != null else "Minha conta")
	$ProfileCard/Content/Info/Level.text = "Nível " + DevicePreferences.number(profile.get("level")) if profile.get("level") != null else "Perfil · sem nível registrado"
	$ProfileCard/Content/Info/Xp.hide()
	_mode_label.text = "Conta conectada" if _services.session.authenticated() else "Demonstração local • entre para sincronizar"
	var avatar: Panel = $ProfileCard/Content/Avatar
	var previous := avatar.get_node_or_null("EquippedPortrait")
	if previous != null:
		avatar.remove_child(previous)
		previous.queue_free()
	var portrait := PlayerUI.portrait(_services.inventory.equipped_id(), 50)
	portrait.name = "EquippedPortrait"
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar.add_child(portrait)
	avatar.move_child(portrait, 0)


func _refresh_wallet() -> void:
	var locale: String = _services.preferences.values.locale
	$TopBar/CoinPill/Content/Value.text = DevicePreferences.number(_services.wallet.balance("coins"), locale)
	$TopBar/GemPill/Content/Value.text = DevicePreferences.number(_services.wallet.balance("gems"), locale)


func _refresh_friends() -> void:
	var list: VBoxContainer = $FriendsPanel/Margin/Content/FriendList
	PlayerUI.clear(list)
	var data: Array = _services.friends.data.get("friends", [])
	var online := 0
	for friend: Dictionary in data:
		if _services.friends.online_ids.has(str(friend.user_id)):
			online += 1
	$FriendsPanel/Margin/Content/Header/Online.text = "%d online" % online if _services.friends.presence_connected else "—"
	for index in mini(data.size(), 4):
		var friend: Dictionary = data[index]
		var row := preload("res://scenes/menu/components/friend_row.tscn").instantiate() as FriendRow
		row.friend_name = str(friend.nickname)
		row.status_text = _services.friends.presence_label(str(friend.user_id))
		row.status_color = Color("#3ddc5c") if _services.friends.online_ids.has(str(friend.user_id)) else Color("#b3bfd0")
		row.tooltip_text = str(_services.inventory.entry(str(friend.equipped_character_id)).get("name", "Skin indisponível"))
		list.add_child(row)
		var avatar: Panel = row.get_node("Avatar")
		var portrait := PlayerUI.portrait(str(friend.equipped_character_id), 40)
		avatar.add_child(portrait)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var friend_label := row.get_node("Info/Name") as Label
		friend_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		friend_label.clip_text = true
		var button := row.get_node("AddButton") as Button
		button.text = "›"
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_navigation.open.bind("public_profile", {"public_id": friend.public_id}))
	if data.is_empty():
		var empty_text := "Nenhum amigo ainda." if _services.friends.state == "success" else "Entre para ver suas amizades."
		var empty_label := PlayerUI.label(empty_text, 18)
		if _services.preferences.values.locale.begins_with("pt"):
			empty_label.text = empty_text
		list.add_child(empty_label)
	if has_node("LobbyComposition"):
		get_node("LobbyComposition").call_deferred("_layout")


func _route_changed(route: String) -> void:
	$LobbyArea/Stage/Viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if route.is_empty() else SubViewport.UPDATE_DISABLED
	if is_instance_valid(_news_button): _news_button.visible = route.is_empty()
	# O mini player é do lobby: nas telas internas ele cobria títulos e conteúdo.
	var now_playing := get_node_or_null("NowPlaying")
	if now_playing != null: now_playing.set_suppressed(not route.is_empty())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
