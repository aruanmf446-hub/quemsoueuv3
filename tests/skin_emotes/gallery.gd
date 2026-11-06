extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value: failures+=1
func settle() -> void:
	for i in 5: await process_frame
func run() -> void:
	root.size=Vector2i(1672,941)
	var services := PlayerServices.new()
	root.add_child(services)
	services.session.set_process(false)
	var screen: Control=load("res://scenes/skins/skins_panel.tscn").instantiate()
	root.add_child(screen)
	screen._generating=true
	screen.open("cowboy")
	await settle()
	check(screen.find_child("CosmeticTab_emotes",true,false)!=null,"aba Emotes disponível")
	screen.find_child("CosmeticTab_emotes",true,false).pressed.emit()
	await settle()
	check(screen.find_child("EmoteChoice",true,false)==null,"prévia não usa lista suspensa")
	check(screen.find_children("EmotePreview_*","Button",true,false).size()==3,"três cartões selecionáveis")
	check(screen.find_child("EmotePreview_celebrate",true,false).size.y>=250,"layout preserva altura das prévias")
	check(not screen._toolbar.visible and not screen._collection_sidebar.visible,"filtros de skins não competem com as prévias")
	check(not screen.find_child("CharacterArrows",true,false).visible,"setas de skins ficam fora da prévia de emotes")
	screen.find_child("EmotePreview_celebrate",true,false).pressed.emit()
	var player: AnimationPlayer=screen._stage.character.get("_anim_player")
	check(player.assigned_animation=="anim_4" and player.is_playing(),"cartão de comemoração inicia seu clipe")
	check(screen.find_child("ReactionPreviewTitle",true,false).text=="Você venceu!","exemplo de vitória identificado")
	screen.find_child("EmotePreview_disappointed",true,false).pressed.emit()
	check(player.assigned_animation=="anim_3" and screen._context_title.text=="Fim de partida","exemplo de derrota usa sua reação")
	screen.find_child("EmotePreview_presentation",true,false).pressed.emit()
	check(player.assigned_animation=="anim_2" and screen._context_title.text=="No lobby","exemplo de lobby usa sua reação")
	screen.find_child("CosmeticTab_shop",true,false).pressed.emit();await settle()
	check(screen.find_child("EmotePreview_celebrate",true,false)==null and screen.find_child("EmotePreview_dance",true,false)!=null,"loja separa dança de vitória e derrota")
	screen.find_child("PreviewDanceMovement",true,false).pressed.emit()
	check(player.assigned_animation=="dance_preview" and player.is_playing(),"prévia do movimento usa uma dancinha própria")
	var skeleton: Skeleton3D=screen._stage.character.get("_skeleton")
	player.advance(0.2) # Completa a transição da pose anterior para o novo clipe.
	player.seek(0.0,true)
	var bones: Array=[]
	for bone in skeleton.get_bone_count(): bones.append(skeleton.get_bone_pose(bone))
	player.advance(0.375)
	var moving := false
	for bone in skeleton.get_bone_count():
		if not bones[bone].is_equal_approx(skeleton.get_bone_pose(bone)): moving=true
	check(moving,"dancinha movimenta os ossos do avatar real")
	var wallet := services.wallet.data.duplicate(true)
	screen.find_child("BuyEmotePreview",true,false).pressed.emit();await settle()
	check(screen.find_child("EmotePurchasePreview",true,false)!=null and services.wallet.data==wallet and screen.find_child("ConfirmEmotePurchase",true,false).disabled,"visitante vê preço, mas precisa entrar para comprar")
	check(screen.handle_back(),"voltar fecha a prévia de compra")
	await settle()
	check(screen.find_child("EmotePurchasePreview",true,false)==null,"modal de compra removido")
	screen.find_child("CosmeticTab_emotes",true,false).pressed.emit();await settle()
	screen._select("el_fuego");await settle()
	check(screen.find_children("EmotePreview_*","Button",true,false).is_empty(),"El Fuego não exibe cartões de clipes ausentes")
	screen.find_child("CosmeticTab_skins",true,false).pressed.emit();await settle()
	check(screen._toolbar.visible and screen._selected=="el_fuego","voltar à galeria preserva o personagem selecionado")
	check(screen.find_child("CharacterArrows",true,false).visible,"navegação de skins restaurada")
	screen.queue_free();services.queue_free();await settle()
	print("EMOTE_GALLERY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
