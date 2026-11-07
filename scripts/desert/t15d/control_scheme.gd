extends RefCounted
## Política de entrada e composição das fontes física/virtual, sem consultar disco por quadro.
const MODES:=["auto","touch","keyboard","mixed"]
const LABELS:=["Automático","Botões na tela","Somente teclado","Teclado e botões"]
const ACTIONS:=["move_left","move_right","crouch","jump","attack","defend","rupture","amber","dash"]
static var mode:="auto"
var _virtual: Dictionary={}
var _previous: Dictionary={}
var _down: Dictionary={}
var _edges: Dictionary={}
var _blocked: Dictionary={}
var _tick:=-1
static func load_saved(tree: SceneTree) -> void:
 var config:=ConfigFile.new()
 config.load("user://device_preferences_v1.cfg")
 var value: Variant=config.get_value("device","control_mode","auto")
 apply(saved_mode(value),tree)
static func saved_mode(value: Variant="auto") -> String:
 if OS.has_feature("web"):
  var stored: Variant=JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('qse-control-mode-v1')||'';}catch(e){return '';}})()")
  if stored in MODES:value=stored
 return str(value) if value in MODES else "auto"
static func apply(value: String,tree: SceneTree) -> void:
 if value not in MODES or mode==value:return
 mode=value
 tree.call_group("campaign_control_consumers","apply_control_scheme")
static func keyboard_enabled() -> bool:return mode!="touch"
static func touch_enabled() -> bool:
 if mode=="keyboard":return false
 if mode in ["touch","mixed"]:return true
 return DisplayServer.is_touchscreen_available() or OS.has_feature("android") or OS.has_feature("web") or UIScale.is_handheld() or "--touch-controls" in OS.get_cmdline_user_args()
static func description() -> String:
 match mode:
  "touch":return "Use o joystick e os botões na tela. As teclas de jogo ficam desativadas."
  "keyboard":return "Use as teclas para jogar. O joystick fica oculto; os ícones mostram suas cargas."
  "mixed":return "Use teclado e botões na tela juntos, sem trocar de modo."
 return "O jogo mostra os botões conforme o aparelho. O teclado continua disponível."
static func key_held(action: String) -> bool:
 if not InputMap.has_action(action):return false
 for event in InputMap.action_get_events(action):
  if event is InputEventKey:
   if event.physical_keycode!=0 and Input.is_physical_key_pressed(event.physical_keycode):return true
   if event.physical_keycode==0 and event.keycode!=0 and Input.is_key_pressed(event.keycode):return true
 return false
func set_virtual(action: String,strength: float) -> void:
 if action not in ACTIONS:return
 if strength>0.0 and touch_enabled():_virtual[action]=clampf(strength,0,1)
 else:_virtual.erase(action)
func reset() -> void:
 _virtual.clear()
 _previous.clear()
 _edges.clear()
 _down.clear()
 _blocked.clear()
 for action: String in ACTIONS:
  if key_held(action):_blocked[action]=true
 _tick=-1
func _sample() -> void:
 var tick:=Engine.get_physics_frames()
 if _tick==tick:return
 _tick=tick
 for action: String in ACTIONS:
  var physical:=keyboard_enabled() and key_held(action)
  if _blocked.has(action):
   if not key_held(action):_blocked.erase(action)
   physical=false
  var virtual: float=float(_virtual.get(action,0.0)) if touch_enabled() else 0.0
  var injected:=0.0
  # Input.action_press é mantido para comandos de acessibilidade e percursos do motor.
  # Em modo só-toque, nenhuma tecla física pode virar comando por este caminho.
  if keyboard_enabled() and not _blocked.has(action) and InputMap.has_action(action):injected=Input.get_action_strength(action)
  var strength:=maxf(virtual,maxf(1.0 if physical else 0.0,injected))
  _down[action]=strength
  _edges[action]=strength>0.0 and not bool(_previous.get(action,false))
  _previous[action]=strength>0.0
func pressed(action: String) -> bool:
 _sample()
 return float(_down.get(action,0.0))>0.0
func just_pressed(action: String) -> bool:
 _sample()
 return bool(_edges.get(action,false))
func axis() -> float:
 _sample()
 return clampf(float(_down.get("move_right",0.0))-float(_down.get("move_left",0.0)),-1,1)
