extends Node
## Fixture local sem rede, conta ou progresso real. Mesmas Configurações e fases do jogo.
const ServicesFixture=preload("res://tests/story_continuity/account_merge.gd")
const Scheme=preload("res://scripts/desert/t15d/control_scheme.gd")
class OfflineSession extends SessionService:
 func _ready() -> void:set_process(false)
var services: PlayerServices
var settings: PlayerScreen
var phase: Node3D
var callback: JavaScriptObject
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 services=ServicesFixture.TestServices.new()
 add_child(services)
 services.preferences=DevicePreferences.new()
 services.add_child(services.preferences)
 services.session=OfflineSession.new()
 services.add_child(services.session)
 services.profile=ProfileService.new()
 services.add_child(services.profile)
 show_settings()
 if OS.has_feature("web") and OS.has_feature("control_modes_fixture"):
  callback=JavaScriptBridge.create_callback(probe)
  JavaScriptBridge.get_interface("window").qseControlProbe=callback
func show_settings() -> void:
 if is_instance_valid(phase):phase.free()
 if is_instance_valid(settings):settings.free()
 settings=load("res://scenes/player/settings.tscn").instantiate()
 settings._category=3
 add_child(settings)
 settings.show_screen()
func play() -> void:
 settings.hide()
 phase=load("res://scenes/desert/phase_01.tscn").instantiate()
 phase.process_mode=Node.PROCESS_MODE_PAUSABLE
 add_child(phase)
 phase.set_physics_process(false)
 phase._player._invulnerable=999
 phase._player.attack_charges=3
 phase._player.defense_charges=3
 for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
 get_viewport().gui_release_focus()
func state() -> Dictionary:
 var result:={"tick":Engine.get_physics_frames(),"mode":Scheme.mode,"preference":services.preferences.values.control_mode,"play":is_instance_valid(phase)}
 if is_instance_valid(settings) and settings.is_visible_in_tree():
  var option: OptionButton=settings.find_child("ControlMode",true,false)
  var rect:=option.get_global_rect()
  var size:=get_viewport().get_visible_rect().size
  result.option=[rect.get_center().x/size.x,rect.get_center().y/size.y]
  result.popup=option.get_popup().visible
  result.selected=option.selected
  result.focused=option.get_popup().get_focused_item()
 if is_instance_valid(phase):
  result.touch=phase._touch_pad.visible
  result.paused=phase._paused
  result.menu={}
  var viewport_size:=get_viewport().get_visible_rect().size
  if phase._session.opened:
   for button in phase._session._column.get_children():
    if button is Button:
     var center: Vector2=button.get_global_rect().get_center()
     result.menu[button.text]=[center.x/viewport_size.x,center.y/viewport_size.y]
   var option: OptionButton=phase._session.find_child("ControlMode",true,false)
   if option!=null:
    var center:=option.get_global_rect().get_center()
    result.option=[center.x/viewport_size.x,center.y/viewport_size.y]
    result.popup=option.get_popup().visible
    result.selected=option.selected
    result.focused=option.get_popup().get_focused_item()
  result.actor={"x":phase._player.position.x,"floor":phase._player.is_on_floor(),"jumps":phase._player.jumps_used,"attack":phase._player.attack_charges,"defense":phase._player.defense_charges,"defending":phase._player.is_defending}
  var size:=get_viewport().get_visible_rect().size
  var spec: Array=phase._touch_pad._buttons.defend
  result.defend_button=[spec[0].x/size.x,spec[0].y/size.y]
  result.stick=[phase._touch_pad._base.x/size.x,phase._touch_pad._base.y/size.y,phase._touch_pad._radius/size.x]
 return result
func probe(args: Array) -> void:
 var command:=str(args[0]) if args.size()>0 else "state"
 if command=="play":play()
 if command=="settings":show_settings()
 if command=="pause-settings" and is_instance_valid(phase):
  phase._pause()
  phase._session.show_settings()
 if command=="resume" and is_instance_valid(phase):phase._resume()
 JavaScriptBridge.eval("window.qseControlState="+JSON.stringify(state()))
