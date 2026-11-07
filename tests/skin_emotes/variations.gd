extends SceneTree
const STYLES=preload("res://scripts/skins/skin_variations.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value: failures+=1
func run() -> void:
	for entry: Dictionary in CharacterCatalog.load_entries():
		var slot := CharacterSlot.new();root.add_child(slot);slot.load_entry(entry)
		var original_root: Node=slot.get("_model_root")
		var styles := STYLES.entries(str(entry.id))
		check(styles.size()==3,"original e duas variações: "+str(entry.id))
		for style: Dictionary in styles:
			check(STYLES.apply(slot,str(style.id)) and slot.get("_model_root")==original_root,"prévia sem recriar modelo: "+str(entry.id)+"/"+str(style.id))
		check(not STYLES.apply(slot,"invalid"),"estilo inexistente recusado: "+str(entry.id))
		STYLES.apply(slot,"original")
		var restored := true
		for mesh: MeshInstance3D in original_root.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh==null: continue
			for surface in mesh.mesh.get_surface_count():
				if mesh.has_meta("qse_surface_material_%d" % surface):
					restored=restored and mesh.get_surface_override_material(surface)==mesh.get_meta("qse_surface_material_%d" % surface)
		check(restored,"materiais originais restaurados: "+str(entry.id))
		slot.queue_free();await process_frame
	await ui_flow()
	print("VARIATIONS checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func ui_flow() -> void:
	root.size=Vector2i(1672,941)
	var services := PlayerServices.new();root.add_child(services)
	var fake := preload("res://tests/skin_emotes/fake_game.gd").new();root.add_child(fake)
	services.emote_shop.client=fake
	var ui: Control=load("res://scenes/skins/skins_panel.tscn").instantiate();root.add_child(ui)
	ui._generating=true;ui.open("cowboy");ui._choose_cosmetic_mode("variations")
	check(ui._stage.static_preview,"variações usam renderização sob demanda")
	ui.find_child("SkinVariation_style_1",true,false).pressed.emit()
	check(ui._selected_styles.cowboy=="style_1","cartão seleciona a paleta do personagem")
	ui._select_neighbor(1)
	check(ui._selected=="michelly" and ui._stage.static_preview,"seta troca o personagem dentro de Variações")
	ui._select_neighbor(-1)
	check(ui._selected_styles.cowboy=="style_1","voltar preserva a escolha de prévia por personagem")
	ui._choose_cosmetic_mode("emotes")
	check(not ui._stage.static_preview and ui._stage.get_node("Viewport").render_target_update_mode==SubViewport.UPDATE_ALWAYS,"reações retomam renderização animada")
	ui.find_child("EmotePreview_celebrate",true,false).pressed.emit()
	check(ui._stage.character.get("_anim_player").is_playing(),"reação de vitória continua tocando")
	ui._choose_cosmetic_mode("variations")
	check(not ui._preview.get_node("EmoteShopActions").visible and fake.coins==250,"prévia de variação fica separada da loja e não cobra moedas")
	ui.queue_free();services.queue_free();fake.queue_free()
	for i in 4: await process_frame
