class_name LobbyStage
extends Control

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

@export_range(0.5, 0.9) var fill_ratio: float = FILL_RATIO
@export var pedestal_lift: float = PEDESTAL_LIFT

@export var interactive: bool = false
@export var profile_name: String = ""

@onready var character: CharacterSlot = $Viewport/World/Character
@onready var _viewport: SubViewport = $Viewport
@onready var _camera: Camera3D = $Viewport/World/Camera
@onready var _key_light: DirectionalLight3D = $Viewport/World/KeyLight
@onready var _rim_light: OmniLight3D = $Viewport/World/RimLight

var _surface: TextureRect
var _resolution_divisor := 1
var stretch_shrink: int:
	get: return _resolution_divisor
var _base_distance: float = 3.0
var _target_y: float = 0.9
var _yaw: float = 0.0
var _pitch: float = 0.0
var _zoom: float = 1.0


func _ready() -> void:
	_surface = TextureRect.new()
	_surface.name = "RenderedCharacter"
	_surface.texture = _viewport.get_texture()
	_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_surface.stretch_mode = TextureRect.STRETCH_SCALE
	_surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_resize_render)
	get_viewport().size_changed.connect(_resize_render)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_to_group("player_preview_stages")
	var environment: Environment = $Viewport/World/Environment.environment.duplicate()
	$Viewport/World/Environment.environment = environment
	environment.ambient_light_color = Color("#c5d7ed")
	environment.ambient_light_energy = 0.46
	_key_light.light_color = Color("#fff0da")
	_key_light.light_energy = 1.0
	_key_light.shadow_bias = 0.035
	_key_light.directional_shadow_max_distance = 12.0
	$Viewport/World/FillLight.light_energy = 0.50
	_rim_light.light_energy = 0.9
	# No lobby o palco não captura cliques; no visualizador ele precisa receber arraste e roda.
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	var preferred := GraphicsProfile.default_for_platform()
	if PlayerServices.current != null and PlayerServices.current.preferences != null:
		preferred = PlayerServices.current.preferences.values.quality
	apply_profile(profile_name if profile_name != "" else preferred)


func apply_profile(name: String) -> void:
	var settings := GraphicsProfile.settings(name)
	var constrained := OS.has_feature("web") or OS.has_feature("mobile") or UIScale.is_compact()
	_viewport.msaa_3d = Viewport.MSAA_DISABLED if constrained else settings["msaa_3d"]
	_resolution_divisor = settings["stretch_shrink"]
	_resize_render()
	_key_light.shadow_enabled = settings["shadows"] and not constrained


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
	_target_y = center_y + pedestal_lift
	_base_distance = (height / fill_ratio) / (2.0 * tan(deg_to_rad(CAMERA_FOV * 0.5)))
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


func _resize_render() -> void:
	if not is_instance_valid(_viewport): return
	if is_instance_valid(_surface):
		_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Render above the physical output resolution, then resolve down to the UI.
	# This also covers UI scaling and high-DPI windows; no low-res container upscale.
	var output_scale := Vector2(get_window().size) / get_viewport().get_visible_rect().size
	var pixels := get_global_transform_with_canvas().get_scale().abs() * size * output_scale
	var supersample := 2.0 / float(_resolution_divisor)
	var target := pixels * supersample
	# Celular e navegador: sem supersampling e com teto de ~0,52 megapixel. Em telas de alta
	# densidade o palco chegava a 2560×2560 com MSAA, estourava a memória do WebGL no
	# iPhone e o navegador recarregava a página ao girar o personagem.
	var budget := 520_000.0 if OS.has_feature("web") or OS.has_feature("mobile") or UIScale.is_compact() else 6_000_000.0
	if OS.has_feature("web") or OS.has_feature("mobile"): target = pixels
	if target.x * target.y > budget: target *= sqrt(budget / (target.x * target.y))
	_viewport.size = Vector2i(clampi(ceili(target.x), 64, 2560), clampi(ceili(target.y), 64, 2560))
