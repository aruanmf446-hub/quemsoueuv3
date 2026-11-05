extends SceneTree
## Políticas do cliente e UI real contra contrato simulado; não prova unicidade no banco.
var checks := 0
var fails := 0
var menu: Control
var services: PlayerServices
var fake: SupabaseClient
var output := ""
var label := "1672x941"
func _initialize() -> void: call_deferred("_run")
func check(value: bool,what: String) -> void:
	checks+=1
	if not value:
		fails+=1
		push_error("NICKNAME_POLICY_FAIL "+what)
func settle(frames := 5) -> void:
	for i in frames: await process_frame
func shot(name: String) -> void:
	if output.is_empty(): return
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+"_"+name+".png")
func reset(value: Variant=null) -> void:
	fake.nickname=value
	fake.canonical_nickname=""
	fake.next_code=""
	fake.delay=0.0
	fake.during_update=Callable()
	services.session.user={"id":fake.user_id,"email":"fixture@example.invalid"}
	services.session.client.access_token="fixture-not-a-real-token"
	services.profile.data=fake.profile()
	services.profile.state="success"
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()>1:
		output=args[0]
		label=args[1]
		var dims := label.split("x")
		root.size=Vector2i(int(dims[0]),int(dims[1]))
		DirAccess.make_dir_recursive_absolute(output)
	else: root.size=Vector2i(1672,941)
	UIScale.apply_device_profile(root)
	menu=load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	await settle()
	services=menu.get_node("Services")
	fake=preload("res://tests/nickname_onboarding/fake_profile_client.gd").new()
	root.add_child(fake)
	services.profile.client=fake
	services.session.client=fake
	services.session.set_process(false) # Token de fixture não possui expiração real.
	menu.set("_initial_login_pending",false)
	for invalid: Variant in [null,"","  ","Jo","Jogador local"," JOGADOR LOCAL ","Sem nickname","<null>","a\nb","a\u200bb","A".repeat(25)]:
		check(not ProfileService.valid_nickname(invalid),"rejeita vazio, reservado, invisível ou inválido")
	for valid: String in ["Lucas","  Pedro  ","Ágata_42","Jogador 01","A".repeat(24)]:
		check(ProfileService.valid_nickname(valid),"aceita nickname próprio de 3–24 caracteres")
	reset()
	check(not services.profile.has_nickname(),"null não vira nickname textual")
	menu.call("_nickname_offer")
	await settle()
	var prompt: Control=menu.get("_nickname_modal")
	check(is_instance_valid(prompt),"primeiro login exige nickname")
	check(prompt.find_child("BlockingBackdrop",true,false)!=null,"bloqueio de mouse/toque")
	var entry: LineEdit=prompt.find_child("NicknameInput",true,false)
	var save: Button=prompt.find_child("ConfirmNickname",true,false)
	check(save.disabled and entry.max_length==24,"campo vazio bloqueia confirmação")
	entry.text="Ocupado"
	entry.text_changed.emit(entry.text)
	await prompt.call("_commit")
	check(prompt.find_child("NicknameNotice",true,false).text.contains("já está em uso"),"conflito do servidor mostra mensagem e mantém formulário")
	check(not services.profile.has_nickname(),"conflito não inventa nickname local")
	entry.text="Lucas_42"
	entry.text_changed.emit(entry.text)
	entry.grab_focus()
	var tab := InputEventKey.new()
	tab.keycode=KEY_TAB
	tab.pressed=true
	Input.parse_input_event(tab)
	await settle()
	check(prompt.is_ancestor_of(root.gui_get_focus_owner()),"Tab continua dentro do cadastro obrigatório")
	await shot("cadastro")
	fake.delay=0.08
	var before: int=fake.update_calls
	prompt.call("_commit")
	prompt.call("_commit")
	await create_timer(0.2).timeout
	await settle()
	check(fake.update_calls==before+1,"confirmação duplicada envia uma ação")
	check(services.profile.has_nickname() and services.profile.data.nickname=="Lucas_42","perfil confirma nickname salvo pelo servidor simulado")
	check(not is_instance_valid(prompt),"libera cadastro apenas após confirmação")
	before=fake.update_calls
	var locked := await services.profile.update_nickname("OutroNick")
	check(locked.code=="nickname_locked" and fake.update_calls==before,"serviço trava troca sem enviar RPC")
	var nav: NavigationManager=menu.get_node("Navigation")
	nav.open("profile",{})
	await settle(12)
	var profile: Control=nav.get("_active")
	check(profile!=null and profile.find_children("*","LineEdit",true,false).is_empty(),"perfil não oferece editor de nickname")
	await shot("perfil")
	await create_timer(0.25).timeout
	nav.open("settings",{})
	await settle(12)
	var settings: Control=nav.get("_active")
	check(settings.find_child("EditNickname",true,false)==null and settings.find_child("NicknameEditor",true,false)==null,"Ajustes não oferece troca de nickname")
	await shot("ajustes")
	reset()
	services.profile.state="loading"
	menu.call("_nickname_offer")
	await settle()
	prompt=menu.get("_nickname_modal")
	check(is_instance_valid(prompt) and prompt.find_child("ConfirmNickname",true,false).disabled,"perfil carregando não libera cadastro nem jogo por trás")
	check(prompt.find_child("LeaveNicknameAccount",true,false)!=null,"há saída da conta se perfil falhar")
	await shot("carregando")
	prompt.queue_free()
	await settle()
	reset("Jogador local")
	check(not services.profile.has_nickname(),"placeholder antigo exige nickname próprio")
	reset("Ágata")
	menu.call("_nickname_offer")
	check(not is_instance_valid(menu.get("_nickname_modal")),"conta com nickname válido não repete cadastro")
	services.session.user={}
	services.session.client.access_token=""
	reset()
	fake.next_code="23505"
	var conflict := await services.profile.update_nickname("Duplicado")
	check(conflict.code=="nickname_taken","conflito unique SQL é apresentado como nickname em uso")
	reset()
	fake.during_update=func() -> void: services.session.user={"id":"00000000-0000-4000-8000-000000000022"}
	var changed := await services.profile.update_nickname("Marta")
	check(changed.code=="session_changed","resposta antiga não atualiza outra conta")
	# PR #99: o servidor persiste NFC; a entrada pode ter acento decomposto.
	reset()
	fake.canonical_nickname="Café"
	menu.call("_nickname_offer")
	await settle()
	prompt=menu.get("_nickname_modal")
	entry=prompt.find_child("NicknameInput",true,false)
	entry.text="Cafe\u0301"
	entry.text_changed.emit(entry.text)
	await prompt.call("_commit")
	await settle()
	check(services.profile.data.nickname=="Café","preserva grafia NFC confirmada pelo servidor")
	check(not is_instance_valid(prompt),"confirma nickname normalizado sem falso erro de cadastro")
	if is_instance_valid(prompt):
		prompt.queue_free()
		await settle()
	check(DuelService.message("nickname_required").to_lower().contains("nickname"),"erro nickname_required do duelo orienta o cadastro")
	services.session.user={}
	services.session.client.access_token=""
	menu.call("_nickname_offer")
	check(not is_instance_valid(menu.get("_nickname_modal")),"convidado mantém modo local sem cadastro")
	var guest := await services.profile.update_nickname("Convidado")
	check(guest.code=="not_authenticated","convidado não registra identidade global")
	menu.queue_free()
	fake.queue_free()
	await settle()
	print("NICKNAME_POLICY checks=",checks," failures=",fails," ",label)
	quit(1 if fails else 0)
