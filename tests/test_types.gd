extends "res://tests/test_base.gd"


func test_cycle() -> void:
	near(TypeChart.multiplier("agua", "fogo"), 1.5, 0.001, "Água forte contra Fogo")
	near(TypeChart.multiplier("fogo", "agua"), 0.67, 0.001, "Fogo fraco contra Água")
	near(TypeChart.multiplier("sombra", "agua"), 1.5, 0.001, "Sombra forte contra Água (ciclo fecha)")
	near(TypeChart.multiplier("agua", "sombra"), 0.67, 0.001, "Água fraca contra Sombra")
	near(TypeChart.multiplier("agua", "planta"), 1.0, 0.001, "Água neutra contra Planta")
	near(TypeChart.multiplier("agua", "agua"), 1.0, 0.001, "Mesmo tipo neutro")


func test_no_type_dominates() -> void:
	# cada tipo tem exatamente 1 vantagem e 1 desvantagem
	for a in DataDB.type_ids:
		var strong := 0
		var weak := 0
		var total := 0.0
		for d in DataDB.type_ids:
			var m := TypeChart.multiplier(a, d)
			total += m
			if m > 1.0:
				strong += 1
			elif m < 1.0:
				weak += 1
		check(strong == 1 and weak == 1, "%s deve ter 1 forte e 1 fraco" % a)
		near(total, 7.0 + 1.5 + 0.67, 0.01, "soma dos multiplicadores igual para %s" % a)


func test_helpers() -> void:
	check(TypeChart.strong_against("agua") == "fogo", "strong_against")
	check(TypeChart.weak_against("agua") == "sombra", "weak_against")
