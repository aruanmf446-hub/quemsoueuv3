extends PlayerScreen


func _ready() -> void:
	super._ready()
	heading.text = tr("Minha carteira")
	services.wallet.changed.connect(func() -> void:
		if is_visible_in_tree(): render())


func render() -> void:
	PlayerUI.clear(body)
	banner.show_state(services.wallet.state)
	var row := PlayerUI.row(body)
	for currency: String in ["coins", "gems"]:
		var card := PlayerUI.card(row)
		card.add_child(PlayerUI.label("Moedas" if currency == "coins" else "Gemas", 28, PlayerUI.GOLD))
		card.add_child(PlayerUI.label(DevicePreferences.number(services.wallet.balance(currency), services.preferences.values.locale), 42))
	body.add_child(PlayerUI.button("Atualizar saldo", func() -> void: services.wallet.refresh()))
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
		history.add_child(PlayerUI.label("%s · %s %s · %s" % [item.created_at,
			DevicePreferences.number(item.amount, services.preferences.values.locale),
			tr("moedas" if item.currency == "coins" else "gemas"), item.reason]))
	if services.wallet.next_cursor != null:
		history.add_child(PlayerUI.button("Carregar mais", func() -> void: status(await services.wallet.load_more())))
