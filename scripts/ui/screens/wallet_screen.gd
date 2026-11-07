extends PlayerScreen
var _coin_store := false
var _checkout_dialog: Control
var _refreshing := false


func _ready() -> void:
	super._ready()
	heading.text = tr("Minha carteira")
	services.wallet.changed.connect(func() -> void:
		if is_visible_in_tree(): render())
	services.coin_store.changed.connect(func()->void:
		if is_visible_in_tree() and _coin_store: render())
	services.session.changed.connect(_close_checkout)
	visibility_changed.connect(func()->void:
		if not is_visible_in_tree(): _close_checkout())


func show_screen(params: Dictionary={}) -> void:
	super.show_screen(params)
	if _coin_store: _refresh_store.call_deferred()


func render() -> void:
	PlayerUI.clear(body)
	if str(parameters.get("tab",""))=="coins": _coin_store=true
	heading.text=tr("Comprar moedas" if _coin_store else "Minha carteira")
	banner.show_state(services.wallet.state)
	if _coin_store:
		_render_coin_store()
		return
	var row := PlayerUI.split(body)
	for currency: String in ["coins", "gems"]:
		var card := PlayerUI.card(row)
		card.add_child(PlayerUI.label("Moedas" if currency == "coins" else "Gemas", 14, PlayerUI.MUTED))
		card.add_child(PlayerUI.label(DevicePreferences.number(services.wallet.balance(currency), services.preferences.values.locale), 42))
	body.add_child(PlayerUI.button("Atualizar saldo", func() -> void: services.wallet.refresh()))
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
	var summary := PlayerUI.card(body)
	summary.add_child(PlayerUI.label("Moedas para a sua conta",28,PlayerUI.TEXT))
	summary.add_child(PlayerUI.label("Compre pacotes de moedas e use o saldo em skins, emotes, mochilas e outros itens.",22,PlayerUI.MUTED))
	summary.add_child(PlayerUI.label("Os itens da loja têm preço em moedas.",20,PlayerUI.GOLD))
	var balance := PlayerUI.label("Saldo: %s moedas" % DevicePreferences.number(services.wallet.balance("coins"),services.preferences.values.locale),30,PlayerUI.TEXT)
	balance.name="CoinStoreBalance"
	body.add_child(balance)
	if not services.session.authenticated():
		account_button(body)
		return
	var store := services.coin_store
	var packages: Array=store.data.get("packages",[])
	if not store.data.get("enabled",false):
		body.add_child(PlayerUI.label("Vendas desabilitadas · valores provisórios. Nenhuma cobrança disponível.",22,PlayerUI.GOLD))
	if packages.is_empty():
		var empty := PlayerUI.card(body)
		empty.add_child(PlayerUI.label("Pacotes de moedas",26,PlayerUI.TEXT))
		var notice := PlayerUI.label("Os pacotes de moedas estarão disponíveis em breve.",22,PlayerUI.MUTED)
		notice.name="CoinPackagesPending"
		empty.add_child(notice)
	else:
		if store.data.get("enabled",false) and not store.data.live_mode:
			body.add_child(PlayerUI.label("Modo de teste · sem cobrança ou crédito de moedas reais.",22,PlayerUI.GOLD))
		var row := PlayerUI.flow(body)
		for pack: Dictionary in packages:
			var card := PlayerUI.card(row)
			card.custom_minimum_size.x=300
			card.add_child(PlayerUI.label(pack.name,24))
			card.add_child(PlayerUI.label("%s %s" % [pack.coins,"crédito(s) de deck" if pack.get("reward_kind")=="deck_credits" else "moedas"],32,PlayerUI.GOLD))
			var buy := PlayerUI.button("%s · COMPRAR" % _brl(int(pack.price_brl_cents)),_prepare_checkout.bind(pack))
			buy.name="CoinPack_"+str(pack.id)
			buy.disabled=not store.data.get("enabled",false) or not pack.get("available",true)
			if buy.disabled: buy.text="%s · EM BREVE" % _brl(int(pack.price_brl_cents))
			PlayerUI.editor_control(buy,true)
			card.add_child(buy)
	if store.state=="error" or store.state=="offline":
		body.add_child(PlayerUI.label("Não foi possível atualizar os pacotes. Tente novamente.",22,PlayerUI.MUTED))
	var credits := PlayerUI.label("Créditos de deck: "+str(services.cosmetic_shop.data.get("deck_credits","—")),26)
	credits.name="DeckCreditBalance"
	body.add_child(credits)
	body.add_child(PlayerUI.label("Um crédito libera um novo deck. Editar, corrigir e reenviar o mesmo deck não usa outro crédito.",20,PlayerUI.MUTED))
	body.add_child(PlayerUI.label("Criação gratuita enquanto o uso de créditos estiver desabilitado.",20,PlayerUI.MUTED))
	var refresh := PlayerUI.button("Atualizar pagamentos e saldo",_refresh_store)
	refresh.name="RefreshCoinPayments"
	refresh.disabled=_refreshing
	body.add_child(refresh)
	var orders: Array=store.data.get("orders",[])
	if not orders.is_empty():
		body.add_child(PlayerUI.label("Seus pagamentos",26))
		for order: Dictionary in orders:
			var item := PlayerUI.card(body)
			item.add_child(PlayerUI.label("%s %s · %s" % [order.coins,"crédito(s) de deck" if order.get("reward_kind")=="deck_credits" else "moedas",CoinStoreService.order_message(order.status)],22))
			item.add_child(PlayerUI.label("Pedido %s · %s" % [str(order.id).left(8),str(order.created_at).left(16).replace("T"," ")],20,PlayerUI.MUTED))


func _refresh_store() -> void:
	if _refreshing or not services.session.authenticated(): return
	_refreshing=true
	await services.coin_store.refresh()
	await services.cosmetic_shop.refresh()
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
	panel.add_child(PlayerUI.label("Comprar moedas",30))
	panel.add_child(PlayerUI.label("%s %s · %s" % [pack.coins,"crédito(s) de deck" if pack.get("reward_kind")=="deck_credits" else "moedas",_brl(int(pack.price_brl_cents))],28,PlayerUI.GOLD))
	var feedback := PlayerUI.label("Preparando pagamento seguro…",22,PlayerUI.MUTED)
	feedback.name="CoinCheckoutFeedback"
	panel.add_child(feedback)
	var open := PlayerUI.button("CONTINUAR NA STRIPE",func()->void:pass)
	open.name="OpenStripeCheckout"
	open.disabled=true
	PlayerUI.editor_control(open,true)
	panel.add_child(open)
	var close := PlayerUI.button("Voltar",_close_checkout)
	close.name="CloseCoinCheckout"
	PlayerUI.editor_control(close)
	panel.add_child(close)
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
