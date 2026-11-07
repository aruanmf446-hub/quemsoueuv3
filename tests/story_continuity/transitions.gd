extends SceneTree
const Local=preload("res://scripts/desert/t15d/campaign_progress.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
 checks+=1
 if not ok:failures+=1
 print(("PASS " if ok else "FAIL ")+text)
func ticks(n: int) -> void:
 for i in n:await physics_frame
func advance(order: int,charges: Dictionary) -> Node3D:
 Local.merge_highest("",order-1)
 PhaseStory.mark_read(order+1)
 var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
 root.add_child(phase)
 current_scene=phase
 for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
 phase._player.attack_charges=charges.attack
 phase._player.defense_charges=charges.defense
 for kind in phase._player.abilities:phase._player.abilities[kind]=charges.get(kind,0)
 # Pré-condição de vitória desta fixture de transição; Tasks são exercitadas separadamente.
 for task: Dictionary in phase._phase.tasks:phase._raised_bridges[str(task.id)]=true
 phase._on_goal_entered(phase._player)
 check(phase.completed,"vitória real registra a fase %d" % order)
 phase._session.next_requested.emit()
 await process_frame
 var loading: CampaignLoading=root.get_node_or_null("CampaignLoading")
 check(is_instance_valid(loading) and loading._status.text.begins_with("Carregando fase"),"passagem tem tela de carregamento real")
 check(loading._completed_reads==0 and not loading._can_skip,"capa aparece antes da leitura terminar")
 for i in 500:
  await process_frame
  for node in root.get_children():
   if node!=phase and node.get_script()==load("res://scripts/desert/t15d/phase.gd") and node._order==order+1:
    return node
 check(false,"próxima fase abriu sem travar")
 return null
func run() -> void:
 preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
 var phase:=await advance(1,{"attack":2,"defense":3})
 if is_instance_valid(phase):
  check(phase._player.attack_charges==2 and phase._player.defense_charges==3,"fase 2 mantém exatamente as cargas guardadas na fase 1")
  phase.free()
 var saved:=Local.carry_for(2,"")
 check(saved.get("attack")==2 and saved.get("defense")==3,"cargas sobrevivem ao fechamento da cena")
 phase=load("res://scenes/desert/phase_02.tscn").instantiate()
 root.add_child(phase)
 check(phase._player.attack_charges==2 and phase._player.defense_charges==3,"abrir a fase pelo menu também recupera as cargas")
 phase.free()
 phase=await advance(3,{"attack":0,"defense":2,"amber":3,"dash":0,"rupture":0})
 if is_instance_valid(phase):
  check(phase._player.attack_charges==0 and phase._player.defense_charges==2 and phase._player.charges("amber")==3,"fase 4 preserva inclusive zero ataque e três cargas de âmbar")
  check(phase._player.discovered.get("amber",false),"poder guardado continua visível")
  check(phase._player.charges("dash")==0,"poder novo continua sem carga inventada")
  phase.free()
 phase=await advance(5,{"attack":3,"defense":1,"amber":2,"dash":3,"rupture":2})
 if is_instance_valid(phase):
  check(phase._charge_snapshot()=={"attack":3,"defense":1,"amber":2,"dash":3,"rupture":2},"fase 6 conserva os cinco tipos de recarga, incluindo relâmpago e ruptura")
  phase.free()
 check(Local.carry_for(5,"").is_empty(),"não aplica cargas de uma fase em outra")
 # Todas as passagens da campanha 1–9, incluindo carga zero e capacidade cheia.
 for order in range(1,9):
  var charges:={"attack":order%4,"defense":(order+1)%4,"amber":3 if order>=3 else 0,"dash":2 if order>=4 else 0,"rupture":1 if order>=5 else 0}
  phase=await advance(order,charges)
  if not is_instance_valid(phase):continue
  check(phase._charge_snapshot()==charges,"fase %d → %d: preserva exatamente todos os recursos sem usar" % [order,order+1])
  check(Local.carry_for(order+1,"")==charges,"fase %d: inventário da vitória salvo para reentrada" % (order+1))
  phase.free()
  phase=load("res://scenes/desert/phase_%02d.tscn" % (order+1)).instantiate()
  root.add_child(phase)
  check(phase._charge_snapshot()==charges,"fase %d: sair e reabrir não zera nem duplica cargas" % (order+1))
  phase.free()
 print("STORY_TRANSITIONS checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)
