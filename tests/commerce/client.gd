extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
 checks+=1
 print("PASS " if value else "FAIL ",label)
 if not value: failures+=1
func run() -> void:
 var services := PlayerServices.new();root.add_child(services)
 var fake := preload("res://tests/commerce/fake_game.gd").new();root.add_child(fake)
 fake.access_token="fixture-not-real"
 services.cosmetic_shop.client=fake;services.coin_store.client=fake;services.session.client=fake
 services.session.user={"id":"00000000-0000-4000-8000-000000000091"}
 services.session._expires_at=Time.get_unix_time_from_system()+86400;services.session.set_process(false)
 var store := services.cosmetic_shop
 check((await store.refresh()).ok,"catálogo real de cosméticos validado pelo contrato")
 check(store.deck_credits()==0,"saldo de cartas vem do servidor")
 check(store.data.deck_credits=="0" and not store.data.deck_credits_required,"créditos separados, criação gratuita enquanto bloqueada")
 var item := store.product("cowboy","style_1")
 check((await store.buy(item)).code=="sales_disabled","vendas desligadas bloqueiam compra antes da RPC")
 check(store.equipped("cowboy")=="original","sem posse fabricada")
 check(not store.valid_data({"enabled":false,"deck_credits_required":false,"deck_credits":"-1","items":[],"equipped":{}}),"créditos negativos recusados")
 check((await services.coin_store.refresh()).ok,"pacotes reais aceitam tipos moedas e créditos")
 check(services.coin_store.data.packages.size()==4,"três pacotes e um crédito de deck")
 check((await services.coin_store.create_checkout(services.coin_store.data.packages[3])).code=="payments_unavailable" and fake.checkout_calls.is_empty(),"desabilitado não cria checkout de créditos")
 store.data.equipped={"cowboy":"style_1"}
 check(store.equipped("cowboy")=="style_1","variação confirmada por conta")
 services.session.user={"id":"00000000-0000-4000-8000-000000000092"}
 check(store.equipped("cowboy")=="original" and store.deck_credits()==null,"trocar conta não herda equipamento nem cartas")
 store.clear()
 check(store.data.is_empty(),"sair limpa catálogo e créditos da sessão")
 check(fake.coins==250 and fake.purchase_calls.is_empty(),"testes de bloqueio não debitam conta")
 services.session.user={"id":"00000000-0000-4000-8000-000000000091"}
 await store.refresh()
 services.wallet.client=fake
 var wallet: Control=load("res://scenes/player/wallet.tscn").instantiate();root.add_child(wallet)
 wallet.show_screen({"tab":"coins","category":"deck_credits"})
 for i in 10: await process_frame
 check(wallet.find_child("CoinPack_deck_credit",true,false)!=null and wallet.find_child("CoinPack_coins_100",true,false)==null,"atalho de cartas abre a categoria correta")
 wallet.queue_free()
 for i in 3: await process_frame
 services.queue_free();fake.queue_free()
 for i in 4: await process_frame
 print("COMMERCE_CLIENT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
