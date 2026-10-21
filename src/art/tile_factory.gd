class_name TileFactory
extends RefCounted
## Tilesets por bioma (atlas 10 tiles de 32x32 em uma linha).
## Índices: 0-2 chão, 3 chão detalhado, 4-5 obstáculo/parede, 6-7 decoração, 8 decoração corrompida, 9 borda.
## Para trocar a arte: salve res://assets/tilesets/<bioma>.png (320x32, mesma ordem). Opcional:
## <bioma>_corrupted.png para o Mundo 2. Sem arquivo, o placeholder é gerado por código.

const T := 32
const COUNT := 10
const ART_DIR := "res://assets/tilesets/"

static var _cache := {}


static func tileset(biome_id: String, corrupted := false) -> TileSet:
	var key := biome_id + ("_c" if corrupted else "")
	if _cache.has(key):
		return _cache[key]
	var tex := atlas_texture(biome_id, corrupted)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(T, T)
	for i in COUNT:
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	_cache[key] = ts
	return ts


static func atlas_texture(biome_id: String, corrupted := false) -> Texture2D:
	var path := ART_DIR + biome_id + ("_corrupted" if corrupted else "") + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	if corrupted and ResourceLoader.exists(ART_DIR + biome_id + ".png"):
		var img: Image = (load(ART_DIR + biome_id + ".png") as Texture2D).get_image()
		img.convert(Image.FORMAT_RGBA8)
		_corrupt_image(img)
		return ImageTexture.create_from_image(img)
	return ImageTexture.create_from_image(generate_atlas(biome_id, corrupted))


static func _corrupt_color(c: Color) -> Color:
	var cc: Dictionary = DataDB.config.get("corruption", {})
	var tint := Color(cc.get("tint", "#4a1a6a"))
	var out := c.lerp(tint, float(cc.get("tint_amount", 0.35))).darkened(float(cc.get("darken", 0.25)))
	out.a = c.a
	return out


static func _corrupt_image(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0:
				img.set_pixel(x, y, _corrupt_color(c))


static func generate_atlas(biome_id: String, corrupted := false) -> Image:
	var b: Dictionary = DataDB.biomes.get(biome_id, DataDB.biomes.values()[0])
	var img := Image.create(T * COUNT, T, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(biome_id)
	var floors: Array = []
	for f in b.floor:
		floors.append(Color(f))
	var wall := Color(b.wall)
	var deco: Array = []
	for d in b.deco:
		deco.append(Color(d))
	for i in 4:
		_floor(img, i * T, floors[i % 3], rng, i == 3)
	for i in [4, 5]:
		_floor(img, i * T, floors[0], rng, false)
		_wall(img, i * T, b.wall_style, wall, rng, i == 5)
	for i in [6, 7]:
		_floor(img, i * T, floors[1], rng, false)
		_deco(img, i * T, b.deco_style, deco[(i - 6) % deco.size()], rng)
	_floor(img, 8 * T, floors[2], rng, false)
	_corruption_deco(img, 8 * T, rng)
	# borda: parede escura/abismo
	for y in T:
		for x in T:
			var c := wall.darkened(0.55 + 0.1 * rng.randf())
			img.set_pixel(8 * 0 + 9 * T + x, y, c)
	if corrupted:
		_corrupt_image(img)
		# brilho de corrupção extra no tile 8 depois do tingimento
		_corruption_deco(img, 8 * T, rng)
	return img


static func _floor(img: Image, ox: int, base: Color, rng: RandomNumberGenerator, detailed: bool) -> void:
	for y in T:
		for x in T:
			var v := rng.randf()
			var c := base
			if v < 0.12:
				c = base.darkened(0.08)
			elif v < 0.2:
				c = base.lightened(0.06)
			img.set_pixel(ox + x, y, c)
	if detailed:
		for i in 6:
			var x := rng.randi_range(2, T - 4)
			var y := rng.randi_range(2, T - 4)
			img.set_pixel(ox + x, y, base.darkened(0.25))
			img.set_pixel(ox + x + 1, y, base.darkened(0.18))
			img.set_pixel(ox + x, y + 1, base.lightened(0.12))


static func _wall(img: Image, ox: int, style: String, c: Color, rng: RandomNumberGenerator, alt: bool) -> void:
	var sub := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var dark := c.darkened(0.35)
	var light := c.lightened(0.3)
	match style:
		"tree":
			SpriteFactory.rect(sub, 13, 18, 6, 12, Color(0.4, 0.25, 0.12))
			SpriteFactory.ellipse(sub, 16, 13, 13 if not alt else 11, 11, c)
			SpriteFactory.ellipse(sub, 12, 9, 6, 4, light)
			SpriteFactory.ellipse(sub, 20, 17, 5, 3, dark)
		"rock":
			SpriteFactory.ellipse(sub, 16, 18, 14, 11 if not alt else 9, c)
			SpriteFactory.ellipse(sub, 12, 14, 6, 4, light)
			SpriteFactory.line(sub, Vector2(18, 12), Vector2(22, 22), dark)
		"water", "lava":
			for y in T:
				for x in T:
					var v := sin((x + y * 0.5) * 0.6 + (8.0 if alt else 0.0)) * 0.5 + 0.5
					sub.set_pixel(x, y, c.lerp(light, v * 0.25) if style == "water" else c.lerp(Color(1, 0.85, 0.3), v * 0.35))
			for i in 5:
				var x := rng.randi_range(3, T - 8)
				var y := rng.randi_range(3, T - 3)
				SpriteFactory.line(sub, Vector2(x, y), Vector2(x + 4, y), light if style == "water" else Color(0.25, 0.1, 0.05))
		"coral":
			SpriteFactory.rect(sub, 0, 0, T, T, Color(0.15, 0.4, 0.6))
			for i in 4:
				var x := 5 + i * 7
				SpriteFactory.line(sub, Vector2(x, 30), Vector2(x + rng.randi_range(-3, 3), 8 + rng.randi_range(0, 8)), c, 3)
				SpriteFactory.ellipse(sub, x, 9 + rng.randi_range(0, 6), 3, 3, light)
		"ice", "crystal":
			SpriteFactory.tri(sub, Vector2(6, 30), Vector2(26, 30), Vector2(16, 2 if not alt else 8), c)
			SpriteFactory.tri(sub, Vector2(2, 30), Vector2(12, 30), Vector2(6, 14), light)
			SpriteFactory.tri(sub, Vector2(20, 30), Vector2(30, 30), Vector2(25, 16), dark)
			SpriteFactory.line(sub, Vector2(14, 8), Vector2(12, 24), Color(1, 1, 1, 0.8))
		"pillar":
			SpriteFactory.rect(sub, 9, 4, 14, 26, c)
			SpriteFactory.rect(sub, 7, 2, 18, 4, light)
			SpriteFactory.rect(sub, 7, 27, 18, 4, dark)
			SpriteFactory.rect(sub, 12, 6, 2, 20, light)
			if alt:
				SpriteFactory.line(sub, Vector2(18, 8), Vector2(14, 20), dark)
		"cloud":
			for y in T:
				for x in T:
					sub.set_pixel(x, y, c.lerp(Color(0.85, 0.92, 1), 0.3 + 0.2 * sin(x * 0.3 + y * 0.2)))
			SpriteFactory.ellipse(sub, 10, 12, 8, 6, Color(1, 1, 1, 0.8))
			SpriteFactory.ellipse(sub, 22, 20, 9, 6, Color(1, 1, 1, 0.7))
		"tomb":
			SpriteFactory.rect(sub, 9, 8, 14, 22, c.lightened(0.15))
			SpriteFactory.ellipse(sub, 16, 9, 7, 5, c.lightened(0.15))
			SpriteFactory.rect(sub, 15, 11, 2, 9, dark)
			SpriteFactory.rect(sub, 12, 14, 8, 2, dark)
			SpriteFactory.rect(sub, 7, 28, 18, 3, dark)
		_:
			SpriteFactory.rect(sub, 2, 2, 28, 28, c)
	var white_outline := style in ["tree", "rock", "ice", "crystal", "pillar", "tomb"]
	if white_outline:
		SpriteFactory._outline(sub, dark.darkened(0.5))
	img.blend_rect(sub, Rect2i(0, 0, T, T), Vector2i(ox, 0))


static func _deco(img: Image, ox: int, style: String, c: Color, rng: RandomNumberGenerator) -> void:
	var sub := Image.create(T, T, false, Image.FORMAT_RGBA8)
	for i in 3:
		var x := rng.randi_range(5, T - 6)
		var y := rng.randi_range(6, T - 6)
		match style:
			"flower":
				SpriteFactory.line(sub, Vector2(x, y), Vector2(x, y + 4), Color(0.2, 0.5, 0.2))
				for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
					sub.set_pixel(x + int(d.x), y + int(d.y), c)
				sub.set_pixel(x, y, Color(1, 0.95, 0.4))
			"pebble":
				SpriteFactory.ellipse(sub, x, y, 2.5, 1.8, c)
			"shell":
				SpriteFactory.ellipse(sub, x, y, 2.5, 2.0, c)
				sub.set_pixel(x, y, c.darkened(0.3))
			"ember":
				SpriteFactory.ellipse(sub, x, y, 1.5, 1.5, c)
				sub.set_pixel(x, y - 2, Color(1, 0.9, 0.4, 0.8))
			"snow":
				SpriteFactory.ellipse(sub, x, y, 2.5, 1.5, Color(1, 1, 1))
			"bone":
				SpriteFactory.line(sub, Vector2(x - 3, y), Vector2(x + 3, y), c)
				sub.set_pixel(x - 3, y - 1, c)
				sub.set_pixel(x + 3, y + 1, c)
			"spark":
				SpriteFactory.line(sub, Vector2(x, y - 2), Vector2(x + 2, y), c)
				SpriteFactory.line(sub, Vector2(x + 2, y), Vector2(x, y + 2), c)
			"feather":
				SpriteFactory.line(sub, Vector2(x - 2, y + 2), Vector2(x + 2, y - 2), c)
				sub.set_pixel(x, y - 1, c.darkened(0.2))
			"grass":
				SpriteFactory.line(sub, Vector2(x, y + 2), Vector2(x - 1, y - 2), c)
				SpriteFactory.line(sub, Vector2(x + 2, y + 2), Vector2(x + 3, y - 1), c)
			"mushroom":
				SpriteFactory.rect(sub, x, y, 1, 3, Color(0.9, 0.9, 0.8))
				SpriteFactory.ellipse(sub, x + 0.5, y, 2.5, 1.5, c)
			"crystal":
				SpriteFactory.tri(sub, Vector2(x - 2, y + 2), Vector2(x + 2, y + 2), Vector2(x, y - 4), c)
			_:
				sub.set_pixel(x, y, c)
	img.blend_rect(sub, Rect2i(0, 0, T, T), Vector2i(ox, 0))


static func _corruption_deco(img: Image, ox: int, rng: RandomNumberGenerator) -> void:
	var sub := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var c := Color(0.75, 0.3, 1.0)
	SpriteFactory.tri(sub, Vector2(10, 26), Vector2(16, 26), Vector2(13, 10), c)
	SpriteFactory.tri(sub, Vector2(16, 26), Vector2(22, 26), Vector2(20, 15), c.darkened(0.3))
	SpriteFactory.line(sub, Vector2(12, 14), Vector2(12, 22), Color(1, 0.8, 1, 0.9))
	img.blend_rect(sub, Rect2i(0, 0, T, T), Vector2i(ox, 0))
