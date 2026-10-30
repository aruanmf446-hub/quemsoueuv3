extends PanelContainer
## Lightweight layered geometry; fixed composition, no bitmap theme or live post-processing.
@export var atmosphere := false
@export var active := false
@export var padding := 9
## "panel" (padrão), "board" (tabuleiro: moldura espessa, brilho de borda e sombra interna)
## ou "player" (cartão do participante: fundo com luz atrás do retrato).
@export var variant := "panel"
## Intensidade do brilho do painel ativo (o jogador da vez respira devagar).
var glow := 1.0
var _halo: GradientTexture2D
var _breath: Tween
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxEmpty.new()
	style.set_content_margin_all(padding if not atmosphere else 0)
	add_theme_stylebox_override("panel", style)
	if atmosphere:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(0.18,0.38,0.62,0.20),Color(0.02,0.05,0.09,0)])
		_halo = GradientTexture2D.new()
		_halo.width = 128
		_halo.height = 128
		_halo.gradient = gradient
		_halo.fill = GradientTexture2D.FILL_RADIAL
		_halo.fill_from = Vector2(0.5,0.5)
		_halo.fill_to = Vector2(1,0.5)
	resized.connect(queue_redraw)
	if active and not atmosphere:
		_breath = create_tween().set_loops()
		_breath.tween_method(_set_glow, 0.55, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
		_breath.tween_method(_set_glow, 1.0, 0.55, 0.9).set_trans(Tween.TRANS_SINE)
func _set_glow(value: float) -> void:
	glow = value
	queue_redraw()
func _draw() -> void:
	if size.x < 8 or size.y < 8: return
	if atmosphere:
		_draw_atmosphere()
		return
	var bounds := Rect2(Vector2(1,1), size - Vector2(2,2))
	var cut := 16.0 if variant == "board" else 13.0
	# Soft contact shadow below a beveled graphite shell.
	for step in range(4,0,-1):
		_polygon(Rect2(bounds.position+Vector2(0,step),bounds.size),Color(0,0,0,0.09),Color(0,0,0,0.09),cut)
	if active:
		for step in range(4,0,-1):
			_edge(bounds.grow(step),Color(1,0.64,0.23,0.07*(5-step)*glow),cut+step,1.5)
	if variant == "board":
		# Halo frio contido em volta do tabuleiro: separa a peça central do fundo.
		for step in range(5,0,-1):
			_edge(bounds.grow(step),Color(0.42,0.62,0.86,0.025*(6-step)),cut+step,2.0)
	_polygon(bounds,Color("#4b6175") if not active else Color("#b18b4f"),Color("#111b29"),cut)
	_edge(bounds,Color("#64819a") if not active else Color("#ffd48b"),cut,1.0)
	var inner := bounds.grow(-2)
	_polygon(inner,Color("#142131") if not active else Color("#382b1b"),Color("#090e17"),cut-1)
	_edge(inner,Color(0.02,0.03,0.04,0.9),cut-1,1)
	if variant == "board":
		# Moldura espessa: segunda placa e sombra interna em degraus.
		var plate := bounds.grow(-4)
		_edge(plate,Color("#8c7247"),cut-2,1.2)
		var well := bounds.grow(-7)
		_polygon(well,Color("#0f1a28"),Color("#070b12"),cut-5)
		for step in range(4):
			_edge(well.grow(-step),Color(0,0,0,0.32-step*0.07),cut-5-step,1.0)
	elif variant == "player":
		# Luz quente/fria atrás do retrato, à esquerda do cartão.
		var light := Color(1,0.66,0.3,0.20*glow) if active else Color(0.35,0.55,0.8,0.12)
		for ring in range(6,0,-1):
			draw_circle(Vector2(minf(size.x*0.12,48.0),size.y*0.62),size.y*0.12*ring,Color(light,light.a/ring))
	# A single inset bevel and short amber corner accents, rather than repeated frames.
	var face := bounds.grow(-5)
	_edge(face,Color(0.38,0.49,0.61,0.2) if not active else Color(1,0.72,0.34,0.42),cut-3,1)
	var inset := cut+4
	var length := minf(size.x*0.16,64.0)
	var gold := Color("#d8ae6c") if active else Color("#9e7c47")
	draw_line(Vector2(inset,4),Vector2(inset+length,4),gold,1,true)
	draw_line(Vector2(size.x-inset-length,size.y-4),Vector2(size.x-inset,size.y-4),Color(gold,0.65),1,true)
	if active:
		draw_line(Vector2(inset,1),Vector2(size.x-inset,1),Color(Color("#ffdc98"),0.6+0.4*glow),2,true)
	if variant == "board":
		# Brilho de borda contido: quatro cantos dourados, sem repetir filetes.
		var corner := minf(size.x,size.y)*0.08
		var shine := Color("#e6bf7d")
		for point in [Vector2(cut+2,6),Vector2(size.x-cut-2,6),Vector2(cut+2,size.y-6),Vector2(size.x-cut-2,size.y-6)]:
			var dir := Vector2(1 if point.x < size.x*0.5 else -1, 1 if point.y < size.y*0.5 else -1)
			draw_line(point,point+Vector2(corner*dir.x,0),shine,1.6,true)
			draw_line(point,point+Vector2(0,corner*0.6*dir.y),Color(shine,0.7),1.6,true)
func _draw_atmosphere() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#060b12"))
	if _halo != null:
		draw_texture_rect(_halo,Rect2(Vector2(-size.x*0.1,-size.y*0.3),Vector2(size.x*0.9,size.y*1.4)),false)
		draw_texture_rect(_halo,Rect2(Vector2(size.x*0.5,size.y*0.15),Vector2(size.x*0.8,size.y*1.3)),false,Color(0.7,0.8,1,0.5))
	for i in range(4):
		var x := size.x*(0.12+i*0.29)
		var diagonal := size.y*0.7
		var band := PackedVector2Array([Vector2(x,0),Vector2(x+14,0),Vector2(x-diagonal+14,size.y),Vector2(x-diagonal,size.y)])
		draw_colored_polygon(band,Color(0.09,0.16,0.25,0.25))
		draw_line(Vector2(x+17,0),Vector2(x-diagonal+17,size.y),Color(0.49,0.33,0.16,0.16),1,true)
	# Luz âmbar baixa à direita e vinheta nas bordas: profundidade sem cenário.
	if _halo != null:
		draw_texture_rect(_halo,Rect2(Vector2(size.x*0.55,size.y*0.55),Vector2(size.x*0.7,size.y*0.9)),false,Color(1.6,0.9,0.35,0.35))
	for step in range(6):
		var inset_v := float(step)*size.y*0.012
		draw_rect(Rect2(Vector2(inset_v,inset_v),size-Vector2(inset_v,inset_v)*2),Color(0,0,0,0.05),false,size.y*0.012)
	# Restrained peripheral glints leave the board as the highest-contrast content.
	for i in range(9):
		var point := Vector2(size.x*(0.035+fmod(i*0.173,0.93)),size.y*(0.18+fmod(i*0.271,0.72)))
		draw_circle(point,1.0 if i%3 else 1.6,Color(0.85,0.55,0.25,0.12))
func _points(rect: Rect2, cut: float) -> PackedVector2Array:
	cut = minf(cut,minf(rect.size.x,rect.size.y)*0.28)
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([Vector2(p.x+cut,p.y),Vector2(e.x-cut,p.y),Vector2(e.x,p.y+cut),Vector2(e.x,e.y-cut),Vector2(e.x-cut,e.y),Vector2(p.x+cut,e.y),Vector2(p.x,e.y-cut),Vector2(p.x,p.y+cut)])
func _polygon(rect: Rect2, top: Color, bottom: Color, cut: float) -> void:
	if rect.size.x <= 1 or rect.size.y <= 1: return
	var points := _points(rect,cut)
	var colors := PackedColorArray()
	for point in points: colors.append(top.lerp(bottom,(point.y-rect.position.y)/rect.size.y))
	draw_polygon(points,colors)
func _edge(rect: Rect2, color: Color, cut: float, width: float) -> void:
	if rect.size.x <= 1 or rect.size.y <= 1: return
	var points := _points(rect,cut)
	points.append(points[0])
	draw_polyline(points,color,width,true)
