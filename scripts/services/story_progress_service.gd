class_name StoryProgressService
extends Node
## Sincroniza avanço e partida da campanha, separados de economia e recompensas.
signal changed
const Local=preload("res://scripts/desert/t15d/campaign_progress.gd")
const Run=preload("res://scripts/desert/t15d/campaign_run.gd")
var client: SupabaseClient
var session: SessionService
var state:="empty"
var notice:=""
var _owner:=""
var _epoch:=0
var _busy:=false
var _pending:=false
var _toast: CanvasLayer
var run_state:="local"
func set_scope() -> void:
	_epoch+=1
	_owner=OwnerStorage.owner_id()
	notice=""
	state="local"
	if is_instance_valid(_toast):_toast.queue_free()
	if not _owner.is_empty():
		Local.adopt_guest(_owner)
		Run.adopt_guest(_owner)
		sync.call_deferred()
	changed.emit()
func sync() -> void:
	if _owner.is_empty() or not session.authenticated():return
	if _busy:
		_pending=true
		return
	_busy=true
	for attempt in 2:
		_pending=false
		var owner:=_owner
		var epoch:=_epoch
		var highest:=Local.highest_for(owner)
		state="loading"
		changed.emit()
		var result:=await client.call_rpc("qse_story_progress_sync",{"p_completed":highest})
		if epoch==_epoch and owner==OwnerStorage.owner_id():
			var value: Variant=result.get("data")
			if result.ok and _valid(value,highest):
				var previous:=int(value.previous_completed)
				var merged:=int(value.highest_completed)
				var saved:=Local.merge_highest(owner,merged)
				state="success" if saved==OK else "offline"
				if merged>highest or (highest>0 and previous>0 and previous!=highest):
					notice="Avanços diferentes encontrados. Mantida automaticamente a fase %d." % mini(merged+1,10) if highest>0 else "Progresso da conta recuperado: fase %d." % mini(merged+1,10)
					_show_notice()
				# Uma vitória pode acontecer enquanto a requisição estava em voo.
				if Local.highest_for(owner)>merged:_pending=true
			else:state="offline"
			await _sync_run(owner,epoch)
			changed.emit()
		if not _pending:break
	_busy=false
	if _pending:sync.call_deferred()
func _sync_run(owner: String,epoch: int) -> void:
	if epoch!=_epoch or owner!=OwnerStorage.owner_id():return
	var record:=Run.read(owner)
	var sent: Dictionary=record.state.duplicate(true)
	run_state="loading"
	var result:=await client.call_rpc("qse_story_run_sync",{"p_state":sent if record.pending else null,"p_revision":int(record.revision),"p_completed":Local.highest_for(owner),"p_intent":str(record.intent)})
	if epoch!=_epoch or owner!=OwnerStorage.owner_id():return
	var value: Variant=result.get("data")
	if result.ok and value is Dictionary and value.get("schema_version")==1 and (value.get("revision") is float or value.get("revision") is int):
		if (value.get("highest_completed") is float or value.get("highest_completed") is int) and int(value.highest_completed)>=Local.highest_for(owner) and int(value.highest_completed)<=10:Local.merge_highest(owner,int(value.highest_completed))
		if value.get("state")==null:
			run_state="success"
		elif Run.valid(value.get("state")):
			Run.accept(owner,value,sent)
			var pending:=Run.read(owner)
			if pending.pending and pending.state.get("run_id")!=sent.get("run_id"):_pending=true
			run_state="success"
		else:run_state="offline"
	else:run_state="offline"
func prepare_run() -> void:
	if _owner.is_empty() or not session.authenticated():return
	var deadline:=Time.get_ticks_msec()+4500
	if not _busy:sync.call_deferred()
	await get_tree().process_frame
	while _busy and Time.get_ticks_msec()<deadline:await get_tree().process_frame
func _valid(value: Variant,sent: int) -> bool:
	if not value is Dictionary or value.get("schema_version")!=1:return false
	for key in ["highest_completed","previous_completed","revision"]:
		if not value.get(key) is int and not value.get(key) is float:return false
		if float(value[key])!=floorf(float(value[key])):return false
	return int(value.highest_completed)>=sent and int(value.highest_completed)<=10 and int(value.previous_completed)>=0 and int(value.previous_completed)<=int(value.highest_completed) and int(value.revision)>=1
func _show_notice() -> void:
	if is_instance_valid(_toast):_toast.queue_free()
	_toast=CanvasLayer.new()
	_toast.layer=150
	add_child(_toast)
	var panel:=PanelContainer.new()
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left=-330
	panel.offset_right=330
	panel.offset_top=-100
	panel.offset_bottom=-32
	PlayerUI.apply_theme(panel)
	panel.add_theme_stylebox_override("panel",PlayerUI.frame_panel(10))
	_toast.add_child(panel)
	var label:=PlayerUI.label(notice,20)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	# Callable do próprio aviso desconecta ao ser removido por uma troca de conta.
	get_tree().create_timer(6.0,true).timeout.connect(_toast.queue_free)
func dismiss_toast() -> void:
	if is_instance_valid(_toast):_toast.queue_free()
