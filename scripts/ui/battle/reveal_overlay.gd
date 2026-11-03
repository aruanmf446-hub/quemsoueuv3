class_name RevealOverlay
extends Control
## Revelação da carta escolhida, no meio da tela (todas as plataformas):
## 1) a carta aparece grande com brilho + som de escolha ("Mona Lisa selecionada");
## 2) "Jogadores atingidos": cada nome entra um a um com ✕ (perdeu uma vida) ou caveira
##    (eliminado), com som de atingido/eliminado;
## 3) rodapé "N jogadores eliminados" ou "Ninguém foi atingido".
## Some sozinha (não bloqueia toques na partida). Só apresenta o que o servidor já revelou (event.hits).
const Style = preload("res://scripts/ui/battle/battle_style.gd")
const SFX_PICK := preload("res://assets/audio/sfx/battle_pick.wav")
const SFX_HIT := preload("res://assets/audio/sfx/battle_hit.wav")
const SFX_ELIMINATE := preload("res://assets/audio/sfx/battle_eliminate.wav")
const RED := Color("#ff7a6e")
const STEP := 0.32

var _audio: AudioStreamPlayer
var _closing := false


## hits: [{name, eliminated}] na ordem do servidor.
func present(card_id: String, card_name: String, hits: Array) -> void:
	name = "RevealOverlay"
	# Não segura toques: a partida continua (o turno corre); o painel some sozinho.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20
	_audio = AudioStreamPlayer.new()
	_audio.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_audio)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	# Carta escolhida, grande.
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 8)
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(card_box)
	var frame := PanelContainer.new()
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0.05, 0.06, 0.09)
	glow.border_color = PlayerUI.GOLD
	glow.set_border_width_all(3)
	glow.set_corner_radius_all(10)
	glow.shadow_color = Color(PlayerUI.GOLD, 0.55)
	glow.shadow_size = 22
	frame.add_theme_stylebox_override("panel", glow)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_box.add_child(frame)
	var art := TextureRect.new()
	art.name = "RevealCard"
	art.texture = DuelService.card_texture(card_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(230, 300)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)
	var picked := Style.label("%s selecionada" % card_name, 24, PlayerUI.GOLD)
	picked.name = "RevealTitle"
	Style.strong(picked)
	picked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picked.custom_minimum_size.x = 230
	picked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_box.add_child(picked)
	# Lista de atingidos.
	var list := VBoxContainer.new()
	list.name = "RevealHits"
	list.add_theme_constant_override("separation", 8)
	list.custom_minimum_size.x = 300
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(list)
	var heading := Style.label("Jogadores atingidos" if not hits.is_empty() else "", 24, Color.WHITE)
	Style.strong(heading)
	heading.visible = not hits.is_empty()
	list.add_child(heading)
	var rows: Array[Control] = []
	for hit: Dictionary in hits:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var who := Style.label(str(hit.get("name", "Jogador")), 26, Color.WHITE)
		who.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		who.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.add_child(who)
		var mark := TextureRect.new()
		mark.name = "Eliminated" if bool(hit.get("eliminated", false)) else "LostLife"
		mark.texture = PremiumUI.icon("skull" if bool(hit.get("eliminated", false)) else "x", Color("#f2f2f2") if bool(hit.get("eliminated", false)) else RED, 64)
		mark.custom_minimum_size = Vector2(32, 32)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(mark)
		line.modulate.a = 0.0
		list.add_child(line)
		rows.append(line)
	var eliminated := hits.filter(func(h: Dictionary) -> bool: return bool(h.get("eliminated", false))).size()
	var footer_text := "Ninguém foi atingido" if hits.is_empty() else ("%d jogador%s eliminado%s" % [eliminated, "" if eliminated == 1 else "es", "" if eliminated == 1 else "s"] if eliminated > 0 else "%d jogador%s perdeu%s uma vida" % [hits.size(), "" if hits.size() == 1 else "es", "" if hits.size() == 1 else "ram"])
	var footer := Style.label(footer_text, 22, RED if eliminated > 0 else PlayerUI.MUTED if hits.is_empty() else Color.WHITE)
	footer.name = "RevealSummary"
	Style.strong(footer)
	footer.modulate.a = 0.0
	list.add_child(footer)
	# Animação.
	modulate.a = 0.0
	frame.pivot_offset = art.custom_minimum_size * 0.5
	frame.scale = Vector2.ONE * 0.6
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(frame, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_play.bind(SFX_PICK)).set_delay(0.0)
	tween.tween_interval(0.55)
	for index in rows.size():
		var line := rows[index]
		var dead := bool(hits[index].get("eliminated", false))
		tween.tween_callback(_play.bind(SFX_ELIMINATE if dead else SFX_HIT))
		tween.tween_property(line, "modulate:a", 1.0, 0.16)
		tween.tween_interval(STEP)
	tween.tween_property(footer, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.0 if not hits.is_empty() else 1.6)
	tween.tween_callback(close)


func _play(stream: AudioStream) -> void:
	if not is_instance_valid(_audio): return
	_audio.stream = stream
	_audio.play()


func close() -> void:
	if _closing: return
	_closing = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		close()
		accept_event()
