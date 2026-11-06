extends Control
## Controles nativos; a permissão e a decisão pertencem ao GAME, nunca ao cliente.
const Service = preload("res://scripts/decks/deck_review_service.gd")
var service: RefCounted
var _body: VBoxContainer
var _notice: Label
var _busy := false

func setup(value: RefCounted) -> void: service=value
func _ready() -> void:
	name="DeckManualReview"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	if PlayerServices.current!=null: PlayerServices.current.session.changed.connect(queue_free)
	PlayerUI.apply_theme(self)
	var bg := ColorRect.new()
	bg.color=PlayerUI.INTERIOR_BG
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	var col := PlayerUI.column(margin)
	var header := PlayerUI.row(col)
	var back := PlayerUI.button("Voltar",func() -> void: queue_free())
	PlayerUI.standard_back(back,"Voltar")
	header.add_child(back)
	back.grab_focus.call_deferred()
	header.add_child(PlayerUI.label("Revisão manual de decks",28,PlayerUI.GOLD))
	_notice=PlayerUI.label("Carregando…",18,PlayerUI.MUTED)
	_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_notice)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_body=PlayerUI.column(scroll)
	_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_load()

func _load() -> void:
	_busy=true
	var result: Dictionary=await service.access()
	if not is_inside_tree(): return
	_busy=false
	if not result.ok:
		_notice.text=Service.message(str(result.code))
		return
	if not result.data.is_moderator:
		_notice.text=Service.message("forbidden")
		return
	_list()

func _list() -> void:
	if _busy: return
	_busy=true
	var result: Dictionary=await service.pending()
	if not is_inside_tree(): return
	_busy=false
	if not result.ok:
		_notice.text=Service.message(str(result.code))
		return
	PlayerUI.clear(_body)
	_body.add_child(PlayerUI.button("Atualizar fila",_list))
	_notice.text="Nenhum deck aguardando revisão." if result.data.items.is_empty() else "Só os aprovados aparecem para outros jogadores."
	for row: Dictionary in result.data.items:
		var action := PlayerUI.button(str(row.name),_open.bind(str(row.id)))
		action.clip_text=true
		action.alignment=HORIZONTAL_ALIGNMENT_LEFT
		_body.add_child(action)

func _preview(path: String,parent: Control,dimensions: Vector2) -> bool:
	var local: String=await service.image(path)
	if not is_inside_tree(): return false
	if local.is_empty(): return false
	var image := Image.load_from_file(local)
	if image==null: return false
	var view := TextureRect.new()
	view.custom_minimum_size=dimensions
	view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	view.texture=ImageTexture.create_from_image(image)
	parent.add_child(view)
	return true

func _open(id: String) -> void:
	if _busy: return
	_busy=true
	_notice.text="Carregando o deck e suas prévias…"
	var result: Dictionary=await service.open_deck(id)
	if not is_inside_tree(): return
	if not result.ok:
		_busy=false
		var code := str(result.code)
		if code in ["invalid_status","deck_not_found"]: await _list()
		_notice.text=Service.message(code)
		return
	PlayerUI.clear(_body)
	_body.add_child(PlayerUI.button("Voltar à fila",_list))
	var deck: Dictionary=result.data.deck
	_body.add_child(PlayerUI.label(str(deck.name),28,PlayerUI.GOLD))
	var nickname: Variant=deck.creator.get("nickname")
	var author := str(nickname).strip_edges() if nickname is String else ""
	var author_label := PlayerUI.label("Enviado por "+(author if not author.is_empty() else "criador sem nickname"),18)
	author_label.name="DeckReviewAuthor"
	_body.add_child(author_label)
	var description := PlayerUI.label(str(deck.get("description","")),18,PlayerUI.MUTED)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(description)
	var valid: bool=result.data.cards.size()>=5
	var cover := str(deck.get("cover_path","")) if deck.get("cover_path")!=null else ""
	if not cover.is_empty(): valid=(await _preview(cover,_body,Vector2(256,160))) and valid
	var grid := GridContainer.new()
	grid.columns=clampi(floori(size.x/240),2,6)
	_body.add_child(grid)
	for card: Dictionary in result.data.cards:
		var item := PlayerUI.column(grid)
		valid=(await _preview(str(card.get("preview_library_path","")),item,Vector2(160,224))) and valid
		valid=(await _preview(str(card.get("preview_duel_path","")),item,Vector2(200,63))) and valid
		var title := PlayerUI.label(str(card.name),18)
		title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		item.add_child(title)
	var reason := LineEdit.new()
	reason.name="DeckReviewReason"
	reason.placeholder_text="Motivo da reprovação (mínimo 3 caracteres)"
	reason.max_length=280
	reason.custom_minimum_size.y=52
	PlayerUI.style_field(reason)
	_body.add_child(reason)
	WebTextBridge.attach(reason)
	var actions := PlayerUI.row(_body)
	var approve := PlayerUI.button("Aprovar",_decide.bind(id,true,reason))
	approve.name="ApproveDeck"
	approve.disabled=not valid or deck.get("status")!="pending_review"
	PlayerUI.style_button(approve,true)
	actions.add_child(approve)
	var reject := PlayerUI.button("Reprovar",_decide.bind(id,false,reason))
	reject.name="RejectDeck"
	reject.disabled=deck.get("status")!="pending_review"
	actions.add_child(reject)
	_busy=false
	_notice.text="Confira capa, nomes e os dois recortes antes de decidir." if valid else Service.message("invalid_image")

func _decide(id: String,approved: bool,reason: LineEdit) -> void:
	if _busy: return
	_busy=true
	var result: Dictionary=await service.decide(id,approved,reason.text)
	if not is_inside_tree(): return
	_busy=false
	if not result.ok:
		var code := str(result.code)
		if code in ["invalid_status","deck_not_found"]: await _list()
		_notice.text=Service.message(code)
		return
	await _list()
	_notice.text="Deck aprovado para a Comunidade." if approved else "Reprovado. O autor verá o motivo em Meus Decks."

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var controls: Array[Control]=[]
		for node: Control in find_children("*","Control",true,false):
			if not node.is_visible_in_tree() or node.focus_mode!=Control.FOCUS_ALL: continue
			if node is BaseButton and node.disabled: continue
			controls.append(node)
		if not controls.is_empty():
			var index := controls.find(get_viewport().gui_get_focus_owner())
			controls[posmod(index+(-1 if event.is_action_pressed("ui_focus_prev") else 1),controls.size())].grab_focus()
		get_viewport().set_input_as_handled()
