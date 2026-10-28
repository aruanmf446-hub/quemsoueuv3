class_name LobbyStage
extends SubViewportContainer

## Palco 3D transparente do lobby e do visualizador de Skins. Mesmo sistema de
## renderização e iluminação nos dois lugares. Quando `interactive` é verdadeiro,
## permite girar (arrastar ou mouse) e aproximar/afastar (roda ou gesto de pinça),
## dentro de limites seguros.

## Fração da altura útil do palco ocupada pelo personagem.
const FILL_RATIO := 0.72
## Campo de visão vertical da câmera, em graus (keep_aspect = KEEP_HEIGHT).
const CAMERA_FOV := 38.0
## Desloca o alvo da câmera para cima, fazendo o personagem pousar no pedestal do fundo.
const PEDESTAL_LIFT := 0.13
const ORBIT_SENSITIVITY := 0.008
const PITCH_LIMIT := 0.35
const ZOOM_MIN := 0.55
const ZOOM_MAX := 1.35
const ZOOM_WHEEL_STEP := 0.9

@export var interactive: bool = false
@export var profile_name: String = ""

@onready var character: CharacterSlot = $Viewport/World/Character
@onready var _viewport: SubViewport = $Viewport
@onready var _camera: Camera3D = $Viewport/World/Camera
@onready var _key_light: DirectionalLight3D = $Viewport/World/KeyLight
@onready var _rim_light: OmniLight3D = $Viewport/World/RimLight

var _base_distance: float = 3.0
var _target_y: float = 0.9
var _yaw: float = 0.0
var _pitch: float = 0.0
var _zoom: float = 1.0


func _ready() -> void:
	# No lobby o palco não captura cliques; no visualizador ele precisa receber arraste e roda.
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	apply_profile(profile_name if profile_name != "" else GraphicsProfile.default_for_platform())


func apply_profile(name: String) -> void:
	var settings := GraphicsProfile.settings(name)
	_viewport.msaa_3d = settings["msaa_3d"]
	stretch_shrink = settings["stretch_shrink"]
	_key_light.shadow_enabled = settings["shadows"]


func show_character(entry: Dictionary) -> void:
	character.load_entry(entry)
	reset_view()


## Volta ao enquadramento padrão, sem rotação e com o zoom inicial.
func reset_view() -> void:
	_yaw = 0.0
	_pitch = 0.0
	_zoom = 1.0
	frame_character()


func frame_character() -> void:
	var framing := character.get_framing()
	if framing.is_empty():
		return
	var height: float = framing["height"]
	var center_y: float = framing["center_y"]
	_target_y = center_y + PEDESTAL_LIFT
	_base_distance = (height / FILL_RATIO) / (2.0 * tan(deg_to_rad(CAMERA_FOV * 0.5)))
	_update_camera()


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventScreenDrag:
		_orbit(event.relative)
	elif event is InputEventMouseMotion:
		# Movimentos emulados a partir de toque já foram tratados por InputEventScreenDrag.
		if event.device != InputEvent.DEVICE_ID_EMULATION and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_orbit(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(ZOOM_WHEEL_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / ZOOM_WHEEL_STEP)
	elif event is InputEventMagnifyGesture:
		_zoom_by(event.factor)


## Define o zoom relativo ao enquadramento padrão (menor = mais perto). Usado nas miniaturas.
func set_zoom(value: float) -> void:
	_zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
	_update_camera()


func _orbit(relative: Vector2) -> void:
	_yaw -= relative.x * ORBIT_SENSITIVITY
	_pitch = clampf(_pitch - relative.y * ORBIT_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
	_update_camera()


func _zoom_by(factor: float) -> void:
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	_update_camera()


func _update_camera() -> void:
	var distance := _base_distance * _zoom
	var target := Vector3(0.0, _target_y, 0.0)
	var offset := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch)
	) * distance
	_camera.position = target + offset
	_camera.look_at(target, Vector3.UP)
