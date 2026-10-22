extends "res://tests/test_base.gd"


func test_damage() -> void:
	near(Formulas.damage_raw(10, 10, 1.0), 5.0, 0.001, "dano 10 vs 10 = 5")
	near(Formulas.damage_raw(10, 0, 1.0), 10.0, 0.001, "sem defesa = ataque")
	near(Formulas.damage_raw(10, 10, 2.0), 10.0, 0.001, "power multiplica")
	check(Formulas.damage_raw(0, 10, 1.0) == 0.0, "ataque zero")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 200:
		var d := Formulas.roll_damage(20, 10, 1.0, 1.5, rng, 0.0)
		check(d.dmg >= 1.0, "dano mínimo 1")
		check(d.dmg <= 20.0 * 20.0 / 30.0 * 1.5 * 1.11, "dano dentro da variância")
	var e1 := Formulas.expected_damage(20, 10, 1.0, 1.0, 0.0)
	var e2 := Formulas.expected_damage(20, 10, 1.0, 1.0, 1.0)
	near(e2 / e1, float(DataDB.config.combat.crit_mult), 0.001, "crítico 100% = crit_mult")


func test_stats_growth() -> void:
	var s1 := Formulas.raw_stats("fogo_1_1", 1)
	var s10 := Formulas.raw_stats("fogo_1_1", 10)
	check(s10.hp > s1.hp and s10.atk > s1.atk, "atributos crescem com o nível")
	near(s10.hp / s1.hp, Formulas.level_mult(10), 0.0001, "crescimento linear")
	var a := Formulas.raw_stats("fogo_1_2", 20)
	var b := Formulas.raw_stats("fogo_1_1", 20)
	near(a.hp / b.hp, float(DataDB.config.stage_mult[1]) / float(DataDB.config.stage_mult[0]), 0.0001, "bônus de estágio")
	var sh := Formulas.raw_stats("fogo_1_1", 20, true)
	near(sh.atk / b.atk, 1.0 + float(DataDB.config.shiny_stat_bonus), 0.0001, "shiny +50%")
	var q := Formulas.raw_stats("fogo_1_1", 20, false, 100)
	near(q.atk / b.atk, 1.0 + float(DataDB.config.quality.max_bonus), 0.0001, "qualidade 100% = +30%")


func test_xp_curve() -> void:
	var prev := 0
	for l in range(1, 300):
		var x := Formulas.xp_to_next(l)
		check(x > prev, "xp_to_next cresce (%d)" % l)
		prev = x
	check(Formulas.xp_to_next(300) == 0, "nível máximo sem XP")
	near(Formulas.xp_level_factor(50, 50), 1.0, 0.0001, "sem penalidade no mesmo nível")
	check(Formulas.xp_level_factor(80, 10) < 1.0, "penalidade em monstros fracos")
	check(Formulas.xp_level_factor(300, 1) >= float(DataDB.config.xp.low_level_penalty_min), "penalidade mínima")
	check(Formulas.xp_for_kill(50) > Formulas.xp_for_kill(10), "xp por abate cresce")


func test_level_up_and_evolution() -> void:
	var m := MonsterLogic.create("agua_1", 1, false, "t1")
	check(m.stage == 1, "começa filhote")
	var need := Formulas.total_xp_for_level(16)
	var ev := MonsterLogic.add_xp(m, need + 1)
	check(m.level == 16, "chega ao 16 (obtido %d)" % m.level)
	check(m.stage == 2 and ev.evolved, "evolui para adolescente no 16")
	MonsterLogic.add_xp(m, Formulas.total_xp_for_level(35) - Formulas.total_xp_for_level(16))
	check(m.level == 35 and m.stage == 3, "adulto no 35")
	MonsterLogic.set_level(m, 999)
	check(m.level == 300, "limite de nível")


func test_early_levels_fast() -> void:
	# até o nível 10 o ritmo é acelerado (menos abates por nível)
	check(Formulas.kills_for_level(2) < Formulas.kills_for_level(12) / 10.0, "nível 2 bem mais rápido que o 12")
	var k := 0.0
	for l in range(1, 10):
		k += Formulas.kills_for_level(l)
	check(k < 260.0, "nível 10 em poucos abates (%d)" % int(k))
