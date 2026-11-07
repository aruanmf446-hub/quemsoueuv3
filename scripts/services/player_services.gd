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
var community_decks: CommunityDecksService
var rewards: OfficialRewardsService
var preferences: DevicePreferences
var profile: ProfileService
var progression: ProgressionService
var story_progress: StoryProgressService
var inventory: InventoryService
var wallet: WalletService
var emote_shop: EmoteShopService
var coin_store: CoinStoreService
var cosmetic_shop: CosmeticShopService
var friends: FriendsService
var presence: FriendPresence
var duel: DuelService
## Catálogo público (conexão catalog, sem sessão); o local continua como fallback.
var catalog: CatalogService
## Atualizações editoriais públicas (novidades e personalização dos decks oficiais).
var editor_content: EditorContentService
## CHAT preparado e desativado até a identidade GAME→CHAT ser verificada no servidor.
var chat: ChatService
## Chat da sala do Duelo (outra instância: não mistura com o chat privado de amigos).
var room_chat: ChatService
## Optional GAME-authorized online voice transport.
var voice: VoiceService


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
	editor_content = EditorContentService.new()
	editor_content.client = client
	add_child(editor_content)
	chat = ChatService.new()
	chat.client = chat_client
	add_child(chat)
	if chat_enabled():
		var gateway := ChatGateway.new()
		gateway.chat_client = chat_client
		gateway.game_client = client
		chat.add_child(gateway)
		chat.transport = gateway
	room_chat = ChatService.new()
	room_chat.client = chat_client
	room_chat.transport = chat.transport
	add_child(room_chat)
	# Testes headless (--script) chamam refresh() quando precisam; o jogo lê ao iniciar.
	if not OS.get_cmdline_args().has("--script"):
		catalog.refresh.call_deferred()
		editor_content.refresh.call_deferred()
	session = SessionService.new()
	session.client = client
	add_child(session)
	rewards = OfficialRewardsService.new()
	rewards.client = client
	rewards.session = session
	add_child(rewards)
	profile = ProfileService.new()
	profile.client = client
	profile.session = session
	add_child(profile)
	progression = ProgressionService.new()
	progression.client = client
	progression.session = session
	add_child(progression)
	story_progress = StoryProgressService.new()
	story_progress.client = client
	story_progress.session = session
	add_child(story_progress)
	wallet = WalletService.new()
	wallet.client = client
	add_child(wallet)
	emote_shop=EmoteShopService.new()
	emote_shop.client=client
	emote_shop.session=session
	add_child(emote_shop)
	cosmetic_shop=CosmeticShopService.new()
	cosmetic_shop.client=client
	cosmetic_shop.session=session
	add_child(cosmetic_shop)
	coin_store=CoinStoreService.new()
	coin_store.client=client
	coin_store.session=session
	add_child(coin_store)
	friends = FriendsService.new()
	friends.client = client
	add_child(friends)
	inventory = InventoryService.new()
	inventory.progression = progression
	inventory.session = session
	add_child(inventory)
	inventory.initialize()
	cosmetic_shop.changed.connect(func()->void: inventory.changed.emit())
	inventory.changed.connect(_equipment_changed)
	presence = FriendPresence.new()
	presence.client = client
	presence.friends = friends
	presence.session = session
	add_child(presence)
	community_decks = CommunityDecksService.new()
	add_child(community_decks)
	duel = DuelService.new()
	duel.client = client
	duel.session = session
	duel.local_server = LocalDuelServer.new()
	duel.local_server.skin_provider = inventory.equipped_id
	duel.local_server.nickname_provider = func() -> String:
		return str(profile.data.nickname) if profile.has_nickname() else ("Defina seu nickname" if session.authenticated() else "Jogador local")
	duel.add_child(duel.local_server)
	add_child(duel)
	voice = VoiceService.new()
	voice.client = client
	voice.session = session
	voice.duel = duel
	add_child(voice)
	session.changed.connect(_session_changed)
	var poller := Timer.new()
	poller.wait_time = 30.0
	poller.timeout.connect(_poll_connected)
	add_child(poller)
	poller.start()
	_session_changed()


## CHAT disponível no jogo. Desligar com QSE_CHAT_ENABLED=0 ou [chat] enabled=false.
## Scripts de teste headless usam o transporte simulado e não abrem conexão real.
static func chat_enabled() -> bool:
	var flag := OS.get_environment("QSE_CHAT_ENABLED")
	if flag == "0": return false
	if flag == "1": return true
	if OS.get_cmdline_args().has("--script"): return false
	var config := ConfigFile.new()
	if config.load("user://backend.cfg") == OK:
		return bool(config.get_value("chat", "enabled", true))
	return true


func _exit_tree() -> void:
	if current == self:
		current = null


func _session_changed() -> void:
	community_decks.clear()
	# Community decks belong to the signed-in account; official local play stays independent.
	if duel.local_server!=null: duel.local_server.community_decks=[]
	duel.decks=[]
	if duel.is_local() and duel.in_room() and (duel.room.room.get("settings",{}).get("deck_ids",[]) as Array).any(func(id:Variant)->bool:return CommunityDecksService.is_ref(str(id))):
		duel.leave()
	rewards.clear()
	presence.stop()
	profile.clear()
	progression.clear()
	story_progress.set_scope()
	wallet.clear()
	emote_shop.clear()
	coin_store.clear()
	cosmetic_shop.clear()
	friends.clear()
	chat.clear()
	chat.me_id = str(session.user.get("id", "")) if session.authenticated() else ""
	room_chat.clear()
	room_chat.me_id = chat.me_id
	# Playlist do menu é pessoal: cada conta (e o visitante) tem a sua neste aparelho.
	var music := get_node_or_null("/root/MenuMusic")
	if music != null and music.has_method("set_owner_scope"):
		music.set_owner_scope(chat.me_id)
	# A partida local não depende da conta: entrar ou sair dela não a interrompe.
	if not duel.is_local(): duel.clear()
	inventory.changed.emit()
	if session.authenticated():
		_last_heartbeat = -INF
		refresh_all()
		_heartbeat()
		rewards.refresh.call_deferred()
		emote_shop.refresh.call_deferred()
		cosmetic_shop.refresh.call_deferred()


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
	_heartbeat()
	wallet.refresh_if_stale(MAX_AGE.wallet)
	progression.refresh_if_stale(MAX_AGE.progression)
	story_progress.sync()


## Presença T22 (qse_presence_heartbeat): no máximo 1 chamada por minuto, só com o jogo
## em foco. O servidor marca "offline" após 90 s sem heartbeat e calcula "in_match".
var _last_heartbeat := -INF
func _heartbeat() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_heartbeat < 55.0: return
	_last_heartbeat = now
	await client.call_rpc("qse_presence_heartbeat")


func _equipment_changed() -> void:
	var selected := inventory.equipped_id()
	if session.authenticated() and not selected.is_empty() and profile.state == "success" and profile.data.get("equipped_character_id") != selected:
		profile.refresh()
