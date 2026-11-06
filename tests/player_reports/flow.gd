extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func settle(frames:=8) -> void:
	for i in frames: await process_frame
func run() -> void:
	root.size=Vector2i(1672,941)
	var services := PlayerServices.new()
	root.add_child(services)
	var fake := preload("res://tests/player_reports/fake_game.gd").new()
	root.add_child(fake)
	services.client=fake;services.session.client=fake
	services.profile.client=fake;services.friends.client=fake
	services.session.user={"id":"00000000-0000-4000-8000-000000000011"}
	services.session._expires_at=Time.get_unix_time_from_system()+86400
	services.session.set_process(false)
	var result := await services.friends.report_player(fake.target.public_id,"Motivo")
	check(not result.ok and fake.calls==0,"sem sessão não envia denúncia")
	fake.access_token="fixture-not-real"
	result=await services.friends.report_player(fake.target.public_id," x ")
	check(not result.ok and fake.calls==0,"motivo curto não chama o servidor")
	var screen: Control=load("res://scenes/player/public_profile.tscn").instantiate()
	root.add_child(screen)
	screen.show_screen({"public_id":fake.target.public_id})
	await settle()
	check(screen.find_child("ReportPlayer",true,false)!=null,"perfil público oferece Denunciar jogador")
	screen.find_child("ReportPlayer",true,false).pressed.emit();await settle()
	var dialog: Control=screen.find_child("PlayerReportDialog",true,false)
	var reason: LineEdit=dialog.find_child("PlayerReportReason",true,false)
	var send: Button=dialog.find_child("SubmitPlayerReport",true,false)
	var feedback: Label=dialog.find_child("PlayerReportFeedback",true,false)
	check(dialog.is_in_group("qse_web_input_modal"),"modal usa o viewport e teclado Web existentes")
	send.pressed.emit();await settle()
	check(fake.calls==0 and feedback.text.contains("3 a 280"),"formulário vazio permanece aberto")
	reason.text="Insultos na partida."
	for code in ["already_reported","cannot_report_self","network","PGRST202"]:
		fake.report_code=code
		send.pressed.emit();await settle()
		check(is_instance_valid(dialog) and reason.text=="Insultos na partida." and not send.disabled,"erro "+code+" preserva motivo e permite continuar")
	fake.report_code="";fake.empty_confirmation=true
	send.pressed.emit();await settle()
	check(feedback.text.contains("confirmar"),"resposta sem confirmação não mostra sucesso")
	fake.empty_confirmation=false;fake.hold=true
	var before := fake.calls
	send.pressed.emit();send.pressed.emit();await settle()
	check(fake.calls==before+1 and send.disabled,"envio duplo bloqueado enquanto aguarda")
	fake.hold=false;await settle()
	check(screen.find_child("PlayerReportDialog",true,false)==null and screen.banner.visible,"sucesso confirmado fecha formulário e mostra retorno")
	screen._open_report(fake.target.public_id);await settle()
	check(screen.handle_back(),"voltar consome o modal")
	await settle()
	check(screen.find_child("PlayerReportDialog",true,false)==null,"voltar remove o formulário")
	screen._open_report(fake.target.public_id);await settle()
	fake.hold=true
	screen.find_child("PlayerReportReason",true,false).text="Outro motivo QA"
	screen.find_child("SubmitPlayerReport",true,false).pressed.emit();await settle()
	services.session.changed.emit();await settle()
	fake.hold=false;await settle()
	check(screen.find_child("PlayerReportDialog",true,false)==null,"troca de conta descarta resposta antiga e motivo")
	fake.target.user_id=services.session.user.id
	screen.show_screen({"public_id":fake.target.public_id});await settle()
	check(screen.find_child("ReportPlayer",true,false)==null,"perfil próprio não oferece denúncia")
	screen.queue_free();services.queue_free();fake.queue_free();await settle()
	print("PLAYER_REPORTS checks=",checks," failures=",failures)
	quit(1 if failures else 0)
