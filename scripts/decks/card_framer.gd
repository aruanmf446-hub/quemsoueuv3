class_name CardFramer
extends Control
## Enquadramento estilo "foto de perfil": a moldura fica parada e a imagem é arrastada
## e ampliada por baixo dela. A imagem nunca é esticada nem deformada; a moldura sempre
## fica coberta. O original não é alterado: só os parâmetros {x, y, zoom} são guardados.
##   x, y : centro da moldura no original, normalizado (0..1)
##   zoom : 1 = menor ampliação que ainda cobre a moldura; até MAX_ZOOM. Abaixo de 1 (até a
##          imagem inteira caber, nunca menos que MIN_ZOOM) a imagem pode se mover dentro da
##          moldura; a sobra é preenchida pela própria imagem desfocada, sem faixas vazias.
signal changed(crop: Dictionary)

const MAX_ZOOM := 6.0
const MIN_ZOOM := 0.35
## Biblioteca: carta em retrato 5:7, a mesma proporção da galeria atual.
const LIBRARY_ASPECT := 5.0 / 7.0
## Duelo: faixa horizontal das cartas no tabuleiro (9 cartas em 3×3, 1920×1080 ≈ 16:5).
const DUEL_ASPECT := 16.0 / 5.0
const DEFAULT := {"x": 0.5, "y": 0.5, "zoom": 1.0}

var texture: Texture2D
var aspect := LIBRARY_ASPECT
var crop: Dictionary = DEFAULT.duplicate()
var _touches := {}
var _pinch_start := 0.0
var _pinch_zoom := 1.0
var _dragging := false
var _blur: Texture2D
var _blur_source: Texture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	custom_minimum_size = Vector2(240, 200)


func setup(source: Texture2D, frame_aspect: float, initial: Dictionary = {}) -> void:
	texture = source
	aspect = frame_aspect
	crop = normalized(initial)
	_clamp()
	queue_redraw()


func reset() -> void:
	crop = DEFAULT.duplicate()
	_clamp()
	queue_redraw()
	changed.emit(crop.duplicate())


static func normalized(value: Dictionary) -> Dictionary:
	var result := DEFAULT.duplicate()
	for key: String in ["x", "y", "zoom"]:
		var number: Variant = value.get(key, result[key])
		if (number is float or number is int) and is_finite(float(number)) and (key != "zoom" or float(number) > 0.0): result[key] = float(number)
	result.zoom = clampf(result.zoom, MIN_ZOOM, MAX_ZOOM)
	result.x = clampf(result.x, 0.0, 1.0)
	result.y = clampf(result.y, 0.0, 1.0)
	return result


## Região do original (em pixels) que aparece na moldura. Mesma proporção da moldura:
## quem usa o recorte só reduz/amplia uniformemente, nunca estica.
static func region(image_size: Vector2, frame_aspect: float, value: Dictionary) -> Rect2:
	var c := normalized(value)
	var base := Vector2(image_size.x, image_size.x / frame_aspect)
	if base.y > image_size.y: base = Vector2(image_size.y * frame_aspect, image_size.y)
	var size: Vector2 = base / maxf(float(c.zoom), min_zoom(image_size, frame_aspect))
	var center := Vector2(float(c.x), float(c.y)) * image_size
	# Em cada eixo: se a moldura é menor que a imagem, ela fica dentro da imagem; se é maior
	# (zoom < 1), a imagem fica dentro da moldura. Nunca sobra borda vazia além do necessário.
	var low := Vector2(minf(0.0, image_size.x - size.x), minf(0.0, image_size.y - size.y))
	var high := Vector2(maxf(0.0, image_size.x - size.x), maxf(0.0, image_size.y - size.y))
	var origin: Vector2 = (center - size * 0.5).clamp(low, high)
	return Rect2(origin, size)


## Menor zoom: a imagem inteira cabe na moldura com folga (60% do "caber exato"), para que
## mesmo uma imagem no formato da carta possa ser movida. Nunca abaixo de MIN_ZOOM.
static func min_zoom(image_size: Vector2, frame_aspect: float) -> float:
	var base := Vector2(image_size.x, image_size.x / frame_aspect)
	if base.y > image_size.y: base = Vector2(image_size.y * frame_aspect, image_size.y)
	return clampf(minf(base.x / image_size.x, base.y / image_size.y) * 0.6, MIN_ZOOM, 1.0)


## Prévia leve para Web/Android: recorte do original reduzido até max_width (nunca ampliado).
static func preview(image: Image, frame_aspect: float, value: Dictionary, max_width := 360) -> Image:
	var source := image
	if source.is_compressed(): source = image.duplicate() as Image
	if source.is_compressed(): source.decompress()
	if source.get_format() != Image.FORMAT_RGBA8:
		source = source.duplicate() as Image
		source.convert(Image.FORMAT_RGBA8)
	var image_size := Vector2(source.get_size())
	var rect := region(image_size, frame_aspect, value)
	var inside := Rect2(Vector2.ZERO, image_size)
	if inside.encloses(rect.grow(-0.5)):
		var area := Rect2i(Vector2i(rect.position.round()), Vector2i(rect.size.round()).max(Vector2i.ONE))
		area = area.intersection(Rect2i(Vector2i.ZERO, source.get_size()))
		var result := source.get_region(area)
		if result.get_width() > max_width:
			result.resize(max_width, maxi(1, roundi(max_width / frame_aspect)), Image.INTERPOLATE_LANCZOS)
		return result
	# Zoom < 1: tela do tamanho da moldura, fundo desfocado da própria imagem e a imagem inteira por cima.
	var width := mini(max_width, maxi(1, roundi(rect.size.x)))
	var out_size := Vector2i(width, maxi(1, roundi(width / frame_aspect)))
	var canvas := backdrop(source, out_size)
	var scale := float(out_size.x) / rect.size.x
	var placed := Vector2i(((-rect.position) * scale).round())
	var scaled := source.duplicate() as Image
	scaled.resize(maxi(1, roundi(image_size.x * scale)), maxi(1, roundi(image_size.y * scale)), Image.INTERPOLATE_LANCZOS)
	canvas.blend_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), placed)
	return canvas


## Fundo "cinema": a imagem cobrindo a área, reduzida e ampliada (desfoque) e escurecida.
static func backdrop(source: Image, out_size: Vector2i) -> Image:
	var small := source.duplicate() as Image
	var ratio := maxf(float(out_size.x) / small.get_width(), float(out_size.y) / small.get_height())
	var cover := Vector2i(maxi(1, ceili(small.get_width() * ratio)), maxi(1, ceili(small.get_height() * ratio)))
	small.resize(maxi(1, cover.x / 14), maxi(1, cover.y / 14), Image.INTERPOLATE_BILINEAR)
	# Ampliação em duas etapas: desfoque suave, sem blocos.
	small.resize(maxi(1, cover.x / 6), maxi(1, cover.y / 6), Image.INTERPOLATE_CUBIC)
	small.resize(cover.x, cover.y, Image.INTERPOLATE_CUBIC)
	var canvas := small.get_region(Rect2i((cover - out_size) / 2, out_size))
	canvas.convert(Image.FORMAT_RGBA8)
	var shade := Image.create(out_size.x, out_size.y, false, Image.FORMAT_RGBA8)
	shade.fill(Color(0.02, 0.03, 0.05, 0.55))
	canvas.blend_rect(shade, Rect2i(Vector2i.ZERO, out_size), Vector2i.ZERO)
	return canvas


func frame_rect() -> Rect2:
	var room := size * 0.86
	var frame := Vector2(room.x, room.x / aspect)
	if frame.y > room.y: frame = Vector2(room.y * aspect, room.y)
	return Rect2((size - frame) * 0.5, frame)


func _image_size() -> Vector2:
	return Vector2(texture.get_size()) if texture != null else Vector2.ONE


## Escala de tela: quantos pixels de tela por pixel do original.
func _scale() -> float:
	return frame_rect().size.x / region(_image_size(), aspect, crop).size.x


func _clamp() -> void:
	crop = normalized(crop)
	crop.zoom = maxf(float(crop.zoom), minimum_zoom())
	var image := _image_size()
	var rect := region(image, aspect, crop)
	var center := rect.get_center() / image
	crop.x = center.x
	crop.y = center.y


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 1.0))
	if texture == null: return
	var frame := frame_rect()
	var image := _image_size()
	var rect := region(image, aspect, crop)
	var scale := _scale()
	# A imagem inteira desenhada na mesma escala (uniforme); fora da moldura fica escurecida.
	var whole := Rect2(frame.position - rect.position * scale, image * scale)
	if not Rect2(Vector2.ZERO, image).encloses(rect.grow(-0.5)):
		# Mesma aparência da prévia salva: a sobra da moldura mostra a imagem desfocada.
		if _blur == null or _blur_source != texture:
			_blur_source = texture
			var source := texture.get_image()
			_blur = ImageTexture.create_from_image(backdrop(source, Vector2i(160, maxi(1, roundi(160 / aspect))))) if source != null else null
		if _blur != null: draw_texture_rect(_blur, frame, false)
	draw_texture_rect(texture, whole, false)
	var shade := Color(0.01, 0.015, 0.03, 0.66)
	draw_rect(Rect2(0, 0, size.x, frame.position.y), shade)
	draw_rect(Rect2(0, frame.end.y, size.x, size.y - frame.end.y), shade)
	draw_rect(Rect2(0, frame.position.y, frame.position.x, frame.size.y), shade)
	draw_rect(Rect2(frame.end.x, frame.position.y, size.x - frame.end.x, frame.size.y), shade)
	draw_rect(frame, Color(PlayerUI.GOLD, 0.9), false, 2.0)
	# Terços discretos ajudam a posicionar o rosto sem poluir a prévia.
	for i in [1, 2]:
		var x: float = frame.position.x + frame.size.x * i / 3.0
		var y: float = frame.position.y + frame.size.y * i / 3.0
		draw_line(Vector2(x, frame.position.y), Vector2(x, frame.end.y), Color(1, 1, 1, 0.12), 1.0)
		draw_line(Vector2(frame.position.x, y), Vector2(frame.end.x, y), Color(1, 1, 1, 0.12), 1.0)


func _pan(screen_delta: Vector2) -> void:
	# Arrastar a imagem para a direita move a moldura para a esquerda no original.
	var image := _image_size()
	var delta := -screen_delta / _scale() / image
	crop.x += delta.x
	crop.y += delta.y
	_commit()


func _zoom_at(factor: float, screen_point: Vector2) -> void:
	var before := _screen_to_image(screen_point)
	crop.zoom = clampf(float(crop.zoom) * factor, minimum_zoom(), MAX_ZOOM)
	_clamp()
	# Mantém o ponto sob o cursor/dedos parado enquanto amplia.
	var after := _screen_to_image(screen_point)
	var image := _image_size()
	crop.x += (before.x - after.x) / image.x
	crop.y += (before.y - after.y) / image.y
	_commit()


func zoom_by(factor: float) -> void:
	_zoom_at(factor, frame_rect().get_center())


func set_zoom(value: float) -> void:
	if texture == null or is_equal_approx(value, float(crop.zoom)): return
	zoom_by(clampf(value, minimum_zoom(), MAX_ZOOM) / float(crop.zoom))


## Move a moldura em frações da própria moldura (botões acessíveis no Android).
func nudge(direction: Vector2) -> void:
	if texture == null: return
	_pan(-direction * frame_rect().size * 0.06)


## Centraliza a imagem sem mudar o zoom.
func center_crop() -> void:
	crop.x = 0.5
	crop.y = 0.5
	_commit()


func minimum_zoom() -> float:
	return min_zoom(_image_size(), aspect)


func _screen_to_image(point: Vector2) -> Vector2:
	var frame := frame_rect()
	var rect := region(_image_size(), aspect, crop)
	return rect.position + (point - frame.position) / _scale()


func _commit() -> void:
	_clamp()
	queue_redraw()
	changed.emit(crop.duplicate())


func _gui_input(event: InputEvent) -> void:
	if texture == null: return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			if button.pressed: grab_focus()
		elif button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_at(1.1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1, button.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging and _touches.is_empty():
		_pan((event as InputEventMouseMotion).relative)
		accept_event()
	elif event is InputEventMagnifyGesture:
		var gesture := event as InputEventMagnifyGesture
		_zoom_at(gesture.factor, gesture.position)
		accept_event()
	elif event is InputEventPanGesture:
		_pan(-(event as InputEventPanGesture).delta * 8.0)
		accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed: _touches[touch.index] = touch.position
		else: _touches.erase(touch.index)
		_dragging = false
		if _touches.size() == 2:
			var points: Array = _touches.values()
			_pinch_start = maxf((points[0] as Vector2).distance_to(points[1]), 1.0)
			_pinch_zoom = float(crop.zoom)
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touches[drag.index] = drag.position
		if _touches.size() >= 2:
			var points: Array = _touches.values()
			var distance := (points[0] as Vector2).distance_to(points[1])
			var middle := ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
			var target := clampf(_pinch_zoom * distance / _pinch_start, minimum_zoom(), MAX_ZOOM)
			_zoom_at(target / float(crop.zoom), middle)
		else:
			_pan(drag.relative)
		accept_event()
	elif event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		var step := {KEY_LEFT: Vector2(12, 0), KEY_RIGHT: Vector2(-12, 0), KEY_UP: Vector2(0, 12), KEY_DOWN: Vector2(0, -12)}
		if step.has(key.keycode):
			_pan(step[key.keycode])
			accept_event()
		elif key.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]:
			zoom_by(1.1 if key.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD] else 1.0 / 1.1)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: queue_redraw()
