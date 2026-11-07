extends RefCounted
## As rotas usam --fixed-fps: minutos simulados passam em segundos reais.
## O mixer Dummy trabalha em tempo real. Dá-lhe quatro buffers para soltar os
## playbacks já parados antes de encerrar o motor, sem esconder nenhum erro.
static func finish(tree: SceneTree,scene: Node=null) -> void:
 if is_instance_valid(scene):scene.free()
 var deadline:=Time.get_ticks_msec()+90
 while Time.get_ticks_msec()<deadline:await tree.process_frame
