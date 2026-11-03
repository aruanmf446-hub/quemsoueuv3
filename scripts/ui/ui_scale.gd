class_name UIScale
extends RefCounted
## Escala da interface pelo tamanho real da tela, não pelos pixels da janela.
## Um iPhone deitado tem ~390 pontos de altura mas 1170 pixels (devicePixelRatio 3):
## medir em pixels fazia o jogo usar o layout de computador, com texto minúsculo.
## Testes podem simular a densidade com o argumento de usuário --ui-scale=<n>.

static func device_scale() -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-scale="): return maxf(float(arg.get_slice("=", 1)), 1.0)
	var scale := DisplayServer.screen_get_scale()
	if OS.has_feature("android"):
		scale = maxf(scale, DisplayServer.screen_get_dpi() / 160.0)
	return maxf(scale, 1.0)

## Tamanho da janela em pontos (pixels lógicos).
static func logical_size() -> Vector2:
	return Vector2(DisplayServer.window_get_size()) / device_scale()

## LAYOUT PADRÃO (decisão do dono do projeto): todas as telas usam o MESMO layout, em
## unidades de design (viewport base 1672×941, stretch canvas_items/expand). O Godot escala o
## conjunto inteiro por igual para qualquer janela; nada é reorganizado nem aumentado por
## densidade de tela. Por isso o layout nunca é "compacto" e a unidade é sempre 1.
static func is_compact(_limit := 600.0) -> bool:
	return false

## Aparelho de mão (celular/tablet ou tela baixa): só para DESEMPENHO e TOQUE (qualidade 3D,
## controles de toque), nunca para mudar o layout.
static func is_handheld() -> bool:
	return logical_size().y < 600.0 or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("web_android") or OS.has_feature("web_ios")

## PERFIL iPHONE (decisão do dono, docs/layout/README_IPHONE.md): só iPhone pelo navegador
## (app instalado ou Safari). O jogo fica dentro da área segura (web/shell.html) e a base de
## design passa de 1672×941 para IPHONE_BASE: com a altura útil de ~350 pt de um iPhone deitado,
## a interface fica ~30% maior. Android, Windows, iPad e navegador de computador não mudam.
## Testes simulam com o argumento de usuário --iphone (ou QSE_TEST_IPHONE=1).
const IPHONE_BASE := Vector2i(1138, 640)
## Piso de legibilidade no iPhone (px de design): ~9,5 pt no 13 mini e ~11 pt no Pro Max.
## Só textos menores sobem; os maiores ficam como estão.
const IPHONE_MIN_FONT := 18
static var _iphone := -1

static func is_iphone() -> bool:
	if _iphone < 0:
		_iphone = 0
		if OS.get_cmdline_user_args().has("--iphone") or OS.get_environment("QSE_TEST_IPHONE") == "1":
			_iphone = 1
		elif OS.has_feature("web"):
			var value: Variant = JavaScriptBridge.eval("!!(window.qsePwa && window.qsePwa.iphone)", true)
			_iphone = 1 if value == true else 0
	return _iphone == 1

## Aplica a base do iPhone na janela principal (chamado por um autoload na abertura).
static func apply_device_profile(root: Window) -> void:
	if not is_iphone(): return
	root.content_scale_size = IPHONE_BASE
	var tree := root.get_tree()
	if tree != null and not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	for node in root.find_children("*", "Control", true, false): _lift_font.call_deferred(node)


static func _on_node_added(node: Node) -> void:
	if node is Control: _lift_font.call_deferred(node)


## Sobe textos abaixo do piso (Label, Button, LineEdit, OptionButton, RichTextLabel...).
## Reaplicado quando a tela troca o tamanho depois (theme_changed não cobre overrides).
static func _lift_font(node: Node) -> void:
	if not is_instance_valid(node) or not node is Control: return
	var control := node as Control
	var key := "normal_font_size" if control is RichTextLabel else "font_size"
	if not (control is Label or control is BaseButton or control is LineEdit or control is TextEdit or control is RichTextLabel): return
	# Telas com escala própria (batalha) ficam fora do piso: lá o texto já é medido pelo espaço.
	var up: Node = control
	for i in 14:
		if up == null: break
		if up.has_meta("qse_no_font_floor"): return
		up = up.get_parent()
	if control.get_theme_font_size(key) < IPHONE_MIN_FONT:
		control.add_theme_font_size_override(key, IPHONE_MIN_FONT)
	if not control.has_meta("qse_font_floor"):
		control.set_meta("qse_font_floor", true)
		# Telas que refazem tamanhos no resize: conferir de novo.
		control.resized.connect(func() -> void:
			if is_instance_valid(control) and control.get_theme_font_size(key) < IPHONE_MIN_FONT:
				control.add_theme_font_size_override(key, IPHONE_MIN_FONT))

## Unidade de layout: 1 unidade de design. Mantida como função para quem multiplica tamanhos.
static func unit_for(_viewport: Viewport) -> float:
	return 1.0
