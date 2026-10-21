extends "res://tests/test_base.gd"


func test_map_generation_connected() -> void:
	for hid in ["w1_s1_agua_1", "w1_s2_luz_1", "w1_mix_pantano", "w2_150_1"]:
		var h: Dictionary = DataDB.hunts[hid]
		var md := MapGenerator.generate(h.biome, Vector2i(int(h.map_size[0]), int(h.map_size[1])), int(h.seed), h.get("corrupted", false))
		check(md.spawns.size() >= 8, "pontos de spawn em %s" % hid)
		check(not md.solid.has(md.start), "início livre em %s" % hid)
		# todos os spawns alcançáveis a partir do início
		var reach := MapGenerator.flood(md.size, md.solid, md.start)
		var ok := true
		for s in md.spawns:
			if not reach.has(s):
				ok = false
		check(ok, "spawns conectados em %s" % hid)
		var md2 := MapGenerator.generate(h.biome, md.size, int(h.seed), h.get("corrupted", false))
		check(md2.solid.size() == md.solid.size() and md2.start == md.start, "seed fixa gera o mesmo mapa (%s)" % hid)
