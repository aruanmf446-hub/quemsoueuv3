extends CommunityDecksService
func _download(_url: String,path: String) -> bool:
	var image := (load("res://assets/duel/decks/oficial/lendas_urbanas/momo.png") as Texture2D).get_image()
	return image.save_png(path)==OK
