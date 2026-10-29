extends Node
## Sons da campanha noturna, sintetizados em memória (sem arquivos de áudio).
## Cada som mistura camadas (ruído filtrado, corpo grave, harmônicos) com envelopes
## próprios, a 44,1 kHz. Tocam no barramento SFX das Configurações; sem ele, no Master.
const RATE := 44100
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 7_211
	var bus := &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	for index in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = bus
		add_child(player)
		_players.append(player)
	_streams.swing = _swing()
	_streams.hit = _hit()
	_streams.hurt = _hurt()
	_streams.block = _block()
	_streams.pickup = _chime([880.0, 1318.5], 0.42, 0.09)
	_streams.checkpoint = _chime([523.3, 659.3, 784.0, 1046.5], 0.9, 0.11)
	_streams.empty = _empty()
	_streams.windup = _windup()
	_streams.fall = _fall()
	_streams.jump = _jump()
	_streams.land = _land()

## Variação leve de altura a cada disparo: repetições não soam idênticas.
func play(cue: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _streams.has(cue): return
	var player := _players[_next]
	_next = (_next+1)%_players.size()
	player.stream = _streams[cue]
	player.pitch_scale = pitch*_rng.randf_range(0.96, 1.04)
	player.volume_db = volume_db
	player.play()

# --- síntese ---------------------------------------------------------------

static func _env(t: float, attack: float, decay: float) -> float:
	return minf(t/maxf(attack, 0.0001), 1.0)*exp(-t/decay)

func _render(length: float, voice: Callable) -> AudioStreamWAV:
	var samples := int(length*RATE)
	var data := PackedByteArray()
	data.resize(samples*2)
	var state := {"lp": 0.0, "lp2": 0.0, "hp": 0.0, "last": 0.0, "phase": 0.0, "phase2": 0.0}
	var noise := RandomNumberGenerator.new()
	noise.seed = 4_513
	var fade := int(0.004*RATE)
	var values := PackedFloat32Array()
	values.resize(samples)
	var peak := 0.0001
	for index in range(samples):
		var t := float(index)/RATE
		var value: float = voice.call(t, noise.randf_range(-1.0, 1.0), state)
		# Rampa curta no fim: nenhum som termina com estalo.
		if index > samples-fade: value *= float(samples-index)/fade
		values[index] = value
		peak = maxf(peak, absf(value))
	# Normaliza pelo pico (sem saturar); o volume relativo fica no volume_db de play().
	var gain := 0.8/peak
	for index in range(samples):
		data.encode_s16(index*2, int(clampf(values[index]*gain, -1.0, 1.0)*32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream

## Filtro passa-baixa de um polo com frequência de corte variável.
static func _lowpass(state: Dictionary, key: String, input: float, cutoff: float) -> float:
	var a := 1.0-exp(-TAU*cutoff/RATE)
	state[key] = float(state[key])+a*(input-float(state[key]))
	return state[key]

## Sopro de ar: ruído com filtro que varre de grave para agudo e volta.
func _swing() -> AudioStreamWAV:
	return _render(0.22, func(t: float, n: float, s: Dictionary) -> float:
		var sweep := 600.0+5200.0*sin(clampf(t/0.22, 0.0, 1.0)*PI)
		var band := _lowpass(s, "lp", n, sweep)-_lowpass(s, "lp2", n, sweep*0.35)
		return band*2.6*_env(t, 0.03, 0.07))

## Impacto: batida grave descendente, estalo agudo curto e ruído de corpo.
func _hit() -> AudioStreamWAV:
	return _render(0.32, func(t: float, n: float, s: Dictionary) -> float:
		s.phase = float(s.phase)+TAU*lerpf(140.0, 48.0, minf(t/0.18, 1.0))/RATE
		var body := sin(s.phase)*_env(t, 0.002, 0.09)
		var crack := _lowpass(s, "lp", n, 3800.0)*_env(t, 0.0005, 0.018)*1.4
		var dust := _lowpass(s, "lp2", n, 900.0)*_env(t, 0.004, 0.08)*0.8
		return body*0.95+crack+dust)

## Dano: golpe surdo com um "ugh" (duas formantes descendentes).
func _hurt() -> AudioStreamWAV:
	return _render(0.34, func(t: float, n: float, s: Dictionary) -> float:
		var pitch := lerpf(210.0, 120.0, minf(t/0.3, 1.0))
		s.phase = float(s.phase)+TAU*pitch/RATE
		var buzz := (fmod(float(s.phase)/TAU, 1.0)*2.0-1.0)
		var voice := _lowpass(s, "lp", buzz, 900.0)-_lowpass(s, "lp2", buzz, 300.0)
		var thump := sin(TAU*60.0*t)*_env(t, 0.002, 0.05)
		return voice*1.6*_env(t, 0.015, 0.12)+thump*0.7+n*0.05*_env(t, 0.001, 0.02))

## Bloqueio: parciais inarmônicas de metal com decaimentos diferentes.
func _block() -> AudioStreamWAV:
	return _render(0.55, func(t: float, n: float, s: Dictionary) -> float:
		var ring := 0.0
		for partial: Array in [[1120.0, 0.16, 0.5], [1693.0, 0.11, 0.35], [2547.0, 0.07, 0.25], [3301.0, 0.05, 0.18]]:
			ring += sin(TAU*float(partial[0])*t)*float(partial[2])*exp(-t/float(partial[1]))
		var click := _lowpass(s, "lp", n, 6000.0)*_env(t, 0.0003, 0.006)
		return ring*0.55+click)

## Coleta/checkpoint: notas em arpejo com harmônico e brilho decaindo.
func _chime(notes: Array, length: float, step: float) -> AudioStreamWAV:
	return _render(length, func(t: float, _n: float, _s: Dictionary) -> float:
		var value := 0.0
		for index in range(notes.size()):
			var start := index*step
			if t < start: continue
			var local := t-start
			var f := float(notes[index])
			value += (sin(TAU*f*local)+0.35*sin(TAU*f*2.0*local)+0.12*sin(TAU*f*3.01*local))*_env(local, 0.004, 0.16)
		return value*0.32)

## Ação sem carga: dois toques graves e abafados.
func _empty() -> AudioStreamWAV:
	return _render(0.2, func(t: float, _n: float, s: Dictionary) -> float:
		var local := fmod(t, 0.09)
		var square := signf(sin(TAU*150.0*t))
		return _lowpass(s, "lp", square, 700.0)*0.45*_env(local, 0.003, 0.03))

## Preparação do Cactus: rosnado crescente com chiado de espinhos.
func _windup() -> AudioStreamWAV:
	return _render(0.36, func(t: float, n: float, s: Dictionary) -> float:
		s.phase = float(s.phase)+TAU*lerpf(85.0, 150.0, t/0.36)/RATE
		var growl := (fmod(float(s.phase)/TAU, 1.0)*2.0-1.0)
		var tone := _lowpass(s, "lp", growl, 650.0)
		var hiss := (n-_lowpass(s, "lp2", n, 4000.0))*0.25
		return (tone*0.9+hiss)*minf(t/0.25, 1.0)*exp(-maxf(t-0.28, 0.0)/0.04))

## Queda: assobio descendente e vento.
func _fall() -> AudioStreamWAV:
	return _render(0.9, func(t: float, n: float, s: Dictionary) -> float:
		s.phase = float(s.phase)+TAU*lerpf(900.0, 160.0, minf(t/0.8, 1.0))/RATE
		var whistle := sin(s.phase)*0.35
		var wind := _lowpass(s, "lp", n, 700.0)*0.9
		return (whistle+wind)*_env(t, 0.02, 0.35))

## Pulo: sopro curto ascendente.
func _jump() -> AudioStreamWAV:
	return _render(0.16, func(t: float, n: float, s: Dictionary) -> float:
		var cutoff := lerpf(700.0, 2600.0, t/0.16)
		return (_lowpass(s, "lp", n, cutoff)-_lowpass(s, "lp2", n, cutoff*0.4))*1.8*_env(t, 0.015, 0.05))

## Aterrissagem: batida macia de areia.
func _land() -> AudioStreamWAV:
	return _render(0.18, func(t: float, n: float, s: Dictionary) -> float:
		var thud := sin(TAU*lerpf(110.0, 60.0, t/0.18)*t)*_env(t, 0.002, 0.04)
		var sand := _lowpass(s, "lp", n, 1500.0)*_env(t, 0.002, 0.035)
		return thud*0.7+sand*0.9)
