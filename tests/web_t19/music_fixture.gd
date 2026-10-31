extends MenuMusicPlayer
var requests := 0
func _web() -> bool: return true
func _available(_track: Dictionary) -> bool: return true
func _fetch_web(track: Dictionary, position: float) -> void:
	requests += 1
	_web_wanted={"track":track,"position":position}
	if _web_loading.is_empty(): _web_loading=str(track.id)
