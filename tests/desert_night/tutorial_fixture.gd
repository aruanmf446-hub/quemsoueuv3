extends RefCounted
## Apenas suites de regressão: simula jogador que já leu as lições, em user:// isolado.
static func experienced() -> void:
	var config:=ConfigFile.new()
	for lesson in ["attack","defense","task","amber","dash","rupture"]:config.set_value("guest",lesson,true)
	config.save("user://desert_first_use_v1.cfg")
