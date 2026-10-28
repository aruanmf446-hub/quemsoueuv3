class_name LobbyStage
extends SubViewportContainer

## Palco 3D transparente do lobby. Enquadra o personagem atual pela altura medida
## do modelo, de modo que personagens de alturas diferentes ocupem a mesma proporção.

## Fração da altura útil do palco ocupada pelo personagem.
const FILL_RATIO := 0.72
## Campo de visão vertical da câmera, em graus (keep_aspect = KEEP_HEIGHT).
const CAMERA_FOV := 38.0
## Desloca o alvo da câmera para cima, fazendo o personagem descer e pousar no pedestal
## desenhado no fundo (medido na captura de referência do lobby).
const PEDESTAL_LIFT := 0.13

@onready var character: CharacterSlot = $Viewport/World/Character
@onready var _camera: Camera3D = $Viewport/World/Camera


func show_character(entry: Dictionary) -> void:
	character.load_entry(entry)
	frame_character()


func frame_character() -> void:
	var framing := character.get_framing()
	if framing.is_empty():
		return
	var height: float = framing["height"]
	var center_y: float = framing["center_y"]
	var visible_height := height / FILL_RATIO
	var distance := visible_height / (2.0 * tan(deg_to_rad(CAMERA_FOV * 0.5)))
	var target_y := center_y + PEDESTAL_LIFT
	_camera.position = Vector3(0.0, target_y, distance)
	_camera.look_at(Vector3(0.0, target_y, 0.0), Vector3.UP)
