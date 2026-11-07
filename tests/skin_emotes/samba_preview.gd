extends SceneTree
const MOTIONS=preload("res://scripts/skins/universal_emotes.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value: failures+=1
func run() -> void:
	check(MOTIONS.universal_assets_ready("emote_samba"),"Samba disponível nos oito rigs")
	check(MOTIONS.price_pending("samba"),"preço pendente explícito")
	for entry: Dictionary in CharacterCatalog.load_entries():
		var slot := CharacterSlot.new();root.add_child(slot);slot.load_entry(entry)
		check(MOTIONS.install(slot,"emote_samba"),"carrega o recurso aprovado: "+str(entry.id))
		slot.set_pose(&"emote_samba",0.1)
		var sk: Skeleton3D=slot.get("_skeleton")
		var rotations: Array=[]
		for bone in sk.get_bone_count():rotations.append(sk.get_bone_pose_rotation(bone))
		slot.set_pose(&"emote_samba",1.5)
		var moving := false;var proportions := true
		for bone in sk.get_bone_count():
			moving=moving or not rotations[bone].is_equal_approx(sk.get_bone_pose_rotation(bone))
			if sk.get_bone_name(bone)!="mixamorig_Hips":proportions=proportions and sk.get_bone_pose_position(bone).is_equal_approx(sk.get_bone_rest(bone).origin)
		check(moving and proportions,"movimento real e proporções preservadas: "+str(entry.id))
		slot.queue_free();await process_frame
	var services := PlayerServices.new();root.add_child(services)
	var fake := preload("res://tests/skin_emotes/fake_game.gd").new();root.add_child(fake)
	fake.access_token="fixture-not-real";services.session.client=fake
	services.session.user={"id":"00000000-0000-4000-8000-000000000081"}
	services.session._expires_at=Time.get_unix_time_from_system()+86400;services.session.set_process(false)
	services.emote_shop.client=fake
	var result := await services.emote_shop.buy("samba",100)
	check(result.code=="price_pending" and fake.purchase_calls.is_empty() and fake.coins==250,"preço pendente bloqueia o serviço antes de qualquer débito")
	var ui: Control=load("res://scenes/skins/skins_panel.tscn").instantiate();root.add_child(ui)
	ui._generating=true;ui.open("cowboy");ui._choose_cosmetic_mode("shop")
	for i in 6:await process_frame
	check(ui.find_child("EmotePreview_samba",true,false)!=null,"Samba aparece na loja")
	check(ui.find_child("BuyEmotePreview",true,false).disabled and ui.find_child("BuyEmotePreview",true,false).text=="PREÇO A DEFINIR","compra/resgate desabilitados sem preço")
	ui.find_child("PreviewDanceMovement",true,false).pressed.emit()
	check(ui._stage.character.get("_anim_player").assigned_animation=="emote_samba","Ver movimento toca a Samba aprovada")
	ui._preview_purchase()
	check(ui.find_child("EmotePurchasePreview",true,false)==null and fake.purchase_calls.is_empty(),"modal de cobrança não abre para Samba")
	ui.queue_free();services.queue_free();fake.queue_free()
	for i in 4:await process_frame
	print("SAMBA_PREVIEW checks=",checks," failures=",failures)
	quit(1 if failures else 0)
