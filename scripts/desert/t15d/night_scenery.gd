extends Node3D
## Cidade do deserto à noite. Cada fase atravessa quatro lugares: a panorâmica muda a
## cada dois distritos com uma transição suave, e cada lugar tem sua cor de luz.
## configure() pode ser chamado antes ou depois de add_child(); follow() mantém a API.
signal location_changed(place: Dictionary)
const PLACES := [
	{"name": "Arredores da Cidade", "texture": "res://assets/desert/night_city/outskirts.png", "tint": Color(0.86, 0.88, 0.95), "ambient": Color("#819ecb")},
	{"name": "Bazar da Meia-Noite", "texture": "res://assets/desert/night_city/bazaar.png", "tint": Color(0.95, 0.88, 0.80), "ambient": Color("#a99a86")},
	# Arte do cânion é diurna: o tom azul-escuro a leva para a noite da campanha.
	{"name": "Cânion das Dunas", "texture": "res://assets/desert/phase01/desert_canyon.png", "tint": Color(0.42, 0.46, 0.72), "ambient": Color("#8a86b0")},
	{"name": "Cidadela de Areia", "texture": "res://assets/desert/night_city/citadel.png", "tint": Color(0.84, 0.86, 0.96), "ambient": Color("#7f95c4")},
	{"name": "Reino do Deserto", "texture": "res://assets/desert/phase01/desert_kingdom.png", "tint": Color(0.94, 0.86, 0.78), "ambient": Color("#a38f7c")},
]
const STAGES := 4
const FADE := 1.2
var _layers: Array[Sprite3D] = []
var _front := 0
var _fade := 1.0
var _order := 1
var _length := 1200.0
var _start := -8.0
var travel := 0.0
var parallax_offset := 0.0
var district := 0
var place_index := -1
## Texturas dos quatro lugares da fase, carregadas na entrada: carregar no meio da corrida
## travava ~50ms a cada troca de lugar.
var _textures := {}

func configure(order: int, length: float = 1200.0, start: float = -8.0) -> void:
	_order = clampi(order, 1, 9)
	_length = maxf(length, 1.0)
	_start = start
	district = clampi(int((_order - 1) / 3.0), 0, 2)

func _ready() -> void:
	for index in range(2):
		var layer := Sprite3D.new()
		layer.name = "MoonlitCityPanorama" if index == 0 else "NextPanorama"
		layer.pixel_size = 0.01
		layer.shaded = false
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		layer.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		layer.render_priority = index
		add_child(layer)
		_layers.append(layer)
	for stage in range(STAGES):
		var index := _place_for((stage + 0.5) / STAGES)
		if not _textures.has(index): _textures[index] = load(PLACES[index].texture)
	_set_place(_place_for(0.0), true)

## Lugar de cada trecho: sequência diferente por fase, para as nove não repetirem igual.
func _place_for(share: float) -> int:
	var stage := mini(int(share * STAGES), STAGES - 1)
	return (_order - 1 + stage * 2) % PLACES.size()

func _set_place(index: int, instant := false) -> void:
	if index == place_index: return
	place_index = index
	var place: Dictionary = PLACES[index]
	if instant:
		_layers[_front].texture = _texture(index)
		_layers[_front].modulate = place.tint
		_layers[1 - _front].modulate.a = 0.0
		_fade = 1.0
	else:
		# Novo lugar entra por cima e aparece aos poucos; depois vira a camada de trás.
		_front = 1 - _front
		_layers[_front].texture = _texture(index)
		_layers[_front].modulate = Color(place.tint, 0.0)
		_layers[_front].render_priority = 1
		_layers[1 - _front].render_priority = 0
		_fade = 0.0
	location_changed.emit(place)

func _texture(index: int) -> Texture2D:
	if not _textures.has(index): _textures[index] = load(PLACES[index].texture)
	return _textures[index]

func current_place() -> Dictionary:
	return PLACES[maxi(place_index, 0)]

func _process(delta: float) -> void:
	if _fade >= 1.0: return
	_fade = minf(_fade + delta / FADE, 1.0)
	_layers[_front].modulate.a = _fade
	if _fade >= 1.0: _layers[1 - _front].modulate.a = 0.0

func follow(camera: Camera3D, x: float) -> void:
	if _layers.is_empty(): return
	travel = clampf((x - _start) / _length, 0.0, 1.0)
	_set_place(_place_for(travel))
	var aspect := camera.get_viewport().get_visible_rect().size.aspect()
	var margin := camera.size * aspect * 0.065
	parallax_offset = lerpf(-margin, margin, travel)
	for layer in _layers:
		if layer.texture == null: continue
		# A margem de 25% cobre as razões landscape testadas e a paralaxe vertical.
		var texture_aspect := float(layer.texture.get_width()) / layer.texture.get_height()
		var height := maxf(camera.size * 1.25, camera.size * aspect / texture_aspect * 1.25)
		var rise := clampf((camera.position.y - 2.65) * 0.22, 0.0, height * 0.05)
		layer.basis = camera.basis
		layer.position = camera.position - camera.basis.z * (48 if layer.render_priority == 0 else 47.5) - camera.basis.x * parallax_offset - camera.basis.y * rise
		layer.scale = Vector3.ONE * height / (layer.texture.get_height() * 0.01)
