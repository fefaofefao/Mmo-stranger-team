extends SceneTree
## Simula os Desafios com o combate real (headless) para calibrar a dificuldade.
##   godot --headless --path . -s tools/challenge_sim.gd
## Para cada desafio testa 3 iniciais (vantagem / neutro / desvantagem de tipo) em níveis acima do desafio.

var G


func _initialize() -> void:
	_run.call_deferred()


func _gear_for(level: int) -> Dictionary:
	# equipamento "típico": itens Incomuns do tier do nível, tema neutro
	var items := {}
	var tier := 1
	for tr in DataDB.item_tiers:
		if int(tr.level) <= level and not tr.world2:
			tier = int(tr.tier)
	var rng := RandomNumberGenerator.new()
	for s in DataDB.item_slots:
		var it := ItemLogic.create("%s_luz_t%d" % [s.id, tier], "incomum", rng, true, "g_" + s.id)
		items[it.uid] = it
	return items


func _run() -> void:
	G = root.get_node("Game")
	var world = load("res://src/world/hunt_world.gd").new()
	world.headless = true
	root.add_child(world)
	world.set_process(false)
	print("desafio | nível | inicial (relação) | vitórias | tempo médio")
	var min_level := 0
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			min_level = int(a)
	for c in DataDB.challenges:
		if int(c.level) < min_level:
			continue
		var bt: String = c.type
		var cases := [["vantagem", TypeChart.weak_against(bt)], ["neutro", DataDB.type_ids[(DataDB.type_index[bt] + 3) % 9]], ["desvantagem", TypeChart.strong_against(bt)]]
		for off in [3, 8]:
			var lvl: int = int(c.level) + off
			for cs in cases:
				# atacante 'vantagem' = tipo forte contra o chefe
				var atk_type: String = cs[1]
				if cs[0] == "vantagem":
					atk_type = TypeChart.weak_against(bt)
				var fam := ""
				for f in DataDB.starters():
					if f.type == atk_type:
						fam = f.id
				var wins := 0
				var tsum := 0.0
				for rep in 2:
					var m := MonsterLogic.create(fam, lvl, false, "sim")
					m.stars = mini(5, int(lvl / 25))
					var gear := _gear_for(lvl)
					for uid in gear:
						m.equip[ItemLogic.base(gear[uid]).slot] = uid
					G.save.items = gear
					G.save.monsters = {"sim": m}
					G.save.party = ["sim"]
					world.setup_challenge(c)
					var done := [false, false, 0.0]
					var cb := func(won, s): done[0] = true; done[1] = won; done[2] = s
					world.challenge_finished.connect(cb)
					var steps := 0
					while not done[0] and steps < 6000:
						world.step(0.05)
						steps += 1
					world.challenge_finished.disconnect(cb)
					if done[1]:
						wins += 1
						tsum += done[2]
				print("%s | %d | %s (%s) | %d/2 | %s" % [c.id, lvl, DataDB.form(fam + "_1").name, cs[0], wins, ("%.0fs" % (tsum / wins)) if wins > 0 else "-"])
	quit()
