class_name UIScale
extends RefCounted
static var _browser_window: Variant
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
	# O canvas Web pode ter resolução limitada sem mudar a densidade física do
	# telefone. Medir os pontos CSS evita ampliar a UI pelo DPR original.
	if OS.has_feature("web"):
		if _browser_window == null: _browser_window = JavaScriptBridge.get_interface("window")
		if _browser_window != null:
			return Vector2(float(_browser_window.innerWidth), float(_browser_window.innerHeight))
	return Vector2(DisplayServer.window_get_size()) / device_scale()

## Tela baixa (celular deitado): layout compacto com alvos de toque maiores.
static func is_compact(limit := 600.0) -> bool:
	return logical_size().y < limit or OS.has_feature("android") or OS.has_feature("web_android") or OS.has_feature("web_ios")

## Quantas unidades do viewport equivalem a um ponto da tela. Multiplicar tamanhos por
## esse fator mantém textos e botões com o mesmo tamanho físico em qualquer aparelho.
static func unit_for(viewport: Viewport) -> float:
	return viewport.get_visible_rect().size.y / maxf(logical_size().y, 1.0)
