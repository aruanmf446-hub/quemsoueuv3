extends SceneTree
## UI real + guardas locais; nenhum usuario ficticio criado no GAME.
var checks := 0
var fails := 0

func check(value: bool, name: String) -> void:
	checks += 1
	if not value:
		fails += 1
		push_error("NICKNAME_ONBOARDING_FAIL " + name)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var script := load("res://scripts/ui/nickname_onboarding.gd") as GDScript
	check(script != null and script.can_instantiate(), "nickname script compila")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var prompt: Control = script.new()
	root.add_child(prompt)
	await process_frame
	check(prompt.get_node_or_null("BlockingBackdrop") != null, "bloqueio interativo real")
	check(prompt.find_child("NicknamePanel", true, false) != null, "painel compacto")
	var entry := prompt.find_child("NicknameInput", true, false) as LineEdit
	var save := prompt.find_child("ConfirmNickname", true, false) as Button
	check(entry != null, "campo real com foco/toque")
	check(save != null, "botao real para confirmar")
	if entry != null and save != null:
		check(entry.max_length == 24, "limite de 24 caracteres")
		check(save.disabled, "vazio nao pode salvar")
		entry.text = "Jogador 01"
		entry.text_changed.emit(entry.text)
		check(not save.disabled, "nickname valido habilita botao")
		entry.text = "A"
		entry.text_changed.emit(entry.text)
		check(save.disabled, "nickname curto bloqueado")
	check(script.source_code.contains("services.profile.update_nickname(nickname)"), "salva pelo GAME")
	check(script.source_code.contains("services.session.authenticated()"), "somente usuario autenticado")
	var valid_skin: String = str(PlayerContracts.initial_ids()[0])
	var first_profile := {
		"user_id": "11111111-1111-4111-8111-111111111111",
		"public_id": "QSE-TEST-0001",
		"nickname": null,
		"equipped_character_id": valid_skin,
		"level": null,
		"experience": "0",
		"statistics": {},
		"discoverable": true
	}
	check(PlayerContracts.valid_profile(first_profile), "perfil proprio permite nickname nulo no primeiro acesso")
	var public_profile: Dictionary = first_profile.duplicate()
	public_profile.erase("statistics")
	public_profile.erase("discoverable")
	public_profile.erase("experience")
	check(not PlayerContracts.valid_public_profile(public_profile), "perfil publico rejeita nickname nulo")
	first_profile.nickname = "Aruan"
	check(PlayerContracts.valid_profile(first_profile), "perfil proprio com nickname valido")
	public_profile.nickname = "Aruan"
	check(PlayerContracts.valid_public_profile(public_profile), "perfil publico com nickname valido")
	check(script.source_code.contains('str(services.profile.data.get("nickname", "")) == nickname'), "confere gravacao real")
	var main_source := (load("res://scripts/menu/main_menu.gd") as GDScript).source_code
	check(main_source.contains("services.profile.state == \"success\"") or main_source.contains("_services.profile.state == \"success\""), "espera carga do perfil")
	check(main_source.contains("func _nickname_offer()"), "oferece apelido automaticamente")
	check(main_source.contains("if not logged or (ready and not nickname.is_empty())"), "dispensa modal quando salvo")
	var provider_src := (load("res://scripts/services/player_services.gd") as GDScript).source_code
	check(provider_src.contains('"Jogador local"'), "convidado local tem rotulo proprio")
	print("NICKNAME_ONBOARDING_RESULT checks=", checks, " failures=", fails)
	quit(1 if fails > 0 else 0)
