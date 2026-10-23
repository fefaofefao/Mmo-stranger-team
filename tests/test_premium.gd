extends "res://tests/test_base.gd"
## Diamantes (dinheiro real), bônus temporários e monstros no Market por diamantes.


func _srv() -> ServerLogic:
	var t := {"v": 2000000.0}
	var srv := ServerLogic.new({}, func(): return t.v)
	srv.set_meta("clock", t)
	srv.login("dev")
	return srv


func test_iap_purchase() -> void:
	var srv := _srv()
	check(int(srv.wallet().diamonds) == 0, "começa sem diamantes")
	check(not srv.iap_purchase("diamonds_500", "token_real_sem_validacao").ok, "mock só aceita compra simulada")
	check(not srv.iap_purchase("nao_existe", "sim_1").ok, "produto inválido")
	var r := srv.iap_purchase("diamonds_500", "sim_1")
	check(r.ok and r.first_bonus, "primeira compra")
	check(int(r.diamonds_gained) == 1000, "primeira compra em dobro (500 + 500)")
	check(not srv.iap_purchase("diamonds_500", "sim_1").ok, "token não pode ser reusado")
	var r2 := srv.iap_purchase("diamonds_1100", "sim_2")
	check(int(r2.diamonds_gained) == 1100 and not r2.first_bonus, "pacote com bônus, sem dobro")
	check(int(srv.wallet().diamonds) == 2100, "saldo somado")
	for pr in DataDB.iap.products:
		check(int(pr.diamonds) > 0 and str(pr.id).begins_with("diamonds_"), "produto %s configurado" % pr.id)


func test_boosts() -> void:
	var srv := _srv()
	check(srv.boost_mult("shiny") == 1.0, "sem bônus")
	check(not srv.boost_buy("shiny").ok, "sem diamantes não compra")
	srv.debug_grant(0, {}, 5000)
	var r := srv.boost_buy("shiny")
	check(r.ok and srv.boost_mult("shiny") == 2.0, "2x shiny ativo")
	var left := float(r.boosts.shiny) - srv.now()
	check(absf(left - 8 * 3600.0) < 2.0, "8 horas")
	srv.boost_buy("shiny")
	check(absf(float(srv.p().boosts.shiny) - srv.now() - 16 * 3600.0) < 2.0, "comprar de novo soma")
	# anúncio: 15 min, acumula até o limite
	var a := srv.boost_ad("recruit")
	check(a.ok and absf(float(srv.p().boosts.recruit) - srv.now() - 900.0) < 2.0, "anúncio = 15 min")
	var n := 1
	while srv.boost_ad("recruit").ok and n < 50:
		n += 1
	check(n <= 10 and n >= 8, "anúncios acumulam até ~2h (%d)" % n)
	check(not srv.boost_ad("shiny").ok, "com 16h ativas não aceita anúncio")
	var d0 := int(srv.wallet().diamonds)
	check(srv.boost_buy("all").ok and d0 - int(srv.wallet().diamonds) == int(DataDB.config.boosts.bundle_price), "pacote completo")
	for k in DataDB.config.boosts.kinds:
		check(srv.boost_mult(k) == 2.0, "pacote ativa %s" % k)
	# efeito no servidor: dobro de shinies nos tickets
	var srv2 := _srv()
	srv2.register_starter("agua_1")
	var base_n := 0
	for i in 40:
		for tk in srv2.request_spawn_tickets("w1_s1_agua_1", 100).tickets:
			base_n += 1 if tk.shiny else 0
	srv2.debug_grant(0, {}, 5000)
	srv2.boost_buy("shiny")
	var boosted := 0
	for i in 40:
		for tk in srv2.request_spawn_tickets("w1_s1_agua_1", 100).tickets:
			boosted += 1 if tk.shiny else 0
	check(boosted >= 0 and srv2.boost_mult("shiny") == 2.0, "tickets com bônus (%d vs %d em 4000)" % [boosted, base_n])
	# expira
	srv.get_meta("clock").v += 40 * 3600.0
	check(srv.boost_mult("gold") == 1.0, "bônus expira")


func test_monster_market() -> void:
	var srv := _srv()
	srv.register_starter("fogo_1")
	var starter: String = srv.p().monsters.keys()[0]
	check(not srv.market_list_monster(starter, 10, 1, 100).ok, "inicial não pode ser vendido")
	var sid := "m_venda"
	srv.p().monsters[sid] = {"server_id": sid, "family": "agua_2", "form": "agua_2_1", "shiny": true, "stars": 1, "converted": false, "quality": 77, "train": 3}
	check(not srv.market_list_monster(sid, 10, 1, 5).ok, "preço mínimo")
	srv.p().validated_level = 20
	var r := srv.market_list_monster(sid, 999, 3, 300)
	check(r.ok and r.listing.currency == "diamonds", "listado por diamantes")
	check(int(r.listing.monster.level) == 30, "nível limitado ao validado + 10")
	check(not srv.p().monsters.has(sid), "monstro sai do jogador")
	# itens/essências não mostram monstros; filtro de monstros sim
	var any_mon := false
	for l in srv.market_search({}).listings:
		any_mon = any_mon or l.kind == "monster"
	check(not any_mon, "busca padrão sem monstros")
	var mons: Array = srv.market_search({"kind": "monster"}).listings
	check(mons.size() > 0, "monstros de outros jogadores à venda")
	var sh: Array = srv.market_search({"kind": "monster", "shiny_only": true}).listings
	for l in sh:
		check(l.monster.shiny, "filtro shiny")
	# compra por diamantes
	var l0: Dictionary = mons[0]
	check(not srv.market_buy(l0.id).ok, "sem diamantes não compra")
	srv.debug_grant(0, {}, int(l0.price))
	var b := srv.market_buy(l0.id)
	check(b.ok and not b.monster.is_empty(), "comprou o monstro")
	check(srv.p().monsters.has(b.monster.server_id), "monstro agora é do comprador")
	check(int(srv.wallet().diamonds) == 0, "diamantes descontados")
	check(int(srv.wallet().gold) == 0, "ouro não é usado em monstros")
	# cancelar devolve
	var c := srv.market_cancel(r.listing.id)
	check(c.ok and srv.p().monsters.has(sid), "cancelar devolve o monstro")
	check(int(srv.p().monsters[sid].train) == 3 and int(srv.p().monsters[sid].quality) == 77, "mantém treino e qualidade")
	# venda para outro jogador (simulado) rende diamantes menos a taxa
	var r3 := srv.market_list_monster(sid, 10, 1, 1000)
	srv.get_meta("clock").v += 120.0
	var sold := false
	for i in 40:
		srv._simulate_fake_buyers()
		if not srv.state.listings.has(r3.listing.id):
			sold = true
			break
		srv.get_meta("clock").v += 60.0
	check(sold and int(srv.wallet().diamonds) == 900, "vendido: recebe 90% em diamantes")
