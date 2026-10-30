extends RefCounted
## Medalhões de ataque, defesa e vida: emblema vetorial (SVG, nítido em qualquer tamanho)
## dentro do anel do HUD (assets/hud/ring*.png). Cada tamanho é montado uma vez
## e fica guardado; desenhar depois custa o mesmo que qualquer textura.

const RINGS := {
	"attack": "res://assets/hud/ring_attack.png",
	"defense": "res://assets/hud/ring.png",
	"health": "res://assets/hud/ring_health.png",
	"empty": "res://assets/hud/ring_empty.png",
}

## Espada dourada em chamas: o golpe de El Fuego.
const ATTACK := """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<defs>
<radialGradient id="bg" cx="64" cy="58" r="46" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#6b2410"/><stop offset="1" stop-color="#1c0705"/></radialGradient>
<radialGradient id="fire" cx="64" cy="64" r="40" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#ffb347" stop-opacity="0.85"/><stop offset="1" stop-color="#ff4d1a" stop-opacity="0"/></radialGradient>
<linearGradient id="blade" x1="56" y1="0" x2="72" y2="0" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fffaf0"/><stop offset="0.48" stop-color="#ffe2a0"/><stop offset="0.52" stop-color="#e8a040"/><stop offset="1" stop-color="#b8661c"/></linearGradient>
<linearGradient id="gold" x1="0" y1="78" x2="0" y2="117" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff0b8"/><stop offset="1" stop-color="#c47a1c"/></linearGradient>
</defs>
<circle cx="64" cy="64" r="46" fill="url(#bg)"/>
<circle cx="64" cy="64" r="40" fill="url(#fire)"/>
<g transform="translate(64 64) rotate(45) scale(0.92) translate(-64 -64)">
<path d="M64 14 L72 28 L72 80 L56 80 L56 28 Z" fill="url(#blade)" stroke="#4a1a06" stroke-width="3" stroke-linejoin="round"/>
<path d="M64 22 L64 76" stroke="#ffffff" stroke-opacity="0.55" stroke-width="2"/>
<rect x="42" y="79" width="44" height="9" rx="4.5" fill="url(#gold)" stroke="#4a1a06" stroke-width="3"/>
<rect x="59" y="88" width="10" height="18" rx="3" fill="#7a3414" stroke="#4a1a06" stroke-width="3"/>
<circle cx="64" cy="110" r="6.5" fill="url(#gold)" stroke="#4a1a06" stroke-width="3"/>
</g>
</svg>"""

## Escudo azul com estrela dourada.
const DEFENSE := """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<defs>
<radialGradient id="bg" cx="64" cy="58" r="46" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#11405f"/><stop offset="1" stop-color="#04121f"/></radialGradient>
<radialGradient id="aura" cx="64" cy="62" r="40" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#7fdcff" stop-opacity="0.7"/><stop offset="1" stop-color="#2a8fd0" stop-opacity="0"/></radialGradient>
<linearGradient id="face" x1="40" y1="30" x2="88" y2="100" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#b8eeff"/><stop offset="0.45" stop-color="#47a9e2"/><stop offset="1" stop-color="#14558a"/></linearGradient>
<linearGradient id="trim" x1="0" y1="26" x2="0" y2="104" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#8fc3df"/></linearGradient>
<linearGradient id="gold" x1="0" y1="44" x2="0" y2="76" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff0b8"/><stop offset="1" stop-color="#d08a24"/></linearGradient>
</defs>
<circle cx="64" cy="64" r="46" fill="url(#bg)"/>
<circle cx="64" cy="64" r="40" fill="url(#aura)"/>
<path d="M64 26 L92 36 L92 60 C92 80 80 94 64 102 C48 94 36 80 36 60 L36 36 Z" fill="url(#face)" stroke="url(#trim)" stroke-width="5" stroke-linejoin="round"/>
<path d="M64 33 L86 41 L86 60 C86 76 77 87 64 94 Z" fill="#ffffff" fill-opacity="0.18"/>
<path d="M64 45 L68.7 55.2 L79.8 56.4 L71.5 63.9 L73.8 74.8 L64 69.2 L54.2 74.8 L56.5 63.9 L48.2 56.4 L59.3 55.2 Z" fill="url(#gold)" stroke="#5a3a0c" stroke-width="2" stroke-linejoin="round"/>
</svg>"""

## Coração do item de vida.
const HEALTH := """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<defs>
<radialGradient id="bg" cx="64" cy="58" r="46" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#5c0f1c"/><stop offset="1" stop-color="#1c0408"/></radialGradient>
<linearGradient id="h" x1="0" y1="32" x2="0" y2="98" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#ff9a90"/><stop offset="0.55" stop-color="#ee3a44"/><stop offset="1" stop-color="#a3122a"/></linearGradient>
</defs>
<circle cx="64" cy="64" r="46" fill="url(#bg)"/>
<path d="M64 98 C40 82 28 69 28 52 C28 40 37 32 48 32 C55 32 60 36 64 42 C68 36 73 32 80 32 C91 32 100 40 100 52 C100 69 88 82 64 98 Z" fill="url(#h)" stroke="#3e0610" stroke-width="4" stroke-linejoin="round"/>
<path d="M42 44 C39 48 38 53 40 58" stroke="#ffffff" stroke-opacity="0.8" stroke-width="5" stroke-linecap="round" fill="none"/>
</svg>"""

## Coração do HUD (sem anel): cheio com brilho; vazio só com o contorno.
const HEART := """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<defs><linearGradient id="h" x1="0" y1="12" x2="0" y2="116" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#ff9a90"/><stop offset="0.55" stop-color="#ee3a44"/><stop offset="1" stop-color="#9c1022"/></linearGradient></defs>
<path d="M64 114 C28 90 10 70 10 45 C10 26 24 13 41 13 C51 13 59 18 64 27 C69 18 77 13 87 13 C104 13 118 26 118 45 C118 70 100 90 64 114 Z" fill="url(#h)" stroke="#3e0610" stroke-width="7" stroke-linejoin="round"/>
<path d="M32 33 C27 39 25 47 28 55" stroke="#ffffff" stroke-opacity="0.85" stroke-width="9" stroke-linecap="round" fill="none"/>
</svg>"""
const HEART_EMPTY := """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<path d="M64 114 C28 90 10 70 10 45 C10 26 24 13 41 13 C51 13 59 18 64 27 C69 18 77 13 87 13 C104 13 118 26 118 45 C118 70 100 90 64 114 Z" fill="#1b2431" fill-opacity="0.7" stroke="#8a95a3" stroke-width="7" stroke-linejoin="round"/>
</svg>"""

static var _cache := {}


## Medalhão completo (emblema + anel) com lado de `pixels`; sem carga fica em cinza.
## `mipmaps` para uso em 3D (itens no mapa), onde a textura é vista de longe.
static func medallion(kind: String, pixels: int, full := true, mipmaps := false) -> Texture2D:
	pixels = _size(pixels)
	var key := "%s/%d/%s/%s" % [kind, pixels, full, mipmaps]
	if _cache.has(key): return _cache[key]
	var svg: String = {"attack": ATTACK, "defense": DEFENSE, "health": HEALTH}.get(kind, HEALTH)
	var image := _raster(svg if full else _greyscale(svg), pixels)
	var ring := (load(RINGS[kind] if full else RINGS.empty) as Texture2D).get_image()
	if ring.is_compressed(): ring.decompress()
	ring.convert(Image.FORMAT_RGBA8)
	ring.resize(pixels, pixels, Image.INTERPOLATE_LANCZOS)
	image.blend_rect(ring, Rect2i(Vector2i.ZERO, ring.get_size()), Vector2i.ZERO)
	if mipmaps: image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func heart(pixels: int, full := true) -> Texture2D:
	pixels = _size(pixels)
	var key := "heart/%d/%s" % [pixels, full]
	if not _cache.has(key): _cache[key] = ImageTexture.create_from_image(_raster(HEART if full else HEART_EMPTY, pixels))
	return _cache[key]


## Tamanho seguro e em degraus de 4 px: telas fora do comum não geram texturas gigantes e
## um redimensionamento não cria uma textura nova a cada pixel.
static func _size(pixels: int) -> int:
	return clampi(snappedi(pixels, 4), 8, 512)


static func _raster(svg: String, pixels: int) -> Image:
	var image := Image.new()
	image.load_svg_from_string(svg, pixels / 128.0)
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != pixels or image.get_height() != pixels:
		image.resize(pixels, pixels, Image.INTERPOLATE_LANCZOS)
	return image


## "Sem carga": cada cor do desenho vira o cinza de mesma luminância, mais escuro.
static func _greyscale(svg: String) -> String:
	var out := svg
	for found in RegEx.create_from_string("#[0-9a-fA-F]{6}").search_all(svg):
		var luminance := Color(found.get_string()).get_luminance() * 0.62
		out = out.replace(found.get_string(), "#" + Color(luminance * 0.92, luminance * 0.96, luminance * 1.04).to_html(false))
	return out
