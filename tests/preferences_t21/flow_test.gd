extends SceneTree
## T21: a playlist do menu é por dono (conta GAME ou visitante) neste aparelho.
## Usa ids de teste e apaga os arquivos que criou. Sem rede nem Supabase.
var failures := 0
const A := "00000000-0000-4000-8000-0000000000a1"
const B := "00000000-0000-4000-8000-0000000000b2"


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func _run() -> void:
	await process_frame
	var music: Node = root.get_node("MenuMusic")
	var ids: Array = []
	for track: Dictionary in music.tracks: ids.append(str(track.id))
	_check(ids.size() >= 2, "catálogo com faixas para o teste")
	var first := str(ids[0])
	var second := str(ids[1])
	var legacy := FileAccess.file_exists(music.SELECTION_PATH)

	music.set_owner_scope(A)
	_check(music.save_selection([], [first]), "conta A grava a playlist")
	_check(music.is_excluded(first), "conta A vê a faixa desmarcada")
	var path_a: String = music.selection_path()

	music.set_owner_scope(B)
	if not legacy:
		_check(not music.is_excluded(first), "conta B não herda a escolha da conta A")
	_check(music.save_selection([], [second]), "conta B grava a própria playlist")
	var path_b: String = music.selection_path()
	_check(path_a != path_b, "arquivos separados por conta")

	music.set_owner_scope("")
	if not legacy:
		_check(not music.is_excluded(first) and not music.is_excluded(second), "visitante tem escolhas próprias")
	_check(music.selection_path().contains("/guest/"), "visitante usa a pasta guest")

	music.set_owner_scope(A)
	_check(music.is_excluded(first) and not music.is_excluded(second), "voltar para a conta A recarrega as escolhas dela")
	music.set_owner_scope("../../etc")
	_check(not music.selection_path().contains(".."), "id inválido nunca vira caminho relativo")

	for path: String in [path_a, path_b]:
		DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(path.get_base_dir())
	music.set_owner_scope("")
	print("T21_PREFERENCES ", "OK" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
