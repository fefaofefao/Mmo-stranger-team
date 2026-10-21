extends "res://tests/test_base.gd"


func _party(levels: Array) -> Array:
	var out: Array = []
	for i in levels.size():
		out.append(MonsterLogic.create("agua_1", levels[i], false, "p%d" % i))
	return out


func test_fighting_count() -> void:
	check(PartyLogic.fighting_count(1, 3) == 1, "1 luta até 109")
	check(PartyLogic.fighting_count(109, 3) == 1, "1 luta no 109")
	check(PartyLogic.fighting_count(110, 3) == 2, "2 lutam no 110")
	check(PartyLogic.fighting_count(209, 3) == 2, "2 lutam no 209")
	check(PartyLogic.fighting_count(210, 3) == 3, "3 lutam no 210")
	check(PartyLogic.fighting_count(250, 1) == 1, "limitado ao tamanho do grupo")


func test_xp_split() -> void:
	var p := _party([10, 10, 10])
	var xs := PartyLogic.split_xp(p, 100.0, 10)
	near(xs[0], 100.0, 0.001, "principal 100%")
	near(xs[1], 50.0, 0.001, "banco 50%")
	near(xs[2], 50.0, 0.001, "banco 50%")
	p = _party([110, 110, 110])
	xs = PartyLogic.split_xp(p, 100.0, 110)
	near(xs[1], 100.0, 0.001, "2º luta no 110 (100%)")
	near(xs[2], 50.0, 0.001, "3º no banco")
	p = _party([210, 210, 210])
	xs = PartyLogic.split_xp(p, 100.0, 210)
	near(xs[2], 100.0, 0.001, "3º luta no 210")
	xs = PartyLogic.split_xp(_party([10]), 100.0, 10, 10.0)
	near(xs[0], 110.0, 0.001, "bônus de XP")
