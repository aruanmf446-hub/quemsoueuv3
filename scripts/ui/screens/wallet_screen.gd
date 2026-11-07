extends PlayerScreen
var _coin_store := false
var _store_category := "coins"
var _checkout_dialog: Control
var _refreshing := false


func _ready() -> void:
	super._ready()
	heading.text = tr("Minha carteira")
	services.wallet.changed.connect(func() -> void:
		if is_visible_in_tree(): render())
	services.coin_store.changed.connect(func()->void:
		if is_visible_in_tree() and _coin_store: render())
	services.cosmetic_shop.changed.connect(func()->void:
		if is_visible_in_tree(): render())
	services.ability_refills.changed.connect(func()->void:
		if is_visible_in_tree() and _coin_store: render())
	services.session.changed.connect(_close_checkout)
	visibility_changed.connect(func()->void:
		if not is_visible_in_tree(): _close_checkout())


func show_screen(params: Dictionary={}) -> void:
	_store_category=str(params.get("category","coins"))
	super.show_screen(params)
	_refresh_store.call_deferred()


func render() -> void:
	PlayerUI.clear(body)
	if str(parameters.get("tab",""))=="coins": _coin_store=true
	heading.text=tr("Comprar moedas" if _coin_store else "Minha carteira")
	banner.show_state(services.wallet.state)
	if _coin_store:
		_render_coin_store()
		return
	var row := PlayerUI.split(body)
	for currency: String in ["coins", "deck_credits"]:
		var card := PlayerUI.card(row)
		var caption := PlayerUI.row(card)
		var icon := TextureRect.new()
		icon.texture=load("res://assets/icons/vector/icon_coin.svg" if currency=="coins" else "res://assets/icons/vector/icon_deck_credit.svg") as Texture2D
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size=Vector2(40,40)
		caption.add_child(icon)
		caption.add_child(PlayerUI.label("Moedas" if currency == "coins" else "Cartas de criação",20,PlayerUI.MUTED))
		card.add_child(PlayerUI.label(DevicePreferences.number(services.wallet.balance(currency) if currency=="coins" else services.cosmetic_shop.deck_credits(), services.preferences.values.locale), 42))
	body.add_child(PlayerUI.label("Cada carta de criação permite criar um deck.",20,PlayerUI.MUTED))
	body.add_child(PlayerUI.button("Atualizar saldo", func() -> void: _refresh_store()))
	var buy := PlayerUI.button("COMPRAR MOEDAS",func()->void:
		_coin_store=true
		render()
		_refresh_store())
	buy.name="BuyCoins"
	PlayerUI.style_button(buy,true)
	body.add_child(buy)
	if not services.session.authenticated():
		account_button(body)
		return
	var history := PlayerUI.card(body)
	history.add_child(PlayerUI.label("Histórico de transações", 28, PlayerUI.GOLD))
	if services.wallet.state != "success":
		history.add_child(PlayerUI.label("O saldo confirmado estará disponível ao reconectar."))
		return
	if services.wallet.transactions.is_empty():
		history.add_child(PlayerUI.label("Nenhuma transação registrada."))
	for item: Dictionary in services.wallet.transactions:
		var reason := tr("Compra de emote") if str(item.reason).begins_with("emote:") else (tr("Compra de moedas") if str(item.reason).begins_with("coin_topup:") else str(item.reason))
		history.add_child(PlayerUI.label("%s · %s %s · %s" % [item.created_at,
			DevicePreferences.number(item.amount, services.preferences.values.locale),
			tr("moedas" if item.currency == "coins" else "gemas"), reason]))
	if services.wallet.next_cursor != null:
		history.add_child(PlayerUI.button("Carregar mais", func() -> void: status(await services.wallet.load_more())))


func _render_coin_store() -> void:
	heading.text=tr("Moedas e cartas")
	body.add_theme_constant_override("separation",6)
	var top := PlayerUI.row(body)
	var balances := PlayerUI.row(top)
	var balance := PlayerUI.label("%s moedas" % DevicePreferences.number(services.wallet.balance("coins"),services.preferences.values.locale),28,PlayerUI.GOLD)
	balance.name="CoinStoreBalance"
	balances.add_child(balance)
	var credits := PlayerUI.label("Cartas: "+DevicePreferences.number(services.cosmetic_shop.deck_credits(),services.preferences.values.locale),20,PlayerUI.MUTED)
	credits.name="DeckCreditBalance"
	var cards := PlayerUI.row(balances)
	var card_symbol := TextureRect.new()
	card_symbol.texture=load("res://assets/icons/vector/icon_deck_credit.svg") as Texture2D
	card_symbol.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	card_symbol.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_symbol.custom_minimum_size=Vector2(36,36)
	cards.add_child(card_symbol)
	cards.add_child(credits)
	var refresh := PlayerUI.button("Atualizar",_refresh_store)
	refresh.name="RefreshCoinPayments"
	refresh.disabled=_refreshing
	top.add_child(refresh)
	if not services.session.authenticated():
		account_button(body)
		return
	var store := services.coin_store
	var categories := PlayerUI.row(body)
	for id: String in ["coins","deck_credits","refills"]:
		var tab := PlayerUI.button({"coins":"MOEDAS","deck_credits":"CARTAS DE CRIAÇÃO","refills":"RECARGAS"}[id],func()->void:
			_store_category=id
			render())
		tab.name="StoreCategory_"+id
		PlayerUI.style_button(tab,_store_category==id)
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		categories.add_child(tab)
	if _store_category=="refills":
		_render_refills()
		return
	var packages: Array=store.data.get("packages",[]).filter(func(p: Dictionary)->bool:return p.get("reward_kind","coins")==_store_category)
	if not store.data.get("enabled",false):
		var notice := PlayerUI.label("Em breve · preços provisórios",20,PlayerUI.MUTED)
		notice.name="CoinSalesNotice"
		body.add_child(notice)
	elif not store.data.get("live_mode",false):
		body.add_child(PlayerUI.label("Modo de teste · sem cobrança ou crédito de moedas reais.",20,PlayerUI.GOLD))
	var row := PlayerUI.row(body)
	for pack: Dictionary in packages:
		var unavailable: bool=not store.data.get("enabled",false) or not pack.get("available",true)
		var buy := PlayerUI.shop_package(row,pack,_brl(int(pack.price_brl_cents)),unavailable,_prepare_checkout.bind(pack))
		buy.name="CoinPack_"+str(pack.id)
	if packages.is_empty():
		var pending := PlayerUI.label("Os pacotes de moedas estarão disponíveis em breve.",24,PlayerUI.MUTED)
		pending.name="CoinPackagesPending"
		body.add_child(pending)
	if _store_category=="deck_credits" and not packages.is_empty():
		var details := PlayerUI.column(row)
		details.size_flags_stretch_ratio=2.0
		details.add_child(PlayerUI.label("Dê vida ao seu deck",30,PlayerUI.TEXT))
		details.add_child(PlayerUI.label("Cada carta permite criar um deck na sua conta.",22,PlayerUI.MUTED))
		details.add_child(PlayerUI.label("Editar e reenviar o mesmo deck não gasta outra carta.",20,PlayerUI.MUTED))
		if not services.cosmetic_shop.data.get("deck_credits_required",false):
			details.add_child(PlayerUI.label("A criação de decks continua gratuita.",22,PlayerUI.GOLD))
	if store.state in ["error","offline"]:
		body.add_child(PlayerUI.label("Não foi possível atualizar. Tente novamente.",20,PlayerUI.MUTED))
	var orders: Array=store.data.get("orders",[])
	if not orders.is_empty():
		body.add_child(PlayerUI.label("Seus pagamentos",26))
		for order: Dictionary in orders:
			var item := PlayerUI.card(body)
			item.add_child(PlayerUI.label("%s %s · %s" % [order.coins,"carta(s) de criação" if order.get("reward_kind")=="deck_credits" else "moedas",CoinStoreService.order_message(order.status)],22))
			item.add_child(PlayerUI.label("Pedido %s · %s" % [str(order.id).left(8),str(order.created_at).left(16).replace("T"," ")],20,PlayerUI.MUTED))


func _render_refills() -> void:
	var service := services.ability_refills
	var row := PlayerUI.row(body)
	var art := TextureRect.new()
	art.texture=load("res://assets/icons/vector/icon_refill.svg") as Texture2D
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size=Vector2(144,144)
	row.add_child(art)
	var info := PlayerUI.column(row)
	info.add_child(PlayerUI.label("Recarga completa",30,PlayerUI.TEXT))
	info.add_child(PlayerUI.label("Completa uma habilidade escolhida até 3/3.",22,PlayerUI.GOLD))
	info.add_child(PlayerUI.label("Use durante a fase: Pausa → Configurações → Recargas compradas.",20,PlayerUI.MUTED))
	info.add_child(PlayerUI.label("Se a habilidade estiver cheia, nenhuma recarga é gasta.",20,PlayerUI.MUTED))
	var n: Variant=service.count()
	body.add_child(PlayerUI.label("Recargas guardadas: "+("—" if n==null else str(n)),24,PlayerUI.TEXT))
	var price := str(service.data.get("price_coins",""))
	var buy := PlayerUI.button((price+" moedas · COMPRAR") if service.data.get("available",false) else (price+" moedas · EM BREVE" if not price.is_empty() else "INDISPONÍVEL"),_prepare_refill_purchase)
	buy.name="BuyAbilityRefill"
	buy.disabled=not service.data.get("available",false) or service.busy
	PlayerUI.style_button(buy,true)
	body.add_child(buy)


func _prepare_refill_purchase() -> void:
	var service := services.ability_refills
	if not service.data.get("available",false) or is_instance_valid(_checkout_dialog): return
	var price := str(service.data.price_coins).to_int()
	_checkout_dialog=Control.new();_checkout_dialog.name="AbilityRefillPurchase"
	var panel := PlayerUI.deck_modal(self,_checkout_dialog)
	PlayerUI.shop_confirmation(panel,"Comprar recarga","1 recarga completa · %d moedas" % price,load("res://assets/icons/vector/icon_refill.svg") as Texture2D)
	var feedback := PlayerUI.label("A recarga fica guardada até você escolher uma habilidade no menu de pausa.",20,PlayerUI.MUTED)
	panel.add_child(feedback)
	var actions := PlayerUI.row(panel)
	var confirm := PlayerUI.button("CONFIRMAR COMPRA",func()->void:pass)
	confirm.name="ConfirmAbilityRefillPurchase"
	PlayerUI.style_button(confirm,true)
	confirm.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var dialog := _checkout_dialog
	confirm.pressed.connect(func()->void:
		confirm.disabled=true
		var result := await service.buy(price)
		if not is_instance_valid(dialog) or dialog!=_checkout_dialog: return
		feedback.text="Recarga guardada na sua conta." if result.ok else AbilityRefillService.message(result.code)
		if result.ok: await services.wallet.refresh()
		else: confirm.disabled=false)
	actions.add_child(confirm)
	var cancel := PlayerUI.button("Voltar",_close_checkout);cancel.name="CloseAbilityRefillPurchase"
	actions.add_child(cancel);cancel.grab_focus.call_deferred()


func _refresh_store() -> void:
	if _refreshing or not services.session.authenticated(): return
	_refreshing=true
	await services.coin_store.refresh()
	await services.cosmetic_shop.refresh()
	await services.ability_refills.refresh()
	await services.wallet.refresh()
	_refreshing=false
	if is_visible_in_tree(): render()


func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready() and is_visible_in_tree() and _coin_store:
		_refresh_store.call_deferred()


func _prepare_checkout(pack: Dictionary) -> void:
	if not services.coin_store.data.get("enabled",false) or not pack.get("available",true): return
	if is_instance_valid(_checkout_dialog): return
	_checkout_dialog=Control.new()
	_checkout_dialog.name="CoinCheckoutPanel"
	var panel := PlayerUI.deck_modal(self,_checkout_dialog)
	var credit: bool=pack.get("reward_kind")=="deck_credits"
	var art := load("res://assets/ui/store/deck_credit.png" if credit else "res://assets/ui/store/coin_treasure.png") as Texture2D
	PlayerUI.shop_confirmation(panel,"Comprar carta de criação" if credit else "Comprar moedas",
		"%s %s · %s" % [pack.coins,"carta(s) de criação" if credit else "moedas",_brl(int(pack.price_brl_cents))],art)
	var feedback := PlayerUI.label("Preparando pagamento seguro…",22,PlayerUI.MUTED)
	feedback.name="CoinCheckoutFeedback"
	panel.add_child(feedback)
	var open := PlayerUI.button("CONTINUAR NA STRIPE",func()->void:pass)
	open.name="OpenStripeCheckout"
	open.disabled=true
	PlayerUI.editor_control(open,true)
	var actions := PlayerUI.row(panel)
	open.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions.add_child(open)
	var close := PlayerUI.button("Voltar",_close_checkout)
	close.name="CloseCoinCheckout"
	PlayerUI.editor_control(close)
	actions.add_child(close)
	close.grab_focus.call_deferred()
	var dialog := _checkout_dialog
	var result := await services.coin_store.create_checkout(pack)
	if not is_instance_valid(dialog) or dialog!=_checkout_dialog: return
	if not result.ok:
		feedback.text=CoinStoreService.message(result.code)
		return
	var url := str(result.data.url)
	feedback.text="Pague na Stripe. Depois, volte ao jogo e atualize o saldo."
	open.disabled=false
	open.pressed.connect(func()->void:
		if not CoinStoreService.safe_checkout(url): return
		# The second, direct gesture prevents Safari/PWA popup blocking after HTTP.
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.open("+JSON.stringify(url)+", '_blank', 'noopener')")
			# noopener may return null even when a new tab opens. Never infer payment.
			feedback.text="Confira a aba da Stripe. Volte ao jogo após pagar."
		else:
			OS.shell_open(url)
			feedback.text="Confira a janela da Stripe. Volte ao jogo após pagar.")
	open.grab_focus()


func _close_checkout() -> void:
	if is_instance_valid(_checkout_dialog):
		_checkout_dialog.hide()
		_checkout_dialog.queue_free()
	_checkout_dialog=null


static func _brl(cents: int) -> String:
	return "R$ %d,%02d" % [cents/100,cents%100]


func handle_back() -> bool:
	if is_instance_valid(_checkout_dialog):
		_close_checkout()
		return true
	if not _coin_store: return false
	var direct := str(parameters.get("tab",""))=="coins"
	_coin_store=false
	parameters.erase("tab")
	if direct: return false
	render()
	return true
