extends SceneTree
const Slot = preload("res://scripts/desert/t15d/actor_slot.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/desert_enemies.json")).enemies.cactus
 var held := []
 for path in entry.animations.values(): held.append(load(path))
 var times := []
 for i in 8:
  var actor := Slot.new()
  root.add_child(actor)
  var start := Time.get_ticks_usec()
  actor.load_entry(entry)
  times.append((Time.get_ticks_usec()-start)/1000.0)
  actor.free()
 print("ACTOR_LOAD_MS ", JSON.stringify(times))
 quit()
