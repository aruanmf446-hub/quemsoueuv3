extends Control
const DeckCatalog = preload("res://scripts/decks/deck_library_catalog.gd")

signal option_selected(option_id: StringName)
@onready var _menu_buttons: Control = $MenuButtons
@onready var _navigation: NavigationManager = $Navigation
@onready var _services: PlayerServices = $Services
var _mode_label: Label
var _news_button: Button
var _news_auto_shown := {}
var _web_invite_intent := WebInviteIntent.new()
var _web_invite_navigating := false
var _initial_login_pending := true
var _startup_cover: TextureRect
var _nickname_modal: Control
var _hero_carousel: Control
var _coin_return_order := ""
var _coin_return_opening := false
var _current_route := ""


func _ready() -> void:
	if OS.has_feature("web"):
		var order := str(JavaScriptBridge.eval("(()=>{const q=new URLSearchParams(location.search).get('coin_order');try{return q||sessionStorage.getItem('qse_coin_return')||''}catch{return q||''}})()"))
		if CoinStoreService.uuid_valid(order): _coin_return_order=order
		if not _coin_return_order.is_empty():
			JavaScriptBridge.eval("try{sessionStorage.setItem('qse_coin_return',"+JSON.stringify(_coin_return_order)+")}catch{}")
	_services.profile.changed.connect(_resume_coin_checkout)
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
	_hotspot($TopBar/GemPill, "wallet", {"tab":"coins","category":"deck_credits"})
	_mode_label = PlayerUI.label("", 18, PlayerUI.GOLD)
	_mode_label.position = Vector2(42, 198)
	_mode_label.size = Vector2(620, 44)
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mode_label)
	move_child(_mode_label, 2)
	_services.profile.changed.connect(_refresh_profile)
	_services.profile.changed.connect(_nickname_profile_changed)
	_services.session.changed.connect(_nickname_profile_changed)
	_services.inventory.changed.connect(_refresh_profile)
	_services.wallet.changed.connect(_refresh_wallet)
	_services.cosmetic_shop.changed.connect(_refresh_wallet)
	_services.friends.changed.connect(_refresh_friends)
	_services.session.changed.connect(_refresh_profile)
	_services.session.changed.connect(_auth_redirect_ready)
	_services.rewards.changed.connect(_rewards_changed)
	_services.preferences.changed.connect(_refresh_wallet)
	_navigation.route_changed.connect(_route_changed)
	_services.duel.changed.connect(func() -> void: _publish_update_safety(_current_route))
	_refresh_profile()
	_refresh_wallet()
	_refresh_friends()
	$MenuButtons/BtnDuel.tooltip_text = "Mata-Mata: partida local contra bots ou salas online"
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
	# Hero cinematografico: apenas se as tres artes locais estiverem presentes.
	_hero_carousel = preload("res://scripts/menu/hero_carousel.gd").new()
	add_child(_hero_carousel)
	# Keep the actual interactive music player painted ABOVE the hero artwork.
	move_child(_hero_carousel, get_node("NowPlaying").get_index())
	_hero_carousel.connect("route_requested", _hero_route_selected)
	_hero_carousel.connect("news_requested", _open_news)
	_rewards_changed()
	# Nao mostrar o login quando um refresh token valido ja existe.
	# A arte cobre o lobby durante a validacao (sem permitir cliques).
	_check_web_invite.call_deferred()
	if OS.get_cmdline_args().has("--script"):
		# Smoke headless nao chama Auth remoto; cobre o caminho de visitante.
		_initial_login_pending = false
		_navigation.open_initial("account", {"startup": true})
	else:
		_show_startup_cover()
		_services.session.initial_restore_finished.connect(_initial_auth_resolved)
		if _services.session.initial_restore_complete:
			_initial_auth_resolved.call_deferred()


## A cena de login deixa de ser obrigatoria quando uma sessao valida ja foi
## restaurada. O overlay impede que o lobby receba toques antes da verificacao.
func _show_startup_cover() -> void:
	_startup_cover = TextureRect.new()
	_startup_cover.name = "StartupSessionCover"
	_startup_cover.texture = preload("res://assets/auth/login_cinematic_bg.webp")
	_startup_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_startup_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_startup_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_startup_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_startup_cover)
	move_child(_startup_cover, get_child_count() - 1)


func _initial_auth_resolved() -> void:
	if not _initial_login_pending or not is_inside_tree():
		return
	_initial_login_pending = false
	if not _services.session.authenticated() or _services.session.needs_password_reset:
		_navigation.open_initial("account", {"startup": true})
	if is_instance_valid(_startup_cover):
		_startup_cover.queue_free()
	_startup_cover = null
	_resume_web_invite()
	_nickname_profile_changed.call_deferred()
	_resume_coin_checkout.call_deferred()
	_maybe_show_news.call_deferred()


## Perfil sem nickname precisa da confirmação do próprio jogador.
## O modal cobre qualquer tela, inclusive uma sala aberta por convite.
func _nickname_profile_changed() -> void:
	if _initial_login_pending or OS.get_cmdline_args().has("--script"):
		return
	_nickname_offer.call_deferred()


func _nickname_offer() -> void:
	if not is_inside_tree() or _initial_login_pending:
		return
	if not is_instance_valid(_nickname_modal): _nickname_modal = null
	var logged := _services.session.authenticated()
	var has_nickname := _services.profile.has_nickname()
	if not logged or has_nickname:
		if is_instance_valid(_nickname_modal):
			_nickname_modal.queue_free()
			_nickname_modal = null
		_maybe_show_news.call_deferred()
		_resume_coin_checkout.call_deferred()
		return
	if _services.session.needs_password_reset or is_instance_valid(_nickname_modal):
		return
	# Sessão autenticada não significa perfil carregado. Não apresentar cadastro
	# enquanto a conta existente ainda está sendo consultada, nem após erro de rede.
	if _services.profile.state != "success":
		return
	var prompt = preload("res://scripts/ui/nickname_onboarding.gd").new()
	prompt.setup(_services)
	_nickname_modal = prompt
	add_child(_nickname_modal)
	move_child(_nickname_modal, get_child_count() - 1)


## A URL de convite é detectada no lobby, sem esperar o jogador tocar em Duelo.
## O token não é copiado para a navegação: duel_screen o consome depois do login.
func _check_web_invite() -> void:
	if not OS.has_feature("web"):
		return
	var present: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).has('invite')")
	# eval devolve número/booleano conforme o navegador: compara como bool.
	_web_invite_intent.capture(bool(present))
	_resume_web_invite()


func _auth_redirect_ready() -> void:
	_resume_coin_checkout.call_deferred()
	if _initial_login_pending:
		return
	# Um retorno de recovery conclui a senha antes de qualquer convite.
	if _services.session.needs_password_reset:
		_open_auth_recovery.call_deferred()
		return
	# O convite nao pode ser descartado por uma volta antecipada ao lobby.
	if OS.has_feature("web"):
		var has_invite: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).has('invite')")
		_web_invite_intent.capture(UIScale.js_true(has_invite))
	_resume_web_invite()
	if _services.session.authenticated() and not _web_invite_intent.pending:
		_finish_startup_login.call_deferred()


func _finish_startup_login() -> void:
	if not _services.session.authenticated() or _web_invite_intent.pending or _services.session.needs_password_reset:
		return
	# Somente fechar a conta quando for de fato a primeira tela do jogo.
	var history: Array = _navigation.get("_history")
	if history.size() != 1 or str(history[0].get("route", "")) != "account":
		return
	if not bool(history[0].get("params", {}).get("startup", false)):
		return
	if bool(_navigation.get("_busy")):
		await get_tree().create_timer(0.2).timeout
	if not bool(_navigation.get("_busy")) and _navigation.get("_active") != null:
		_navigation.back()


func _open_auth_recovery() -> void:
	if not _services.session.needs_password_reset:
		return
	if bool(_navigation.get("_busy")):
		await get_tree().create_timer(0.25).timeout
	if not bool(_navigation.get("_busy")):
		_navigation.open("account")


func _resume_web_invite() -> void:
	if _initial_login_pending:
		return
	if _services.session.needs_password_reset:
		return
	if _web_invite_navigating:
		return
	var route := _web_invite_intent.next_route(_services.session.authenticated())
	if route.is_empty():
		return
	# A tela account ja esta aberta no primeiro frame. Nao empilhar outra.
	if route == "account":
		var history: Array = _navigation.get("_history")
		if not history.is_empty() and str(history.back().get("route", "")) == "account":
			return
	_web_invite_navigating = true
	_navigate_web_invite(route)


func _navigate_web_invite(route: String) -> void:
	# A transição do login pode estar animando. Espera limitada, sem loop de ingresso.
	for attempt in range(10):
		if not bool(_navigation.get("_busy")):
			break
		await get_tree().create_timer(0.1).timeout
	if not is_inside_tree():
		return
	if bool(_navigation.get("_busy")):
		_web_invite_navigating = false
		return
	_navigation.open(route)
	_web_invite_intent.mark_opened(route)
	_web_invite_navigating = false


func _layout_news_button() -> void:
	if not is_instance_valid(_news_button): return
	var unit := 1.0
	var pad := 24.0 if UIScale.is_compact() else 40.0
	_news_button.size = Vector2(248, 88) * unit
	_news_button.position = Vector2(pad * unit, size.y - 112 * unit)
	_news_button.add_theme_font_size_override("font_size", roundi(30 * unit))
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.06) if state == "hover" else Color.TRANSPARENT
		_news_button.add_theme_stylebox_override(state, style)

## Oferta automática no máximo uma vez por campanha e por conta; recibo é do GAME.
func _rewards_changed() -> void:
	if not is_instance_valid(_news_button): return
	var reward := _services.rewards
	var ready := reward.state == "success" and not (str(reward.campaign.get("id", "")) == "diva_pop_2026" and DeckCatalog.find_deck("diva_pop").is_empty())
	_news_button.text = "NOVIDADES  •  NOVO" if ready and not reward.seen else "NOVIDADES"
	_news_button.tooltip_text = "Presentes gratuitos e novidades oficiais"
	_maybe_show_news.call_deferred()


func _maybe_show_news() -> void:
	if not _coin_return_order.is_empty(): return
	if not is_inside_tree() or _initial_login_pending or OS.get_cmdline_args().has("--script"): return
	if not _services.session.authenticated() or _services.session.needs_password_reset: return
	if _web_invite_intent.pending or _navigation.get("_active") != null: return
	if is_instance_valid(_nickname_modal) or _services.profile.state != "success": return
	if not _services.profile.has_nickname(): return
	var reward := _services.rewards
	if reward.state != "success" or reward.seen or reward.campaign.is_empty(): return
	# T30: não anunciar deck até as dez imagens existirem no export do jogo.
	if str(reward.campaign.get("id", "")) == "diva_pop_2026" and DeckCatalog.find_deck("diva_pop").is_empty(): return
	var key := str(_services.session.user.get("id", "")) + ":" + str(reward.campaign.get("id", ""))
	if _news_auto_shown.has(key): return
	_news_auto_shown[key] = true
	_open_news()


## The return query only opens the wallet. Only the verified webhook credits coins.
func _resume_coin_checkout() -> void:
	if _coin_return_order.is_empty() or _coin_return_opening or _initial_login_pending: return
	if not _services.session.authenticated() or _services.session.needs_password_reset: return
	if _web_invite_intent.pending or not _services.profile.has_nickname() or is_instance_valid(_nickname_modal): return
	_coin_return_opening=true
	var owner := str(_services.session.user.get("id",""))
	while bool(_navigation.get("_busy")):
		await get_tree().create_timer(0.2).timeout
	_coin_return_opening=false
	if owner!=str(_services.session.user.get("id","")) or not _services.session.authenticated(): return
	_coin_return_order=""
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(()=>{const u=new URL(location.href);u.searchParams.delete('coin_order');history.replaceState(null,'',u.href);try{sessionStorage.removeItem('qse_coin_return')}catch{}})()")
	_navigation.open("wallet",{"tab":"coins"})


func _hero_route_selected(route: String) -> void:
	if route == "wallet":
		if not ReleaseFeatures.COMMERCE_ENABLED: return
		_navigation.open("wallet", {"tab":"coins"})
	elif route == "emotes":
		if not ReleaseFeatures.COSMETIC_EXTRAS_ENABLED: return
		_navigation.open("skins", {"cosmetic_mode":"shop"})
	else:
		_on_menu_button_activated(StringName(route))

func _open_news() -> void:
	if get_node_or_null("NewsOverlay") != null: return
	var overlay := NewsOverlay.new()
	overlay.name = "NewsOverlay"
	add_child(overlay)


func _on_menu_button_activated(button_id: StringName) -> void:
	option_selected.emit(button_id)
	_navigation.open(String(button_id))


func _hotspot(target: Control, route: String, params: Dictionary={}) -> void:
	var button := Button.new()
	button.tooltip_text = {"profile": "Meu perfil", "wallet": "Minha carteira"}.get(route, route)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(_navigation.open.bind(route, params))
	target.add_child(button)


func _refresh_profile() -> void:
	var profile := _services.profile.data
	$ProfileCard/Content/Info/Name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	$ProfileCard/Content/Info/Name.text = str(profile.get("nickname")) if profile.get("nickname") != null else tr("Minha conta")
	$ProfileCard/Content/Info/Level.text = str(TranslationServer.translate("Nível ")) + DevicePreferences.number(profile.get("level")) if profile.get("level") != null else "Perfil · sem nível registrado"
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
	$TopBar/GemPill/Content/Value.text = DevicePreferences.number(_services.cosmetic_shop.deck_credits(), locale)


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
		row.tooltip_text = tr(str(_services.inventory.entry(str(friend.equipped_character_id)).get("name", "Skin indisponível")))
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
	_current_route = route
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.qseSetInternalScreen && window.qseSetInternalScreen("+("false" if route.is_empty() else "true")+")")
	var hero_active := is_instance_valid(_hero_carousel) and bool(_hero_carousel.get("using_art"))
	var show_legacy_stage := route.is_empty() and not hero_active
	$LobbyArea/Stage/Viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if show_legacy_stage else SubViewport.UPDATE_DISABLED
	# Keep the original 3D scene paused when the illustrated hero takes over.
	$LobbyArea/Stage/Viewport/World.process_mode = Node.PROCESS_MODE_INHERIT if show_legacy_stage else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_news_button): _news_button.visible = show_legacy_stage
	# Lobby: player normal. Telas internas: versão mini no canto (some em sala/partida).
	var now_playing := get_node_or_null("NowPlaying")
	# Mini só onde o canto superior direito está livre (não cobre busca, filtros nem botões).
	const MINI_ROUTES := ["duel", "friends", "profile", "wallet", "story", "music"]
	if now_playing != null:
		now_playing.set_suppressed(not route.is_empty() and not MINI_ROUTES.has(route))
		now_playing.set_mini(not route.is_empty())
	if route.is_empty(): _maybe_show_news.call_deferred()
	_publish_update_safety(route)


## PWA: o shell só oferece "Reiniciar para atualizar" fora de sala/partida (inclusive no login,
## para quem ainda não entrou também receber a versão nova).
func _publish_update_safety(route: String) -> void:
	if not OS.has_feature("web"): return
	var services := PlayerServices.current
	var safe := route in ["", "settings", "account"] and not (services != null and services.duel != null and services.duel.in_room())
	JavaScriptBridge.eval("window.qseSafeToUpdate = %s; window.dispatchEvent(new Event('qse-update-safety'));" % ("true" if safe else "false"), true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_profile()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
