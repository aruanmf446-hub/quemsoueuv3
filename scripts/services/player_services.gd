class_name PlayerServices
extends Node

## Composição única para menu, lobby e telas. Não cria contas nem saldos fictícios.
static var current: PlayerServices
## Conexão "game" (a atual): login, perfis e serviços existentes.
var client: SupabaseClient
## Conexões preparadas, ainda sem projeto nem uso: sem sessão e sem integração com a game.
var chat_client: SupabaseClient
var catalog_client: SupabaseClient
var session: SessionService
var preferences: DevicePreferences
var profile: ProfileService
var progression: ProgressionService
var inventory: InventoryService
var wallet: WalletService
var friends: FriendsService
var presence: FriendPresence
var duel: DuelService
## Catálogo público (conexão catalog, sem sessão); o local continua como fallback.
var catalog: CatalogService
## CHAT preparado e desativado até a identidade GAME→CHAT ser verificada no servidor.
var chat: ChatService


func _enter_tree() -> void:
	current = self


func _ready() -> void:
	preferences = DevicePreferences.new()
	add_child(preferences)
	client = SupabaseClient.new()
	add_child(client)
	chat_client = SupabaseClient.new()
	chat_client.connection = "chat"
	add_child(chat_client)
	catalog_client = SupabaseClient.new()
	catalog_client.connection = "catalog"
	add_child(catalog_client)
	catalog = CatalogService.new()
	catalog.client = catalog_client
	add_child(catalog)
	chat = ChatService.new()
	chat.client = chat_client
	add_child(chat)
	if chat_enabled():
		var gateway := ChatGateway.new()
		gateway.chat_client = chat_client
		gateway.game_client = client
		chat.add_child(gateway)
		chat.transport = gateway
	# Testes headless (--script) chamam refresh() quando precisam; o jogo lê ao iniciar.
	if not OS.get_cmdline_args().has("--script"): catalog.refresh.call_deferred()
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
	duel = DuelService.new()
	duel.client = client
	duel.session = session
	duel.local_server = LocalDuelServer.new()
	duel.local_server.skin_provider = inventory.equipped_id
	duel.local_server.nickname_provider = func() -> String:
		return str(profile.data.get("nickname", "")) if session.authenticated() else ""
	duel.add_child(duel.local_server)
	add_child(duel)
	session.changed.connect(_session_changed)
	var poller := Timer.new()
	poller.wait_time = 30.0
	poller.timeout.connect(_poll_connected)
	add_child(poller)
	poller.start()
	_session_changed()


## CHAT real só depois da validação: QSE_CHAT_ENABLED=1 ou [chat] enabled=true no backend.cfg.
static func chat_enabled() -> bool:
	if OS.get_environment("QSE_CHAT_ENABLED") == "1": return true
	var config := ConfigFile.new()
	return config.load("user://backend.cfg") == OK and bool(config.get_value("chat", "enabled", false))


func _exit_tree() -> void:
	if current == self:
		current = null


func _session_changed() -> void:
	presence.stop()
	profile.clear()
	progression.clear()
	wallet.clear()
	friends.clear()
	chat.clear()
	chat.me_id = str(session.user.get("id", "")) if session.authenticated() else ""
	# A partida local não depende da conta: entrar ou sair dela não a interrompe.
	if not duel.is_local(): duel.clear()
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


## Idade máxima dos dados antes de o poller buscar de novo (segundos). Ações do jogador
## (comprar, equipar, amizade) e os botões "Atualizar" continuam buscando na hora.
const MAX_AGE := {"friends": 90.0, "wallet": 300.0, "progression": 300.0}
## Sem foco (app em segundo plano/minimizado) o poller não consulta nada.
var _focused := true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		_poll_connected()


func _poll_connected() -> void:
	if not session.authenticated() or not _focused:
		return
	friends.refresh_if_stale(MAX_AGE.friends)
	wallet.refresh_if_stale(MAX_AGE.wallet)
	progression.refresh_if_stale(MAX_AGE.progression)


func _equipment_changed() -> void:
	var selected := inventory.equipped_id()
	if session.authenticated() and not selected.is_empty() and profile.state == "success" and profile.data.get("equipped_character_id") != selected:
		profile.refresh()
