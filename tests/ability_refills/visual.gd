extends Control
## Exact pause overlay and player rules on a lightweight labelled test background.
var _player: Node
var _session: CanvasLayer
var _order := 5
var _paused := true
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var bg:=ColorRect.new();bg.color=PlayerUI.INTERIOR_BG;add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var marker:=PlayerUI.label("Configurações da fase · validação visual",22,PlayerUI.MUTED);marker.autowrap_mode=TextServer.AUTOWRAP_OFF;marker.position=Vector2(30,25);add_child(marker)
 _player=preload("res://scripts/desert/t15d/player.gd").new()
 _player.attack_charges=3;_player.defense_charges=0
 _player.abilities={"amber":0,"dash":1,"rupture":3}
 _player.discovered={"attack":true,"defense":true,"amber":true,"dash":true,"rupture":true}
 _session=preload("res://scripts/desert/t15d/session_overlay.gd").new();add_child(_session)
 _session.order=5;_session.phase_name="Jardins do Oásis"
 _session.resume_requested.connect(_resume)
 _session.show_pause()
 get_tree().paused=true
func _sync_resources() -> void:pass
func _resume() -> void:
 if _session.operation_busy:return
 _paused=false;get_tree().paused=false;_session.close()
func _exit_tree() -> void:
 if is_instance_valid(_player):_player.free()
 if get_tree()!=null:get_tree().paused=false
