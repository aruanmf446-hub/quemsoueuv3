extends Node
## Sons curtos da campanha noturna, sintetizados em memória (sem arquivos de áudio).
## Tocam no barramento SFX controlado pelas Configurações; sem ele, caem no Master.
const RATE := 22050
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus := &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	for index in range(6):
		var player := AudioStreamPlayer.new()
		player.bus = bus
		add_child(player)
		_players.append(player)
	_streams.swing = _make(0.13, func(t: float, n: float) -> float: return n*_env(t,0.13,0.01)*0.55*(1.0-t/0.13))
	_streams.hit = _make(0.18, func(t: float, n: float) -> float: return (sin(TAU*lerpf(150.0,60.0,t/0.18)*t)*0.9+n*0.35)*_env(t,0.18,0.002))
	_streams.hurt = _make(0.26, func(t: float, n: float) -> float: return (sin(TAU*lerpf(320.0,140.0,t/0.26)*t)*0.6+sin(TAU*lerpf(330.0,150.0,t/0.26)*t)*0.4+n*0.15)*_env(t,0.26,0.004))
	_streams.block = _make(0.22, func(t: float, n: float) -> float: return (sin(TAU*1250.0*t)*0.5+sin(TAU*1870.0*t)*0.3+n*0.1)*exp(-t*18.0))
	_streams.pickup = _make(0.24, func(t: float, _n: float) -> float: return sin(TAU*(660.0 if t < 0.09 else 990.0)*t)*0.45*_env(t,0.24,0.005))
	_streams.empty = _make(0.12, func(t: float, _n: float) -> float: return signf(sin(TAU*110.0*t))*0.22*_env(t,0.12,0.004))
	_streams.windup = _make(0.20, func(t: float, n: float) -> float: return (sin(TAU*lerpf(90.0,170.0,t/0.2)*t)*0.5+n*0.12)*_env(t,0.20,0.03))
	_streams.fall = _make(0.55, func(t: float, n: float) -> float: return (sin(TAU*lerpf(420.0,70.0,t/0.55)*t)*0.45+n*0.1)*_env(t,0.55,0.01))

func play(cue: String, pitch := 1.0) -> void:
	if not _streams.has(cue): return
	var player := _players[_next]
	_next = (_next+1)%_players.size()
	player.stream = _streams[cue]
	player.pitch_scale = pitch
	player.play()

static func _env(t: float, length: float, attack: float) -> float:
	return minf(t/attack,1.0)*clampf(1.0-t/length,0.0,1.0)

func _make(length: float, wave: Callable) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7_211
	var samples := int(length*RATE)
	var data := PackedByteArray()
	data.resize(samples*2)
	for index in range(samples):
		var value := clampf(float(wave.call(float(index)/RATE, rng.randf_range(-1.0,1.0))),-1.0,1.0)
		data.encode_s16(index*2, int(value*24000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
