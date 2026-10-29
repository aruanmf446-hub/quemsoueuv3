extends PlayerScreen


func _ready() -> void:
	super._ready()
	heading.text = tr("Minha carteira")
	ModernUI.style_header(self)
	body.add_theme_constant_override("separation", ModernUI.fs(18))
	services.wallet.changed.connect(func() -> void:
		if is_visible_in_tree(): render())
	ModernUI.follow_resize(self)


func render() -> void:
	PlayerUI.clear(body)
	ModernUI.update_scale(self)
	banner.show_state(services.wallet.state)
	var locale: String = services.preferences.values.locale
	# Saldos em destaque: os dois valores são o que importa nesta tela.
	var balances := _layout()
	for currency: String in ["coins", "gems"]:
		var caption := "Moedas" if currency == "coins" else "Gemas"
		ModernUI.stat(balances, caption, DevicePreferences.number(services.wallet.balance(currency), locale), 52)
	var refresh := ModernUI.panel(body, 18)
	var actions := PlayerUI.row(refresh)
	actions.add_child(ModernUI.muted("Saldo confirmado pelo servidor. Atualize depois de uma compra ou recompensa."))
	actions.add_child(ModernUI.button("Atualizar saldo", func() -> void: services.wallet.refresh()))
	if not services.session.authenticated():
		var guest := ModernUI.panel(body, 22)
		guest.add_child(ModernUI.eyebrow("Histórico"))
		guest.add_child(ModernUI.title("Entre para ver suas transações", 26))
		guest.add_child(ModernUI.button("Entrar na conta", func() -> void: navigate_requested.emit("account", {}), true))
		return
	var history := ModernUI.panel(body, 22)
	history.add_child(ModernUI.eyebrow("Histórico de transações"))
	if services.wallet.state != "success":
		history.add_child(ModernUI.muted("O saldo confirmado estará disponível ao reconectar."))
		return
	if services.wallet.transactions.is_empty():
		history.add_child(ModernUI.muted("Nenhuma transação registrada."))
	for item: Dictionary in services.wallet.transactions:
		var line := PlayerUI.row(history)
		line.add_child(ModernUI.muted(str(item.created_at), 16))
		line.add_child(PlayerUI.label("%s %s" % [DevicePreferences.number(item.amount, locale), tr("moedas" if item.currency == "coins" else "gemas")], ModernUI.fs(18), ModernUI.TEXT))
		line.add_child(ModernUI.muted(str(item.reason), 16))
	if services.wallet.next_cursor != null:
		history.add_child(ModernUI.button("Carregar mais", func() -> void: status(await services.wallet.load_more())))


## Linha horizontal em telas largas e coluna em telas estreitas.
func _layout() -> BoxContainer:
	var layout: BoxContainer = VBoxContainer.new() if ModernUI.compact() else HBoxContainer.new()
	layout.add_theme_constant_override("separation", ModernUI.fs(16))
	body.add_child(layout)
	return layout
