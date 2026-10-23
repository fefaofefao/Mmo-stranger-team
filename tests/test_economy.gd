extends "res://tests/test_base.gd"
## Destinos do ouro: loja rotativa e treino de monstros.


func _srv() -> ServerLogic:
	var t := {"v": 1000000.0}
	var srv := ServerLogic.new({}, func(): return t.v)
	srv.set_meta("clock", t)
	srv.login("dev")
	return srv


func test_shop_rotation() -> void:
	var srv := _srv()
	srv.debug_set_validated_level(80)
	var st := srv.shop_status()
	check(st.ok and st.slots.size() == 5, "5 ofertas")
	var first: String = st.slots[0].item.uid
	check(srv.shop_status().slots[0].item.uid == first, "mesmas ofertas dentro do período")
	for s in st.slots:
		var b: Dictionary = DataDB.item_bases[s.item.base]
		check(int(b.level) <= 85 and int(b.level) >= 80 - int(DataDB.config.shop.level_window), "item perto do nível (%d)" % int(b.level))
		check(s.item.bound, "item da loja é vinculado")
		check(int(s.price) == Formulas.shop_item_price(int(b.level), s.item.rarity), "preço pela fórmula")
	check(Formulas.shop_item_price(80, "lendario") > Formulas.shop_item_price(80, "raro") * 10, "lendário muito mais caro que raro")
	check(Formulas.shop_item_price(80, "raro") > Formulas.gold_for_kill(80) * 1000, "raro custa mais de 1000 abates de ouro")
	# compra
	var r := srv.shop_buy(0)
	check(not r.ok, "sem ouro não compra")
	srv.debug_grant(100000000, {})
	var g0 := int(srv.p().gold)
	r = srv.shop_buy(0)
	check(r.ok and r.item.uid == first, "compra a oferta")
	check(g0 - int(srv.p().gold) == int(st.slots[0].price), "cobra o preço")
	check(not srv.shop_buy(0).ok, "não compra duas vezes")
	# atualização paga, custo crescente
	var c1 := int(srv.shop_status().refresh_cost)
	var st2 := srv.shop_refresh()
	check(st2.ok and int(st2.refresh_cost) > c1, "atualizar custa mais a cada vez")
	check(st2.slots[0].item.uid != first, "ofertas novas")
	# novo período
	srv.get_meta("clock").v += float(DataDB.config.shop.rotation_hours) * 3600.0
	var st3 := srv.shop_status()
	check(int(st3.refresh_cost) == Formulas.shop_refresh_cost(80, 0), "período novo zera as atualizações")


func test_train_monster() -> void:
	var srv := _srv()
	srv.register_starter("fogo_1")
	var sid: String = srv.p().monsters.keys()[0]
	check(not srv.train_monster(sid).ok, "sem ouro não treina")
	srv.debug_grant(1000000000, {})
	var costs: Array = []
	for i in int(DataDB.config.train.max):
		var g0 := int(srv.p().gold)
		var r := srv.train_monster(sid)
		check(r.ok and int(r.train) == i + 1, "treino +%d" % (i + 1))
		costs.append(g0 - int(srv.p().gold))
	check(not srv.train_monster(sid).ok, "não passa do máximo")
	check(int(costs[14]) > int(costs[0]) * 50, "custo exponencial")
	var m := MonsterLogic.create("fogo_1", 50, false, "x")
	var base := MonsterLogic.compute_stats(m)
	m.train = 10
	var s := MonsterLogic.compute_stats(m)
	check(absf(s.atk / base.atk - 1.4) < 0.01, "+10 = +40% ataque")
	check(absf(s.def / base.def - 1.4) < 0.01, "+10 = +40% defesa")
	check(absf(s.hp / base.hp - 1.2) < 0.01, "+10 = +20% vida")
	check(MonsterLogic.glow_tier(m) == 2, "+10 = brilho intenso")
	m.train = 4
	check(MonsterLogic.glow_tier(m) == 0, "+4 sem brilho")
	m.train = 15
	check(MonsterLogic.glow_tier(m) == 3, "+15 radiante")
	# limites anti-trapaça consideram o treino do servidor
	var party := [{"server_id": sid, "family": "fogo_1", "stage": 1, "level": 1}]
	var up: Array = srv._party_upper_stats(party)
	srv.p().monsters[sid].train = 0
	var up0: Array = srv._party_upper_stats(party)
	check(up[0].atk > up0[0].atk * 1.5, "limite superior inclui o treino")
