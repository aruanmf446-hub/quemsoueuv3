extends "res://scripts/desert/t15d/cactus.gd"
signal hit_received(amount: int)
## Boss-only animation/limited landing movement; campaign still owns damage and Tasks.
var stunned:=false
var throw_serial:=0
var _home:=Vector3.ZERO
var _time:=0.0
var _action_left:=0.0
var _throw_left:=0.0
var _held: Node3D
var _kind:="green"
func setup(entry: Dictionary,spawn: Dictionary)->void:
 super.setup(entry,spawn)
 _home=position
 _model.play_animation("base",true)
 _refill_bottle()
func _refill_bottle()->void:
 if is_instance_valid(_held):_held.queue_free()
 _held=preload("res://scripts/desert/malagueta/bottle.gd").new();_held.kind=_kind;add_child(_held)
func throwing()->bool:return _throw_left>0.0
func throw_bottle(kind: String)->bool:
 if stunned or _state==State.DEAD or _action_left>0 or crystallized_left>0:return false
 throw_serial+=1
 _kind=kind;_refill_bottle()
 _action_left=_model.animation_length(&"throw")/1.4
 _throw_left=_action_left
 _model.play_animation("throw",false)
 return true
func hand_position()->Vector3:
 var socket:=_model.get_socket(&"hand_right")
 return socket.global_position if socket!=null else global_position+Vector3.UP
func set_stunned(value: bool)->void:
 stunned=value;_action_left=0;_throw_left=0;throw_serial+=1
 if is_instance_valid(_held):_held.visible=not value
 _model.play_animation("dizzy" if value else "base",true)
func _physics_process(delta: float)->void:
 if _state==State.DEAD:return
 if crystallized_left>0:
  crystallized_left=maxf(0,crystallized_left-delta);_model.set_rate(0.0)
  if crystallized_left<=0:
   if is_instance_valid(_crystal):_crystal.finish()
   _model.set_rate(1.0)
  return
 _model.set_rate(1.0)
 _time+=delta
 var previous:=_action_left
 _action_left=maxf(0,_action_left-delta)
 _throw_left=maxf(0,_throw_left-delta)
 if is_instance_valid(_held):
  var socket:=_model.get_socket(&"hand_right")
  if socket!=null:_held.global_transform=socket.global_transform.orthonormalized()
  _held.visible=not stunned and (_throw_left<=0.0 or (_model.animation_length(&"throw")/1.4-_throw_left)<0.65)
 if stunned:return
 var player:=get_tree().get_first_node_in_group("player") as Node3D
 if player!=null and not throwing():_model.rotation.y=PI*0.5*signf(player.global_position.x-global_position.x)
 if _action_left>0:return
 if previous>0:_model.play_animation("base",true)
 # Short walks stay entirely on the existing upper landing; never move the skeleton root.
 if fmod(_time,6.5)>3.0:
  var away:=player!=null and absf(player.global_position.x-global_position.x)<2.5
  var destination:=_home.x+0.65 if away else _home.x-0.45
  var old:=position.x;position.x=move_toward(position.x,destination,delta*0.4)
  if absf(position.x-old)>0.0001:
   _model.rotation.y=PI*0.5*signf(position.x-old)
   _model.play_animation("retreat" if away else "carry",true)
   _model.set_rate(0.55)
  else:_model.play_animation("base",true)
 else:_model.play_animation("base",true)
func take_damage(amount: int)->void:
 if amount<=0 or _state==State.DEAD:return
 hit_received.emit(amount)
 if not stunned:
  throw_serial+=1
  _action_left=0.45;_throw_left=0
  _model.play_animation("hurt",false)
func crystallize(seconds: float)->void:
 super.crystallize(seconds)
 _action_left=0;_throw_left=0;throw_serial+=1
func defeat()->void:
 if _state==State.DEAD:return
 _action_left=0;_throw_left=0
 if is_instance_valid(_held):_held.hide()
 health=0;_die()
