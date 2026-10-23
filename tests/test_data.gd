extends "res://tests/test_base.gd"


func test_content_counts() -> void:
	check(DataDB.type_ids.size() == 9, "9 tipos")
	check(DataDB.family_list.size() == 45, "45 famílias")
	check(DataDB.form_list.size() == 135, "135 formas")
	check(DataDB.starters().size() == 9, "9 iniciais")
	var starter_types := {}
	for f in DataDB.starters():
		starter_types[f.type] = true
	check(starter_types.size() == 9, "1 inicial por tipo")
	var names := {}
	for f in DataDB.form_list:
		check(not names.has(f.name), "nome único: %s" % f.name)
		names[f.name] = true
		for a in f.abilities:
			check(DataDB.abilities.has(a), "habilidade existe: %s" % a)


func test_world1_hunts_cover_all_forms() -> void:
	var seen := {}
	var lvl1 := 0
	var lvl6 := 0
	var lvl12 := 0
	for h in DataDB.hunt_list:
		check(DataDB.biomes.has(h.biome), "bioma existe %s" % h.biome)
		for m in h.monsters:
			check(DataDB.forms.has(m.form), "forma existe %s" % m.form)
		for d in h.drops:
			check(DataDB.item_bases.has(d.base), "base de drop existe %s" % d.base)
		if int(h.world) == 1 and int(h.level) <= 80:
			for m in h.monsters:
				seen[m.form] = true
		if h.category == "filhote":
			match int(h.unlock_level):
				1: lvl1 += 1
				6: lvl6 += 1
				12: lvl12 += 1
	check(seen.size() == 135, "todas as 135 formas aparecem até o 80 (%d)" % seen.size())
	check(lvl1 == 15 and lvl6 == 15 and lvl12 == 15, "15 hunts de filhotes em 1/6/12")


func test_world2() -> void:
	var w2 := 0
	var maxl := 0
	for h in DataDB.hunt_list:
		if int(h.world) == 2:
			w2 += 1
			maxl = max(maxl, int(h.level))
			check(not h.recruit, "sem recrutamento no Mundo 2")
			check(h.get("corrupted", false), "bioma corrompido")
	check(w2 >= 22, "hunts do Mundo 2 geradas (%d)" % w2)
	check(maxl == int(DataDB.config.world2.end), "Mundo 2 vai até %d" % int(DataDB.config.world2.end))


func test_challenges() -> void:
	var lv := []
	for c in DataDB.challenges:
		lv.append(int(c.level))
		check(DataDB.forms.has(c.boss_form), "boss existe")
		check(DataDB.biomes.has(c.biome), "bioma do boss existe")
	check(lv == [10, 20, 30, 40, 50, 60, 70, 80, 90, 110, 210], "desafios 10..90 + Chefes de Mundo 110 e 210")
	check(DataDB.challenge_for_level(110).unlocks == "world2", "Chefe de Mundo 110 abre o Mundo 2")
	check(DataDB.challenge_for_level(210).unlocks == "world3", "Chefe de Mundo 210 abre o Mundo 3")
	check(int(DataDB.challenge_for_level(110).min_fighters) == 2 and int(DataDB.challenge_for_level(210).min_fighters) == 3, "chefes de mundo pedem 2 e 3 monstros")
	# mundos: Fronteira até o 110, Mundo 2 de 110 a 200, Mundo 3 de 210 em diante
	var by_world := {1: [], 2: [], 3: []}
	for h in DataDB.hunt_list:
		by_world[int(h.world)].append(int(h.level))
	check(by_world[1].max() >= 105 and by_world[1].max() < 110, "Mundo 1 vai até perto do 110")
	check(by_world[2].min() == 110 and by_world[2].max() == 200, "Mundo 2: 110 a 200")
	check(by_world[3].min() == 210 and by_world[3].max() == 300, "Mundo 3: 210 a 300")
	for h in DataDB.hunt_list:
		if int(h.world) == 2:
			check(int(h.requires_challenge) == 110 and not h.recruit, "Mundo 2 pede o Chefe 110 e não recruta")
		elif int(h.world) == 3:
			check(int(h.requires_challenge) == 210 and h.theme == "astral", "Mundo 3 pede o Chefe 210")
	check(KillRate.density_mult(3) > KillRate.density_mult(2) and KillRate.density_mult(2) > KillRate.density_mult(1), "mais monstros em campo = mais selvagens")
