class_name MapGenerator
extends RefCounted
## Geração procedural de layout de mapa com seed fixa por hunt.
## Resultado (Dictionary):
##   size: Vector2i, solid: {Vector2i: true}, tiles: {Vector2i: int (índice no atlas do bioma)},
##   spawns: Array[Vector2i], start: Vector2i
## Índices do atlas (ver TileFactory): 0-2 chão, 3 chão detalhado, 4-5 parede/obstáculo,
## 6-7 decoração andável, 8 decoração corrompida, 9 borda.

const FLOOR_TILES := [0, 1, 2, 3]
const T_WALL_A := 4
const T_WALL_B := 5
const T_DECO_A := 6
const T_DECO_B := 7
const T_CORRUPT := 8
const T_BORDER := 9

const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func generate(biome_id: String, size: Vector2i, seed_value: int, corrupted := false, spawn_count := 24) -> Dictionary:
	var biome: Dictionary = DataDB.biomes.get(biome_id, {})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var solid := {}
	var style: String = biome.get("gen", "open")
	match style:
		"cave":
			_gen_cave(size, rng, solid)
		"islands":
			_gen_islands(size, rng, solid, seed_value)
		"rooms":
			_gen_rooms(size, rng, solid)
		_:
			_gen_open(size, rng, solid)
	# bordas sempre sólidas
	for x in size.x:
		solid[Vector2i(x, 0)] = true
		solid[Vector2i(x, size.y - 1)] = true
	for y in size.y:
		solid[Vector2i(0, y)] = true
		solid[Vector2i(size.x - 1, y)] = true
	# conectividade: mantém só a maior região livre
	var start := _largest_region_keep(size, solid)
	var tiles := {}
	for y in size.y:
		for x in size.x:
			var p := Vector2i(x, y)
			if solid.has(p):
				var border := x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
				tiles[p] = T_BORDER if border else (T_WALL_A if rng.randf() < 0.7 else T_WALL_B)
			else:
				var r := rng.randf()
				var t := 0
				if r < 0.06:
					t = T_DECO_A
				elif r < 0.10:
					t = T_DECO_B
				elif corrupted and r < 0.10 + float(DataDB.config.get("corruption", {}).get("extra_deco", 0.04)):
					t = T_CORRUPT
				elif r < 0.25:
					t = 3
				else:
					t = rng.randi_range(0, 2)
				tiles[p] = t
	var spawns := _pick_spawns(size, solid, start, rng, spawn_count)
	return {"size": size, "solid": solid, "tiles": tiles, "spawns": spawns, "start": start, "biome": biome_id, "corrupted": corrupted, "seed": seed_value}


static func _gen_open(size: Vector2i, rng: RandomNumberGenerator, solid: Dictionary) -> void:
	var clusters := int(size.x * size.y / 70.0)
	for i in clusters:
		var p := Vector2i(rng.randi_range(2, size.x - 3), rng.randi_range(2, size.y - 3))
		var steps := rng.randi_range(3, 10)
		for s in steps:
			solid[p] = true
			p += DIRS4[rng.randi_range(0, 3)]
			p = Vector2i(clampi(p.x, 1, size.x - 2), clampi(p.y, 1, size.y - 2))


static func _gen_cave(size: Vector2i, rng: RandomNumberGenerator, solid: Dictionary) -> void:
	var grid := {}
	for y in size.y:
		for x in size.x:
			grid[Vector2i(x, y)] = rng.randf() < 0.42
	for it in 4:
		var ng := {}
		for y in size.y:
			for x in size.x:
				var walls := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var q := Vector2i(x + dx, y + dy)
						if q.x < 0 or q.y < 0 or q.x >= size.x or q.y >= size.y or grid[q]:
							walls += 1
				ng[Vector2i(x, y)] = walls >= 5 or (it < 2 and walls == 0)
		grid = ng
	for p in grid:
		if grid[p]:
			solid[p] = true


static func _gen_islands(size: Vector2i, rng: RandomNumberGenerator, solid: Dictionary, seed_value: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.07
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	for y in size.y:
		for x in size.x:
			if noise.get_noise_2d(x, y) > 0.28:
				solid[Vector2i(x, y)] = true
	# algumas rochas/obstáculos soltos
	for i in int(size.x * size.y / 180.0):
		solid[Vector2i(rng.randi_range(2, size.x - 3), rng.randi_range(2, size.y - 3))] = true


static func _gen_rooms(size: Vector2i, rng: RandomNumberGenerator, solid: Dictionary) -> void:
	for y in size.y:
		for x in size.x:
			solid[Vector2i(x, y)] = true
	var rooms: Array = []
	var tries := 0
	while rooms.size() < int(size.x * size.y / 120.0) and tries < 400:
		tries += 1
		var w := rng.randi_range(5, 10)
		var h := rng.randi_range(5, 9)
		var r := Rect2i(rng.randi_range(1, size.x - w - 2), rng.randi_range(1, size.y - h - 2), w, h)
		var overlap := false
		for o in rooms:
			if (o as Rect2i).grow(1).intersects(r):
				overlap = true
				break
		if overlap:
			continue
		rooms.append(r)
		for yy in range(r.position.y, r.end.y):
			for xx in range(r.position.x, r.end.x):
				solid.erase(Vector2i(xx, yy))
		# pilares
		if w >= 7 and h >= 7:
			solid[r.position + Vector2i(2, 2)] = true
			solid[r.end - Vector2i(3, 3)] = true
	rooms.sort_custom(func(a, b): return a.get_center().x < b.get_center().x)
	for i in range(1, rooms.size()):
		var a: Vector2i = rooms[i - 1].get_center()
		var b: Vector2i = rooms[i].get_center()
		_carve_corridor(a, b, solid, rng)
		if rng.randf() < 0.3 and i >= 2:
			_carve_corridor(rooms[i - 2].get_center(), b, solid, rng)


static func _carve_corridor(a: Vector2i, b: Vector2i, solid: Dictionary, rng: RandomNumberGenerator) -> void:
	var p := a
	var horizontal_first := rng.randf() < 0.5
	while p != b:
		if (horizontal_first and p.x != b.x) or p.y == b.y:
			p.x += signi(b.x - p.x)
		else:
			p.y += signi(b.y - p.y)
		solid.erase(p)
		solid.erase(p + Vector2i(0, 1))


static func flood(size: Vector2i, solid: Dictionary, from: Vector2i) -> Dictionary:
	var seen := {}
	if solid.has(from):
		return seen
	var stack: Array = [from]
	seen[from] = true
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		for d in DIRS4:
			var q: Vector2i = p + d
			if q.x < 0 or q.y < 0 or q.x >= size.x or q.y >= size.y:
				continue
			if solid.has(q) or seen.has(q):
				continue
			seen[q] = true
			stack.append(q)
	return seen


static func _largest_region_keep(size: Vector2i, solid: Dictionary) -> Vector2i:
	var visited := {}
	var best := {}
	for y in size.y:
		for x in size.x:
			var p := Vector2i(x, y)
			if solid.has(p) or visited.has(p):
				continue
			var reg := flood(size, solid, p)
			for q in reg:
				visited[q] = true
			if reg.size() > best.size():
				best = reg
	if best.is_empty():
		# mapa todo sólido (improvável): abre o centro
		var c := size / 2
		for y in range(c.y - 3, c.y + 4):
			for x in range(c.x - 3, c.x + 4):
				solid.erase(Vector2i(x, y))
		best = flood(size, solid, c)
	for y in size.y:
		for x in size.x:
			var p := Vector2i(x, y)
			if not solid.has(p) and not best.has(p):
				solid[p] = true
	# início: célula livre mais perto do centro
	var center := size / 2
	var start := center
	var bd := 1 << 30
	for p in best:
		var d: int = (p - center).length_squared()
		if d < bd:
			bd = d
			start = p
	return start


static func _pick_spawns(size: Vector2i, solid: Dictionary, start: Vector2i, rng: RandomNumberGenerator, count: int) -> Array:
	var free: Array = []
	for y in size.y:
		for x in size.x:
			var p := Vector2i(x, y)
			if not solid.has(p) and (p - start).length() >= 5.0:
				free.append(p)
	var out: Array = []
	var tries := 0
	while out.size() < count and tries < 4000 and not free.is_empty():
		tries += 1
		var p: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		var ok := true
		for s in out:
			if (s - p).length() < 3.0:
				ok = false
				break
		if ok:
			out.append(p)
	return out
