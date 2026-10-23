extends "res://tests/test_base.gd"


func _srv() -> ServerLogic:
	var t := {"v": 100000.0}
	var srv := ServerLogic.new({}, func(): return t.v)
	srv.set_meta("clock", t)
	srv.login("dev")
	return srv


func _adv(srv: ServerLogic, s: float) -> void:
	srv.get_meta("clock").v += s


func test_claim_kills_plausibility() -> void:
	var srv := _srv()
	srv.register_starter("agua_1")
	var sid: String = srv.p().monsters.keys()[0]
	var hunt: Dictionary = DataDB.hunts["w1_s1_agua_1"]
	var party := [{"server_id": sid, "family": "agua_1", "stage": 1, "level": 3}]
	_adv(srv, 10.0)
	var kills: Array = []
	for i in 500:
		kills.append({"form": "agua_1_1", "level": 1, "ticket": ""})
	var r := srv.claim_kills(hunt.id, kills, party, [])
	check(r.ok, "claim ok")
	check(int(r.accepted) < 20, "não aceita 500 abates em 10s (aceitou %d)" % int(r.accepted))
	check(int(r.rejected) > 400, "rejeita o excesso")
	check(int(srv.p().gold) == int(r.gold_gained), "ouro creditado no servidor")


func test_shiny_tickets() -> void:
	var srv := _srv()
	srv.register_starter("agua_1")
	var sid: String = srv.p().monsters.keys()[0]
	var party := [{"server_id": sid, "family": "agua_1", "stage": 1, "level": 3}]
	srv.debug_force["shiny"] = 1
	var tk := srv.request_spawn_tickets("w1_s1_agua_1", 3)
	check(tk.tickets[0].shiny, "ticket shiny forçado")
	_adv(srv, 60.0)
	srv.debug_force["recruit"] = 1
	var r := srv.claim_kills("w1_s1_agua_1", [{"form": "agua_1_1", "level": 1, "ticket": tk.tickets[0].id}], party, [])
	check(int(r.shinies) == 1, "shiny confirmado pelo ticket")
	check(r.recruits.size() == 1 and r.recruits[0].shiny, "recrutado mantém shiny")
	_adv(srv, 60.0)
	var r2 := srv.claim_kills("w1_s1_agua_1", [{"form": "agua_1_1", "level": 1, "ticket": tk.tickets[0].id}], party, [])
	check(int(r2.shinies) == 0, "ticket não pode ser reutilizado")
	# ticket inventado
	_adv(srv, 60.0)
	var r3 := srv.claim_kills("w1_s1_agua_1", [{"form": "agua_1_1", "level": 1, "ticket": "t_falso"}], party, [])
	check(int(r3.shinies) == 0, "ticket falso não gera shiny")


func test_no_recruit_in_world2() -> void:
	var srv := _srv()
	srv.register_starter("agua_1")
	var sid: String = srv.p().monsters.keys()[0]
	var party := [{"server_id": sid, "family": "agua_1", "stage": 3, "level": 150}]
	srv.debug_set_validated_level(150)
	srv.debug_force["recruit"] = 5
	_adv(srv, 600.0)
	var kills: Array = []
	var h: Dictionary = DataDB.hunts["w2_150_0"]
	for i in 5:
		kills.append({"form": h.monsters[0].form, "level": 150, "ticket": ""})
	var r := srv.claim_kills(h.id, kills, party, [])
	check(r.recruits.is_empty(), "sem recrutamento no Mundo 2")


func test_market_atomic() -> void:
	var srv := _srv()
	srv.debug_grant(1000000, {"fogo": 500})
	var rng := RandomNumberGenerator.new()
	var it := ItemLogic.create("garra_fogo_t2", "raro", rng, false, "s_test")
	srv.p().items[it.uid] = it
	var l := srv.market_list_item(it.uid, 500)
	check(l.ok, "listou")
	check(not srv.p().items.has(it.uid), "item listado sai do inventário")
	var again := srv.market_list_item(it.uid, 500)
	check(not again.ok, "não dá para listar o mesmo item duas vezes (sem duplicação)")
	var c := srv.market_cancel(l.listing.id)
	check(c.ok and srv.p().items.has(it.uid), "cancelar devolve o item")
	check(not srv.market_cancel(l.listing.id).ok, "cancelar duas vezes falha")
	# compra de vendedor fictício
	var res := srv.market_search({"kind": "item"})
	check(res.listings.size() > 0, "market populado por vendedores fictícios")
	var target: Dictionary = res.listings[0]
	var gold_before := int(srv.p().gold)
	var b := srv.market_buy(target.id)
	check(b.ok, "comprou")
	check(int(srv.p().gold) == gold_before - int(target.price), "ouro debitado")
	check(srv.p().items.has(b.item.uid), "item recebido")
	check(not srv.market_buy(target.id).ok, "não compra duas vezes a mesma listagem")
	# essência
	var le := srv.market_list_essence("fogo", 100, 1000)
	check(le.ok and int(srv.p().essences.fogo) == 400, "essência listada sai da carteira")
	check(not srv.market_list_essence("fogo", 1000, 10).ok, "não lista mais essência do que tem")
	# limite de listagens
	for i in 20:
		srv.market_list_essence("fogo", 1, 10)
	var mine := 0
	for x in srv.state.listings.values():
		if x.seller_id == srv.p().id:
			mine += 1
	check(mine == int(DataDB.config.market.max_listings), "limite de listagens (%d)" % mine)


func test_market_fee_on_sale() -> void:
	var srv := _srv()
	srv.debug_grant(0, {"luz": 100})
	var l := srv.market_list_essence("luz", 100, 1000)
	check(l.ok, "listou")
	_adv(srv, 3600.0)
	for i in 50:
		srv._simulate_fake_buyers()
	check(int(srv.p().gold) == 950, "venda credita preço - 5%% (ouro=%d)" % int(srv.p().gold))


func test_npc_sell_budget() -> void:
	var srv := _srv()
	var rng := RandomNumberGenerator.new()
	var fake := ItemLogic.create("garra_fogo_t6", "comum", rng, true)
	var r := srv.npc_sell(fake)
	check(r.ok and int(r.gold_gained) == 0, "item vinculado sem orçamento de abates não gera ouro")


func test_level_validation() -> void:
	var srv := _srv()
	_adv(srv, 3600.0)
	var r := srv.sync_save({"main_level": 250})
	check(r.corrected, "nível 250 em 1h é corrigido")
	check(int(r.allowed_level) < 60, "nível permitido em 1h (%d)" % int(r.allowed_level))
	_adv(srv, 3600.0 * 24 * 365)
	var r2 := srv.sync_save({"main_level": 120})
	check(not r2.corrected, "progresso plausível é aceito")


func test_convert_and_stars() -> void:
	var srv := _srv()
	srv.register_starter("agua_1")
	var starter: String = srv.p().monsters.keys()[0]
	check(not srv.convert_monster(starter, 5, 1, 0).ok, "inicial não pode ser trocado")
	srv.debug_force["recruit"] = 1
	var hunt: Dictionary = DataDB.hunts["w1_s1_agua_1"]
	_adv(srv, 60.0)
	var r := srv.claim_kills(hunt.id, [{"form": "agua_1_1", "level": 1, "ticket": ""}], [{"server_id": starter, "family": "agua_1", "stage": 1, "level": 3}], [])
	var rec: Dictionary = r.recruits[0]
	var c := srv.convert_monster(rec.server_id, 1, 1, 0)
	check(c.ok and int(c.amount) > 0, "converteu em Essência")
	check(not srv.convert_monster(rec.server_id, 1, 1, 0).ok, "não converte duas vezes")
	check(not srv.buy_star(starter).ok, "estrela sem Essência falha")
	srv.debug_grant(0, {"agua": 10000})
	for i in 5:
		check(srv.buy_star(starter).ok, "compra estrela %d" % (i + 1))
	check(not srv.buy_star(starter).ok, "máximo 5 estrelas")


func test_quality_rolls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lo := 0
	var sum := 0
	for i in 2000:
		var q := MonsterLogic.roll_quality(rng, false)
		check(q >= 0 and q <= 100, "qualidade 0-100")
		sum += q
		if q < 40:
			lo += 1
	check(lo > 1000, "maioria dos recrutados tem qualidade baixa (%d/2000 abaixo de 40)" % lo)
	for i in 500:
		var qs := MonsterLogic.roll_quality(rng, true)
		check(qs >= 50 and qs <= 100, "shiny tem qualidade 50-100")


func test_recruit_has_quality_from_server() -> void:
	var srv := _srv()
	srv.register_starter("agua_1")
	var starter: Dictionary = srv.p().monsters.values()[0]
	check(int(starter.quality) == int(DataDB.config.quality.starter), "inicial com qualidade padrão")
	srv.debug_force["recruit"] = 1
	_adv(srv, 60.0)
	var r := srv.claim_kills("w1_s1_agua_1", [{"form": "agua_1_1", "level": 1, "ticket": ""}], [{"server_id": starter.server_id, "family": "agua_1", "stage": 1, "level": 3}], [])
	check(r.recruits.size() == 1 and r.recruits[0].has("quality"), "recrutado vem com qualidade do servidor")
	var m := MonsterLogic.create("agua_1", 10, false, "a", "", 0)
	var m2 := MonsterLogic.create("agua_1", 10, false, "b", "", 100)
	check(EssenceLogic.essence_value(m2) > EssenceLogic.essence_value(m), "qualidade aumenta a Essência")


func test_daily_boss() -> void:
	var srv := _srv()
	srv.register_starter("fogo_1")
	var sid: String = srv.p().monsters.keys()[0]
	srv.debug_set_validated_level(30)
	var party := [{"server_id": sid, "family": "fogo_1", "stage": 2, "level": 30}]
	var st := srv.daily_boss_status(30)
	check(st.ok and int(st.used) == 0 and int(st.entries) == 3, "3 entradas por dia")
	var tokens: Array = []
	for i in 3:
		var s := srv.daily_boss_start(30)
		check(s.ok, "entrada %d" % (i + 1))
		tokens.append(s.token)
	check(not srv.daily_boss_start(30).ok, "4ª entrada recusada")
	_adv(srv, 60.0)
	var gold0 := int(srv.p().gold)
	var r := srv.daily_boss_claim(tokens[0], 1.0, 60.0, true, party)
	check(r.ok and int(r.gold_gained) > 0 and int(r.essence_gained) > 0, "recompensa de ouro e Essência")
	check(int(srv.p().gold) == gold0 + int(r.gold_gained), "ouro creditado")
	check(not srv.daily_boss_claim(tokens[0], 1.0, 60.0, true, party).ok, "token não reutilizável")
	# dano impossível em 1 segundo é limitado
	var r2 := srv.daily_boss_claim(tokens[1], 1.0, 1.0, true, party)
	check(r2.ok and not r2.won and float(r2.fraction) < 0.5, "vitória implausível vira derrota parcial")
	_adv(srv, 86400.0)
	check(int(srv.daily_boss_status(30).used) == 0, "entradas renovam no dia seguinte")


func test_challenge_fast_win_by_strong_team() -> void:
	# time nível 300 vence o Desafio 20 em 1 s: plausível (antes era recusado com "tempo implausível")
	var srv := _srv()
	srv.register_starter("fogo_1")
	var sid: String = srv.p().monsters.keys()[0]
	srv.debug_set_validated_level(300)
	var strong := [{"server_id": sid, "family": "fogo_1", "stage": 3, "level": 300}]
	var r := srv.claim_challenge("c20", true, 1.0, strong)
	check(r.ok and r.won, "time forte vence em 1 s (%s)" % str(r.get("error", "")))
	# time fraco no nível do desafio não vence em 1 s
	var srv2 := _srv()
	srv2.register_starter("fogo_1")
	var sid2: String = srv2.p().monsters.keys()[0]
	srv2.debug_set_validated_level(20)
	var weak := [{"server_id": sid2, "family": "fogo_1", "stage": 2, "level": 22}]
	check(not srv2.claim_challenge("c20", true, 1.0, weak).ok, "time no nível do desafio não vence em 1 s")
	check(srv2.claim_challenge("c20", true, 40.0, weak).ok, "vitória em 40 s aceita")
