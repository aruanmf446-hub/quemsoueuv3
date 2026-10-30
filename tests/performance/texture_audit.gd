extends SceneTree
var used := {}
func _initialize() -> void:
 audit("res://assets")
 for path in used: print("TEXTURE_DEP ",path)
 quit()
func audit(path: String) -> void:
 for leaf in DirAccess.get_directories_at(path): audit(path.path_join(leaf))
 for leaf in DirAccess.get_files_at(path):
  var full := path.path_join(leaf)
  if leaf.get_extension() in ["fbx","scn","glb","gltf","tscn","tres","res"]:
   for dependency in ResourceLoader.get_dependencies(full):
    var actual: String = dependency.get_slice("::",2) if "::" in dependency else dependency
    if actual.get_extension() in ["png","jpg","jpeg"]: used[actual] = true
