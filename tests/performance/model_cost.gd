extends SceneTree
func _initialize() -> void:
 for path in ["res://assets/characters/El fuego/Correr.fbx", "res://assets/characters/Lorena/1.fbx"]:
  var scene: Node = load(path).instantiate()
  var vertices := 0
  for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
   for i in mesh.mesh.get_surface_count(): vertices += mesh.mesh.surface_get_array_len(i)
  var keys := 0
  for player: AnimationPlayer in scene.find_children("*", "AnimationPlayer", true, false):
   for anim in player.get_animation_list():
    var a := player.get_animation(anim)
    for track in a.get_track_count(): keys += a.track_get_key_count(track)
  print(path, " vertices=", vertices, " keys=", keys)
  scene.free()
 quit()
