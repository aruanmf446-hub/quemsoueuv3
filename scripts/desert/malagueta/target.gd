extends "res://scripts/desert/t15d/cactus.gd"
signal hit_received(amount: int)
## Use the existing boss model and combat target contract, never chase/attack like a soldier.
func _physics_process(delta: float) -> void:
	if crystallized_left>0:
		crystallized_left=maxf(0,crystallized_left-delta)
		_model.set_rate(0.0)
		if crystallized_left<=0:
			if is_instance_valid(_crystal): _crystal.finish()
			_model.set_rate(1.0)
func take_damage(amount: int) -> void:
	if amount > 0: hit_received.emit(amount)
