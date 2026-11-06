extends StaticBody3D
## Jolt conserva RIDs nas exceções do personagem: limpar antes de liberar cada apoio.
func _exit_tree() -> void:
	for actor: Node in get_tree().get_nodes_in_group("player"):
		if actor is PhysicsBody3D:actor.remove_collision_exception_with(self)
