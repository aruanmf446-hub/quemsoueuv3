extends SceneTree
## Gera versões leves dos modelos com malha gigante (gerados por IA: El Fuego tinha 671 mil
## triângulos, Lorena 440 mil). Usa um nível de detalhe que o próprio importador do Godot
## calcula, compacta os vértices usados e salva uma cena com esqueleto, pele e animação.
## Rodar: godot --headless --path . --script res://tools/godot/make_lite_models.gd
const MODELS := [
	["res://assets/characters/El fuego/Correr.fbx", "res://assets/characters/El fuego/el_fuego_lite.scn", 42000],
	["res://assets/characters/Lorena/1.fbx", "res://assets/characters/Lorena/lorena_lite.scn", 42000],
]

func _initialize() -> void:
	for spec: Array in MODELS:
		_make(spec[0], spec[1], spec[2])
	quit()

func _make(source: String, target: String, max_tris: int) -> void:
	var root: Node = (load(source) as PackedScene).instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		instance.mesh = _lite_mesh(instance.mesh as ArrayMesh, max_tris)
	for node in root.find_children("*", "", true, false):
		node.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	var error := ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS)
	print("LITE ", target, " -> ", error)
	root.free()

func _lite_mesh(mesh: ArrayMesh, max_tris: int) -> ArrayMesh:
	var lite := ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index_data: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		# Escolhe o primeiro LOD com no máximo max_tris triângulos.
		var info := RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
		var width := 4 if vertices.size() > 65535 else 2
		for lod: Dictionary in info.get("lods", []):
			var bytes: PackedByteArray = lod.index_data
			if bytes.size() / width / 3 <= max_tris:
				index_data = bytes.to_int32_array() if width == 4 else _u16(bytes)
				break
		# Compacta: só os vértices usados, na ordem em que aparecem.
		var remap := {}
		var order := PackedInt32Array()
		var new_index := PackedInt32Array()
		new_index.resize(index_data.size())
		for i in range(index_data.size()):
			var old := index_data[i]
			if not remap.has(old):
				remap[old] = order.size()
				order.append(old)
			new_index[i] = remap[old]
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		for slot in range(Mesh.ARRAY_MAX):
			var data = arrays[slot]
			if data == null or slot == Mesh.ARRAY_INDEX: continue
			var per := 1
			if slot == Mesh.ARRAY_TANGENT: per = 4
			elif slot in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]: per = data.size() / vertices.size()
			var copy = data.duplicate()
			copy.resize(order.size() * per)
			for i in range(order.size()):
				for k in range(per): copy[i * per + k] = data[order[i] * per + k]
			out[slot] = copy
		out[Mesh.ARRAY_INDEX] = new_index
		lite.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		lite.surface_set_material(surface, mesh.surface_get_material(surface))
		print("  surface ", surface, ": ", vertices.size(), " -> ", order.size(), " vértices, ", new_index.size() / 3, " triângulos")
	return lite

func _u16(bytes: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(bytes.size() / 2)
	for i in range(out.size()): out[i] = bytes.decode_u16(i * 2)
	return out
