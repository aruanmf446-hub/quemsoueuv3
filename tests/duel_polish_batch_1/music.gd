extends Node
## Transport fixture only; never starts a real audio stream or changes account playlists.
var id:="first"
var paused:=false
func available_tracks()->Array:return [{"id":id}]
func current_track()->Dictionary:return {"id":id,"title":"Faixa de teste"}
func track_length()->float:return 100.0
func playback_position()->float:return 20.0
