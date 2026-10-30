extends SceneTree
## Shared internal frame and real packaged portraits, without user cache or network.
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	for entry: Dictionary in CharacterCatalog.load_entries():
		var portrait := PlayerUI.portrait(entry.id, 88)
		check(portrait.texture != null and portrait.texture.resource_path == "res://assets/portraits/%s.png" % entry.id, "packaged_portrait_" + entry.id)
		var image := Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/portraits/%s.png" % entry.id))
		check(image.get_height() >= 512 and image.detect_alpha() != Image.ALPHA_NONE, "portrait_resolution_alpha_" + entry.id)
		portrait.free()
	for id: String in ["", "../not-a-skin", "unknown"]:
		var portrait := PlayerUI.portrait(id)
		check(portrait.texture != null, "safe_unknown_skin_" + id)
		portrait.free()
	var screen := load("res://scenes/player/components/screen_frame.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	for frame in range(4): await process_frame
	var backdrop: TextureRect = screen.get_node("Backdrop")
	var tint: ColorRect = screen.get_node("Tint")
	check(not backdrop.visible and backdrop.texture == null, "shared_frame_no_lobby_art")
	check(tint.visible and tint.color == PlayerUI.INTERIOR_BG and tint.material == null, "shared_frame_opaque_solid_surface")
	screen.queue_free()
	await process_frame
	print("SOLID_INTERIORS checks=", checks, " failures=", failures)
	call_deferred("quit", 1 if failures else 0)
