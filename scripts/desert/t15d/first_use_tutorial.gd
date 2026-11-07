extends CanvasLayer
## Lições iniciais locais por perfil. Marcar como vistas só depois de continuar.
signal opened(kind: String)
signal closed(kind: String)
const SAVE_PATH := "user://desert_first_use_v1.cfg"
const LESSONS := {
 "attack":["Seu primeiro ataque","Você começa sem cargas de ataque ou defesa. Pegue uma recarga de fogo e toque no botão de chama para dar um soco nos cactos. Cada golpe usa uma carga. No teclado: J."],
 "defense":["Sua primeira defesa","O soldado à frente vai arremessar uma lança. Toque no escudo quando ela vier para bloquear (Shift). Cada defesa usa uma carga.\nVocê também pode pular ou agachar para desviar. Ele só persegue depois de acertar você ou o escudo."],
 "task":["Sua primeira Task","Este caminho depende de uma tarefa do cenário. Toque em TASK, acima do ataque, para executar a ação indicada. O botão só aparece perto das tarefas e some depois. Não usa cargas de ataque ou defesa. No teclado: F."],
 "amber":["Âmbar · congele quem vem atrás","Imobilize os cactos atrás de você por alguns segundos. Toque no botão de Âmbar ou use E.\nCada uso gasta 1 carga. Pegue outra recarga para usar de novo."],
 "dash":["Relâmpago · avance com choque","Corra mais rápido e dê choque nos cactos que tocar. Toque no botão de Relâmpago ou use R.\nCada uso gasta 1 carga. Pegue outra recarga para usar de novo."],
 "rupture":["Ruptura · abra caminho atrás","Rompa o piso marcado atrás de você para atrasar os cactos. Toque no botão de Ruptura ou use Q.\nCada uso gasta 1 carga; o piso se recompõe após 8 segundos."]}
var active := false
var kind := ""
var _was_paused := false
var _root: Control
var _title: Label
var _body: Label
var _continue: Button
var _illustration: TextureRect
var _panel: PanelContainer
var _section := "guest"
var _seen := {}
func _save_key(lesson: String) -> String:
	return "defense_spear_v1" if lesson=="defense" else lesson
func _web_key(lesson: String) -> String:
	return JSON.stringify("qse-desert-first-use-v1:"+_section+":"+_save_key(lesson))
func _ready() -> void:
	layer=100
	process_mode=Node.PROCESS_MODE_ALWAYS
	if PlayerServices.current!=null:
		_section=str(PlayerServices.current.session.user.get("id","guest"))
	_root=Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	PlayerUI.apply_theme(_root)
	add_child(_root)
	var shade:=ColorRect.new()
	shade.color=PlayerUI.INTERIOR_BG
	shade.color.a=0.78
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel:=PanelContainer.new()
	_panel=panel
	panel.custom_minimum_size=Vector2(660,380)
	panel.add_theme_stylebox_override("panel",PlayerUI.plate())
	center.add_child(panel)
	var margins:=MarginContainer.new()
	for edge in ["left","top","right","bottom"]:margins.add_theme_constant_override("margin_"+edge,24)
	panel.add_child(margins)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",20)
	margins.add_child(column)
	_title=Label.new()
	_title.add_theme_font_size_override("font_size",32)
	column.add_child(_title)
	_illustration=TextureRect.new()
	_illustration.custom_minimum_size=Vector2(600,180)
	_illustration.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_illustration.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_illustration.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_illustration.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_illustration.hide()
	column.add_child(_illustration)
	_body=Label.new()
	_body.custom_minimum_size=Vector2(600,0)
	_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size",24)
	_body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(_body)
	_continue=PlayerUI.button("Entendi · Continuar",dismiss)
	PlayerUI.style_button(_continue,true)
	column.add_child(_continue)
	_root.hide()
func seen(lesson: String) -> bool:
	if _seen.has(lesson):return bool(_seen[lesson])
	var config:=ConfigFile.new()
	var value:=config.load(SAVE_PATH)==OK and bool(config.get_value(_section,_save_key(lesson),false))
	if OS.has_feature("web"):
		value=value or bool(JavaScriptBridge.eval("(()=>{try{return localStorage.getItem("+_web_key(lesson)+")==='1';}catch(e){return false;}})()"))
	_seen[lesson]=value
	return value
func present(lesson: String,context := "") -> void:
	if active or not LESSONS.has(lesson) or seen(lesson):return
	kind=lesson
	active=true
	_was_paused=get_tree().paused
	_title.text=LESSONS[lesson][0]
	_body.text=LESSONS[lesson][1]
	var art_path:="res://assets/desert/tutorial/"+lesson+".res"
	_illustration.texture=load(art_path) if lesson in ["defense","amber","dash","rupture"] and ResourceLoader.exists(art_path) else null
	_illustration.visible=_illustration.texture!=null
	_panel.custom_minimum_size.y=540 if _illustration.visible else 380
	_panel.reset_size()
	if not context.is_empty():_body.text+="\n\n"+context
	_root.show()
	opened.emit(lesson)
	get_tree().paused=true
	_continue.grab_focus()
func import_seen(kinds: Array) -> void:
	var config:=ConfigFile.new()
	config.load(SAVE_PATH)
	for value: Variant in kinds:
		var lesson:=str(value)
		if not LESSONS.has(lesson):continue
		_seen[lesson]=true
		config.set_value(_section,_save_key(lesson),true)
		if OS.has_feature("web"):JavaScriptBridge.eval("try{localStorage.setItem("+_web_key(lesson)+",'1');}catch(e){}")
	config.save(SAVE_PATH)
func dismiss() -> void:
	if not active:return
	var config:=ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value(_section,_save_key(kind),true)
	config.save(SAVE_PATH)
	_seen[kind]=true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem("+_web_key(kind)+",'1');}catch(e){}")
	var completed:=kind
	active=false
	_root.hide()
	get_viewport().gui_release_focus()
	get_tree().paused=_was_paused
	closed.emit(completed)
func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
func _exit_tree() -> void:
	if active:get_tree().paused=_was_paused
