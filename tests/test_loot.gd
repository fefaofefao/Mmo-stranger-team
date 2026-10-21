extends "res://tests/test_base.gd"


func test_rarity_rates() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var n := 400000
	var counts := {}
	for i in n:
		var r := LootTable.roll_rarity(rng, true)
		if r != "":
			counts[r] = int(counts.get(r, 0)) + 1
	var raro := float(counts.get("raro", 0)) / n
	near(raro, 1.0 / 200.0, 0.0006, "Raro ~1/200")
	var epico := float(counts.get("epico", 0)) / n
	near(epico, 1.0 / 2000.0, 0.00015, "Épico ~1/2000")
	check(not counts.has("comum") and not counts.has("incomum"), "servidor não sorteia Comum/Incomum")
	var local := {}
	for i in 100000:
		var r2 := LootTable.roll_rarity(rng, false)
		if r2 != "":
			local[r2] = true
	check(not local.has("raro") and not local.has("mitico"), "cliente nunca sorteia Raro+")


func test_rarity_mult() -> void:
	near(LootTable.chance("raro", 1.5), 0.0075, 0.00001, "multiplicador do Mundo 2")
	near(LootTable.chance("comum", 1.5), float(DataDB.rarity("comum").chance), 0.00001, "comum não multiplica")


func test_pick_base_and_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hunt: Dictionary = DataDB.hunt_list[0]
	for i in 50:
		var b := LootTable.pick_base(hunt, rng)
		check(DataDB.item_bases.has(b), "base de drop existe: %s" % b)
	var it := ItemLogic.create(LootTable.pick_base(hunt, rng), "mitico", rng, false)
	check(it.affixes.size() == 3, "mítico tem 3 afixos")
	var ep := ItemLogic.create(LootTable.pick_base(hunt, rng), "epico", rng, false)
	check(ep.affixes.size() == 1, "épico tem 1 afixo")
	var co := ItemLogic.create(LootTable.pick_base(hunt, rng), "comum", rng, true)
	check(co.affixes.is_empty() and co.bound, "comum sem afixo e vinculado")
	check(ItemLogic.main_value(it) > ItemLogic.main_value(co) or ItemLogic.base(it).slot != ItemLogic.base(co).slot, "raridade aumenta atributo")
	check(ItemLogic.sell_price(it) > 0, "preço de venda")


func test_binomial() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var tot := 0
	for i in 200:
		tot += LootTable.binomial(10000, 0.005, rng)
	near(tot / 200.0, 50.0, 3.0, "binomial média n*p")
	check(LootTable.binomial(0, 0.5, rng) == 0, "n=0")
