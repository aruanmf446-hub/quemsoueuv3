class_name ThumbnailCache
extends RefCounted

## Gera miniaturas estáticas dos personagens com o mesmo palco do lobby (mesma câmera,
## iluminação e perfil gráfico). Em vez de renderizar oito modelos em tempo real no painel,
## cada miniatura é capturada uma vez e reutilizada. Para atualizar as miniaturas após
## mudar iluminação ou modelos, incremente VERSION: os arquivos antigos deixam de ser usados.

const CACHE_DIR := "user://thumbnails"
const VERSION := 5
const THUMB_SIZE := Vector2i(1024, 1280)
## Zoom de captura: deixa o personagem maior dentro da miniatura (menor = mais perto).
const THUMB_ZOOM := 0.8
## Ajuste de câmera por personagem (multiplica o zoom; maior = mais longe).
## El Fuego tem pose de corrida mais larga que a altura declarada, então precisa de mais distância.
const FRAME_ZOOM := {"el_fuego": 1.25}

var _stage_scene: PackedScene


func _init(stage_scene: PackedScene) -> void:
	_stage_scene = stage_scene


static func path_for(character_id: String) -> String:
	return "%s/%s_v%d.png" % [CACHE_DIR, character_id, VERSION]


## Multiplicador de zoom para a skin (1.0 quando não há ajuste). Usado também na prévia.
static func framing_zoom(character_id: String) -> float:
	return FRAME_ZOOM.get(character_id, 1.0)


## Gera as miniaturas que ainda não existem e retorna {character_id: caminho_png}.
## `host` precisa estar na árvore e visível, porque o palco é renderizado dentro dele.
func ensure(host: Control, entries: Array) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	var result := {}
	var missing: Array = []
	for entry: Dictionary in entries:
		var path := path_for(entry["id"])
		if FileAccess.file_exists(path):
			result[entry["id"]] = path
		else:
			missing.append(entry)
	# O renderizador headless não produz frame_post_draw para capturas.
	if DisplayServer.get_name() == "headless":
		return result
	if missing.is_empty():
		return result

	var stage := _stage_scene.instantiate() as LobbyStage
	stage.position = Vector2(-6000, 0)
	stage.custom_minimum_size = Vector2(THUMB_SIZE)
	stage.size = Vector2(THUMB_SIZE)
	host.add_child(stage)
	stage.apply_profile("alto")
	for entry: Dictionary in missing:
		if not is_instance_valid(host) or not host.is_visible_in_tree():
			break
		stage.show_character(entry)
		stage.set_zoom(THUMB_ZOOM * framing_zoom(entry["id"]))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if not is_instance_valid(stage) or not is_instance_valid(host):
			return result
		if not host.is_visible_in_tree():
			break
		var viewport := stage.get_node("Viewport") as SubViewport
		var image: Image = viewport.get_texture().get_image()
		if image == null or image.is_empty():
			continue
		# Capture at native resolution; never enlarge a low-resolution render.
		if image.get_size() != THUMB_SIZE:
			push_warning("Unexpected thumbnail render size: %s" % image.get_size())
		var path := path_for(entry["id"])
		var err: Error = image.save_png(path)
		if err == OK:
			result[entry["id"]] = path
		else:
			push_warning("Miniatura não salva para %s (erro %d)." % [entry["id"], err])
	if is_instance_valid(stage):
		stage.queue_free()
	return result
