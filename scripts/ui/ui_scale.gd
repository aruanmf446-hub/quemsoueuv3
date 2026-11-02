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

## Unidade de layout: 1 unidade de design. Mantida como função para quem multiplica tamanhos.
static func unit_for(_viewport: Viewport) -> float:
	return 1.0
