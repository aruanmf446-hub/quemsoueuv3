extends PlayerScreen
## Descoberta pública dos decks, favoritos e rascunhos do dono atual (neste aparelho).
## Publicar depende do backend: o fluxo existe até a revisão e avisa quando não há servidor.
const Catalog = preload("res://scripts/decks/deck_library_catalog.gd")
const StylePrompt = preload("res://scripts/decks/deck_style_prompt.gd")
var _publish_busy := false
var _claim_busy := false
var _owned_pulled := false
var _report_dialog: Control
var _report_busy := false
const TABS := ["Descobrir", "Populares", "Recentes", "Favoritos", "Meus Decks"]
var _query := ""
var _tab := "Descobrir"
var _deck: Dictionary = {}
var _index := -1
var _view := "library"
var _catalog: Array[Dictionary] = []
var _search: LineEdit
var _results: VBoxContainer
var _tabs: Array[Button] = []
var _grid: GridContainer
var _reader_image: TextureRect
var _reader_previous: Button
var _reader_next: Button
var _reader_gallery: Button
var _refresh_width := -1.0
var _gallery_scroll := 0
var _draft: Dictionary = {}
var _drafts: DeckDrafts
var _picker: ImagePicker
var _pending_card := -1
var _editor_details_open := false
var _editor_overlay: CardFrameEditor
## Uma busca no servidor por visita à aba (evita repetir a cada redesenho).
var _pulled_decks := false
var _pulled_favorites := false
var _remote_busy := false
## Filtros e ordenação (T23). _demo_entries só é preenchido por testes/capturas.
var _types := {}
var _themes := {}
var _sort := ""
var _featured := 0
## T24: destaques escolhidos (FeaturedPicker) e rotação automática do header.
var _slides: Array[Dictionary] = []
var _rotation: Timer
## Só para testes/capturas: regras de destaque e relógio fixos.
var _demo_rules: Array = []
var _clock := 0.0
var _covers := {}
var _filter_panel: Control
var _demo_entries: Array[Dictionary] = []
## T24: totais de popularidade (deck_ref -> {plays_30d, players_30d, favorites, score}).
## "idle" | "loading" | "ok" | "offline" | "error". Cliente de teste pode substituir _stats_client.
var _stats := {}
var _stats_state := "idle"
var _stats_at := -1000.0
var _stats_client: Object
const STATS_TTL := 300.0
const SURFACE_SHADER := """shader_type canvas_item;
// Textura muito sutil e uma linha orgânica discreta: só estética, sem contraste extra.
uniform float seed = 0.0;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float noise(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y); }
void fragment() {
	float grain = noise(UV * vec2(90.0, 40.0)) * 0.5 + noise(UV * vec2(9.0, 4.0)) * 0.5;
	float curve = 0.62 + 0.18 * sin(UV.x * 3.4 + seed) + 0.06 * sin(UV.x * 9.0 + seed * 2.0);
	float line = smoothstep(0.006, 0.0, abs(UV.y - curve)) * smoothstep(0.0, 0.35, UV.x) * smoothstep(1.0, 0.55, UV.x);
	float tone = mix(-0.012, 0.022, UV.x) + (grain - 0.5) * 0.035;
	COLOR = vec4(vec3(0.85, 0.74, 0.52), clamp(tone, 0.0, 0.04) + line * 0.07);
}"""

func _ready() -> void:
	super._ready()
	_catalog = Catalog.decks()
	if services.editor_content != null: services.editor_content.changed.connect(_editor_content_changed)
	if services.rewards != null: services.rewards.changed.connect(_rewards_updated)
	_search = LineEdit.new()
	_search.name = "DeckSearch"
	_search.placeholder_text = tr("Pesquisar deck ou criador")
	_search.tooltip_text = tr("Pesquisar pelo nome do deck ou do criador")
	_search.custom_minimum_size = Vector2(360, PlayerUI.SMALL_CONTROL_HEIGHT)
	_search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search.add_theme_font_size_override("font_size", PlayerUI.SMALL_CONTROL_FONT)
	PlayerUI.style_field(_search)
	_search.text_changed.connect(func(value: String) -> void:
		_query = value
		_update_results())
	$Margin/Column/Header.add_child(_search)
	resized.connect(_layout_changed)
	_picker = ImagePicker.new()
	_picker.name = "ImagePicker"
	add_child(_picker)
	_picker.picked.connect(_image_picked)
	_picker.failed.connect(func(message: String) -> void: banner.show_state("error", message))
	if services != null: services.session.changed.connect(func() -> void:
		_close_report()
		# Trocar de conta troca também os rascunhos e favoritos visíveis.
		_drafts = null
		_pulled_decks = false
		_owned_pulled=false
		_claim_busy=false
		_pulled_favorites = false
		_remote_error.clear()
		_community_cover_attempts.clear()
		_moderation_checked=false
		_moderation_busy=false
		_moderation_generation+=1
		_moderation_state="idle"
		if is_visible_in_tree() and _view in ["library", "editor", "review", "submissions"]:
			_draft = {}
			_render_library())

func _editor_content_changed() -> void:
	_catalog = Catalog.decks()
	if is_visible_in_tree() and _view == "library" and is_instance_valid(_results):
		_update_results()


func render() -> void:
	_catalog = Catalog.decks()
	if services != null and services.editor_content != null:
		services.editor_content.refresh.call_deferred()
	var requested := str(parameters.get("deck_id", ""))
	if not requested.is_empty():
		var item := Catalog.find_deck(requested)
		if item.is_empty():
			_render_library()
			PlayerUI.clear(_results)
			_empty(_results, "Coleção indisponível", "Este deck não está disponível para consulta.")
			return
		_render_deck(item)
		var card_id := str(parameters.get("card_id", ""))
		if not card_id.is_empty():
			for i in range(item.cards.size()):
				if item.cards[i].id == card_id:
					_render_card(i)
					return
		return
	_render_library()

func _physical_size() -> Vector2:
	return size / PlayerUI.unit(self)

func _compact() -> bool:
	return _physical_size().y < 600

func _adapt_scale() -> void:
	super._adapt_scale()
	_layout_changed()

func _layout_changed() -> void:
	if not is_instance_valid(_search): return
	var width := _physical_size().x
	_search.custom_minimum_size.x = 360 if width >= 1100 else (240 if width >= 800 else 190)
	# iPhone: a busca divide o cabeçalho com o título; nunca passa da borda.
	if UIScale.is_iphone(): _search.custom_minimum_size.x = 230
	_search.size_flags_horizontal = Control.SIZE_SHRINK_END
	heading.add_theme_font_size_override("font_size", 24 if width < 900 else 40)
	if UIScale.is_iphone():
		# iPhone: título cede espaço (corta com reticências) para a busca caber na tela.
		heading.add_theme_font_size_override("font_size", 30)
		heading.clip_text = true
		heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.custom_minimum_size = Vector2(0, 44)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$Margin/Column/Header.add_theme_constant_override("separation", 16 if width < 900 else 28)
	if not is_equal_approx(_refresh_width, width):
		_refresh_width = width
		if _view == "library": _fit_tiles()
		elif is_instance_valid(_grid): _fit_grid()

func _page(title: String, view: String) -> void:
	var footer := get_node_or_null("Margin/Column/DeckEditorActions")
	if footer!=null:
		footer.get_parent().remove_child(footer)
		footer.queue_free()
	_view = view
	_grid = null
	PlayerUI.clear(body)
	banner.hide()
	heading.text = title
	heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT if view == "library" else Node.AUTO_TRANSLATE_MODE_DISABLED
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12 if _compact() else 20)
	$Margin/Column/Scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if view == "reader" else ScrollContainer.SCROLL_MODE_AUTO
	_search.visible = view == "library"
	var back: Button = $Margin/Column/Header/Back
	back.custom_minimum_size.x = 0
	PlayerUI.standard_back(back, "Voltar" if view == "library" else ("Biblioteca" if view == "deck" else "Galeria"))
	_layout_changed()
	if view in ["editor","review","submissions"]:
		PlayerUI.standard_back(back,"Editar" if view=="review" else "Meus Decks")
		heading.add_theme_font_size_override("font_size",34)
	_refit_margin.call_deferred()

func _render_library() -> void:
	_deck = {}
	_index = -1
	# Ao (re)abrir a Biblioteca o header começa no destaque de maior prioridade.
	_featured = 0
	_page("BIBLIOTECA DE DECKS", "library")
	if services.session.authenticated():
		var review := _action("Revisão manual",_open_manual_review)
		review.name="OpenManualReview"
		body.add_child(review)
	_search.text = _query
	_search.editable = true
	var compact := _compact()
	var tabs := HBoxContainer.new()
	tabs.name = "LibraryTabs"
	tabs.add_theme_constant_override("separation", 6 if compact else 12)
	body.add_child(tabs)
	_tabs.clear()
	for text: String in TABS:
		var button := Button.new()
		button.name = "Tab" + text.replace(" ", "")
		button.text = tr(text)
		button.toggle_mode = true
		button.button_pressed = _tab == text
		button.custom_minimum_size = Vector2(0, 34 if compact else PlayerUI.CONTROL_HEIGHT)
		button.add_theme_font_size_override("font_size", 14 if compact else PlayerUI.CONTROL_FONT)
		PremiumUI.style_tab(button)
		for state in ["normal", "disabled"]: button.add_theme_stylebox_override(state, PremiumUI.flat(Color.TRANSPARENT, Color.TRANSPARENT, 10, 0, 14 if compact else 22))
		for state in ["pressed", "hover_pressed"]:
			var box := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			box.set_content_margin_all(14 if compact else 22)
			box.content_margin_top = 4
			box.content_margin_bottom = 4
			button.add_theme_stylebox_override(state, box)
		button.pressed.connect(_select_tab.bind(text))
		tabs.add_child(button)
		_tabs.append(button)
	var rule := ColorRect.new()
	rule.color = Color(PremiumUI.GOLD, 0.25)
	rule.custom_minimum_size.y = 1
	body.add_child(rule)
	var layout := HBoxContainer.new()
	layout.name = "LibraryLayout"
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12 if compact else 24)
	body.add_child(layout)
	_results = VBoxContainer.new()
	_results.name = "DeckResults"
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_theme_constant_override("separation", 10 if compact else 18)
	layout.add_child(_results)
	_filter_panel = _filters()
	layout.add_child(_filter_panel)
	_update_results()


func _select_tab(tab: String) -> void:
	_tab = tab
	# "Meus Decks" mostra os próprios; nas outras abas o filtro de tipo continua o do jogador.
	if tab == "Meus Decks":
		_types = {"mine": true}
		_moderation_checked=false
	elif _types.size() == 1 and _types.has("mine"): _types = {}
	for i in range(_tabs.size()): if is_instance_valid(_tabs[i]): _tabs[i].button_pressed = TABS[i] == tab
	_sort = ""
	_render_library()
	PlayerUI.cascade(_results)


# --- Modelo único das abas: oficiais, comunidade e meus rascunhos ---------------------

## Entradas reais. Decks de demonstração só existem quando um TESTE preenche _demo_entries.
func _entries() -> Array[Dictionary]:
	if not _owned_pulled and services.session.authenticated():
		_owned_pulled=true
		_pull_owned.call_deferred()
	var result: Array[Dictionary] = []
	for item in _catalog:
		var images: Array = (item.cards as Array).map(func(card: Dictionary) -> String: return str(card.image))
		result.append({"id": str(item.id), "name": str(item.name), "origin": "official" if item.official else "community",
			"creator": str(item.creator), "category": str(item.category), "count": int(item.count), "tags": item.get("tags", []),
			"cover": DeckCover.resolve_item(item), "live_cover_path": str(item.get("cover_path", "")),
			"focus": DeckCover.PORTRAIT_FOCUS, "images": images, "item": item,
			"ref": ("official:" if item.official else "creator:") + str(item.id),
			"published": PlayerContracts.iso_seconds(str(item.get("published_at", ""))),
			"owned": bool(item.official and services.rewards != null and services.rewards.is_deck_claimed(str(item.id)))})
	for draft: Dictionary in _store().list():
		var cards: Array = draft.get("cards", [])
		var cover := DeckCover.resolve_draft(_store(), draft)
		result.append({"id": "draft:" + str(draft.id), "name": str(draft.name) if not str(draft.name).is_empty() else tr("Sem nome"),
			"origin": "mine", "creator": tr("Você"), "category": str(draft.get("category", "")), "count": cards.size(),
			"cover": cover.path, "focus": cover.focus, "cover_mode": cover.mode,
			"images": cards.map(func(card: Dictionary) -> String: return _store().preview_path(str(draft.id), card)),
			"edited": float(draft.get("updated_at", 0)), "draft": draft})
	# Comunidade: decks publicados por outros jogadores (vitrine real do GAME).
	for row: Dictionary in CommunityService.items:
		var creator: Dictionary = row.get("creator", {}) if row.get("creator") is Dictionary else {}
		var cover := CommunityService.cached_image(str(row.get("cover_path", "")) if row.get("cover_path") != null else "")
		result.append({"id": str(row.id), "name": str(row.get("name", "")), "origin": "community", "community": true,
			"creator": CommunityService.creator_name(creator),
			"category": str(row.get("category", "")) if row.get("category") != null else "", "count": int(row.get("card_count", 0)), "tags": [],
			"cover": cover, "focus": DeckCover.PORTRAIT_FOCUS, "images": [cover] if not cover.is_empty() else [],
			"ref": "creator:" + str(row.id), "score": float(row.get("score", 0)),
			"published": PlayerContracts.iso_seconds(str(row.get("published_at", "")) if row.get("published_at") != null else "")})
	if services.community_decks!=null:
		for own: Dictionary in services.community_decks.library_entries():
			var found := false
			for entry: Dictionary in result:
				if str(entry.id)==str(own.id) and str(entry.origin)=="community":
					entry.owned=true
					entry.owned_ref=own.owned_ref
					found=true
					break
			if not found: result.append(own)
	for demo: Dictionary in _demo_entries: result.append(demo)
	return result


## Busca a vitrine da Comunidade (com cache de 2 min) e baixa as capas que faltam.
var _community_busy := false
var _community_cover_attempts := {}
var _moderation_checked := false
var _moderation_busy := false
var _moderation_generation := 0
var _moderation_state := "idle"
func _load_community() -> void:
	if _community_busy or not _demo_entries.is_empty(): return
	var service := CommunityService.for_current()
	if not service.available() or CommunityService.state=="error": return
	var complete := not _query.strip_edges().is_empty()
	var needs_catalog := CommunityService.state!="ok" or Time.get_ticks_msec()/1000.0-CommunityService.loaded_at>=CommunityService.LIST_TTL or (complete and not CommunityService.next_cursor.is_empty())
	var term := Catalog.search_key(_query)
	var missing_cover := false
	for row: Dictionary in CommunityService.items:
		if not term.is_empty() and not Catalog.search_key(str(row.get("name",""))+" "+CommunityService.creator_name(row.get("creator"))).contains(term): continue
		var path := str(row.get("cover_path","")) if row.get("cover_path")!=null else ""
		if not path.is_empty() and not _community_cover_attempts.has(path) and CommunityService.cached_image(path).is_empty(): missing_cover=true
	if not needs_catalog and not missing_cover: return
	_community_busy=true
	if complete and needs_catalog and is_instance_valid(_results):
		var loading := _text("Pesquisando decks publicados na Comunidade…",20,PlayerUI.MUTED)
		loading.name="CommunitySearchLoading"
		_results.add_child(loading)
		_results.move_child(loading,0)
	var result := await service.refresh(false,complete) if needs_catalog else ServiceResult.success(CommunityService.items)
	if result.ok:
		# Só baixar as capas dos resultados desta pesquisa; nunca os originais/cartas.
		var covers := 0
		term=Catalog.search_key(_query)
		for row: Dictionary in CommunityService.items:
			if not term.is_empty() and not Catalog.search_key(str(row.get("name",""))+" "+CommunityService.creator_name(row.get("creator"))).contains(term): continue
			if row.get("cover_path")!=null:
				var path := str(row.cover_path)
				if not _community_cover_attempts.has(path):
					_community_cover_attempts[path]=true
					await service.image(path)
					covers+=1
			if covers>=48: break
	_community_busy=false
	if is_inside_tree() and _view=="library" and _tab!="Meus Decks": _update_results()

func _retry_community() -> void:
	if _community_busy: return
	_community_cover_attempts.clear()
	CommunityService.state="idle"
	CommunityService.loaded_at=-1000.0
	_update_results()


func _open_community(deck_id: String) -> void:
	var service := CommunityService.for_current()
	if not service.available():
		banner.show_state("error", CommunityService.message("unauthorized"))
		return
	banner.show_state("loading")
	var result: Dictionary = await service.open_deck(deck_id)
	if not result.ok:
		banner.show_state("error", CommunityService.message(str(result.get("code", ""))))
		CommunityService.loaded_at = -1000.0
		return
	banner.show_state("success")
	_render_deck(result.data)


func _close_report() -> void:
	if is_instance_valid(_report_dialog): _report_dialog.queue_free()
	_report_dialog=null
	_report_busy=false

func _report_deck(deck_id: String) -> void:
	if is_instance_valid(_report_dialog): return
	banner.hide()
	var dialog := Control.new()
	dialog.name="ReportDialog"
	_report_dialog=dialog
	var panel := PlayerUI.deck_modal(self,dialog)
	panel.add_child(_text("Denunciar deck",30))
	panel.add_child(_text("Informe o motivo. A denúncia será enviada à moderação.",20,PlayerUI.MUTED))
	var reason := _field("","Motivo da denúncia",280)
	reason.name="ReportReason"
	PlayerUI.editor_control(reason)
	panel.add_child(reason)
	WebTextBridge.attach(reason)
	var feedback := _text("",20,PlayerUI.MUTED)
	feedback.name="ReportFeedback"
	feedback.visible=false
	panel.add_child(feedback)
	var actions := PlayerUI.row(panel)
	var cancel := _action("Cancelar",_close_report)
	cancel.name="CancelReport"
	var confirm := _action("Enviar denúncia",func()->void:
		await _submit_report(deck_id,dialog,reason,feedback))
	confirm.name="SubmitReport"
	for button: Button in [cancel,confirm]:
		PlayerUI.editor_control(button,button==confirm)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	reason.text_submitted.connect(func(_text:String)->void:confirm.pressed.emit())
	# No celular Web, o toque precisa focar primeiro o input HTML. Dar foco
	# ao LineEdit ao abrir ativa o IME do motor e rouba o foco do teclado nativo.
	if not WebTextBridge.enabled(): reason.grab_focus.call_deferred()

func _submit_report(deck_id: String,dialog: Control,reason: LineEdit,feedback: Label) -> void:
	if _report_busy or dialog!=_report_dialog: return
	if reason.text.strip_edges().is_empty():
		feedback.text=tr("Escreva o motivo antes de enviar.")
		feedback.show()
		if not WebTextBridge.enabled(): reason.grab_focus()
		return
	_report_busy=true
	var confirm := dialog.find_child("SubmitReport",true,false) as Button
	confirm.disabled=true
	reason.editable=false
	feedback.text=tr("Enviando denúncia…")
	feedback.show()
	var result: Dictionary=await CommunityService.for_current().report(deck_id,reason.text)
	if not is_inside_tree() or not is_instance_valid(dialog) or dialog!=_report_dialog: return
	_report_busy=false
	confirm.disabled=false
	reason.editable=true
	if result.ok:
		_close_report()
		banner.show_state("success",tr("Denúncia registrada. Obrigado por ajudar a moderação."))
	else:
		feedback.text=tr("Denúncia não enviada: ")+CommunityService.message(str(result.code))
		banner.show_state("error",tr("Denúncia não enviada. Confira o motivo informado na janela."))


## Situação de moderação de um rascunho já enviado ("" = nunca pediu publicação).
func _moderation(draft: Dictionary) -> String:
	return str(draft.get("server_status", "draft"))


## Envia para a conta e pede publicação (moderação). Erros do servidor viram mensagens claras.
func _publish_draft(draft: Dictionary) -> void:
	if _publish_busy: return
	_publish_busy=true
	await _send_draft_for_review(draft)
	_publish_busy=false

func _send_draft_for_review(draft: Dictionary) -> void:
	if _moderation(draft) in ["pending_review","published","removed"]: return
	var sync := _sync()
	if not sync.available():
		banner.show_state("error", CommunityService.message("unauthorized"))
		return
	banner.show_state("loading")
	_store().save(draft)
	var pushed: Dictionary = await sync.push(draft)
	if not pushed.ok:
		banner.show_state("error", tr("Não foi possível enviar o deck para a conta. Tente novamente."))
		return
	var result: Dictionary = await CommunityService.for_current().publish_request(str(draft.server_id))
	if not result.ok:
		banner.show_state("error", CommunityService.message(str(result.get("code", ""))))
		return
	draft.server_status = "pending_review"
	draft.review_note = ""
	_store().save(draft)
	banner.show_state("success", tr("Deck enviado para revisão. Ele aparece na Comunidade quando for aprovado."))
	if _view == "review":
		_render_review()
		banner.show_state("success",tr("Deck enviado para revisão. Acompanhe a decisão em Meus Decks → Acompanhar envios."))
	elif _view == "library": _update_results()


func _unpublish_draft(draft: Dictionary) -> void:
	banner.show_state("loading")
	var result: Dictionary = await CommunityService.for_current().unpublish(str(draft.get("server_id", "")))
	if not result.ok:
		banner.show_state("error", CommunityService.message(str(result.get("code", ""))))
		return
	draft.server_status = "draft"
	_store().save(draft)
	CommunityService.loaded_at = -1000.0
	banner.show_state("success", tr("Deck retirado da Comunidade. Agora você pode editá-lo."))
	if _view == "editor": _render_editor()
	elif _view == "library": _update_results()


## Consulta leve: preserva as cartas e alterações locais, atualiza só status/motivo.
func _refresh_moderation() -> void:
	if _moderation_busy: return
	var service := CommunityService.for_current()
	if not service.available():
		_moderation_state="offline"
		if _view=="submissions": _render_submissions()
		return
	var store := _store()
	var owner := store.owner
	_moderation_generation+=1
	var generation := _moderation_generation
	_moderation_busy=true
	_moderation_state="loading"
	if _view=="submissions": _render_submissions()
	var result: Dictionary = await service.statuses()
	if not is_inside_tree() or generation!=_moderation_generation or _store().owner!=owner: return
	_moderation_busy=false
	_moderation_state="fresh" if result.ok else "error"
	var changed := false
	if result.ok:
		for draft: Dictionary in store.list():
			var info: Dictionary = result.data.get(str(draft.get("server_id", "")), {})
			if info.is_empty(): continue
			if str(draft.get("server_status", "")) != info.status or str(draft.get("review_note", "")) != info.review_note:
				CommunityService.loaded_at=-1000.0
				draft.server_status = info.status
				draft.review_note = info.review_note
				store.save(draft)
				changed = true
			# O editor pode ter alterações ainda não salvas: não substituir o rascunho.
			if str(_draft.get("id", ""))==str(draft.id):
				_draft.server_status=info.status
				_draft.review_note=info.review_note
	if _view=="submissions": _render_submissions()
	elif changed and _view=="library" and _tab=="Meus Decks": _update_results()

func _open_submissions() -> void:
	_render_submissions()
	$Margin/Column/Scroll.scroll_vertical=0
	_refresh_moderation.call_deferred()

func _submission_text(parent: Node, value: String, node_name: String, color:=PlayerUI.TEXT, font_size:=22) -> Label:
	var label := _data_text(value,font_size,color)
	label.name=node_name
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _is_revision(draft: Dictionary) -> bool:
	return _moderation(draft)=="rejected" or (_moderation(draft)=="draft" and not str(draft.get("review_note", "")).strip_edges().is_empty())

func _draft_picture(draft: Dictionary) -> Texture2D:
	var cover := DeckCover.resolve_draft(_store(),draft)
	return DeckCover.load_texture(str(cover.get("path","")))

func _draft_summary(parent: Node, draft: Dictionary) -> void:
	var panel := PlayerUI.creator_panel(parent)
	panel.name="DeckSummary"
	var line := PlayerUI.row(panel)
	PlayerUI.creator_picture(line,_draft_picture(draft),Vector2(76,106))
	var words := PlayerUI.column(line)
	words.add_theme_constant_override("separation",12)
	var title := _submission_text(words,str(draft.get("name","")) if not str(draft.get("name", "")).is_empty() else tr("Sem nome"),"DeckSummaryName",PlayerUI.TEXT,26)
	title.tooltip_text=title.text
	words.add_theme_constant_override("separation",8)
	if not str(draft.get("category", "")).is_empty(): _submission_text(words,tr(str(draft.category)),"DeckSummaryCategory",PlayerUI.MUTED,20)
	var facts := HFlowContainer.new()
	facts.add_theme_constant_override("h_separation",8)
	facts.add_theme_constant_override("v_separation",8)
	words.add_child(facts)
	PlayerUI.creator_badge(facts,tr({"private":"Privado","unlisted":"Não listado","public":"Público"}.get(str(draft.get("visibility","private")),"Privado")))
	var count := (draft.get("cards",[]) as Array).size()
	PlayerUI.creator_badge(facts,tr("%d carta" if count==1 else "%d cartas") % count)

func _review_feedback(parent: Node, draft: Dictionary) -> void:
	if not _is_revision(draft): return
	var warning := PlayerUI.creator_panel(parent,"warning",16)
	var line := PlayerUI.row(warning)
	line.add_child(PremiumUI.icon_rect("info",Color("#ffb1bc"),30))
	var text := PlayerUI.column(line)
	text.add_theme_constant_override("separation",6)
	_submission_text(text,tr("Motivo da reprovação"),"RejectionHeading",Color("#ffb1bc"))
	var reason := str(draft.get("review_note", "")).strip_edges()
	_submission_text(text,reason if not reason.is_empty() else tr("A revisão não informou um motivo. Atualize o status para consultar novamente."),"RejectionReason")

func _render_submissions() -> void:
	_page(tr("Status dos decks"),"submissions")
	PlayerUI.standard_back($Margin/Column/Header/Back,"Meus Decks")
	var intro := PlayerUI.row(body)
	var caption := PlayerUI.column(intro)
	PlayerUI.creator_heading(caption,"Acompanhe seus decks","Veja o resultado da revisão e o próximo passo.","cards")
	var refresh := _action("Atualizar status",_refresh_moderation)
	refresh.name="RefreshDeckStatuses"
	refresh.disabled=_moderation_busy
	PlayerUI.creator_action(refresh,"refresh")
	refresh.custom_minimum_size.x=260
	intro.add_child(refresh)
	var messages := {
		"idle":"Mostrando o último status salvo. Atualize para consultar a revisão.",
		"loading":"Consultando o status dos seus decks…",
		"fresh":"Status atualizado. Depois de corrigir um deck reprovado, envie para uma nova revisão.",
		"error":"Não foi possível atualizar agora. Mostrando o último status salvo; tente novamente.",
		"offline":"Entre na sua conta para atualizar. Mostrando os decks salvos neste aparelho."}
	_submission_text(body,tr(messages.get(_moderation_state,messages.idle)),"DeckStatusNotice",PlayerUI.MUTED)
	if _remote_busy: _submission_text(body,tr("Sincronizando os decks da sua conta…"),"DeckStatusSync",PlayerUI.MUTED)
	elif _remote_error.has("decks"):
		_submission_text(body,tr("Alguns decks da conta podem não aparecer. Volte a Meus Decks e toque em Tentar novamente."),"DeckStatusSyncError",PlayerUI.MUTED)
	var drafts := _store().list()
	if drafts.is_empty():
		_submission_text(body,tr("Nenhum deck neste aparelho. Seus envios aparecem aqui após a sincronização da conta."),"NoSubmissions",PlayerUI.MUTED)
	for draft: Dictionary in drafts:
		var panel := PlayerUI.creator_panel(body,"accent")
		panel.name="Submission_"+str(draft.id)
		var layout := PlayerUI.row(panel)
		PlayerUI.creator_picture(layout,_draft_picture(draft),Vector2(138,194))
		var row := PlayerUI.column(layout)
		_submission_text(row,str(draft.get("name","")) if not str(draft.get("name", "")).is_empty() else tr("Sem nome"),"SubmissionName",PlayerUI.TEXT,28)
		var state := "revision" if _is_revision(draft) and _moderation(draft)=="draft" else _moderation(draft)
		var titles := {"draft":"Rascunho · ainda não enviado", "pending_review":"Em revisão", "rejected":"Reprovado · precisa de ajustes", "revision":"Em correção · aguardando reenvio", "published":"Aprovado · publicado", "removed":"Removido pela moderação"}
		var badge := PlayerUI.creator_badge(row,tr(titles.get(state,"Status indisponível · atualize")),state)
		badge.name="SubmissionState"
		var help := {"revision":"Suas alterações estão em rascunho. Conclua a correção e reenvie para nova revisão.", "draft":"Conclua as cartas e envie o deck para revisão.", "pending_review":"Seu envio aguarda a decisão da moderação. A aprovação libera o deck na Comunidade.", "rejected":"Corrija o conteúdo conforme o motivo abaixo e reenvie. O deck passará por uma nova revisão.", "published":"O deck foi aprovado e está disponível na Comunidade.", "removed":"Este deck foi removido e não pode ser reenviado por esta tela."}
		_submission_text(row,tr(help.get(state,"Consulte novamente antes de enviar.")),"SubmissionHelp",PlayerUI.MUTED)
		_review_feedback(row,draft)
		var action := _action("Corrigir e reenviar" if state in ["rejected","revision"] else ("Continuar edição" if state=="draft" else "Ver envio"),func()->void:
			_draft=draft
			if _moderation(draft) in ["draft","rejected"]: _render_editor()
			else: _render_review())
		action.name="SubmissionAction"
		PlayerUI.creator_action(action,"pencil" if state in ["rejected","revision","draft"] else "eye",state in ["rejected","revision"])
		row.add_child(action)
	_reveal()


func _matches(entry: Dictionary) -> bool:
	if not _types.is_empty() and not _types.has(str(entry.origin)):
		if not (_types.has("mine") and bool(entry.get("owned", false))): return false
	if not _themes.is_empty() and not _themes.has(str(entry.category)): return false
	var term := Catalog.search_key(_query)
	return term.is_empty() or Catalog.search_key("%s %s" % [entry.name, entry.creator]).contains(term)


## Ordenações sustentadas pelos dados atuais (sem popularidade nem datas inventadas).
func _sort_options() -> Array:
	match _tab:
		"Favoritos": return [["recent_favorite", "Adicionados recentemente"], ["name", "Nome A–Z"]]
		"Meus Decks": return [["edited", "Última edição"], ["name", "Nome A–Z"]]
	if _tab == "Populares" and _stats_state == "ok": return [["popular", "Mais populares"], ["name", "Nome A–Z"]]
	if _tab == "Recentes": return [["recent", "Publicados recentemente"], ["name", "Nome A–Z"]]
	return [["name", "Nome A–Z"]]


func _score(entry: Dictionary) -> float:
	return float(_stats.get(str(entry.get("ref", "")), {}).get("score", entry.get("score", 0.0)))


func _sorted(list: Array[Dictionary]) -> Array[Dictionary]:
	var mode := _sort if not _sort.is_empty() else str(_sort_options()[0][0])
	if mode == "edited":
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("edited", 0)) > float(b.get("edited", 0)))
	elif mode == "popular":
		# Sem engajamento medido (score 0) vai para o fim, em ordem alfabética.
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var sa := _score(a)
			var sb := _score(b)
			return Catalog.search_key(a.name).naturalnocasecmp_to(Catalog.search_key(b.name)) < 0 if is_equal_approx(sa, sb) else sa > sb)
	elif mode == "recent":
		# Sem data real de publicação (rascunhos) vai para o fim.
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var pa := float(a.get("published", 0))
			var pb := float(b.get("published", 0))
			return Catalog.search_key(a.name).naturalnocasecmp_to(Catalog.search_key(b.name)) < 0 if is_equal_approx(pa, pb) else pa > pb)
	elif mode == "recent_favorite":
		var order := _store().favorites()
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return order.find(str(a.id)) > order.find(str(b.id)))
	else:
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Catalog.search_key(a.name).naturalnocasecmp_to(Catalog.search_key(b.name)) < 0)
	return list


func _update_results() -> void:
	if not is_instance_valid(_results): return
	PlayerUI.clear(_results)
	var all := _entries()
	var shown: Array[Dictionary] = []
	for entry in all:
		if _tab == "Favoritos" and not _store().is_favorite(str(entry.id)): continue
		if _tab == "Meus Decks" and entry.origin != "mine" and not bool(entry.get("owned", false)): continue
		if _matches(entry): shown.append(entry)
	shown = _sorted(shown)
	if _tab == "Descobrir": _discover_top(all)
	var titles := {"Descobrir": ["layers", "Resultados"], "Populares": ["bolt", "Decks populares"], "Recentes": ["clock", "Decks recentes"], "Favoritos": ["star", "Meus favoritos"], "Meus Decks": ["layers", "Meus decks"]}
	_results_header(titles[_tab][0], "%s (%d)" % [tr(titles[_tab][1]), shown.size()])
	if _tab == "Populares":
		match _stats_state:
			"ok":
				if shown.all(func(e: Dictionary) -> bool: return _score(e) <= 0.0): _notice("Ainda não há partidas nem favoritos registrados nos últimos 30 dias.")
			"loading", "idle": _notice("Carregando popularidade…")
			"offline": _notice("Entre na sua conta para ver a popularidade dos decks. Mostrando de A a Z.")
			_: _notice("Não foi possível carregar a popularidade agora. Mostrando de A a Z.")
		_load_stats.call_deferred()
	if _tab == "Recentes" and shown.all(func(e: Dictionary) -> bool: return float(e.get("published", 0)) <= 0.0):
		_notice("Nenhum deck com data de publicação disponível.")
	if _tab == "Meus Decks":
		var refused := all.filter(func(entry:Dictionary)->bool:return str(entry.get("origin",""))=="mine" and _moderation(entry.draft)=="rejected").size()
		var track := _action("Acompanhar envios"+(" · %d reprovado%s" % [refused,"" if refused==1 else "s"] if refused>0 else ""),_open_submissions)
		track.name="OpenDeckSubmissions"
		PlayerUI.editor_control(track)
		_results.add_child(track)
		_remote_section.call_deferred("decks")
		if not _moderation_checked:
			_moderation_checked = true
			_refresh_moderation.call_deferred()
	else:
		if CommunityService.state=="error":
			_notice("Não foi possível atualizar a Comunidade. Os resultados podem estar incompletos.")
			var retry := _action("Tentar novamente",_retry_community)
			retry.name="RetryCommunity"
			_results.add_child(retry)
		_load_community.call_deferred()
	if _tab == "Favoritos": _remote_section.call_deferred("favorites")
	if shown.is_empty():
		_empty_results()
		return
	_grid = GridContainer.new()
	_grid.name = "DeckGrid"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10 if _compact() else 18)
	_grid.add_theme_constant_override("v_separation", 10 if _compact() else 18)
	_results.add_child(_grid)
	for entry in shown: _grid.add_child(_deck_tile(entry))
	if _tab == "Meus Decks": _grid.add_child(_create_tile())
	_fit_tiles()


func _results_header(icon: String, title: String) -> void:
	var compact := _compact()
	var row := HBoxContainer.new()
	row.name = "ResultsHeader"
	row.add_theme_constant_override("separation", 10)
	_results.add_child(row)
	row.add_child(PremiumUI.icon_rect(icon, PremiumUI.GOLD, 22 if compact else 32))
	var label := PremiumUI.plain(title, 17 if compact else 26, Color.WHITE, false)
	label.name = "ResultsTitle"
	row.add_child(label)
	if _tab == "Meus Decks":
		var create := PremiumUI.action("Criar novo deck", "user_plus", true, _create_deck, compact)
		create.name = "CreateDeck"
		create.icon = null
		create.text = "+  " + tr("Criar novo deck")
		row.add_child(create)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	if not compact: row.add_child(PremiumUI.plain("Ordenar por:", 16, PremiumUI.MUTED))
	var options := OptionButton.new()
	options.name = "SortBy"
	var modes := _sort_options()
	for mode: Array in modes: options.add_item(tr(mode[1]))
	var current := _sort if not _sort.is_empty() else str(modes[0][0])
	for i in range(modes.size()): if modes[i][0] == current: options.select(i)
	options.custom_minimum_size = Vector2(130 if compact else 220, 32 if compact else 44)
	options.tooltip_text = tr("Ordenar por")
	# Texto longo não empurra a página: corta com reticências dentro do botão.
	options.clip_text = true
	options.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	options.add_theme_font_size_override("font_size", 13 if compact else 17)
	PremiumUI.style_outline(options)
	options.item_selected.connect(func(index: int) -> void:
		_sort = str(modes[index][0])
		_update_results())
	row.add_child(options)
	if _tab!="Meus Decks" and services.session.authenticated():
		var refresh := PlayerUI.button("Atualizar",_retry_community)
		refresh.name="RefreshCommunity"
		refresh.disabled=_community_busy
		row.add_child(refresh)


## Fatos reais por aba: jogadores/favoritos (Populares) e "Publicado há" (Recentes). Nada inventado.
func _tile_facts(meta: HBoxContainer, entry: Dictionary, compact: bool) -> void:
	var size := 11 if compact else 14
	if _tab == "Populares":
		var stat: Dictionary = _stats.get(str(entry.get("ref", "")), entry.get("stats", {}))
		if int(stat.get("players_30d", 0)) > 0:
			var text := tr("%d jog.") % int(stat.players_30d) if compact else (tr("%d jogadores · 30 dias") % int(stat.players_30d) if int(stat.players_30d) != 1 else tr("1 jogador · 30 dias"))
			var players := PremiumUI.plain(text, size, PremiumUI.GOLD, false)
			players.tooltip_text = tr("Jogadores distintos nos últimos 30 dias")
			players.name = "Players30d"
			meta.add_child(players)
		if int(stat.get("favorites", 0)) > 0:
			var hearts := PremiumUI.plain("♥ %d" % int(stat.favorites), size, Color("#e8817a"), false)
			hearts.name = "FavoritesCount"
			meta.add_child(hearts)
	elif _tab == "Recentes":
		var when := PlayerContracts.ago(float(entry.get("published", 0)))
		if not when.is_empty():
			var label := PremiumUI.plain(when if compact else tr("Publicado ") + when, size, PremiumUI.MUTED, false)
			label.name = "PublishedAgo"
			meta.add_child(label)


## Busca os totais uma vez por STATS_TTL (só com sessão). Os refs são os decks oficiais.
func _load_stats() -> void:
	if _stats_state == "loading": return
	if _stats_state in ["ok", "error"] and Time.get_ticks_msec() / 1000.0 - _stats_at < STATS_TTL: return
	var client: Object = _stats_client
	var services := PlayerServices.current
	if client == null and services != null and services.session != null and services.session.authenticated(): client = services.client
	if client == null:
		if _stats_state != "offline":
			_stats_state = "offline"
			if _view == "library" and _tab == "Populares": _update_results()
		return
	var refs: Array = []
	for entry in _entries():
		var ref := str(entry.get("ref", ""))
		if not ref.is_empty() and not refs.has(ref): refs.append(ref)
	_stats_state = "loading"
	var result: Dictionary = await client.call_rpc("qse_deck_stats", {"p_refs": refs.slice(0, 100)})
	_stats_at = Time.get_ticks_msec() / 1000.0
	_stats.clear()
	if result.ok and result.data is Array:
		for row: Variant in result.data:
			if row is Dictionary and row.get("deck_ref") is String:
				_stats[row.deck_ref] = {"plays_30d": int(row.get("plays_30d", 0)), "players_30d": int(row.get("players_30d", 0)),
					"favorites": int(row.get("favorites", 0)), "score": float(row.get("score", 0))}
		_stats_state = "ok"
	else:
		_stats_state = "error"
	if is_inside_tree() and _view == "library" and _tab in ["Populares", "Descobrir"]: _update_results()


func _notice(text: String) -> void:
	var note := PlayerUI.label(text, 12 if _compact() else 15, PremiumUI.MUTED)
	note.name = "DataNotice"
	_results.add_child(note)


func _empty_results() -> void:
	var box := VBoxContainer.new()
	box.name = "EmptyResults"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size.y = 160 if _compact() else 280
	box.add_theme_constant_override("separation", 12)
	_results.add_child(box)
	var filtered := not _query.strip_edges().is_empty() or not _themes.is_empty() or (not _types.is_empty() and _tab != "Meus Decks")
	var title: String = "Nenhum deck encontrado" if filtered else {"Favoritos": "Você ainda não tem decks favoritos.", "Meus Decks": "Você ainda não criou decks."}.get(_tab, "Nenhum deck disponível")
	var heading_label := PlayerUI.label(title, 18 if _compact() else 26, Color.WHITE)
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading_label)
	var button: Button
	if filtered:
		button = PremiumUI.action("Limpar filtros", "refresh", false, _clear_filters, _compact())
		button.name = "ClearSearch"
	elif _tab == "Meus Decks":
		button = PremiumUI.action("Criar novo deck", "user_plus", true, _create_deck, _compact())
		button.name = "CreateDeckEmpty"
	else:
		button = PremiumUI.action("Explorar decks", "search", true, _select_tab.bind("Descobrir"), _compact())
		button.name = "ExploreDecks"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size.x = 220 if _compact() else 300
	box.add_child(button)


func _clear_filters() -> void:
	_query = ""
	_search.clear()
	_themes.clear()
	_types = {"mine": true} if _tab == "Meus Decks" else {}
	_render_library()


func _create_deck() -> void:
	_draft = _store().new_draft()
	_render_editor()


## Descobrir: destaque oficial e coleções (contagens calculadas dos dados reais).
func _discover_top(all: Array[Dictionary]) -> void:
	var compact := _compact()
	_slides.clear()
	if _query.strip_edges().is_empty(): _slides = FeaturedPicker.pick(all, _featured_rules(), _stats, _now())
	if not _slides.is_empty():
		_featured = clampi(_featured, 0, _slides.size() - 1)
		_results.add_child(_banner(_slides[_featured], _slides.size()))
		_arm_rotation()
	_load_stats.call_deferred()
	var counts := {"official": 0, "themed": 0, "community": 0, "mine": 0}
	for entry in all:
		counts[entry.origin] = int(counts.get(entry.origin, 0)) + 1
		if not str(entry.category).is_empty(): counts.themed += 1
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(PremiumUI.icon_rect("layers", PremiumUI.GOLD, 22 if compact else 30))
	head.add_child(PremiumUI.plain("Coleções em destaque", 16 if compact else 24, Color.WHITE))
	_results.add_child(head)
	var row := HBoxContainer.new()
	row.name = "Collections"
	row.add_theme_constant_override("separation", 8 if compact else 16)
	_results.add_child(row)
	for item: Array in [["Oficiais", "crown", "official", counts.official], ["Temáticos", "tag", "themed", counts.themed], ["Comunidade", "friends", "community", counts.community], ["Meus Decks", "cards", "mine", counts.mine]]:
		var card := Button.new()
		card.name = "Collection_" + str(item[2])
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 48 if compact else 72
		PremiumUI.style_tab(card)
		card.pressed.connect(_open_collection.bind(str(item[2])))
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 10 if compact else 18)
		card.add_child(line)
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 12 if compact else 24
		line.add_child(PremiumUI.icon_rect(item[1], PremiumUI.GOLD, 22 if compact else 40))
		var text := VBoxContainer.new()
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.add_theme_constant_override("separation", 0)
		line.add_child(text)
		text.add_child(PremiumUI.plain(item[0], 13 if compact else 21, Color.WHITE))
		text.add_child(PremiumUI.plain(tr("%d decks") % int(item[3]) if int(item[3]) != 1 else tr("1 deck"), 11 if compact else 17, PremiumUI.MUTED, false))
		row.add_child(card)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size.y = 1
	_results.add_child(rule)


func _open_collection(kind: String) -> void:
	_themes.clear()
	if kind == "mine":
		_select_tab("Meus Decks")
		return
	if kind == "themed":
		_types = {}
		for entry in _entries():
			if not str(entry.category).is_empty(): _themes[str(entry.category)] = true
	else:
		_types = {kind: true}
	_render_library()


## Regras de destaque do CATALOG; testes podem injetar as próprias (_demo_rules).
func _featured_rules() -> Array:
	if not _demo_rules.is_empty(): return _demo_rules
	var services := PlayerServices.current
	return services.catalog.featured if services != null and services.catalog != null else []


func _now() -> float:
	return _clock if _clock > 0.0 else Time.get_unix_time_from_system()


## Personagens do header: a capa primeiro, depois os mais representativos (até 16 avaliados).
func _banner_images(entry: Dictionary) -> Array:
	var images: Array = entry.get("images", [])
	if images.size() > 16:
		var spread: Array = []
		for i in 16: spread.append(images[int(i * images.size() / 16.0)])
		images = spread
	var ordered: Array = []
	if DeckCover.exists(str(entry.get("cover", ""))): ordered.append(str(entry.cover))
	for index in DeckCover.ranked(images):
		if not ordered.has(images[index]): ordered.append(images[index])
	return ordered.slice(0, CinematicBanner.MAX_CHARACTERS)


func _arm_rotation() -> void:
	if _slides.size() <= 1: return
	if not is_instance_valid(_rotation):
		_rotation = Timer.new()
		_rotation.name = "FeaturedTimer"
		_rotation.wait_time = 9.0
		_rotation.timeout.connect(func() -> void:
			if is_visible_in_tree() and _view == "library" and _tab == "Descobrir" and _slides.size() > 1:
				_show_slide((_featured + 1) % _slides.size()))
		add_child(_rotation)
	_rotation.start()


## Troca só o banner (sem refazer a lista).
func _show_slide(index: int) -> void:
	var old := _results.find_child("FeaturedBanner", false, false)
	if old == null or _slides.is_empty(): return
	_featured = clampi(index, 0, _slides.size() - 1)
	old.name = "FeaturedBannerOld"
	var fresh := _banner(_slides[_featured], _slides.size())
	_results.add_child(fresh)
	_results.move_child(fresh, old.get_index())
	old.queue_free()
	fresh.name = "FeaturedBanner"
	if is_instance_valid(_rotation): _rotation.start()


func _banner(slide: Dictionary, total: int) -> Control:
	var entry: Dictionary = slide.entry
	var compact := _compact()
	var banner_panel := PanelContainer.new()
	banner_panel.name = "FeaturedBanner"
	banner_panel.set_meta("reason", slide.reason)
	banner_panel.set_meta("deck", str(entry.get("ref", entry.id)))
	banner_panel.custom_minimum_size.y = 440
	var frame := PremiumUI.flat(Color(0.03, 0.04, 0.07), Color(PremiumUI.GOLD, 0.4), 16, 1, 0)
	banner_panel.add_theme_stylebox_override("panel", frame)
	banner_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var art := CinematicBanner.new()
	art.name = "Cinematic"
	art.setup(_banner_images(entry))
	banner_panel.add_child(art)
	# Capa personalizada do editor: substitui a arte somente se um asset remoto existir.
	if entry.origin == "official" and services.editor_content != null and not str(entry.get("live_cover_path", "")).is_empty():
		var custom_art := TextureRect.new()
		custom_art.name = "EditorFeaturedCover"
		custom_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		custom_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		banner_panel.add_child(custom_art)
		custom_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		services.editor_content.attach_cover(custom_art, str(entry.live_cover_path))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 16 if compact else 44)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12 if compact else 30)
	banner_panel.add_child(margin)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 3 if compact else 8)
	margin.add_child(text)
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 8)
	var reason := PlayerUI.pill(tr(str(slide.label)).to_upper(), "equipped" if slide.reason in ["pin", "campaign"] else "")
	reason.name = "FeaturedReason"
	badges.add_child(reason)
	if entry.origin == "official":
		badges.add_child(PlayerUI.pill("OFICIAL", "equipped"))
	text.add_child(badges)
	var title := PremiumUI.plain(str(entry.name), 50, Color.WHITE, false)
	title.name = "FeaturedTitle"
	text.add_child(title)
	text.add_child(PremiumUI.plain("%s  •  %s" % [tr("Criado por %s") % str(entry.creator) if entry.origin=="community" else entry.creator, tr("%d cartas") % int(entry.count)], 24, Color("#d6dbe4"), false))
	var explore := PremiumUI.action("Explorar coleção  →", "layers", true, _open_entry.bind(entry), compact)
	explore.name = "ExploreFeatured"
	explore.icon = null
	explore.custom_minimum_size.y = 80
	explore.add_theme_font_size_override("font_size", 30)
	explore.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	text.add_child(explore)
	# Pontos só quando há mais de um destaque real.
	if total > 1:
		var dots := HBoxContainer.new()
		dots.name = "BannerDots"
		dots.add_theme_constant_override("separation", 8)
		for i in total:
			var dot := Button.new()
			dot.name = "Dot_%d" % i
			dot.custom_minimum_size = Vector2(26, 14) if i == _featured else Vector2(14, 14)
			dot.tooltip_text = str(_slides[i].entry.name)
			for state in ["normal", "hover", "pressed", "focus"]:
				dot.add_theme_stylebox_override(state, PremiumUI.flat(PremiumUI.GOLD if i == _featured else Color(1, 1, 1, 0.35), Color.TRANSPARENT, 7, 0, 0))
			dot.pressed.connect(_show_slide.bind(i))
			dots.add_child(dot)
		text.add_child(dots)
	return banner_panel


func _open_entry(entry: Dictionary) -> void:
	if entry.has("owned_ref"):
		_open_owned(str(entry.owned_ref))
		return
	if entry.get("community", false):
		_open_community(str(entry.id))
		return
	if entry.has("item") and not entry.item.is_empty(): _render_deck(entry.item)
	elif entry.has("draft"):
		_draft = entry.draft
		if _moderation(_draft) in ["pending_review","published","rejected","removed"] or _is_revision(_draft): _open_submissions()
		else: _render_editor()


## Cartão de deck: capa horizontal enquadrada, selo, nome, cartas e coração (ou menu ⋯).
func _empty(parent: Node, title: String, message: String, font_size := 26) -> void:
	parent.add_child(_text(title, font_size))
	parent.add_child(_text(message, 16, PlayerUI.MUTED))


func _deck_tile(entry: Dictionary) -> Control:
	var compact := _compact()
	var tile := Button.new()
	tile.name = "Deck_" + str(entry.id).replace(":", "_")
	tile.tooltip_text = str(entry.name)
	tile.focus_mode = Control.FOCUS_ALL
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := PremiumUI.flat(Color(0.05, 0.07, 0.11), PremiumUI.EDGE if state == "normal" else Color(PremiumUI.GOLD, 0.7), 14, 1 if state == "normal" else 2, 0)
		if state == "focus": box.draw_center = false
		tile.add_theme_stylebox_override(state, box)
	tile.clip_contents = true
	tile.pressed.connect(_open_entry.bind(entry))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	tile.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cover := TextureRect.new()
	cover.name = "Cover"
	cover.texture = DeckCover.framed(str(entry.cover), DeckCover.ASPECT, entry.get("focus", DeckCover.PORTRAIT_FOCUS)) if DeckCover.exists(str(entry.get("cover", ""))) else null
	if cover.texture == null: _monogram(cover, str(entry.name))
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cover.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cover.size_flags_stretch_ratio = 3.2
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.clip_contents = true
	column.add_child(cover)
	if entry.origin == "official" and services.editor_content != null:
		services.editor_content.attach_cover(cover, str(entry.get("live_cover_path", "")))
	if entry.origin == "official":
		var seal := PlayerUI.pill("OFICIAL", "equipped")
		seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.add_child(seal)
		seal.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		seal.position += Vector2(10, -32)
	var info := MarginContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]: info.add_theme_constant_override("margin_" + side, 10 if compact else 14)
	for side in ["top", "bottom"]: info.add_theme_constant_override("margin_" + side, 4 if compact else 8)
	column.add_child(info)
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 2)
	info.add_child(lines)
	var title := PremiumUI.plain(str(entry.name), 14 if compact else 21, Color.WHITE, false)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_child(title)
	if entry.origin=="community":
		var credit := _data_text(tr("Criado por %s") % str(entry.creator),20,PlayerUI.MUTED)
		credit.name="DeckCreator"
		credit.autowrap_mode=TextServer.AUTOWRAP_OFF
		credit.clip_text=true
		credit.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		credit.tooltip_text=credit.text
		lines.add_child(credit)
	var meta := HBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_theme_constant_override("separation", 6)
	lines.add_child(meta)
	if entry.origin == "mine":
		var edited := PlayerContracts.ago(float(entry.get("edited", 0)))
		if not edited.is_empty():
			meta.add_child(PremiumUI.icon_rect("pencil", PremiumUI.MUTED, 12 if compact else 16))
			meta.add_child(PremiumUI.plain(tr("Editado ") + edited, 11 if compact else 14, PremiumUI.MUTED, false))
	meta.add_child(PremiumUI.icon_rect("cards", PremiumUI.MUTED, 12 if compact else 16))
	meta.add_child(PremiumUI.plain(tr("%d cartas") % int(entry.count), 11 if compact else 14, PremiumUI.MUTED, false))
	_tile_facts(meta, entry, compact)
	if entry.origin == "official" and bool(entry.get("owned", false)):
		meta.add_child(PlayerUI.pill("RESGATADO", "equipped"))
	if entry.origin == "mine":
		var state := str(entry.draft.get("sync_state", "local"))
		var pill_text: String = {"synced": "NA CONTA", "pending": "ENVIANDO", "error": "ERRO AO ENVIAR"}.get(state, "RASCUNHO")
		var moderation := _moderation(entry.draft)
		if moderation in ["pending_review", "published", "rejected", "removed"]:
			pill_text = {"pending_review": "EM REVISÃO", "published": "PUBLICADO", "rejected": "REPROVADO", "removed": "REMOVIDO"}[moderation]
		if moderation=="draft" and _is_revision(entry.draft): pill_text="EM CORREÇÃO"
		var pill := PlayerUI.pill(pill_text, "equipped" if state == "synced" or moderation == "published" else "available")
		if moderation == "rejected" and not str(entry.draft.get("review_note", "")).is_empty(): pill.tooltip_text = tr("Motivo: ") + str(entry.draft.review_note)
		pill.name = "SyncState"
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta.add_child(pill)
	var corner := _deck_menu(entry) if entry.origin == "mine" else _heart(str(entry.id))
	tile.add_child(corner)
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	corner.anchor_top = 1.0
	corner.anchor_bottom = 1.0
	corner.offset_left = -50
	corner.offset_right = -6
	corner.offset_top = -46
	corner.offset_bottom = -6
	return tile


func _create_tile() -> Control:
	var tile := Button.new()
	tile.name = "CreateDeckTile"
	tile.text = "+\n" + tr("Criar novo deck")
	tile.add_theme_font_size_override("font_size", 14 if _compact() else 20)
	var dashed := PremiumUI.flat(Color(0.04, 0.06, 0.1), Color(1, 1, 1, 0.22), 14, 1, 0)
	for state in ["normal", "hover", "pressed", "focus"]: tile.add_theme_stylebox_override(state, dashed)
	tile.add_theme_color_override("font_color", Color.WHITE)
	tile.pressed.connect(_create_deck)
	return tile


## Menu ⋯ dos decks próprios: só ações que existem de verdade.
func _deck_menu(entry: Dictionary) -> Control:
	var menu := MenuButton.new()
	menu.name = "DeckMenu"
	menu.text = "⋯"
	menu.flat = true
	menu.add_theme_font_size_override("font_size", 22)
	menu.add_theme_color_override("font_color", Color.WHITE)
	var popup := menu.get_popup()
	popup.add_item(tr("Editar"),0)
	popup.add_item(tr("Duplicar"), 1)
	popup.add_item(tr("Acompanhar revisão"),6)
	var moderation := _moderation(entry.draft)
	if moderation in ["pending_review", "published"]: popup.add_item(tr("Retirar da Comunidade"), 5)
	else: popup.add_item(tr("Revisar e publicar"), 2)
	if str(entry.draft.get("sync_state", "")) in ["error", "pending"] and _sync().available():
		popup.add_item(tr("Tentar novamente"), 4)
	popup.add_separator()
	popup.add_item(tr("Excluir"), 3)
	popup.id_pressed.connect(_menu_action.bind(entry))
	return menu


func _menu_action(id: int, entry: Dictionary) -> void:
	var draft: Dictionary = entry.draft
	match id:
		0:
			_draft=draft
			_render_editor()
		1: _duplicate_draft(draft)
		2:
			_draft = draft
			_render_review()
		3: _confirm_delete(draft)
		4: _retry_draft(draft)
		5: _unpublish_draft(draft)
		6: _open_submissions()


## Mantém o retry de rascunhos individuais, existente antes do redesign T23.
func _retry_draft(draft: Dictionary) -> void:
	var sync := _sync()
	if not sync.available():
		banner.show_state("error", "Entre na conta para sincronizar este rascunho.")
		return
	banner.show_state("loading")
	var result: Dictionary = await sync.push(draft)
	if not is_inside_tree(): return
	if result.ok:
		banner.show_state("success", "Rascunho salvo neste aparelho e na sua conta.")
	elif str(result.get("code", "")) == "deck_incomplete":
		banner.show_state("error", CreatorSync.deck_ready(draft))
	else:
		banner.show_state("error", str(TranslationServer.translate("Sincronização não concluída (%s). Seus dados permanecem neste aparelho.")) % str(result.get("code", "erro")))
	if _view == "library": _update_results()


func _duplicate_draft(draft: Dictionary) -> void:
	var copy := _store().new_draft()
	copy.name = (str(draft.name) + " " + tr("(cópia)")).left(DeckDrafts.NAME_MAX)
	for key in ["description", "category", "visibility"]: copy[key] = draft.get(key, copy[key])
	for card: Dictionary in draft.get("cards", []):
		var clone := {"id": "card_%d_%d" % [Time.get_ticks_msec(), randi() % 100000], "name": card.get("name", ""), "description": card.get("description", ""), "crops": card.get("crops", {}).duplicate(true), "image_file": ""}
		var bytes := _store().file_bytes(str(draft.id), str(card.get("image_file", "")))
		if not bytes.is_empty():
			clone.image_file = _store().store_original(str(copy.id), str(clone.id), bytes, str(card.image_file).get_extension())
			var image := _store().original_image(str(copy.id), clone)
			if image != null: _store().store_previews(str(copy.id), clone, image)
		copy.cards.append(clone)
	_store().save(copy)
	banner.show_state("success", "Cópia criada neste aparelho.")
	_update_results()


## Capas: texturas importadas (res://) ou prévias locais em cache (sem reler o disco a cada filtro).
func _cover(path: String) -> Texture2D:
	if path.is_empty(): return null
	if path.begins_with("res://"): return load(path) as Texture2D if ResourceLoader.exists(path) else null
	if not FileAccess.file_exists(path): return null
	var key := "%s@%d" % [path, FileAccess.get_modified_time(path)]
	if not _covers.has(key):
		var image := Image.load_from_file(path)
		_covers[key] = ImageTexture.create_from_image(image) if image != null else null
	return _covers[key]


## Sem capa possível (deck sem imagens): monograma dourado sobre degradê — nunca vazio.
func _monogram(cover: TextureRect, title: String) -> void:
	cover.name = "Cover"
	var back := ColorRect.new()
	back.name = "Monogram"
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.color = Color(0.07, 0.09, 0.14)
	cover.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var initial := "?"
	for character in title.replace("[DEMO]", "").strip_edges():
		if character.to_upper() != character.to_lower() or character.is_valid_int():
			initial = character.to_upper()
			break
	var letter := PremiumUI.plain(initial, 34 if _compact() else 56, Color(PremiumUI.GOLD, 0.85), false)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back.add_child(letter)
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Colunas pela largura disponível, sem comprimir as capas: cada cartão tem largura mínima
## (desktop 320, compacto 200) e a capa mantém 16:10 + faixa de texto.
func _fit_tiles() -> void:
	if not is_instance_valid(_grid) or _grid.name != "DeckGrid": return
	var compact := _compact()
	var panel := _filter_panel.custom_minimum_size.x + 18.0 if is_instance_valid(_filter_panel) and _filter_panel.visible else 0.0
	# iPhone: margens reais da página (laterais + espaçamento do painel) para a grade nunca
	# alargar a tela e empurrar a busca para fora.
	var width: float = _physical_size().x - panel - (170.0 if UIScale.is_iphone() else (60.0 if compact else 130.0))
	var gap := 10.0 if compact else 18.0
	var minimum := 200.0 if compact else 320.0
	_grid.columns = clampi(floori((width + gap) / (minimum + gap)), 1, 5)
	var tile_width := floorf((width - (_grid.columns - 1) * gap) / _grid.columns)
	var text_band := 52.0 if compact else 74.0
	for tile: Control in _grid.get_children():
		var credit_height := 28.0 if tile.find_child("DeckCreator",true,false)!=null else 0.0
		tile.custom_minimum_size=Vector2(tile_width,tile_width/DeckCover.ASPECT+text_band+credit_height)


# --- Painel "Filtrar decks" --------------------------------------------------------------

func _filters() -> Control:
	var compact := _compact()
	var panel := PremiumUI.panel("FilterPanel", 10 if compact else 20)
	panel.custom_minimum_size.x = 170 if compact else 300
	if UIScale.is_iphone(): panel.custom_minimum_size.x = 220
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4 if compact else 8)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(PremiumUI.icon_rect("filter", PremiumUI.GOLD, 18 if compact else 28))
	head.add_child(PremiumUI.plain("Filtrar decks", 15 if compact else 24, Color.WHITE))
	column.add_child(head)
	column.add_child(_filter_group("Tipo", [["Oficiais", "official"], ["Comunidade", "community"], ["Meus decks", "mine"]], _types, "Type_"))
	var themes: Array = []
	for entry in _entries():
		var category := str(entry.category)
		if not category.is_empty() and not themes.has([category, category]): themes.append([category, category])
	themes.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
	var theme_group := _filter_group("Temática", themes, _themes, "Theme_")
	if themes.is_empty(): theme_group.add_child(PlayerUI.label("Os decks ainda não informam temática.", 11 if compact else 14, PremiumUI.MUTED))
	column.add_child(theme_group)
	var clear := PremiumUI.action("Limpar filtros", "refresh", false, _clear_filters, compact)
	clear.name = "ClearFilters"
	column.add_child(clear)
	return panel


func _filter_group(title: String, options: Array, selected: Dictionary, prefix: String) -> VBoxContainer:
	var compact := _compact()
	var group := VBoxContainer.new()
	group.name = "Group_" + title
	group.add_theme_constant_override("separation", 0 if compact else 4)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size.y = 1
	group.add_child(rule)
	group.add_child(PremiumUI.plain(title, 13 if compact else 20, Color.WHITE))
	for option: Array in options:
		var box := CheckBox.new()
		box.name = prefix + str(option[1]).replace(" ", "_")
		box.text = tr(str(option[0]))
		box.button_pressed = selected.has(str(option[1]))
		box.add_theme_font_size_override("font_size", 12 if compact else 17)
		box.add_theme_color_override("font_color", Color("#e8edf5"))
		box.add_theme_color_override("font_pressed_color", Color.WHITE)
		box.add_theme_icon_override("checked", _check_icon(true))
		box.add_theme_icon_override("unchecked", _check_icon(false))
		box.toggled.connect(func(value: bool) -> void:
			if value: selected[str(option[1])] = true
			else: selected.erase(str(option[1]))
			_update_results())
		group.add_child(box)
	return group


func _check_icon(on: bool) -> Texture2D:
	var key := "check_%s" % on
	if _covers.has(key): return _covers[key]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 24 24">' + ('<rect x="2" y="2" width="20" height="20" rx="5" fill="#e8b860"/><path d="M6.5 12.5l3.5 3.5 7.5-8" fill="none" stroke="#141006" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>' if on else '<rect x="3" y="3" width="18" height="18" rx="5" fill="none" stroke="#a8bad3" stroke-width="1.6"/>') + '</svg>'
	var image := Image.new()
	image.load_svg_from_string(svg)
	image.resize(22, 22, Image.INTERPOLATE_LANCZOS)
	_covers[key] = ImageTexture.create_from_image(image)
	return _covers[key]


func _render_deck(item: Dictionary) -> void:
	if _deck.get("id", "") != item.id: _gallery_scroll = 0
	_deck = item
	_index = -1
	_page(str(item.name), "deck")
	var metadata := PlayerUI.flow(body)
	metadata.name = "DeckMetadata"
	if item.official:
		metadata.add_child(PlayerUI.pill("OFICIAL", "equipped"))
		if services.rewards != null and services.rewards.is_deck_claimed(str(item.id)):
			metadata.add_child(PlayerUI.pill("NA SUA CONTA", "equipped"))
		elif services.session.authenticated():
			var redeem := _action("RESGATAR GRÁTIS", _open_rewards)
			redeem.name = "RedeemOfficialDeck"
			metadata.add_child(redeem)
	metadata.add_child(_heart(str(item.id)))
	if item.get("community", false):
		metadata.add_child(PlayerUI.pill("COMUNIDADE", "available"))
		if services.community_decks.is_claimed(str(item.id)):
			metadata.add_child(PlayerUI.pill("NA SUA CONTA", "equipped"))
		elif services.session.authenticated():
			var redeem := _action("RESGATAR GRÁTIS",func()->void:await _claim_community(str(item.id)))
			PlayerUI.editor_control(redeem,true)
			redeem.name="RedeemCommunityDeck"
			redeem.disabled=_claim_busy
			metadata.add_child(redeem)
		var report := _action("Denunciar", _report_deck.bind(str(item.id)))
		report.name = "ReportDeck"
		metadata.add_child(report)
	var credit := _data_text(tr("Criado por %s") % str(item.creator) if item.get("community",false) else (str(item.creator) if not str(item.creator).is_empty() else "Autoria não informada"),20,PlayerUI.MUTED)
	credit.name="DeckCreator"
	metadata.add_child(credit)
	metadata.add_child(_text("%d cartas  ·  A–Z" % item.count, 16, PlayerUI.MUTED))
	if not str(item.category).is_empty(): metadata.add_child(_data_text(item.category, 16))
	for tag: String in item.tags: metadata.add_child(PlayerUI.pill(tag, "available"))
	if not str(item.age_rating).is_empty(): metadata.add_child(_text(str(TranslationServer.translate("Classificação: ")) + str(item.age_rating), 16))
	if not str(item.description).is_empty(): body.add_child(_data_text(item.description, 18, PlayerUI.MUTED))
	for warning: String in item.content_warnings: body.add_child(_data_text(warning, 16, PlayerUI.GOLD))
	_grid = GridContainer.new()
	_grid.name = "CardGallery"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	body.add_child(_grid)
	for i in range(item.cards.size()):
		var entry: Dictionary = item.cards[i]
		var button := _action("", _render_card.bind(i))
		button.name = "Card_" + str(entry.id).get_file()
		button.tooltip_text = str(entry.name)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 8)
		var column := PlayerUI.column(margin)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 4)
		var image := _image(entry.image)
		image.name = "CardImage"
		image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(image)
		var name_label := _data_text(entry.name, 16 if _compact() else 18)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.custom_minimum_size.y = 42
		name_label.max_lines_visible = 2
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		_grid.add_child(button)
	_fit_grid()
	if _grid.get_child_count() > 0: _focus.call_deferred(_grid.get_child(0))
	$Margin/Column/Scroll.set_deferred("scroll_vertical", _gallery_scroll)
	_reveal()

func _fit_grid() -> void:
	if not is_instance_valid(_grid): return
	if _view=="review":
		_grid.columns=clampi(floori((_physical_size().x-480)/130),2,8)
		return
	var available := _physical_size().x - (56 if _compact() else 96)
	_grid.columns = clampi(floori((available + 16) / (148 if _compact() else 236)), 1, 6)
	var width := floorf((available - (_grid.columns - 1) * 16) / _grid.columns)
	var image_height := clampf(_physical_size().y - 240, 120, 210) if _compact() else width * 1.35
	for button: Control in _grid.get_children():
		button.custom_minimum_size = Vector2(width, image_height + 62)
	_refit_margin.call_deferred()

func _render_card(index: int) -> void:
	var entries: Array = _deck.get("cards", [])
	if index < 0 or index >= entries.size(): return
	if _view == "deck": _gallery_scroll = $Margin/Column/Scroll.scroll_vertical
	_index = index
	var entry: Dictionary = entries[index]
	_page(str(entry.name), "reader")
	var row := PlayerUI.row(body)
	row.name = "CardReader"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24 if not _compact() else 16)
	_reader_image = _image(entry.image)
	_reader_image.name = "FullCardImage"
	_reader_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader_image.size_flags_stretch_ratio = 1.4
	row.add_child(_reader_image)
	var info := PlayerUI.column(row)
	info.custom_minimum_size.x = 240 if _compact() else 340
	info.size_flags_stretch_ratio = 1.0
	info.add_child(_text("CARTA %02d / %02d" % [index + 1, entries.size()], 12, PlayerUI.GOLD))
	info.add_child(_data_text(str(_deck.name), 18, PlayerUI.MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info.add_child(scroll)
	var description := _data_text(str(entry.description) if not str(entry.description).is_empty() else "Descrição ainda não disponível.", 18, PlayerUI.TEXT if not str(entry.description).is_empty() else PlayerUI.MUTED)
	scroll.add_child(description)
	var controls := PlayerUI.row(info)
	controls.add_theme_constant_override("separation", 10)
	_reader_previous = _action("‹ Anterior", _render_card.bind(index - 1))
	_reader_previous.name = "PreviousCard"
	_reader_previous.disabled = index == 0
	controls.add_child(_reader_previous)
	_reader_next = _action("Próxima ›", _render_card.bind(index + 1))
	_reader_next.name = "NextCard"
	_reader_next.disabled = index == entries.size() - 1
	controls.add_child(_reader_next)
	_reader_gallery = _action("Voltar à galeria", func() -> void: handle_back())
	_reader_gallery.name = "ReturnToGallery"
	PlayerUI.style_back(_reader_gallery)
	info.add_child(_reader_gallery)
	_focus.call_deferred(_reader_gallery)
	_reveal()

func handle_back() -> bool:
	if is_instance_valid(_report_dialog):
		_close_report()
		return true
	if is_instance_valid(_editor_overlay):
		_close_framer()
		return true
	if _view == "submissions":
		_tab="Meus Decks"
		_render_library()
		return true
	if _view == "review":
		if _moderation(_draft) in ["pending_review","published","removed"]: _open_submissions()
		else: _render_editor()
		return true
	if _view == "editor":
		_draft = {}
		_tab = "Meus Decks"
		_render_library()
		return true
	if _view == "reader":
		var previous := _index
		_render_deck(_deck)
		if is_instance_valid(_grid) and previous < _grid.get_child_count():
			_focus.call_deferred(_grid.get_child(previous))
		return true
	if _view == "deck":
		var id := str(_deck.id)
		_render_library()
		var card := _results.get_node_or_null("Deck_" + id) as Control
		if card != null: _focus.call_deferred(card)
		_reveal()
		return true
	return false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _view != "reader" or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
		_render_card(_index + (-1 if event.keycode == KEY_LEFT else 1))
		get_viewport().set_input_as_handled()

func _action(text: String, callback: Callable) -> Button:
	var button := PlayerUI.button(text, callback)
	button.custom_minimum_size = Vector2(132, PlayerUI.SMALL_CONTROL_HEIGHT)
	button.add_theme_font_size_override("font_size", PlayerUI.SMALL_CONTROL_FONT)
	return button

func _text(value: String, font_size := 20, color := PlayerUI.TEXT) -> Label:
	return PlayerUI.label(value, font_size, color)

func _data_text(value: String, font_size := 20, color := PlayerUI.TEXT) -> Label:
	var label := _text(value, font_size, color)
	label.text = value
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _image(path: String) -> TextureRect:
	var image := TextureRect.new()
	image.texture = DeckCover.load_texture(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return image

func _reveal() -> void:
	# Animate the new content, so rapid card changes never accumulate body scale.
	for child: Control in body.get_children(): PlayerUI.reveal(child, 0.0, 0.18)

func animate_in() -> void:
	if _view == "library": PlayerUI.cascade(body)

func _focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree(): control.grab_focus()


# --- Favoritos, Meus Decks, editor e revisão (T21) --------------------------------------

func _store() -> DeckDrafts:
	if _drafts == null: _drafts = DeckDrafts.for_current()
	return _drafts


func _surface(card: Control, seed: int) -> void:
	var surface := ColorRect.new()
	surface.name = "Surface"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.show_behind_parent = false
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SURFACE_SHADER
	material.shader = shader
	material.set_shader_parameter("seed", float(seed))
	surface.material = material
	card.add_child(surface)
	card.move_child(surface, 0)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Hover suave: só um leve clareamento, sem brilho forte.
	card.mouse_entered.connect(func() -> void: card.create_tween().tween_property(card, "self_modulate", Color(1.06, 1.05, 1.02), 0.16))
	card.mouse_exited.connect(func() -> void: card.create_tween().tween_property(card, "self_modulate", Color.WHITE, 0.2))


func _heart(deck_id: String) -> Button:
	var heart := Button.new()
	heart.name = "Favorite"
	heart.toggle_mode = true
	heart.focus_mode = Control.FOCUS_ALL
	heart.custom_minimum_size = Vector2(44, 40)
	heart.button_pressed = _store().is_favorite(deck_id)
	heart.text = "♥" if heart.button_pressed else "♡"
	heart.tooltip_text = tr("Remover dos favoritos" if heart.button_pressed else "Adicionar aos favoritos")
	heart.add_theme_font_size_override("font_size", 22)
	heart.add_theme_color_override("font_color", PlayerUI.MUTED)
	heart.add_theme_color_override("font_pressed_color", Color("#e8817a"))
	heart.add_theme_color_override("font_hover_pressed_color", Color("#f09891"))
	heart.add_theme_color_override("font_hover_color", PlayerUI.TEXT)
	var flat := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]: heart.add_theme_stylebox_override(state, flat)
	heart.toggled.connect(func(value: bool) -> void:
		if not _store().set_favorite(deck_id, value):
			heart.set_pressed_no_signal(not value)
			banner.show_state("error", "Não foi possível salvar o favorito neste aparelho.")
			return
		heart.text = "♥" if value else "♡"
		heart.tooltip_text = tr("Remover dos favoritos" if value else "Adicionar aos favoritos")
		if _view == "library" and _tab == "Favoritos": _update_results.call_deferred()
		var sync := _sync()
		if sync.available():
			var result: Dictionary = await sync.set_remote_favorite(deck_id, value)
			if result.ok and not value: _store().clear_pending_favorite(deck_id)
			if not result.ok and is_inside_tree():
				banner.show_state("error", "Favorito salvo neste aparelho; a conta será atualizada na próxima conexão."))
	return heart


func _sync() -> CreatorSync:
	return CreatorSync.for_current(_store())


## Busca no servidor uma vez por visita; mostra carregando, erro e "Tentar novamente".
## Falha não repete sozinha: só pelo botão, para não martelar o servidor.
var _remote_error := {}
func _remote_section(kind: String) -> void:
	if not is_instance_valid(_results): return
	var sync := _sync()
	if not sync.available():
		_results.add_child(_text("Entre na conta para guardar também no servidor. Aqui tudo fica salvo neste aparelho.", 14, PlayerUI.MUTED))
		return
	if _remote_busy:
		var loading := _text("Sincronizando com a sua conta…", 14, PlayerUI.MUTED)
		loading.name = "RemoteLoading"
		_results.add_child(loading)
		return
	if _remote_error.has(kind):
		_results.add_child(_text(str(TranslationServer.translate("Não foi possível falar com o servidor (%s). Seus dados continuam salvos neste aparelho.")) % str(_remote_error[kind]), 14, Color("#ff9797")))
		var retry := _action("Tentar novamente", func() -> void:
			_remote_error.erase(kind)
			if kind == "decks": _pulled_decks = false
			else: _pulled_favorites = false
			_update_results())
		retry.name = "RetrySync"
		_results.add_child(retry)
		return
	if (_pulled_decks if kind == "decks" else _pulled_favorites): return
	_remote_busy = true
	var loading := _text("Sincronizando com a sua conta…", 14, PlayerUI.MUTED)
	loading.name = "RemoteLoading"
	_results.add_child(loading)
	var result: Dictionary
	if kind == "decks": result = await sync.pull()
	else: result = await sync.sync_favorites()
	_remote_busy = false
	if kind == "decks": _pulled_decks = true
	else: _pulled_favorites = true
	if not result.ok: _remote_error[kind] = str(result.get("code", "erro"))
	if is_inside_tree():
		if _view == "library": _update_results()
		elif _view == "submissions": _render_submissions()


func _confirm_delete(draft: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "ConfirmDeleteDraft"
	dialog.title = tr("Excluir rascunho")
	dialog.dialog_text = tr("Excluir \"%s\" deste aparelho e da sua conta? Não dá para desfazer.") % (str(draft.name) if not str(draft.name).is_empty() else tr("Sem nome"))
	dialog.ok_button_text = tr("Excluir")
	dialog.cancel_button_text = tr("Cancelar")
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		# Só o dono atual enxerga (e apaga) a própria pasta de rascunhos.
		# Servidor primeiro; a cópia local só sai depois que ele confirmar.
		var result: Dictionary = await _sync().remove(draft)
		if not result.ok: banner.show_state("error", "Não foi possível excluir na conta. O rascunho continua salvo; tente novamente.")
		_update_results())
	dialog.visibility_changed.connect(func() -> void: if not dialog.visible: dialog.queue_free())
	dialog.popup_centered()


func _render_editor() -> void:
	if _draft.is_empty(): _draft = _store().new_draft()
	if _moderation(_draft)=="removed":
		_page(str(_draft.name),"editor")
		var locked := _text("Este deck foi removido pela moderação. Consulte o status do envio.",22,PlayerUI.MUTED)
		locked.name="EditorLocked"
		body.add_child(locked)
		_reveal()
		return
	if _moderation(_draft) in ["pending_review", "published"]:
		_page(str(_draft.name), "editor")
		PlayerUI.standard_back($Margin/Column/Header/Back,"Meus Decks")
		var locked := _text(str(TranslationServer.translate("Este deck está %s. Para editar, retire-o da Comunidade primeiro.")) % (tr("em revisão") if _moderation(_draft) == "pending_review" else tr("publicado")), 18)
		locked.name = "EditorLocked"
		body.add_child(locked)
		var withdraw := _action("Retirar da Comunidade para editar", _unpublish_draft.bind(_draft))
		withdraw.name = "UnpublishDeck"
		withdraw.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		body.add_child(withdraw)
		_reveal()
		return
	_page(tr("Criar deck") if str(_draft.name).is_empty() else str(_draft.name), "editor")
	PlayerUI.standard_back($Margin/Column/Header/Back,"Meus Decks")
	body.add_theme_constant_override("separation",12)
	_review_feedback(body,_draft)
	var credit_info := PlayerUI.row(body)
	credit_info.name = "DeckCreationCredits"
	credit_info.visible = ReleaseFeatures.COMMERCE_ENABLED
	var commerce := services.cosmetic_shop
	credit_info.add_child(_text(str(TranslationServer.translate("Cartas de criação: "))+str(commerce.data.get("deck_credits","—"))+ (tr(" · 1 carta = 1 deck") if commerce.data.get("deck_credits_required",false) else tr(" · criação gratuita")),20,PlayerUI.MUTED))
	credit_info.add_child(PlayerUI.button("Cartas",func()->void:navigate_requested.emit("wallet",{"tab":"coins","category":"deck_credits"})))
	var metadata := PlayerUI.creator_panel(body)
	var form := PlayerUI.row(metadata)
	form.name="DeckForm"
	var identity := PlayerUI.column(form)
	var identity_label := PlayerUI.row(identity)
	identity_label.add_child(_text("NOME DO DECK *",20,PlayerUI.TEXT))
	var name_count := _text("%d/%d" % [str(_draft.name).length(),DeckDrafts.NAME_MAX],18,PlayerUI.MUTED)
	name_count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	identity_label.add_child(name_count)
	var name_field := _field(str(_draft.name),"Dê um nome ao seu deck",DeckDrafts.NAME_MAX)
	name_field.name="DeckName"
	PlayerUI.editor_control(name_field)
	name_field.text_changed.connect(func(value: String)->void:
		_draft.name=value
		name_count.text="%d/%d" % [value.length(),DeckDrafts.NAME_MAX])
	identity.add_child(name_field)
	var category := PlayerUI.column(form)
	category.add_child(_text("CATEGORIA *",20,PlayerUI.TEXT))
	var select := _options("DeckCategory",DeckDrafts.CATEGORIES,DeckDrafts.CATEGORIES,"category")
	PlayerUI.editor_control(select)
	category.add_child(select)
	var description_label := PlayerUI.row(metadata)
	description_label.add_child(_text("DESCRIÇÃO · OPCIONAL",20,PlayerUI.MUTED))
	var description_count := _text("%d/%d" % [str(_draft.description).length(),DeckDrafts.DESCRIPTION_MAX],18,PlayerUI.MUTED)
	description_count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	description_label.add_child(description_count)
	var description := TextEdit.new()
	description.name="DeckDescription"
	description.text=str(_draft.description)
	description.placeholder_text=tr("Conte em poucas palavras o tema do deck")
	description.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	description.set_meta("qse_max_length",DeckDrafts.DESCRIPTION_MAX)
	PlayerUI.editor_control(description)
	description.text_changed.connect(func()->void:
		_draft.description=description.text.left(DeckDrafts.DESCRIPTION_MAX)
		description_count.text="%d/%d" % [str(_draft.description).length(),DeckDrafts.DESCRIPTION_MAX])
	metadata.add_child(description)
	WebTextBridge.attach(description)
	var details := _action(("▾" if _editor_details_open else "▸")+tr(" Capa e referência visual · opcional"),func()->void:
		_editor_details_open=not _editor_details_open
		_render_editor())
	details.name="DeckDetails"
	PlayerUI.creator_action(details,"eye")
	body.add_child(details)
	var extra := PlayerUI.column(body)
	extra.name="DeckOptionalDetails"
	extra.visible=_editor_details_open
	var cover := _cover_section()
	extra.add_child(cover)
	extra.add_child(_text("VISIBILIDADE",20,PlayerUI.MUTED))
	extra.add_child(_options("DeckVisibility",["Privado","Não listado","Público"],DeckDrafts.VISIBILITY,"visibility"))
	extra.add_child(_text("REFERÊNCIA VISUAL",20,PlayerUI.MUTED))
	var references := StylePrompt.references()
	extra.add_child(_options("DeckStyleReference",references.map(func(item: Dictionary)->String:return str(item.name)),references.map(func(item: Dictionary)->String:return str(item.id)),"style_reference"))
	for node: Control in extra.find_children("*","Control",true,false):
		if node is BaseButton or node is LineEdit: PlayerUI.editor_control(node)
	var card_intro := PlayerUI.creator_panel(body)
	PlayerUI.creator_heading(card_intro,str(TranslationServer.translate("CARTAS · %d de %d")) % [_draft.cards.size(),Catalog.MAX_CARDS],"Adicione suas imagens e dê um nome a cada carta. Mínimo de 5 para revisão.","cards")
	PlayerUI.creator_progress(card_intro,_draft.cards.size(),Catalog.MAX_CARDS)
	_add_prompt_action()
	var list := PlayerUI.column(body)
	list.name="DraftCards"
	for i in range(_draft.cards.size()): list.add_child(_card_row(i))
	var actions := PlayerUI.row($Margin/Column)
	actions.name="DeckEditorActions"
	actions.size_flags_vertical=Control.SIZE_SHRINK_END
	var add := _action("Adicionar imagem",func()->void:
		_pending_card=-1
		_picker.pick())
	add.name="AddCard"
	add.disabled=_draft.cards.size()>=Catalog.MAX_CARDS
	actions.add_child(add)
	_picker.bind_button(add,func()->void:_pending_card=-1)
	var save := _action("Salvar rascunho",_save_draft)
	save.name="SaveDraft"
	actions.add_child(save)
	var review := _action("Revisar reenvio →" if _is_revision(_draft) else "Revisar deck →",func()->void:
		await _save_draft()
		_render_review())
	review.name="ReviewDeck"
	actions.add_child(review)
	for button: Button in [add,save,review]:
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		PlayerUI.creator_action(button,"plus" if button==add else ("inbox" if button==save else "chevron"),button==review)
	_reveal()


func _field(value: String, placeholder: String, limit: int) -> LineEdit:
	var field := LineEdit.new()
	field.text = value
	field.placeholder_text = tr(placeholder)
	field.max_length = limit
	field.custom_minimum_size.y = 44
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PlayerUI.style_field(field)
	return field


func _options(node_name: String, labels: Array, values: Array, key: String) -> OptionButton:
	var options := OptionButton.new()
	options.name = node_name
	options.custom_minimum_size.y = 44
	if key == "category": options.add_item(tr("Escolha…"))
	for label: String in labels: options.add_item(tr(label))
	var offset := 1 if key == "category" else 0
	options.select(values.find(str(_draft.get(key, ""))) + offset if values.has(str(_draft.get(key, ""))) else 0)
	options.item_selected.connect(func(index: int) -> void: _draft[key] = values[index - offset] if index - offset >= 0 else "")
	PlayerUI.style_row(options)
	return options


func _card_row(index: int) -> Control:
	var card: Dictionary = _draft.cards[index]
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	wrapper.name="DraftCard_%d" % index
	var surface := PlayerUI.creator_panel(wrapper)
	var row := PlayerUI.row(surface)
	row.add_theme_constant_override("separation",20)
	var preview := _store().preview_path(str(_draft.id),card)
	var thumb := PlayerUI.creator_picture(row,DeckCover.load_texture(preview),Vector2(126,176))
	thumb.name="Thumb"
	var fields := PlayerUI.column(row)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_field := _field(str(card.get("name", "")), "Nome da carta", DeckDrafts.CARD_NAME_MAX)
	name_field.name = "CardName"
	PlayerUI.editor_control(name_field)
	name_field.text_changed.connect(func(value: String) -> void: card.name = value)
	fields.add_child(name_field)
	var description := _field(str(card.get("description", "")), "Descrição (opcional)", DeckDrafts.CARD_DESCRIPTION_MAX)
	description.name = "CardDescription"
	PlayerUI.editor_control(description)
	description.text_changed.connect(func(value: String) -> void: card.description = value)
	fields.add_child(description)
	var tools := PlayerUI.row(surface)
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.custom_minimum_size.x = 0
	tools.add_theme_constant_override("separation", 6)
	var arrows := PlayerUI.row(tools)
	var up := _action("↑", _move_card.bind(index, -1))
	up.name = "MoveUp"
	up.custom_minimum_size.x = 80
	up.disabled = index == 0
	arrows.add_child(up)
	var down := _action("↓", _move_card.bind(index, 1))
	down.name = "MoveDown"
	down.custom_minimum_size.x = 80
	down.disabled = index == _draft.cards.size() - 1
	arrows.add_child(down)
	var frame := _action("Enquadrar", _open_framer.bind(index))
	frame.name = "FrameCard"
	frame.disabled = str(card.get("image_file", "")).is_empty()
	tools.add_child(frame)
	var replace := _action("Trocar imagem", func() -> void:
		_pending_card = index
		_picker.pick())
	replace.name = "ReplaceImage"
	tools.add_child(replace)
	_picker.bind_button(replace,func()->void:_pending_card=index)
	var remove := _action("Remover", func() -> void:
		_draft.cards.remove_at(index)
		_render_editor())
	remove.name = "RemoveCard"
	tools.add_child(remove)
	for button: Button in tools.find_children("*","Button",true,false):
		PlayerUI.editor_control(button)
		if button not in [up,down]:
			button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			PlayerUI.creator_action(button,"target" if button==frame else ("cards" if button==replace else "x"))
	return wrapper


func _move_card(index: int, direction: int) -> void:
	var target := index + direction
	if target < 0 or target >= _draft.cards.size(): return
	var card: Variant = _draft.cards[index]
	_draft.cards[index] = _draft.cards[target]
	_draft.cards[target] = card
	_render_editor()


## Capa (T24): Automática, Escolher carta ou Enviar imagem. A prévia mostra a capa resolvida
## (que volta para a automática sozinha se a carta/arquivo escolhido sumir).
func _cover_section() -> Control:
	var box := VBoxContainer.new()
	box.name = "CoverSection"
	box.add_theme_constant_override("separation", 6)
	box.add_child(_text("CAPA", 12, PlayerUI.GOLD))
	var resolved := DeckCover.resolve_draft(_store(), _draft)
	var preview := TextureRect.new()
	preview.name = "CoverPreview"
	preview.custom_minimum_size = Vector2(240, 150)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	preview.texture = DeckCover.framed(str(resolved.path), DeckCover.ASPECT, resolved.focus) if DeckCover.exists(str(resolved.path)) else null
	if preview.texture == null: _monogram(preview, str(_draft.get("name", "")))
	preview.name = "CoverPreview"
	box.add_child(preview)
	var hint := {"auto": "Automática: o jogo escolhe a carta mais representativa.", "card": "Carta escolhida por você.", "upload": "Imagem enviada por você."}
	var mode := str(resolved.mode)
	var note := PlayerUI.label(hint.get(mode, ""), 12, PlayerUI.MUTED)
	note.name = "CoverMode"
	note.set_meta("mode", mode)
	box.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var auto := _action("Automática", func() -> void: _set_cover({"mode": "auto"}))
	auto.name = "CoverAuto"
	row.add_child(auto)
	var upload := _action("Enviar imagem", func() -> void:
		_pending_card = -2
		_picker.pick())
	upload.name = "CoverUpload"
	row.add_child(upload)
	_picker.bind_button(upload,func()->void:_pending_card=-2)
	var cards: Array = _draft.get("cards", [])
	var pick := OptionButton.new()
	pick.name = "CoverCardPick"
	pick.add_item(tr("Escolher carta…"))
	for card: Dictionary in cards: pick.add_item(str(card.get("name", "")) if not str(card.get("name", "")).is_empty() else tr("Carta sem nome"))
	pick.disabled = cards.is_empty()
	if mode == "card":
		for i in cards.size(): if str(cards[i].id) == str(resolved.card_id): pick.select(i + 1)
	PremiumUI.style_outline(pick)
	pick.item_selected.connect(func(index: int) -> void:
		if index > 0: _set_cover({"mode": "card", "card_id": str(cards[index - 1].id)}))
	box.add_child(pick)
	return box


func _set_cover(choice: Dictionary) -> void:
	_draft.cover = choice
	if str(choice.get("mode", "")) != "upload": _store().remove_cover(str(_draft.id))
	_store().save(_draft)
	_render_editor()


func _open_cover_framer(image: Image, bytes: PackedByteArray, extension: String) -> void:
	_close_framer()
	_editor_overlay = CardFrameEditor.new()
	add_child(_editor_overlay)
	_editor_overlay.open(image, {}, CardFrameEditor.COVER_FORMATS)
	_editor_overlay.confirmed.connect(func(crops: Dictionary) -> void:
		if not _store().store_cover(str(_draft.id), image, crops.get("cover", {}), bytes, extension):
			banner.show_state("error", "Não foi possível guardar a capa neste aparelho.")
		else:
			_draft.cover = {"mode": "upload", "crop": crops.get("cover", {})}
			_store().save(_draft)
		_close_framer()
		_render_editor())
	_editor_overlay.cancelled.connect(func() -> void:
		_close_framer()
		_render_editor())


func _image_picked(image: Image, bytes: PackedByteArray, extension: String) -> void:
	if _view != "editor": return
	if _pending_card == -2:
		_pending_card = -1
		_open_cover_framer(image, bytes, extension)
		return
	var index := _pending_card
	if index < 0:
		if _draft.cards.size() >= Catalog.MAX_CARDS: return
		_draft.cards.append({"id": "card_%d_%d" % [Time.get_ticks_msec(), randi() % 1000], "name": "", "description": "", "image_file": "", "crops": {}})
		index = _draft.cards.size() - 1
	var card: Dictionary = _draft.cards[index]
	var file := _store().store_original(str(_draft.id), str(card.id), bytes, extension)
	if file.is_empty():
		banner.show_state("error", "Não foi possível guardar a imagem neste aparelho.")
		return
	card.image_file = file
	card.image_size = [image.get_width(), image.get_height()]
	card.crops = {}
	_open_framer(index, image)


func _open_framer(index: int, image: Image = null) -> void:
	var card: Dictionary = _draft.cards[index]
	if image == null: image = _store().original_image(str(_draft.id), card)
	if image == null:
		banner.show_state("error", "Imagem original não encontrada.")
		return
	_close_framer()
	_editor_overlay = CardFrameEditor.new()
	add_child(_editor_overlay)
	_editor_overlay.open(image, card.get("crops", {}))
	_editor_overlay.confirmed.connect(func(crops: Dictionary) -> void:
		card.crops = crops
		_store().store_previews(str(_draft.id), card, image)
		_close_framer()
		await _save_draft()
		_render_editor()
		_show_editor_card.call_deferred(index))
	_editor_overlay.cancelled.connect(func() -> void:
		_close_framer()
		_render_editor())


func _close_framer() -> void:
	if is_instance_valid(_editor_overlay): _editor_overlay.queue_free()
	_editor_overlay = null

func _show_editor_card(index: int) -> void:
	await get_tree().process_frame
	if _view!="editor" or not is_inside_tree(): return
	var card := find_child("DraftCard_%d" % index,true,false) as Control
	if card!=null: ($Margin/Column/Scroll as ScrollContainer).ensure_control_visible(card)


func _save_draft() -> void:
	var result := _store().save(_draft)
	if not result.ok:
		status(result)
		return
	var sync := _sync()
	if not sync.available():
		banner.show_state("success", "Rascunho salvo neste aparelho.")
		return
	banner.show_state("loading")
	_report(await sync.push(_draft))


func _report(result: Dictionary) -> void:
	if not is_inside_tree(): return
	if result.ok: banner.show_state("success", "Rascunho salvo neste aparelho e na sua conta.")
	elif result.code == "deck_incomplete": banner.show_state("success", "Salvo neste aparelho. " + CreatorSync.deck_ready(_draft if not _draft.is_empty() else {}))
	else: banner.show_state("error", "Salvo neste aparelho, mas não na conta (%s). Use \"Tentar novamente\" no menu ⋯ do rascunho em Meus Decks." % str(result.code))


func _render_review() -> void:
	_page(tr("Revisar deck"), "review")
	$Margin/Column/Scroll.scroll_vertical=0
	PlayerUI.standard_back($Margin/Column/Header/Back,"Editar")
	var problems := DeckDrafts.problems(_draft)
	var layout := PlayerUI.row(body)
	layout.add_theme_constant_override("separation",20)
	var sidebar := PlayerUI.column(layout)
	sidebar.custom_minimum_size.x=340
	sidebar.size_flags_horizontal=Control.SIZE_FILL
	_draft_summary(sidebar,_draft)
	_add_prompt_action(sidebar,true)
	_review_feedback(sidebar,_draft)
	if not problems.is_empty():
		var warning := PlayerUI.creator_panel(sidebar,"warning",16)
		PlayerUI.creator_heading(warning,"Antes de publicar","Complete os itens abaixo.","info")
		for problem: String in problems: _submission_text(warning,"• "+problem,"DeckValidationIssue",Color("#ffb1bc"),20)
	var gallery := PlayerUI.creator_panel(layout)
	PlayerUI.creator_heading(gallery,"Confira as cartas do seu deck","Revise imagens, nomes e tema antes de enviar.","eye")
	_grid = GridContainer.new()
	_grid.name = "ReviewGallery"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	gallery.add_child(_grid)
	_grid.columns=clampi(floori((_physical_size().x-480)/130),2,8)
	for card: Dictionary in _draft.cards:
		var column := PlayerUI.column(_grid)
		column.add_theme_constant_override("separation",8)
		var preview := _store().preview_path(str(_draft.id),card)
		PlayerUI.creator_picture(column,DeckCover.load_texture(preview),Vector2(118,166))
		var title := _submission_text(column,str(card.get("name","")),"ReviewCardName",PlayerUI.TEXT,20)
		title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		title.custom_minimum_size.x=118
	var moderation := _moderation(_draft)
	var publish := _action("Reenviar para revisão · grátis" if _is_revision(_draft) else "Enviar para revisão · grátis", _publish_draft.bind(_draft))
	publish.name = "PublishDeck"
	publish.disabled = not problems.is_empty() or moderation in ["pending_review", "published", "removed"] or not _sync().available()
	var footer := PlayerUI.column($Margin/Column)
	footer.name="DeckEditorActions"
	footer.add_theme_constant_override("separation",8)
	var actions := PlayerUI.row(footer)
	PlayerUI.creator_action(publish,"send",true)
	publish.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions.add_child(publish)
	var note: String = {"pending_review": "Em revisão pela moderação. Ele aparece na Comunidade quando for aprovado.",
		"published": "Publicado na Comunidade.", "removed": "Removido pela moderação."}.get(moderation,
		"Ao publicar, o deck vai para revisão antes de aparecer para outros jogadores." if _sync().available() else "Entre na conta para publicar na Comunidade.")
	var note_label := _text(note,20,PlayerUI.MUTED)
	note_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	note_label.name = "PublishNote"
	footer.add_child(note_label)
	var track := _action("Acompanhar envio",_open_submissions)
	track.name="TrackDeckSubmission"
	PlayerUI.creator_action(track,"clock")
	actions.add_child(track)
	_reveal()

func _add_prompt_action(parent: Node=null, stacked:=false) -> void:
	var panel := PlayerUI.creator_panel(parent if parent!=null else body,"accent",14)
	panel.name="DeckPromptPanel"
	var line := PlayerUI.row(panel)
	var caption := PlayerUI.column(line)
	if stacked:
		caption.add_theme_constant_override("separation",4)
		caption.add_child(_text("Prompt para IA",22))
		caption.add_child(_text("3D · 9:16",20,PlayerUI.MUTED))
	else:
		PlayerUI.creator_heading(caption,"Prompt para IA","Gere suas imagens em 3D cinematográfico · vertical 9:16.","bolt")
	var prompt := _action("Copiar" if stacked else "Copiar prompt",_copy_style_prompt)
	prompt.name="CopyDeckStylePrompt"
	PlayerUI.creator_action(prompt,"copy")
	prompt.custom_minimum_size.x=144 if stacked else 232
	line.add_child(prompt)

func _copy_style_prompt() -> void:
	DisplayServer.clipboard_set(StylePrompt.build(_draft))
	banner.show_state("success","Prompt copiado! Cole na sua IA para gerar as imagens das cartas.")

func _open_manual_review() -> void:
	if get_node_or_null("DeckManualReview")!=null: return
	var review := preload("res://scripts/decks/deck_review_screen.gd").new()
	review.setup(preload("res://scripts/decks/deck_review_service.gd").new())
	add_child(review)


## A posse oficial pertence à conta GAME, não aos favoritos ou ao cache local.
func _rewards_updated() -> void:
	if not is_visible_in_tree(): return
	if _view == "library" and is_instance_valid(_results): _update_results()
	elif _view == "deck" and bool(_deck.get("official", false)) and not _deck.is_empty(): _render_deck(_deck)


func _open_rewards() -> void:
	if get_node_or_null("OfficialRewardsOverlay") != null: return
	var overlay := NewsOverlay.new()
	overlay.name = "OfficialRewardsOverlay"
	add_child(overlay)


func _pull_owned() -> void:
	var result := await services.community_decks.refresh()
	if is_inside_tree() and result.ok and _view=="library": _update_results()

func _claim_community(id: String) -> void:
	var epoch := _moderation_generation
	if _claim_busy: return
	_claim_busy=true
	var button := find_child("RedeemCommunityDeck",true,false) as Button
	if button!=null:
		button.disabled=true
		button.text=tr("Resgatando…")
	banner.show_state("loading",tr("Preparando seu deck. Aguarde a confirmação."))
	var result := await services.community_decks.claim(id)
	if epoch!=_moderation_generation: return
	_claim_busy=false
	if not is_inside_tree(): return
	if is_instance_valid(button):
		button.disabled=false
		button.text=tr("RESGATAR GRÁTIS")
	if result.ok:
		if _view=="deck" and str(_deck.get("id",""))==id: _render_deck(_deck)
		banner.show_state("success",tr("Deck guardado na sua conta e liberado no Mata-Mata.") if result.data.inventory_refreshed else tr("Resgate confirmado. Atualize Meus Decks para carregar as cartas."))
	else: banner.show_state("error",tr("Resgate não concluído: ")+CommunityService.message(str(result.code)))

func _open_owned(ref: String) -> void:
	banner.show_state("loading",tr("Carregando as cartas do seu deck…"))
	var result := await services.community_decks.open_owned(ref)
	if not is_inside_tree(): return
	if result.ok:
		_render_deck(result.data)
		banner.hide()
	else: banner.show_state("error",CommunityService.message(str(result.code)))
