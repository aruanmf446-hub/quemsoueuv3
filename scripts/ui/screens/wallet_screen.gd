extends PlayerScreen
var _coin_store := false


func _ready() -> void:
	super._ready()
	heading.text = tr("Minha carteira")
	services.wallet.changed.connect(func() -> void:
		if is_visible_in_tree(): render())


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
		render())
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
		var reason := tr("Compra de emote") if str(item.reason).begins_with("emote:") else str(item.reason)
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
	if not services.session.authenticated(): account_button(body)
	var empty := PlayerUI.card(body)
	empty.add_child(PlayerUI.label("Pacotes de moedas",26,PlayerUI.TEXT))
	var notice := PlayerUI.label("Os pacotes de moedas estarão disponíveis em breve.",22,PlayerUI.MUTED)
	notice.name="CoinPackagesPending"
	empty.add_child(notice)
	body.add_child(PlayerUI.button("Atualizar saldo",func()->void:services.wallet.refresh()))


func handle_back() -> bool:
	if not _coin_store: return false
	var direct := str(parameters.get("tab",""))=="coins"
	_coin_store=false
	parameters.erase("tab")
	if direct: return false
	render()
	return true
