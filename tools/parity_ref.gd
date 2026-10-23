extends SceneTree
## Gera valores de referência (GDScript) para o teste de paridade com a Edge Function (TypeScript).
##   godot --headless --path . -s tools/parity_ref.gd && deno run --allow-read supabase/functions/_shared/parity_test.ts


func _initialize() -> void:
	DataDB.load_all()
	var out := {"xp": {}, "gold": {}, "kills": {}, "essence": [], "reach": [], "daily": [], "quality": [], "mastery": [], "train": []}
	for d in [[20000, 40], [20001, 150], [20123, 300]]:
		var b := ServerLogic.daily_boss_def(d[0], d[1])
		out.daily.append({"in": d, "form": b.form, "hp": b.hp})
	for q in [0, 37, 100]:
		var mq := MonsterLogic.create("luz_2", 77, q == 100, "q", "", q)
		out.quality.append({"q": q, "shiny": q == 100, "atk": MonsterLogic.compute_stats(mq).atk, "ess": EssenceLogic.essence_value(mq)})
	for kb in [{"agua_1_1": 60, "fogo_2_2": 1200}, {"sombra_3_3": 20000, "vento_1_1": 9, "luz_2_1": 250, "eletrico_1_2": 4000}]:
		var b := Mastery.bonuses(kb)
		var mm2 := MonsterLogic.create("terra_1", 90, false, "mm", "", 40)
		mm2.stage = 3
		out.mastery.append({"in": kb, "b": b, "stats": MonsterLogic.compute_stats(mm2, {}, b)})
	for tr in [0, 4, 15]:
		var mt := MonsterLogic.create("gelo_3", 120, false, "t", "", 70)
		mt.stage = 3
		mt.train = tr
		var stt := MonsterLogic.compute_stats(mt)
		out.train.append({"t": tr, "hp": stt.hp, "atk": stt.atk, "def": stt.def, "cost": Formulas.train_cost(tr, 133),
			"shop": Formulas.shop_item_price(77, "epico"), "refresh": Formulas.shop_refresh_cost(50, 2)})
	for l in [1, 2, 5, 9, 10, 11, 50, 80, 120, 210, 299]:
		out.xp[str(l)] = Formulas.xp_to_next(l)
		out.gold[str(l)] = Formulas.gold_for_kill(l)
	for hid in ["w1_s1_agua_1", "w1_s3_fogo_2", "w1_mix_pantano", "w1x_95_1", "w2_150_1", "w3_250_2"]:
		var h: Dictionary = DataDB.hunts[hid]
		var lvl := int(h.level)
		var m := MonsterLogic.create("fogo_1", lvl + 2, false, "x")
		m.stars = 2
		var s := MonsterLogic.compute_stats(m)
		var n := PartyLogic.fighting_count(lvl + 2, 3)
		var f: Array = []
		for i in n:
			f.append(s)
		out.kills[hid] = {"level": lvl + 2, "n": n, "kph": KillRate.estimate(f, h).kills_per_hour}
	for e in [["agua_2", 1, 1, 0, false], ["luz_4", 3, 120, 2, true], ["sombra_1", 2, 30, 5, false]]:
		var mm := MonsterLogic.create(e[0], e[2], e[4], "y")
		mm.stage = e[1]
		mm.stars = e[3]
		out.essence.append({"in": e, "v": EssenceLogic.essence_value(mm)})
	for r in [[1, 3600.0], [50, 86400.0], [200, 86400.0 * 30]]:
		out.reach.append({"in": r, "v": ServerLogic.max_reachable_level(r[0], r[1])})
	var fl := FileAccess.open("res://supabase/functions/_shared/parity_ref.json", FileAccess.WRITE)
	fl.store_string(JSON.stringify(out))
	print("ok")
	quit()
