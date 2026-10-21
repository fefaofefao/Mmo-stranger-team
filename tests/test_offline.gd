extends "res://tests/test_base.gd"


func _hunt(level: int) -> Dictionary:
	var best: Dictionary = {}
	for h in DataDB.hunt_list:
		if int(h.world) == 1 and (best.is_empty() or absi(int(h.level) - level) < absi(int(best.level) - level)):
			best = h
	return best


func test_kill_rate_sane() -> void:
	var m := MonsterLogic.create("fogo_1", 5, false, "x")
	var s := MonsterLogic.compute_stats(m)
	var est := KillRate.estimate([s], _hunt(5))
	check(est.kills_per_hour > 150 and est.kills_per_hour < 2000, "abates/h plausíveis no nível 5 (%d)" % est.kills_per_hour)
	var weak := MonsterLogic.compute_stats(MonsterLogic.create("fogo_1", 1, false, "x"))
	var hard := KillRate.estimate([weak], _hunt(40))
	check(hard.kills_per_hour < est.kills_per_hour * 0.2, "hunt muito difícil rende pouco")
	var strong := MonsterLogic.compute_stats(MonsterLogic.create("fogo_1", 30, false, "x"))
	var easy := KillRate.estimate([strong], _hunt(5))
	check(easy.kills_per_hour > est.kills_per_hour, "monstro mais forte mata mais rápido")


func test_more_fighters_more_kills() -> void:
	var a := MonsterLogic.compute_stats(MonsterLogic.create("agua_1", 120, false, "a"))
	var h: Dictionary = DataDB.hunts["w2_120_0"]
	var one := KillRate.estimate([a], h)
	var two := KillRate.estimate([a, a], h)
	check(two.kills_per_hour > one.kills_per_hour, "2 monstros matam mais que 1")


func test_offline_server_claim() -> void:
	var t := [1000000.0]
	var srv := ServerLogic.new({}, func(): return t[0])
	srv.login("dev")
	srv.register_starter("fogo_1")
	var sid: String = srv.p().monsters.keys()[0]
	var hunt := _hunt(5)
	var party := [{"server_id": sid, "family": "fogo_1", "stage": 1, "level": 5}]
	var stats := [MonsterLogic.compute_stats(MonsterLogic.create("fogo_1", 5, false, "x"))]
	t[0] += 3600.0 * 2
	var r := srv.claim_offline(hunt.id, party, stats)
	var expected: float = KillRate.estimate(stats, hunt).kills_per_hour * 2.0 * float(DataDB.config.offline.efficiency)
	near(float(r.kills), expected, expected * 0.02 + 2, "abates offline = taxa x tempo x eficiência")
	check(int(r.gold_gained) > 0, "ouro offline")
	# limite de 8h
	t[0] += 3600.0 * 30
	var r2 := srv.claim_offline(hunt.id, party, stats)
	near(float(r2.seconds), float(DataDB.config.offline.max_hours) * 3600.0, 1.0, "offline limitado a 8h")
	# não dá para pedir de novo sem tempo passar
	var r3 := srv.claim_offline(hunt.id, party, stats)
	check(int(r3.kills) == 0, "sem tempo decorrido = sem abates")
	# dobrar recompensa só uma vez
	var d1 := srv.double_offline()
	var d2 := srv.double_offline()
	check(d1.ok and not d2.ok, "dobrar apenas uma vez")


func test_client_cannot_inflate_stats() -> void:
	var t := [5000.0]
	var srv := ServerLogic.new({}, func(): return t[0])
	srv.login("dev")
	srv.register_starter("fogo_1")
	var sid: String = srv.p().monsters.keys()[0]
	var hunt := _hunt(5)
	var party := [{"server_id": sid, "family": "fogo_1", "stage": 1, "level": 5}]
	var fake := [{"hp": 1e9, "atk": 1e9, "def": 1e9, "spd": 1e5, "crit": 1.0}]
	t[0] += 3600.0
	var r := srv.claim_offline(hunt.id, party, fake)
	var upper := srv._party_upper_stats(party)
	var cap: float = KillRate.estimate(upper, hunt).kills_per_hour * float(DataDB.config.offline.efficiency)
	check(float(r.kills) <= cap + 1, "stats falsos são limitados pelo servidor")
