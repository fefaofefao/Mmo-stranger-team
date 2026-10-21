extends "res://tests/test_base.gd"


func test_essence_value() -> void:
	var a := MonsterLogic.create("agua_2", 1, false, "a")
	var b := MonsterLogic.create("agua_2", 40, false, "b")
	check(EssenceLogic.essence_value(b) > EssenceLogic.essence_value(a), "nível e estágio aumentam a Essência")
	var s := MonsterLogic.create("agua_2", 40, true, "s")
	near(float(EssenceLogic.essence_value(s)) / EssenceLogic.essence_value(b), float(DataDB.config.essence.shiny_mult), 1.0, "shiny multiplica")
	var e: Dictionary = DataDB.config.essence
	var fam: Dictionary = DataDB.families["agua_2"]
	var expected := float(e.stage_base[0]) * (1.0 + 1.0 / float(e.level_div)) * float(fam.essence_mult)
	near(EssenceLogic.essence_value(a), round(expected), 0.5, "fórmula de Essência")


func test_star_cost_and_bonus() -> void:
	var m := MonsterLogic.create("agua_1", 10, false, "a")
	check(EssenceLogic.star_cost(m) == int(DataDB.config.stars.cost[0]), "custo da 1ª estrela")
	var base := MonsterLogic.compute_stats(m)
	m.stars = 3
	var s3 := MonsterLogic.compute_stats(m)
	near(s3.hp / base.hp, 1.0 + 3 * float(DataDB.config.stars.stat_bonus_per_star), 0.0001, "bônus por estrela")
	check(s3.ability_power_mult > base.ability_power_mult, "3ª estrela melhora habilidade")
	m.stars = 5
	check(EssenceLogic.star_cost(m) == -1, "máximo de 5 estrelas")
	check(MonsterLogic.ability_upgrades(m) == 2, "2 melhorias de habilidade na 5ª")


func test_enhance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var it := ItemLogic.create("garra_fogo_t2", "raro", rng, false)
	var v0 := ItemLogic.main_value(it)
	for i in 5:
		check(EssenceLogic.try_enhance(it, rng), "+1..+5 sempre sucesso")
	check(it.enh == 5, "+5")
	check(ItemLogic.main_value(it) > v0, "aprimoramento aumenta atributo")
	var fails := 0
	for i in 200:
		var t := it.duplicate(true)
		if not EssenceLogic.try_enhance(t, rng):
			fails += 1
			check(t.enh == 5, "falha não destrói nem reduz")
	check(fails > 20 and fails < 90, "chance de falha no +6 (~25%%): %d/200" % fails)
	it.enh = 10
	check(not EssenceLogic.try_enhance(it, rng), "máximo +10")
