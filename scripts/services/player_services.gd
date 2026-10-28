class_name PlayerServices
extends Node

## Composição única para menu, lobby e telas. Não cria contas nem saldos fictícios.
static var current: PlayerServices
var client: SupabaseClient
var session: SessionService
var preferences: DevicePreferences
var profile: ProfileService
var progression: ProgressionService
var inventory: InventoryService
var wallet: WalletService
var friends: FriendsService
var presence: FriendPresence


func _enter_tree() -> void:
	current = self


func _ready() -> void:
	preferences = DevicePreferences.new()
	add_child(preferences)
	client = SupabaseClient.new()
	add_child(client)
	session = SessionService.new()
	session.client = client
	add_child(session)
	profile = ProfileService.new()
	profile.client = client
	profile.session = session
	add_child(profile)
	progression = ProgressionService.new()
	progression.client = client
	progression.session = session
	add_child(progression)
	wallet = WalletService.new()
	wallet.client = client
	add_child(wallet)
	friends = FriendsService.new()
	friends.client = client
	add_child(friends)
	inventory = InventoryService.new()
	inventory.progression = progression
	inventory.session = session
	add_child(inventory)
	inventory.initialize()
	inventory.changed.connect(_equipment_changed)
	presence = FriendPresence.new()
	presence.client = client
	presence.friends = friends
	presence.session = session
	add_child(presence)
	session.changed.connect(_session_changed)
	var poller := Timer.new()
	poller.wait_time = 30.0
	poller.timeout.connect(_poll_connected)
	add_child(poller)
	poller.start()
	_session_changed()


func _exit_tree() -> void:
	if current == self:
		current = null


func _session_changed() -> void:
	presence.stop()
	profile.clear()
	progression.clear()
	wallet.clear()
	friends.clear()
	inventory.changed.emit()
	if session.authenticated():
		refresh_all()


func refresh_all() -> void:
	# Cada resposta HTTP verifica a geração da sessão para impedir vazamento entre contas.
	var generation := client.generation
	await profile.refresh()
	if generation != client.generation: return
	await progression.refresh()
	if generation != client.generation: return
	await wallet.refresh()
	if generation != client.generation: return
	await friends.refresh()
	if generation != client.generation: return
	if session.authenticated():
		presence.start()


func _poll_connected() -> void:
	if not session.authenticated():
		return
	if wallet.state != "loading":
		wallet.refresh()
	if friends.state != "loading":
		friends.refresh()
	if progression.state != "loading":
		progression.refresh()


func _equipment_changed() -> void:
	var selected := inventory.equipped_id()
	if session.authenticated() and not selected.is_empty() and profile.state == "success" and profile.data.get("equipped_character_id") != selected:
		profile.refresh()
