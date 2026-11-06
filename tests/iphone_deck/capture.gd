extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0]
	var dimensions := args[1]
	var dims := dimensions.split("x")
	root.size=Vector2i(int(dims[0]),int(dims[1]))
	UIScale.apply_device_profile(root)
	DirAccess.make_dir_recursive_absolute(output)
	var fixture := preload("res://tests/iphone_deck/web_fixture.gd").new()
	root.add_child(fixture)
	for frame in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+dimensions+"_form.png")
	var add: Button=fixture.ui.find_child("AddCard",true,false)
	if add.custom_minimum_size.y<80 or not Rect2(Vector2.ZERO,fixture.ui.size).encloses(add.get_global_rect()): failures+=1
	var image := (load("res://assets/duel/decks/oficial/lendas_urbanas/momo.png") as Texture2D).get_image()
	fixture.ui._pending_card=-1
	fixture.ui._image_picked(image,image.save_png_to_buffer(),"png")
	for frame in 8: await process_frame
	var confirm: Button=fixture.ui.find_child("ConfirmFrame",true,false)
	if not Rect2(Vector2.ZERO,fixture.ui.size).encloses(confirm.get_global_rect()): failures+=1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+dimensions+"_frame.png")
	fixture.ui._editor_overlay.confirmed.emit({})
	for frame in 12: await process_frame
	var scroll: ScrollContainer=fixture.ui.get_node("Margin/Column/Scroll")
	scroll.ensure_control_visible(fixture.ui.find_child("DraftCard_0",true,false))
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+dimensions+"_card.png")
	add=fixture.ui.find_child("AddCard",true,false)
	if not Rect2(Vector2.ZERO,fixture.ui.size).encloses(add.get_global_rect()): failures+=1
	fixture.ui._render_review()
	for frame in 12: await process_frame
	var prompt: Button=fixture.ui.find_child("CopyDeckStylePrompt",true,false)
	if not prompt.is_visible_in_tree() or not Rect2(Vector2.ZERO,fixture.ui.size).encloses(prompt.get_global_rect()): failures+=1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+dimensions+"_review.png")
	fixture.queue_free()
	for frame in 4: await process_frame
	print("IPHONE_DECK_LAYOUT failures=",failures," ",dimensions)
	quit(1 if failures else 0)
