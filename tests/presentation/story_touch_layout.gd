extends SceneTree
## Geometria nativa dos alvos de toque; sem gameplay nem serviços externos.
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+message)
func run() -> void:
	var models := [Vector2i(640,360)]
	if UIScale.is_iphone(): models = [Vector2i(750,353),Vector2i(712,338),Vector2i(667,359)]
	for model: Vector2i in models:
		root.mode = Window.MODE_WINDOWED
		root.size = model
		var carousel := PresentationCarousel.new()
		carousel.manual_story = true
		root.add_child(carousel)
		carousel.set_cards_data([PhaseStory.cards_for(1)[4],PhaseStory.cards_for(1)[4]])
		carousel.index = 1
		for frame in range(5): await process_frame
		carousel._layout()
		var expected := 88.0 if UIScale.is_iphone() else 64.0
		check(carousel._story_next.size.y >= expected,"%s: altura da ação %.0f" % [model,expected])
		check(carousel._skip.size.y >= expected and carousel._back.size.y >= expected,"%s: pular e voltar têm alvo adequado" % model)
		var message: Label = carousel._front.get_node("Caption/Message")
		var needed := message.get_line_count()*message.get_line_height()
		check(message.global_position.y+needed <= carousel._story_next.global_position.y,"%s: fala longa não cobre ação" % model)
		check(not carousel._back.get_global_rect().intersects(carousel._front.get_node("Caption").get_global_rect()),"%s: Voltar fica fora da legenda" % model)
		check(root.get_visible_rect().encloses(carousel._story_next.get_global_rect()),"%s: ação dentro do viewport" % model)
		carousel.queue_free()
		await process_frame
	print("STORY_TOUCH_LAYOUT_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
