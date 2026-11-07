extends Node
## Banco PCM curto, preparado antes do jogo. Kenney Impact Sounds (CC0) + camadas
## próprias de areia. Sem síntese/decodificação MP3 ao clicar ou trocar de fase.
const ROOT="res://assets/audio/desert_sfx/"
const BANK={
 "swing":[preload(ROOT+"sand_swing.wav")],
 "hit":[preload(ROOT+"impact_punch_heavy_000.wav"),preload(ROOT+"impact_punch_heavy_001.wav"),preload(ROOT+"impact_punch_heavy_002.wav")],
 "hurt":[preload(ROOT+"impact_soft_heavy_000.wav")],
 "block":[preload(ROOT+"impact_mining_000.wav"),preload(ROOT+"impact_mining_001.wav"),preload(ROOT+"impact_mining_002.wav")],
 "jump":[preload(ROOT+"sand_jump.wav")],
 "double_jump":[preload(ROOT+"sand_double_jump.wav")],
 "land":[preload(ROOT+"footstep_snow_000.wav"),preload(ROOT+"footstep_snow_001.wav")],
 "step":[preload(ROOT+"footstep_concrete_000.wav"),preload(ROOT+"footstep_concrete_001.wav")],
 "step_wood":[preload(ROOT+"footstep_wood_000.wav"),preload(ROOT+"footstep_wood_001.wav")],
 "step_soft":[preload(ROOT+"footstep_carpet_000.wav"),preload(ROOT+"footstep_carpet_001.wav")],
 "windup":[preload(ROOT+"impact_wood_light_000.wav")],
 "fall":[preload(ROOT+"sand_fall.wav")],
 "pickup":[preload(ROOT+"collect.wav")],
 "checkpoint":[preload(ROOT+"save.wav")],
 "empty":[preload(ROOT+"footstep_carpet_001.wav")],
}
const GAINS={"hit":-4.0,"hurt":-3.0,"block":-6.0,"swing":-6.0,"jump":-4.0,"double_jump":-3.0,"land":-5.0,"step":-5.0,"step_soft":-5.0,"windup":-11.0,"fall":-7.0,"pickup":-9.0,"checkpoint":-7.0,"empty":-13.0}
const PRIORITY={"hurt":3,"block":3,"checkpoint":3,"hit":2,"pickup":2,"double_jump":2}
var _streams:=BANK
var _players: Array[AudioStreamPlayer]=[]
var _last: Dictionary={}
var _variant: Dictionary={}
var _rng:=RandomNumberGenerator.new()
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 _rng.seed=7211
 for i in 8:
  var player:=AudioStreamPlayer.new()
  player.bus=&"SFX" if AudioServer.get_bus_index(&"SFX")>=0 else &"Master"
  add_child(player)
  _players.append(player)
func play(cue: String,pitch:=1.0,volume_db:=0.0) -> void:
 if not _streams.has(cue):return
 var now:=Time.get_ticks_msec()
 var spacing:=150 if cue in ["windup","empty"] else 45
 if now-int(_last.get(cue,-10000))<spacing:return
 var priority:=int(PRIORITY.get(cue,1))
 var voice: AudioStreamPlayer
 for candidate in _players:
  if not candidate.playing:
   voice=candidate
   break
 if voice==null:
  for candidate in _players:
   if int(candidate.get_meta("priority",0))<priority:
    if voice==null or int(candidate.get_meta("started",0))<int(voice.get_meta("started",0)):voice=candidate
 if voice==null:return
 var variants: Array=_streams[cue]
 var index:=int(_variant.get(cue,0))%variants.size()
 _variant[cue]=index+1
 _last[cue]=now
 voice.stream=variants[index]
 voice.pitch_scale=clampf(pitch*_rng.randf_range(0.975,1.025),0.45,1.65)
 voice.volume_db=clampf(float(GAINS.get(cue,-7.0))+volume_db,-32.0,-1.0)
 voice.set_meta("priority",priority)
 voice.set_meta("started",now)
 voice.play()

func _exit_tree() -> void:
 for voice in _players:
  voice.stop()
  voice.stream=null
