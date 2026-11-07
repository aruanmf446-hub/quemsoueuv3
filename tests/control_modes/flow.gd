extends SceneTree
const Scheme=preload("res://scripts/desert/t15d/control_scheme.gd")
var checks:=0
var failures:=0
var fixture: Node
var output:=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1
 print(("PASS " if ok else "FAIL ")+label)
func ticks(n: int) -> void:
 for i in n:await physics_frame
func key(code: Key,pressed: bool) -> void:
 var event:=InputEventKey.new()
 event.physical_keycode=code
 event.keycode=code
 event.pressed=pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 await process_frame
 await ticks(2)
func set_mode(mode: String) -> void:
 check(fixture.services.preferences.set_preference("control_mode",mode),"escolha %s salva" % mode)
 await ticks(2)
func snap(name: String) -> void:
 if output.is_empty():return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_jpg(output+"/"+name+".jpg",0.94)
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()>=2:
  output=args[0]
  DirAccess.make_dir_recursive_absolute(output)
  var dims:=args[1].split("x")
  root.size=Vector2i(int(dims[0]),int(dims[1]))
 fixture=preload("res://tests/control_modes/fixture.gd").new()
 root.add_child(fixture)
 await ticks(10)
 check(fixture.settings.find_child("ControlMode",true,false)!=null,"Configurações tem seletor real de modos")
 await snap("01_configuracoes")
 await set_mode("keyboard")
 fixture.play()
 await ticks(20)
 var player: CharacterBody3D=fixture.phase._player
 check(not fixture.phase._touch_pad.visible,"somente teclado oculta o joystick e os botões de toque")
 await key(KEY_K,true)
 await key(KEY_K,false)
 check(player.is_defending and player.defense_charges==2,"somente teclado defende com K")
 await snap("02_teclado")
 player._shield_timer=0
 player.is_defending=false
 await set_mode("touch")
 check(fixture.phase._touch_pad.visible,"modo toque mostra botões mesmo no computador")
 await key(KEY_D,true)
 var x: float=player.position.x
 await ticks(20)
 check(absf(player.position.x-x)<0.02,"modo só-toque ignora movimento do teclado")
 await key(KEY_D,false)
 await key(KEY_J,true)
 await key(KEY_J,false)
 check(player.attack_charges==3,"modo só-toque não ataca pelo teclado")
 var pad: Control=fixture.phase._touch_pad
 pad._press(7,pad._buttons.defend[0])
 await ticks(3)
 pad._release(7)
 check(player.is_defending and player.defense_charges==1,"modo só-toque defende pelo botão")
 player._shield_timer=0
 player.is_defending=false
 pad._press(8,pad._buttons.defend[0])
 pad._release(8)
 await ticks(3)
 check(player.is_defending and player.defense_charges==0,"toque curto entre quadros também ativa defesa uma única vez")
 await snap("03_toque")
 player._shield_timer=0
 player.is_defending=false
 await set_mode("mixed")
 check(pad.visible,"modo misto mantém botões na tela")
 await key(KEY_D,true)
 pad._press(4,pad._base)
 pad._drag(4,pad._base+Vector2(pad._radius*0.55,0))
 await ticks(5)
 pad._release(4)
 x=player.position.x
 await ticks(8)
 check(player.position.x>x+0.2,"soltar o toque não cancela a tecla mantida no modo misto")
 await key(KEY_D,false)
 pad._press(5,pad._base)
 pad._drag(5,pad._base+Vector2(pad._radius*0.55,0))
 await key(KEY_D,true)
 await key(KEY_D,false)
 x=player.position.x
 await ticks(8)
 check(player.position.x>x+0.2,"soltar a tecla não cancela o joystick no modo misto")
 pad._release(5)
 await ticks(10)
 await snap("04_misto")
 fixture.phase._pause()
 fixture.phase._session.show_settings()
 var picker: OptionButton=fixture.phase._session.find_child("ControlMode",true,false)
 check(picker!=null and paused,"pausa permite alterar controles sem sair da fase")
 picker.select(2)
 picker.item_selected.emit(2)
 check(not pad.visible and fixture.services.preferences.values.control_mode=="keyboard","seletor da pausa aplica o modo imediatamente")
 await ticks(8)
 var bounds: Rect2=fixture.phase._session._panel.get_global_rect()
 var viewport_size:=root.get_visible_rect().size
 check(bounds.position.x>=0 and bounds.position.y>=0 and bounds.end.x<=viewport_size.x and bounds.end.y<=viewport_size.y,"opções e retorno da pausa cabem inteiros na tela")
 await snap("05_pausa")
 fixture.phase._resume()
 await ticks(8)
 check(absf(player.velocity.x)<0.02,"trocar o modo libera os comandos antigos")
 var prefs:=DevicePreferences.new()
 fixture.services.add_child(prefs)
 check(prefs.values.control_mode=="keyboard","reabrir as preferências recupera a escolha salva")
 check(not prefs.set_preference("control_mode","invalid"),"modo inválido não altera a escolha")
 fixture.free()
 await preload("res://tests/common/audio_cleanup.gd").finish(self)
 print("CONTROL_MODES checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)
