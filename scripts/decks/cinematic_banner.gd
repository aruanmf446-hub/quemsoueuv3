class_name CinematicBanner
extends Control
## Composição promocional automática do header da Biblioteca (T24), montada na GPU.
## Até 6 personagens do deck em profundidades diferentes: o principal maior e mais claro,
## os demais atrás, menores e mais escuros. As imagens têm fundo (sem transparência), então
## as bordas são dissolvidas por máscaras suaves sobre um fundo desfocado da própria arte —
## uma transição disfarçada, não um recorte falso. Nunca estica: cada camada tem a proporção
## exata do recorte que mostra.

const MAX_CHARACTERS := 6
## Proporção de cada personagem (meio-corpo em retrato).
const FIGURE_ASPECT := 0.74
## Meio-corpo: recorte 1,45× mais fechado, centrado no terço superior (rosto e ombros).
const FOCUS := Vector2(0.5, 0.36)
const FIGURE_ZOOM := 1.45
## Encaixes por importância: centro x (fração da largura), altura (fração da altura) e
## profundidade (0 = frente). O lado esquerdo fica livre para o título.
const SLOTS := [
	[0.69, 1.32, 0.0], [0.815, 1.14, 0.34], [0.565, 1.12, 0.38],
	[0.925, 1.0, 0.62], [0.455, 0.98, 0.66], [1.02, 0.9, 0.85]]

const FIGURE_SHADER := """
shader_type canvas_item;
uniform float depth = 0.0;
uniform float feather = 0.36;
uniform vec2 rect_size = vec2(1.0);
varying vec2 local;
void vertex() { local = VERTEX / rect_size; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float side = smoothstep(0.0, feather, local.x) * smoothstep(0.0, feather, 1.0 - local.x);
	float floor_fade = smoothstep(0.0, 0.5, 1.0 - local.y);
	float top_fade = smoothstep(0.0, 0.06, local.y);
	vec2 d = (local - vec2(0.5, 0.42)) / vec2(0.62, 0.78);
	float oval = 1.0 - smoothstep(0.55, 1.0, length(d));
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = mix(c.rgb, vec3(luma) * vec3(0.55, 0.62, 0.78), depth * 0.55);
	tinted *= 1.0 - depth * 0.5;
	COLOR = vec4(tinted, c.a * side * floor_fade * top_fade * mix(1.0, oval, 0.85));
}
"""
const OVERLAY_SHADER := """
shader_type canvas_item;
uniform float text_side = 0.46;
void fragment() {
	float left = 1.0 - smoothstep(0.08, text_side, UV.x);
	float bottom = smoothstep(0.55, 1.0, UV.y);
	float top = 1.0 - smoothstep(0.0, 0.18, UV.y);
	float edge = smoothstep(0.9, 1.0, UV.x);
	float a = clamp(0.18 + left * 0.78 + bottom * 0.55 + top * 0.25 + edge * 0.35, 0.0, 0.96);
	COLOR = vec4(0.015, 0.02, 0.04, a);
}
"""
const GLOW_SHADER := """
shader_type canvas_item;
uniform vec2 center = vec2(0.7, 0.55);
uniform vec4 tint : source_color = vec4(0.91, 0.72, 0.38, 1.0);
void fragment() {
	vec2 d = (UV - center) * vec2(1.6, 1.0);
	float g = 1.0 - smoothstep(0.0, 0.6, length(d));
	COLOR = vec4(tint.rgb, g * g * 0.32);
}
"""
static var _shaders := {}
static var _blurs := {}

var paths: Array = []
var _layers: Array[TextureRect] = []
var _backdrop: TextureRect
var _glow: ColorRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


## `ordered`: imagens já em ordem de importância (a primeira é o personagem principal).
func setup(ordered: Array) -> void:
	paths = ordered.filter(func(p: Variant) -> bool: return DeckCover.exists(str(p))).slice(0, MAX_CHARACTERS)
	for child in get_children(): child.queue_free()
	_layers.clear()
	_backdrop = TextureRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_backdrop.modulate = Color(0.62, 0.6, 0.66)
	_backdrop.texture = blurred(str(paths[0])) if not paths.is_empty() else null
	add_child(_backdrop)
	_glow = ColorRect.new()
	_glow.name = "Glow"
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.material = _material("glow")
	add_child(_glow)
	# Do fundo para a frente: os mais distantes primeiro.
	var order: Array = range(paths.size())
	order.sort_custom(func(a: int, b: int) -> bool: return float(_slot(a)[2]) > float(_slot(b)[2]))
	for index: int in order:
		var figure := TextureRect.new()
		figure.name = "Character_%d" % index
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		figure.stretch_mode = TextureRect.STRETCH_SCALE
		figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		figure.texture = DeckCover.framed(str(paths[index]), FIGURE_ASPECT, FOCUS, FIGURE_ZOOM)
		var material := ShaderMaterial.new()
		material.shader = _shader("figure")
		material.set_shader_parameter("depth", float(_slot(index)[2]))
		figure.material = material
		figure.set_meta("slot", index)
		add_child(figure)
		_layers.append(figure)
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = _material("overlay")
	add_child(overlay)
	_layout()


func layers() -> Array[TextureRect]:
	return _layers


## Encaixe do personagem `index`, recentralizado quando há poucos personagens.
func _slot(index: int) -> Array:
	var slot: Array = SLOTS[index].duplicate()
	var count := paths.size()
	if count <= 3: slot[0] = float(slot[0]) + (0.04 if count == 1 else 0.02)
	return slot


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	for node: Control in [_backdrop, _glow]:
		if is_instance_valid(node):
			node.position = Vector2.ZERO
			node.size = size
	var overlay := get_node_or_null("Overlay") as Control
	if overlay != null:
		overlay.position = Vector2.ZERO
		overlay.size = size
		(overlay.material as ShaderMaterial).set_shader_parameter("text_side", 0.5 if size.x > 900 else 0.62)
	if is_instance_valid(_glow) and not paths.is_empty():
		(_glow.material as ShaderMaterial).set_shader_parameter("center", Vector2(float(_slot(0)[0]), 0.55))
	for figure in _layers:
		var slot := _slot(int(figure.get_meta("slot")))
		var height := size.y * float(slot[1])
		var width := height * FIGURE_ASPECT
		figure.size = Vector2(width, height)
		# Cabeça perto do topo (os mais distantes um pouco mais baixos); o excesso sai por baixo.
		figure.position = Vector2(size.x * float(slot[0]) - width * 0.5, size.y * (0.0 + float(slot[2]) * 0.12) - height * 0.03)
		(figure.material as ShaderMaterial).set_shader_parameter("rect_size", figure.size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: _layout()


## Versão reduzida (desfocada ao ampliar) para o fundo; cacheada por arquivo.
static func blurred(path: String) -> Texture2D:
	var key := DeckCover.stamp(path)
	if _blurs.has(key): return _blurs[key]
	var texture := DeckCover.load_texture(path)
	var image: Image = texture.get_image() if texture != null else null
	var result: Texture2D = null
	if image != null and not image.is_empty():
		image = image.duplicate() as Image
		if image.is_compressed(): image.decompress()
		image.resize(40, maxi(4, roundi(40.0 * image.get_height() / image.get_width())), Image.INTERPOLATE_BILINEAR)
		result = ImageTexture.create_from_image(image)
	_blurs[key] = result
	return result


static func _shader(kind: String) -> Shader:
	if not _shaders.has(kind):
		var shader := Shader.new()
		shader.code = {"figure": FIGURE_SHADER, "overlay": OVERLAY_SHADER, "glow": GLOW_SHADER}[kind]
		_shaders[kind] = shader
	return _shaders[kind]


static func _material(kind: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader(kind)
	return material
