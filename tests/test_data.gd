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
	check(lv == [10, 20, 30, 40, 50, 60, 70, 80, 90], "desafios 10..90")
	check(DataDB.challenge_for_level(80).unlocks == "world2", "desafio 80 abre o Mundo 2")
