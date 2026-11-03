extends SceneTree
## T32 — Teste offline real do Godot 4.7.2.
## Não abre microfone ou LiveKit; verifica apenas estados e integração.
var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool, description: String) -> void:
    checks += 1
    print(("PASS " if ok else "FAIL ") + description)
    if not ok: failures += 1

func _run() -> void:
    var services := PlayerServices.new()
    root.add_child(services)
    for i in range(4): await process_frame
    verify(services.voice != null, "VoiceService criado pelo PlayerServices")
    verify(services.voice.state == "idle", "Voz inicia desconectada")
    verify(not services.voice.microphone_on, "Microfone inicia desligado")
    verify(not services.voice.supported(), "Headless nao finge suporte Web")
    verify(not services.voice.eligible(), "Usuario anonimo nao conecta")
    services.duel.mode = "local"
    services.duel.room = {"room": {"id": "00000000-0000-4000-8000-000000000032", "status": "lobby"}}
    services.duel.changed.emit()
    verify(not services.voice.eligible(), "Partida local nao usa LiveKit")
    var panel := load("res://scripts/ui/battle/voice_panel.gd").new() as Control
    panel.setup(services)
    root.add_child(panel)
    for i in range(3): await process_frame
    var join := panel.find_child("VoiceConnect", true, false) as Button
    var mic := panel.find_child("VoiceMicrophone", true, false) as Button
    verify(join != null and not join.visible, "Botao de conexao oculto em partida local")
    verify(mic != null and not mic.visible, "Botao de microfone oculto sem conexao")
    services.voice.leave_voice()
    verify(services.voice.state == "idle" and not services.voice.microphone_on, "Desconectar limpa estado")
    print("T32_VOICE checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
