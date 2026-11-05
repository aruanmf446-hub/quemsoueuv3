extends Control
## Tela nativa de envio e revisão. Autorização para aprovar é sempre conferida no servidor.
const Service = preload("res://scripts/decks/repository_service.gd")
var service: RefCounted
var _body: VBoxContainer
var _notice: Label
var _busy := false
var _admin := false

func setup(value: RefCounted) -> void: service=value
func _ready() -> void:
	name="RepositoryDeckReview"
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
	header.add_child(PlayerUI.label("Envios e revisão de decks",28,PlayerUI.GOLD))
	_notice=PlayerUI.label("Carregando…",18,PlayerUI.MUTED)
	_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_notice)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_body=PlayerUI.column(scroll)
	_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_load()
func _show_message(result: Dictionary) -> void:
	_notice.text="" if result.ok else Service.message(str(result.get("code","network")))
func _load() -> void:
	if _busy: return
	_busy=true
	PlayerUI.clear(_body)
	var who: Dictionary=await service.request("/me")
	if not is_inside_tree(): return
	if not who.ok:
		_show_message(who)
		_busy=false
		return
	_admin=bool(who.data.get("is_moderator",false))
	var mine := PlayerUI.row(_body)
	mine.add_child(PlayerUI.button("Meus envios",func() -> void: _list(false)))
	if _admin: mine.add_child(PlayerUI.button("Fila para aprovar",func() -> void: _list(true)))
	_busy=false
	_list(_admin)
func _list(admin: bool) -> void:
	if _busy: return
	_busy=true
	var result: Dictionary=await service.request("/review" if admin else "/submissions")
	if not is_inside_tree(): return
	_busy=false
	_show_message(result)
	if not result.ok: return
	for child in _body.get_children().slice(1):
		_body.remove_child(child)
		child.queue_free()
	var items: Array=result.data.get("items",[])
	_notice.text="Nenhum envio para mostrar." if items.is_empty() else ("Aprovação manual · criação gratuita" if admin else "Só os aprovados entram na biblioteca após a atualização do jogo.")
	for row: Dictionary in items:
		var status: String = {"pending_review":"Em revisão","publishing":"Publicando · concluir aprovação","approved":"Aprovado","rejected":"Reprovado"}.get(str(row.get("status","")),"Em revisão")
		var button := PlayerUI.button("%s · %d cartas · %s" % [str(row.get("name","Deck")),int(row.get("count",0)),status],_open.bind(str(row.id)))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text=true
		_body.add_child(button)
func _open(id: String) -> void:
	if _busy: return
	_busy=true
	var result: Dictionary=await service.request("/submissions/"+id)
	if not is_inside_tree(): return
	_busy=false
	_show_message(result)
	if not result.ok: return
	var record: Dictionary=result.data.get("submission",{})
	for child in _body.get_children().slice(1):
		_body.remove_child(child)
		child.queue_free()
	_body.add_child(PlayerUI.label(str(record.payload.name),28,PlayerUI.GOLD))
	_body.add_child(PlayerUI.label("Enviado por "+str(record.author.nickname),18))
	var description := PlayerUI.label(str(record.payload.get("description","")),18,PlayerUI.MUTED)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(description)
	var valid_images := true
	if record.payload.get("cover") is Dictionary:
		var cover_image := Image.new()
		if cover_image.load_webp_from_buffer(Marshalls.base64_to_raw(str(record.payload.cover.get("image",""))))!=OK:
			valid_images=false
		else:
			var cover := TextureRect.new()
			cover.name="SubmissionCover"
			cover.custom_minimum_size=Vector2(256,160)
			cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cover.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
			cover.texture=ImageTexture.create_from_image(cover_image)
			_body.add_child(cover)
	var grid := GridContainer.new()
	grid.columns=clampi(floori(size.x/220),2,6)
	_body.add_child(grid)
	for card: Dictionary in record.payload.cards:
		var item := PlayerUI.column(grid)
		var image := Image.new()
		var error := image.load_webp_from_buffer(Marshalls.base64_to_raw(str(card.get("image",""))))
		var preview := TextureRect.new()
		preview.custom_minimum_size=Vector2(160,224)
		preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if error!=OK: valid_images=false
		if error==OK:
			var framed := CardFramer.preview(image,CardFramer.LIBRARY_ASPECT,card.get("crops",{}).get("library",{}),240)
			preview.texture=ImageTexture.create_from_image(framed)
		item.add_child(preview)
		var title := PlayerUI.label(str(card.name),18)
		title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		item.add_child(title)
	var note := LineEdit.new()
	note.name="RepositoryReviewReason"
	note.max_length=280
	note.placeholder_text="Motivo da reprovação (mínimo 3 caracteres)"
	note.custom_minimum_size.y=52
	PlayerUI.style_field(note)
	_body.add_child(note)
	WebTextBridge.attach(note)
	var controls := PlayerUI.row(_body)
	if _admin and record.status in ["pending_review","publishing"]:
		var approve := PlayerUI.button("Aprovar e publicar" if record.status=="pending_review" else "Concluir publicação",_decide.bind(id,true,note))
		approve.name="ApproveRepositoryDeck"
		approve.disabled=not valid_images
		PlayerUI.style_button(approve,true)
		controls.add_child(approve)
		if record.status=="pending_review":
			var reject := PlayerUI.button("Reprovar",_decide.bind(id,false,note))
			reject.name="RejectRepositoryDeck"
			controls.add_child(reject)
	else:
		note.editable=false
		note.text=str(record.get("review_note",""))
func _decide(id: String,approved: bool,note: LineEdit) -> void:
	if _busy: return
	if not approved and note.text.strip_edges().length()<3:
		_notice.text="Informe o motivo da reprovação."
		return
	_busy=true
	_notice.text="Publicando…" if approved else "Registrando decisão…"
	var result: Dictionary=await service.approve(id) if approved else await service.request("/submissions/"+id+"/reject",HTTPClient.METHOD_POST,{"reason":note.text.strip_edges()})
	if not is_inside_tree(): return
	_busy=false
	_show_message(result)
	if result.ok:
		_list(true)
		_notice.text="Aprovado. Entrará na biblioteca após a publicação e atualização do jogo." if approved else "Deck reprovado; o autor verá o motivo."

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
			if node is LineEdit and not node.editable: continue
			controls.append(node)
		if not controls.is_empty():
			var index := controls.find(get_viewport().gui_get_focus_owner())
			controls[posmod(index+(-1 if event.is_action_pressed("ui_focus_prev") else 1),controls.size())].grab_focus()
		get_viewport().set_input_as_handled()
