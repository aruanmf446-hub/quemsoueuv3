class_name GraphicsProfile
extends RefCounted

## Perfis de renderização do palco 3D (Compatibility). "alto" é a referência visual.
## "medio" e "baixo" reduzem apenas custo: MSAA, resolução interna e sombras.
## Nenhum perfil altera brilho, saturação ou texturas dos personagens.

const PROFILES := {
	"alto": {
		"msaa_3d": Viewport.MSAA_4X,
		"stretch_shrink": 1,
		"shadows": true,
	},
	"medio": {
		"msaa_3d": Viewport.MSAA_2X,
		"stretch_shrink": 1,
		"shadows": true,
	},
	"baixo": {
		"msaa_3d": Viewport.MSAA_DISABLED,
		"stretch_shrink": 2,
		"shadows": false,
	},
}


static func default_for_platform() -> String:
	# Navegador também usa "medio": no "baixo" o personagem do lobby saía serrilhado
	# (sem MSAA) e em meia resolução, o que parecia pixelado em telas de celular.
	if OS.has_feature("web"):
		return "medio"
	if OS.has_feature("android"):
		return "medio"
	return "alto"


static func settings(profile_name: String) -> Dictionary:
	return PROFILES.get(profile_name, PROFILES["alto"])
