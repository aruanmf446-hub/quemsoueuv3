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
	screen._select("el_fuego");await settle()
	check(screen.find_children("EmotePreview_*","Button",true,false).is_empty(),"El Fuego não exibe cartões de clipes ausentes")
	screen.find_child("CosmeticTab_skins",true,false).pressed.emit();await settle()
	check(screen._toolbar.visible and screen._selected=="el_fuego","voltar à galeria preserva o personagem selecionado")
	check(screen.find_child("CharacterArrows",true,false).visible,"navegação de skins restaurada")
	screen.queue_free();services.queue_free();await settle()
	print("EMOTE_GALLERY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
