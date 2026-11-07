extends SceneTree
const MOTIONS=preload("res://scripts/skins/universal_emotes.gd")
const A="00000000-0000-4000-8000-000000000081"
const B="00000000-0000-4000-8000-000000000082"
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value: failures+=1
func run() -> void:
	var services := PlayerServices.new();root.add_child(services)
	var fake := preload("res://tests/skin_emotes/universal_game.gd").new();root.add_child(fake)
	fake.access_token="fixture-not-real";fake.account=A
	services.session.client=fake;services.session.user={"id":A}
	services.session._expires_at=Time.get_unix_time_from_system()+86400;services.session.set_process(false)
	var shop := services.emote_shop;shop.client=fake
	await shop.refresh()
	check(not shop.owned("dance_01"),"conta sem compra não tem emote")
	check((await shop.buy("dance_01",100)).ok and shop.owned("dance_01"),"uma compra concede posse à conta")
	check(fake.balances[A]==150,"único débito de 100 moedas")
	check(not MOTIONS.universal_assets_ready("emote_dance_01"),"movimento real ausente não é declarado universal pronto")
	var slots: Array[CharacterSlot]=[]
	for entry: Dictionary in CharacterCatalog.load_entries():
		var slot := CharacterSlot.new();root.add_child(slot);slot.load_entry(entry);slots.append(slot)
		check(not MOTIONS.install(slot,"emote_dance_01"),"produção sem asset não entrega demonstração: "+str(entry.id))
		# The original base clips below test binding only; they are NOT saleable dances.
		var catalog := {"items":[{"scope":"account","animation_key":"emote_dance_01","clips":{str(entry.id):str(entry.animations.base)}}]}
		check(MOTIONS.install_from_catalog(slot,"emote_dance_01",catalog),"adaptador liga movimento ao rig: "+str(entry.id))
		var reads := fake.shop_reads
		var result := await shop.play_owned(slot,"dance_01")
		check(result.ok and result.data.scope=="account" and result.data.character_id==str(entry.id),"mesmo item usado em "+str(entry.id))
		check(fake.purchase_calls.size()==1 and fake.balances[A]==150 and fake.shop_reads==reads,"trocar skin não cobra nem espera nova consulta: "+str(entry.id))
	var player: AnimationPlayer=slots[0].get("_anim_player")
	var skeleton: Skeleton3D=slots[0].get("_skeleton")
	var invalid := Animation.new();var track := invalid.add_track(Animation.TYPE_ROTATION_3D)
	invalid.track_set_path(track,NodePath("SourceRig:missing_bone"))
	check(MOTIONS.adapt(invalid,player,skeleton)==null,"rig incompatível recusado sem deformar o personagem")
	var source := Animation.new();track=source.add_track(Animation.TYPE_POSITION_3D)
	source.track_set_path(track,NodePath("SourceRig:"+skeleton.get_bone_name(0)))
	source.track_insert_key(track,0.0,Vector3.ZERO)
	var event := source.add_track(Animation.TYPE_METHOD)
	source.track_set_path(event,NodePath(".."))
	source.track_insert_key(event,0.0,{"method":"queue_free","args":[]})
	var safe := MOTIONS.adapt(source,player,skeleton)
	check(safe!=null and safe.get_track_count()==1,"eventos de método não são executados pelo emote importado")
	check(safe!=null and not str(safe.track_get_path(0)).contains("SourceRig"),"caminho do rig é ligado ao avatar atual")
	# New client instance represents a reopened app/device reading the same server account.
	var reopened := EmoteShopService.new();reopened.client=fake;reopened.session=services.session;root.add_child(reopened)
	await reopened.refresh()
	check(reopened.owned("dance_01"),"nova instância recupera a posse do servidor")
	services.session.user={"id":B};fake.account=B;fake.generation+=1
	check(not shop.owned("dance_01"),"cache anterior não concede posse à outra conta")
	check((await shop.play_owned(slots[0],"dance_01")).code=="emote_not_owned","outra conta não usa o item")
	services.session.user={"id":A};fake.account=A;fake.generation+=1;shop.clear();await shop.refresh()
	check((await shop.play_owned(slots[0],"dance_01",func()->bool:return false)).code=="emote_target_changed","navegação cancelada impede reprodução atrasada")
	check((await shop.play_owned(slots[0],"missing")).code=="emote_not_owned","produto não adquirido recusado")
	services.session.user={};shop.clear()
	check((await shop.play_owned(slots[0],"dance_01")).code=="not_authenticated","convidado não herda emotes de conta")
	for slot in slots: slot.queue_free()
	reopened.queue_free();services.queue_free();fake.queue_free()
	for i in 4: await process_frame
	print("UNIVERSAL_EMOTES checks=",checks," failures=",failures)
	quit(1 if failures else 0)
