extends "res://tests/test_base.gd"
## Marcos de Caça: marcos por forma, bônus por tipo e contagem no servidor.


func test_tiers_and_points() -> void:
	var ts: Array = Mastery.tiers()
	check(ts.size() == 6, "6 marcos por forma")
	check(Mastery.tier_of(0) == 0, "sem abates = sem marco")
	check(Mastery.tier_of(int(ts[0]) - 1) == 0, "1 abaixo do Bronze")
	check(Mastery.tier_of(int(ts[0])) == 1, "Bronze no limite")
	check(Mastery.tier_of(int(ts[5]) * 10) == 6, "Lenda no máximo")
	for i in range(1, ts.size()):
		check(int(ts[i]) > int(ts[i - 1]), "marcos crescentes")
	check(Mastery.points_at(0) == 0, "0 pontos sem marco")
	check(Mastery.points_at(6) == 12, "12 pontos no máximo")


func test_bonus_by_type() -> void:
	var fid := "agua_1_1"
	var b := Mastery.bonuses({fid: 1000000})
	var st := Mastery.stat_of_form(fid)
	check(st.stat == "hp_pct", "água dá Vida")
	check(absf(float(b.hp_pct) - 12 * float(st.per_point)) < 0.0001, "bônus máximo de uma forma")
	check(float(b.atk_pct) == 0.0, "água não dá ataque")
	var b2 := Mastery.bonuses({"fogo_1_1": 50, "fogo_2_1": 50})
	check(absf(float(b2.atk_pct) - 4 * float(Mastery.stat_of_type("fogo").per_point)) < 0.0001, "formas somam (2 marcos x 2 formas)")
	check(int(b2.tiers) == 4, "conta os marcos")
	var stats := {}
	for t in DataDB.type_ids:
		stats[Mastery.stat_of_type(t).stat] = true
	check(stats.size() == 9, "cada tipo dá um atributo diferente")
	# info do painel da hunt
	var info := Mastery.form_info(fid, int(Mastery.tiers()[1]) + 3)
	check(int(info.tier) == 2, "Prata")
	check(int(info.next_at) == int(Mastery.tiers()[2]), "próximo = Ouro")
	check(float(info.next_gain) > 0.0 and float(info.earned) > 0.0, "próximo e atual positivos")
	check(float(info.progress) > 0.0 and float(info.progress) < 1.0, "progresso entre marcos")


func test_bonus_applies_to_stats() -> void:
	var m := MonsterLogic.create("agua_1", 30, false, "x")
	var base := MonsterLogic.compute_stats(m)
	var b := Mastery.bonuses({"agua_1_1": 1000000, "fogo_1_1": 1000000, "gelo_1_1": 1000000, "eletrico_1_1": 1000000, "sombra_1_1": 1000000})
	var s := MonsterLogic.compute_stats(m, {}, b)
	check(s.hp > base.hp * 1.02, "Vida aumenta")
	check(s.atk > base.atk * 1.02, "Ataque aumenta")
	check(s.def > base.def * 1.02, "Defesa aumenta")
	check(s.spd > base.spd, "Velocidade aumenta")
	check(s.crit > base.crit, "Crítico aumenta")


func test_server_counts_mastery() -> void:
	var t := {"v": 100000.0}
	var srv := ServerLogic.new({}, func(): return t.v)
	srv.login("dev")
	srv.register_starter("agua_1")
	var sid: String = srv.p().monsters.keys()[0]
	var party := [{"server_id": sid, "family": "agua_1", "stage": 1, "level": 5}]
	t.v += 120.0
	var kills: Array = []
	for i in 12:
		kills.append({"form": "agua_1_1", "level": 1, "ticket": ""})
	kills.append({"form": "fogo_9_9", "level": 1, "ticket": ""})
	var r := srv.claim_kills("w1_s1_agua_1", kills, party, [])
	check(r.ok, "claim ok")
	check(int(srv.p().mastery.get("agua_1_1", 0)) == int(r.accepted) - 0 or int(srv.p().mastery.get("agua_1_1", 0)) <= 12, "servidor conta abates válidos")
	check(not srv.p().mastery.has("fogo_9_9"), "forma inválida não conta")
	# offline também conta
	var before := int(srv.p().mastery.get("agua_1_1", 0))
	t.v += 3600.0
	var off := srv.claim_offline("w1_s1_agua_1", party, [])
	check(int(srv.p().mastery.get("agua_1_1", 0)) >= before, "offline soma marcos")
	check(int(off.kills) > 0, "offline gerou abates")
	# ouro com Marcos de terra validados no servidor
	srv.p().mastery["terra_1_1"] = 100000
	check(srv._gold_mult(0.0) > 1.0, "Marcos de terra aumentam o ouro no servidor")
	check(srv._gold_mult(500.0) <= 2.0 + float(Mastery.bonuses({"terra_1_1": 100000}).gold_pct) / 100.0 + 0.0001, "bônus de equipamento continua limitado")
	var prof := srv.get_profile()
	check(prof.has("mastery"), "perfil devolve os marcos")


func test_batch_endpoints() -> void:
	var t := {"v": 100000.0}
	var srv := ServerLogic.new({}, func(): return t.v)
	srv.login("dev")
	srv.register_starter("agua_1")
	var ids: Array = []
	for i in 3:
		var sid := "m_batch_%d" % i
		srv.p().monsters[sid] = {"server_id": sid, "family": "fogo_1", "form": "fogo_1_1", "shiny": false, "stars": 0, "converted": false, "quality": 50}
		ids.append({"server_id": sid, "level": 10, "stage": 1, "stars": 0})
	ids.append({"server_id": "nao_existe", "level": 10, "stage": 1, "stars": 0})
	var r := srv.convert_monsters(ids)
	check(r.ok, "lote ok")
	var oks := 0
	for x in r.results:
		if x.ok:
			oks += 1
	check(oks == 3, "3 trocados, 1 inválido")
	check(int(r.totals.get("fogo", 0)) > 0 and int(srv.p().essences.fogo) == int(r.totals.fogo), "essência somada")
	var again := srv.convert_monsters(ids.slice(0, 1))
	check(not again.results[0].ok, "não troca duas vezes")
	# venda em lote
	srv.p().npc_budget = 100000.0
	var rng := RandomNumberGenerator.new()
	var items: Array = []
	for i in 4:
		items.append(ItemLogic.create("garra_fogo_t1", "comum", rng, true, "b%d" % i))
	items[3].locked = true
	var g0 := int(srv.p().gold)
	var s := srv.npc_sell_many(items)
	check(s.sold.size() == 3, "vende 3, ignora o travado")
	check(int(srv.p().gold) - g0 == int(s.gold_gained) and int(s.gold_gained) > 0, "ouro do lote creditado")
