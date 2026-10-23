class_name TileFactory
extends RefCounted
## Terreno dos mapas por bioma: atlas de chão com transições orgânicas + objetos com altura (props).
##
## ATLAS (16 x 4 tiles de 32 px = 512 x 128):
##   linha 0: 0-7 variações de chão | 8-15 decorações andáveis (fundo transparente)
##   linha 1: transições chão → "trilha" (segundo piso) pela máscara de cantos (1 = sup.esq, 2 = sup.dir, 4 = inf.esq, 8 = inf.dir)
##   linha 2: transições chão → massa (água, lava, céu, rocha, mata, muralha...) pela mesma máscara
##   linha 3: 0-3 massa cheia (variações) | 4-7 decorações de corrupção (Mundo 2)
## PROPS (árvores, rochas, cristais, colunas, lápides, corais): imagens soltas desenhadas em pé, com sombra.
##
## Para trocar a arte: res://assets/tilesets/<bioma>.png (512x128, mesma ordem) e
## res://assets/tilesets/<bioma>_prop<0..2>.png. Sem arquivo, tudo é gerado por código.

const T := 32
const COLS := 16
const ROWS := 4
const ART_DIR := "res://assets/tilesets/"
const LIQUID := ["water", "lava", "cloud"]
const PROP_CHANCE := {"tree": 0.85, "rock": 0.5, "ice": 0.55, "crystal": 0.6, "coral": 0.6, "pillar": 0.0, "tomb": 0.25}

static var _cache := {}
static var _theme := "abyss"


## {tileset, props: Array[Texture2D], style, liquid, deco_style, biome}
static func terrain(biome_id: String, corrupted := false, theme := "") -> Dictionary:
	if corrupted and theme == "":
		theme = "abyss"
	_theme = theme
	var key := biome_id + ("_c" + theme if corrupted else "")
	if _cache.has(key):
		return _cache[key]
	var b: Dictionary = DataDB.biomes.get(biome_id, DataDB.biomes.values()[0])
	var img := atlas_image(biome_id, corrupted)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(T, T)
	for y in ROWS:
		for x in COLS:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	var props: Array = []
	for im in prop_images(biome_id, corrupted):
		props.append(ImageTexture.create_from_image(im))
	var out := {"tileset": ts, "props": props, "style": b.wall_style, "liquid": b.wall_style in LIQUID,
		"deco_style": b.deco_style, "biome": biome_id}
	_cache[key] = out
	return out


static func atlas_image(biome_id: String, corrupted := false) -> Image:
	var path := ART_DIR + biome_id + ".png"
	var img: Image
	if ResourceLoader.exists(path):
		img = (load(path) as Texture2D).get_image()
		img.convert(Image.FORMAT_RGBA8)
	else:
		img = generate_atlas(biome_id)
	if corrupted:
		img = img.duplicate()
		_corrupt_image(img)
		_corruption_overlays(img)
	return img


static func prop_images(biome_id: String, corrupted := false) -> Array:
	var out: Array = []
	for i in 3:
		var path := ART_DIR + "%s_prop%d.png" % [biome_id, i]
		var im: Image
		if ResourceLoader.exists(path):
			im = (load(path) as Texture2D).get_image()
			im.convert(Image.FORMAT_RGBA8)
		else:
			im = generate_prop(biome_id, i)
		if corrupted:
			im = im.duplicate()
			_corrupt_image(im)
		out.append(im)
	return out


# ------------------------------------------------------------------ cores e ruído

static func _corrupt_color(c: Color) -> Color:
	var cc: Dictionary = DataDB.config.get("themes", {}).get(_theme, DataDB.config.get("corruption", {}))
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


static func _noise(seed_value: int, freq: float, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.noise_type = kind
	return n


static func _is_green(c: Color) -> bool:
	return c.h > 0.17 and c.h < 0.48 and c.s > 0.25


## Cor do segundo piso (trilhas/manchas): terra batida na grama, areia molhada na praia, cascalho na rocha...
static func _patch_color(b: Dictionary) -> Color:
	var f := Color(b.floor[0])
	if _is_green(f):
		return f.lerp(Color("#8a6a42"), 0.62)
	if b.wall_style in ["ice", "crystal", "cloud"] or f.v > 0.85:
		return f.darkened(0.05).lerp(Color("#c8dce8"), 0.2)
	if b.wall_style == "lava":
		return f.darkened(0.25)
	return Color(b.floor[1]).darkened(0.1)


# ------------------------------------------------------------------ atlas

static func generate_atlas(biome_id: String) -> Image:
	var b: Dictionary = DataDB.biomes.get(biome_id, DataDB.biomes.values()[0])
	var img := Image.create(T * COLS, T * ROWS, false, Image.FORMAT_RGBA8)
	var seed_value := hash(biome_id)
	var ctx := {
		"b": b, "fl": [Color(b.floor[0]), Color(b.floor[1]), Color(b.floor[2])], "patch": _patch_color(b),
		"wall": Color(b.wall), "deco": [Color(b.deco[0]), Color(b.deco[1])], "style": b.wall_style,
		"n1": _noise(seed_value, 0.11), "n2": _noise(seed_value + 1, 0.45, FastNoiseLite.TYPE_VALUE),
		"ne": _noise(seed_value + 2, 0.16), "n3": _noise(seed_value + 3, 0.22, FastNoiseLite.TYPE_CELLULAR),
		"rng": RandomNumberGenerator.new(),
	}
	ctx.rng.seed = seed_value
	for v in 8:
		_tile(img, ctx, Vector2i(v, 0), [0, 0, 0, 0], 0, v * 41)
	for m in range(1, 16):
		_tile(img, ctx, Vector2i(m, 1), _bits(m), 1, m * 13)
		_tile(img, ctx, Vector2i(m, 2), _bits(m), 2, m * 17)
	for v in 4:
		_tile(img, ctx, Vector2i(v, 3), [1, 1, 1, 1], 2, 300 + v * 29)
	# máscara 0 das linhas 1/2 nunca é usada: repete o chão
	_tile(img, ctx, Vector2i(0, 1), [0, 0, 0, 0], 0, 7)
	_tile(img, ctx, Vector2i(0, 2), [0, 0, 0, 0], 0, 9)
	for v in 8:
		_deco_tile(img, ctx, Vector2i(8 + v, 0), v)
	return img


static func _bits(m: int) -> Array:
	return [m & 1, (m >> 1) & 1, (m >> 2) & 1, (m >> 3) & 1]


## Valor de "massa" no pixel: bilinear dos cantos + ruído que some nas bordas do tile (tiles vizinhos casam).
static func _f(ctx: Dictionary, c: Array, x: float, y: float) -> float:
	var u := clampf((x + 0.5) / T, 0.0, 1.0)
	var v := clampf((y + 0.5) / T, 0.0, 1.0)
	var top := lerpf(c[0], c[1], u)
	var bot := lerpf(c[2], c[3], u)
	var f := lerpf(top, bot, v)
	var edge := minf(minf(x, T - 1 - x), minf(y, T - 1 - y))
	var amp := 0.3 * clampf(edge / 7.0, 0.0, 1.0)
	return f + (ctx.ne as FastNoiseLite).get_noise_2d(x * 1.0, y * 1.0) * amp


## layer: 0 = só chão, 1 = chão/trilha, 2 = chão/massa
static func _tile(img: Image, ctx: Dictionary, cell: Vector2i, corners: Array, layer: int, off: int) -> void:
	var style: String = ctx.style
	var liquid := style in LIQUID
	for y in T:
		for x in T:
			var f := _f(ctx, corners, x, y) if layer > 0 else 0.0
			var c: Color
			if layer == 2 and f > 0.5:
				c = _mass_px(ctx, x + off, y, f, corners)
				# contorno escuro na borda da massa elevada (lê como parede/penhasco)
				if not liquid and f < 0.56:
					c = (ctx.wall as Color).darkened(0.55)
				# face do penhasco (massa elevada com chão logo abaixo)
				elif not liquid and _f(ctx, corners, x, y + 6) <= 0.5:
					c = c.darkened(0.32) if int(x + off) % 5 != 0 else c.darkened(0.42)
				elif not liquid and _f(ctx, corners, x, y - 3) <= 0.5:
					c = c.lightened(0.26)
				# borda: espuma, crosta, nuvem
				if liquid and f < 0.62:
					c = {"water": Color("#e8f6ff"), "lava": Color("#2a1410"), "cloud": Color("#ffffff")}[style]
			elif layer == 1 and f > 0.5:
				c = _patch_px(ctx, x + off, y)
				if f < 0.58:
					c = c.darkened(0.08)
			else:
				c = _floor_px(ctx, x + off, y)
				if layer == 2 and f > 0.34:
					if liquid:
						c = c.darkened(0.14) if style == "water" else (c.darkened(0.35) if style == "lava" else c.darkened(0.25))
					elif _f(ctx, corners, x, y - 5) > 0.5:
						c = c.darkened(0.32)  # sombra projetada pela massa acima
					else:
						c = c.darkened(0.1)
				elif layer == 1 and f > 0.42:
					c = c.lerp(ctx.patch, 0.3)
			img.set_pixel(cell.x * T + x, cell.y * T + y, c)
	if layer == 0:
		_floor_details(img, ctx, cell, off)


static func _floor_px(ctx: Dictionary, x: int, y: int) -> Color:
	var fl: Array = ctx.fl
	var v := (ctx.n1 as FastNoiseLite).get_noise_2d(x, y)
	var g := (ctx.n2 as FastNoiseLite).get_noise_2d(x, y)
	var c: Color = fl[0].lerp(fl[1] if v < 0 else fl[2], minf(1.0, absf(v) * 1.6))
	if g > 0.62:
		c = c.lightened(0.06)
	elif g < -0.62:
		c = c.darkened(0.07)
	return c


static func _patch_px(ctx: Dictionary, x: int, y: int) -> Color:
	var p: Color = ctx.patch
	var v := (ctx.n1 as FastNoiseLite).get_noise_2d(x + 500, y)
	var g := (ctx.n2 as FastNoiseLite).get_noise_2d(x + 500, y)
	var c := p.lerp(p.lightened(0.12) if v > 0 else p.darkened(0.1), absf(v))
	if g > 0.7:
		c = c.darkened(0.2)  # pedrinhas
	elif g < -0.72:
		c = c.lightened(0.14)
	return c


static func _mass_px(ctx: Dictionary, x: int, y: int, f: float, corners: Array) -> Color:
	var w: Color = ctx.wall
	var n1 := (ctx.n1 as FastNoiseLite).get_noise_2d(x * 1.6, y * 1.6)
	var n3 := (ctx.n3 as FastNoiseLite).get_noise_2d(x, y)
	match ctx.style:
		"water":
			var deep := clampf((f - 0.5) * 2.0, 0.0, 1.0)
			var c := w.lightened(0.18).lerp(w.darkened(0.12), deep)
			var wave := sin((x * 0.55 + y * 0.9) + n1 * 3.0)
			if wave > 0.9:
				c = c.lightened(0.22)
			elif wave < -0.94:
				c = c.darkened(0.08)
			return c
		"lava":
			var c := w.lerp(Color("#ffb03a"), clampf(n1 * 0.8 + 0.3, 0.0, 1.0))
			if n3 > 0.15:
				c = Color("#3a2018").lerp(Color("#5a3020"), clampf(n1 + 0.5, 0, 1))
				if n3 < 0.22:
					c = Color("#ff7a2a")
			return c
		"cloud":
			var c := w.lerp(Color("#c8e0f8"), clampf(float(y) / T * 0.4 + n1 * 0.3, 0, 1))
			if n1 > 0.35:
				c = c.lerp(Color(1, 1, 1), 0.55)
			return c
		"tree":
			var c := w.lerp(w.lightened(0.28), clampf(n3 * 0.9 + 0.35, 0, 1))
			if n1 > 0.45:
				c = c.lightened(0.12)
			elif n1 < -0.5:
				c = c.darkened(0.25)
			return c
		"pillar", "tomb":
			var row := int(floor(y / 8.0))
			var bx := (x + (8 if row % 2 == 1 else 0)) % 16
			var c := w.lerp(w.lightened(0.18), clampf(n1 * 0.6 + 0.4, 0, 1))
			if y % 8 == 7 or bx == 15:
				c = w.darkened(0.35)
			elif y % 8 == 0 or bx == 0:
				c = c.lightened(0.12)
			if ctx.style == "tomb" and n3 > 0.4:
				c = c.lerp(Color("#4a6a3a"), 0.4)  # musgo
			return c
		"ice", "crystal":
			var c := w.lerp(w.lightened(0.35), clampf(n1 * 0.7 + 0.4, 0, 1))
			if absf(sin((x - y) * 0.35 + n3 * 2.0)) < 0.08:
				c = c.lightened(0.35)
			return c
		"coral":
			var c := w.lerp(w.lightened(0.2), clampf(n1 + 0.4, 0, 1))
			if n3 > 0.3:
				c = c.darkened(0.25)
			elif n3 < -0.45:
				c = Color("#f2a9b8")
			return c
		_:
			# rocha
			var c := w.lerp(w.lightened(0.25), clampf(n1 * 0.7 + 0.45, 0, 1))
			if absf(n3) < 0.035:
				c = w.darkened(0.4)  # rachaduras
			return c


static func _floor_details(img: Image, ctx: Dictionary, cell: Vector2i, off: int) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	rng.seed = hash(off) + cell.x
	var fl: Array = ctx.fl
	var green := _is_green(fl[0])
	for i in (9 if green else 5):
		var x := rng.randi_range(1, T - 3)
		var y := rng.randi_range(2, T - 2)
		var ox := cell.x * T
		var oy := cell.y * T
		if green:
			# folhas de grama
			var gc: Color = fl[0].lightened(0.2)
			img.set_pixel(ox + x, oy + y, gc)
			img.set_pixel(ox + x, oy + y - 1, gc)
			img.set_pixel(ox + x + 1, oy + y, fl[0].darkened(0.15))
		else:
			img.set_pixel(ox + x, oy + y, fl[0].darkened(0.2))
			img.set_pixel(ox + x + 1, oy + y, fl[0].lightened(0.1))


## Decorações andáveis (sobrepostas ao chão).
static func _deco_tile(img: Image, ctx: Dictionary, cell: Vector2i, v: int) -> void:
	var sub := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(ctx.b.id) + str(v))
	var deco: Array = ctx.deco
	var style: String = ctx.b.deco_style
	var n := rng.randi_range(2, 4)
	for i in n:
		var x := rng.randf_range(6, T - 7)
		var y := rng.randf_range(8, T - 5)
		var c: Color = deco[(i + v) % 2]
		match style:
			"flower":
				SpriteFactory.line(sub, Vector2(x, y + 1), Vector2(x, y + 5), Color("#2f7a2a"))
				for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
					SpriteFactory.ellipse(sub, x + d.x, y + d.y, 1.6, 1.6, c)
				SpriteFactory.ellipse(sub, x, y, 1.2, 1.2, Color("#fff2a0"))
			"grass":
				for k in 3:
					SpriteFactory.line(sub, Vector2(x + k * 2 - 2, y + 3), Vector2(x + k * 2 - 3 + k, y - 3 - k), c.darkened(0.1 * k))
			"pebble":
				SpriteFactory.ellipse(sub, x, y + 1, 3.5, 1.4, Color(0, 0, 0, 0.25))
				SpriteFactory.ellipse(sub, x, y, 3.2, 2.2, c)
				SpriteFactory.ellipse(sub, x - 1, y - 1, 1.2, 0.8, c.lightened(0.3))
			"shell":
				SpriteFactory.ellipse(sub, x, y, 3.0, 2.4, c)
				SpriteFactory.line(sub, Vector2(x - 2, y + 1), Vector2(x, y - 2), c.darkened(0.25))
				SpriteFactory.line(sub, Vector2(x + 2, y + 1), Vector2(x, y - 2), c.darkened(0.25))
			"ember":
				SpriteFactory.ellipse(sub, x, y, 3.0, 3.0, Color(c.r, c.g, c.b, 0.25))
				SpriteFactory.ellipse(sub, x, y, 1.6, 1.6, c)
				sub.set_pixel(int(x), int(y) - 1, Color(1, 0.95, 0.6))
			"snow":
				SpriteFactory.ellipse(sub, x, y, 4.0, 2.0, Color(1, 1, 1, 0.95))
				SpriteFactory.ellipse(sub, x + 1, y + 1, 3.0, 1.0, Color("#cfe4f0"))
			"bone":
				SpriteFactory.line(sub, Vector2(x - 4, y), Vector2(x + 4, y - 1), c, 2)
				SpriteFactory.ellipse(sub, x - 4, y, 1.5, 1.5, c)
				SpriteFactory.ellipse(sub, x + 4, y - 1, 1.5, 1.5, c)
			"spark":
				SpriteFactory.line(sub, Vector2(x, y - 3), Vector2(x + 2, y), c)
				SpriteFactory.line(sub, Vector2(x + 2, y), Vector2(x, y + 1), c)
				SpriteFactory.line(sub, Vector2(x, y + 1), Vector2(x + 2, y + 4), c)
			"feather":
				SpriteFactory.line(sub, Vector2(x - 3, y + 3), Vector2(x + 3, y - 3), c.darkened(0.2))
				SpriteFactory.ellipse(sub, x, y, 2.4, 1.2, c)
			"mushroom":
				SpriteFactory.rect(sub, x - 0.5, y, 2, 4, Color("#f0ead8"))
				SpriteFactory.ellipse(sub, x + 0.5, y, 3.5, 2.2, c)
				sub.set_pixel(int(x) - 1, int(y) - 1, Color(1, 1, 1, 0.9))
			"crystal":
				SpriteFactory.tri(sub, Vector2(x - 2.5, y + 3), Vector2(x + 2.5, y + 3), Vector2(x, y - 5), c)
				SpriteFactory.line(sub, Vector2(x - 1, y + 2), Vector2(x, y - 3), Color(1, 1, 1, 0.8))
			_:
				SpriteFactory.ellipse(sub, x, y, 1.5, 1.5, c)
	_shade_and_outline(sub, Color(0, 0, 0, 0.55), false)
	img.blend_rect(sub, Rect2i(0, 0, T, T), Vector2i(cell.x * T, cell.y * T))


static func _corruption_overlays(img: Image) -> void:
	for v in 4:
		var sub := Image.create(T, T, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + v
		var c := Color(0.78, 0.32, 1.0)
		for i in rng.randi_range(1, 3):
			var x := rng.randf_range(8, T - 8)
			var y := rng.randf_range(12, T - 4)
			var h := rng.randf_range(6, 14)
			SpriteFactory.ellipse(sub, x, y + 1, 5, 2, Color(0.5, 0.1, 0.8, 0.35))
			SpriteFactory.tri(sub, Vector2(x - 3, y), Vector2(x + 3, y), Vector2(x + rng.randf_range(-1, 1), y - h), c)
			SpriteFactory.line(sub, Vector2(x - 1, y - 1), Vector2(x, y - h + 2), Color(1, 0.85, 1, 0.9))
		_shade_and_outline(sub, Color("#2a0a3a"), false)
		img.blend_rect(sub, Rect2i(0, 0, T, T), Vector2i((4 + v) * T, 3 * T))


# ------------------------------------------------------------------ props (objetos com altura)

static func generate_prop(biome_id: String, variant: int) -> Image:
	var b: Dictionary = DataDB.biomes.get(biome_id, DataDB.biomes.values()[0])
	var style: String = b.wall_style
	var w := Color(b.wall)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(biome_id) + variant * 7
	var img: Image
	match style:
		"tree":
			img = Image.create(44, 60, false, Image.FORMAT_RGBA8)
			SpriteFactory.ellipse(img, 22, 56, 15, 4, Color(0, 0, 0, 0.3))
			SpriteFactory.rect(img, 19, 36, 6, 20, Color("#6a4424"))
			SpriteFactory.rect(img, 19, 36, 2, 20, Color("#8a5a32"))
			var leaf := w.lightened(0.12)
			var puffs := [[22, 22, 15, 13], [13, 30, 9, 8], [31, 30, 9, 8], [22, 12, 10, 9]]
			for p in puffs:
				SpriteFactory.ellipse(img, p[0] + rng.randf_range(-1, 1), p[1], p[2] - variant, p[3], leaf)
			for i in 7:
				SpriteFactory.ellipse(img, rng.randf_range(12, 32), rng.randf_range(10, 34), 3, 2.5, leaf.lightened(0.18))
			if variant == 2:
				for i in 4:
					SpriteFactory.ellipse(img, rng.randf_range(12, 32), rng.randf_range(14, 34), 1.6, 1.6, Color(b.deco[0]))
		"pillar":
			img = Image.create(34, 58, false, Image.FORMAT_RGBA8)
			SpriteFactory.ellipse(img, 17, 54, 14, 3.5, Color(0, 0, 0, 0.3))
			SpriteFactory.rect(img, 3, 47, 28, 7, w.lightened(0.05))
			SpriteFactory.rect(img, 7, 12, 20, 36, w.lightened(0.22))
			for k in 3:
				SpriteFactory.rect(img, 10 + k * 5, 14, 2, 32, w.lightened(0.05))
			SpriteFactory.rect(img, 3, 5, 28, 8, w.lightened(0.32))
			SpriteFactory.rect(img, 5, 12, 24, 2, w.darkened(0.1))
			if variant == 1:
				SpriteFactory.line(img, Vector2(17, 16), Vector2(12, 30), w.darkened(0.4))
			if variant == 2:
				SpriteFactory.ellipse(img, 15, 2, 4, 3, Color(b.deco[0]))
		"tomb":
			img = Image.create(28, 40, false, Image.FORMAT_RGBA8)
			SpriteFactory.ellipse(img, 14, 36, 11, 3, Color(0, 0, 0, 0.3))
			var st := w.lightened(0.35)
			SpriteFactory.rect(img, 5, 14, 18, 22, st)
			SpriteFactory.ellipse(img, 14, 14, 9, 7, st)
			SpriteFactory.rect(img, 13, 12, 2, 12, st.darkened(0.35))
			SpriteFactory.rect(img, 9, 16, 10, 2, st.darkened(0.35))
			if variant != 1:
				SpriteFactory.ellipse(img, 8, 33, 4, 2, Color("#4a6a3a"))
		"ice", "crystal":
			img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
			SpriteFactory.ellipse(img, 16, 44, 13, 3.5, Color(0, 0, 0, 0.25))
			var cc := w.lightened(0.15)
			SpriteFactory.tri(img, Vector2(8, 44), Vector2(22, 44), Vector2(15 + variant, 6), cc)
			SpriteFactory.tri(img, Vector2(3, 44), Vector2(13, 44), Vector2(6, 22 + variant * 2), cc.darkened(0.12))
			SpriteFactory.tri(img, Vector2(18, 44), Vector2(29, 44), Vector2(25, 18), cc.lightened(0.12))
			SpriteFactory.line(img, Vector2(13, 12), Vector2(11, 38), Color(1, 1, 1, 0.85))
		"coral":
			img = Image.create(34, 40, false, Image.FORMAT_RGBA8)
			SpriteFactory.ellipse(img, 17, 36, 13, 3, Color(0, 0, 0, 0.25))
			for i in 4:
				var x := 6 + i * 7 + rng.randf_range(-1, 1)
				var top := rng.randf_range(8, 18)
				SpriteFactory.line(img, Vector2(x, 36), Vector2(x + rng.randf_range(-3, 3), top), w, 3)
				SpriteFactory.ellipse(img, x, top, 3.5, 3.5, w.lightened(0.25))
		_:
			# rocha (também para mapas de água/lava/nuvem)
			var rc := w
			if style == "water":
				rc = Color("#7a8a80")
			elif style == "lava":
				rc = Color("#3a2a30")
			elif style == "cloud":
				rc = Color("#e8f0fa")
			img = Image.create(34, 32, false, Image.FORMAT_RGBA8)
			SpriteFactory.ellipse(img, 17, 28, 14, 3.5, Color(0, 0, 0, 0.3))
			SpriteFactory.ellipse(img, 17, 19, 13 - variant, 10, rc)
			SpriteFactory.ellipse(img, 11 + variant * 2, 16, 7, 6, rc.lightened(0.15))
			SpriteFactory.ellipse(img, 23, 23, 6, 4, rc.darkened(0.15))
			if style == "water" or variant == 2:
				SpriteFactory.ellipse(img, 13, 10, 6, 2.5, Color("#5a8a3a"))  # musgo
			if style == "lava":
				SpriteFactory.line(img, Vector2(12, 14), Vector2(18, 24), Color("#ff7a2a"))
	_shade_and_outline(img, w.darkened(0.7), true)
	return img


## Luz de cima/esquerda, sombra embaixo/direita e contorno (pixels com alfa < 0.5 = sombra no chão, ignorados).
static func _shade_and_outline(img: Image, outline: Color, shade := true) -> void:
	var wd := img.get_width()
	var ht := img.get_height()
	var solid := PackedByteArray()
	solid.resize(wd * ht)
	for y in ht:
		for x in wd:
			solid[y * wd + x] = 1 if img.get_pixel(x, y).a > 0.5 else 0
	var _s := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < wd and y < ht and solid[y * wd + x] == 1
	if shade:
		for y in ht:
			for x in wd:
				if solid[y * wd + x] == 0:
					continue
				var c := img.get_pixel(x, y)
				if not _s.call(x - 1, y - 1) or not _s.call(x, y - 2):
					img.set_pixel(x, y, c.lightened(0.16))
				elif not _s.call(x + 1, y + 1) or not _s.call(x + 2, y):
					img.set_pixel(x, y, c.darkened(0.22))
	var add: Array = []
	for y in ht:
		for x in wd:
			if solid[y * wd + x] == 1:
				continue
			if _s.call(x + 1, y) or _s.call(x - 1, y) or _s.call(x, y + 1) or _s.call(x, y - 1):
				add.append(Vector2i(x, y))
	for p in add:
		img.set_pixel(p.x, p.y, outline)


## Monta o mapa em duas camadas + props. Retorna os nós de props criados.
static func paint(map: Dictionary, ground: TileMapLayer, deco: TileMapLayer, props_parent: Node2D, seed_value: int) -> void:
	var ter := terrain(map.biome, map.get("corrupted", false), map.get("theme", ""))
	ground.tile_set = ter.tileset
	deco.tile_set = ter.tileset
	var sz: Vector2i = map.size
	var solid: Dictionary = map.solid
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pn := _noise(seed_value, 0.085)
	var is_solid := func(x: int, y: int) -> bool:
		return x < 0 or y < 0 or x >= sz.x or y >= sz.y or solid.has(Vector2i(x, y))
	# cantos: massa quando as 4 células em volta são sólidas; trilha pelo ruído
	var mass_c := {}
	var patch_c := {}
	for cy in sz.y + 1:
		for cx in sz.x + 1:
			if is_solid.call(cx - 1, cy - 1) and is_solid.call(cx, cy - 1) and is_solid.call(cx - 1, cy) and is_solid.call(cx, cy):
				mass_c[Vector2i(cx, cy)] = true
			if pn.get_noise_2d(cx, cy) > 0.36:
				patch_c[Vector2i(cx, cy)] = true
	var liquid: bool = ter.liquid
	var chance: float = PROP_CHANCE.get(ter.style, 0.5)
	var props: Array = ter.props
	for y in sz.y:
		for x in sz.x:
			var p := Vector2i(x, y)
			var mm := _mask(mass_c, x, y)
			var pm := _mask(patch_c, x, y)
			if mm == 15:
				ground.set_cell(p, 0, Vector2i(rng.randi_range(0, 3), 3))
			elif mm > 0:
				ground.set_cell(p, 0, Vector2i(mm, 2))
			elif pm > 0:
				ground.set_cell(p, 0, Vector2i(pm, 1))
			else:
				var r := rng.randf()
				ground.set_cell(p, 0, Vector2i(rng.randi_range(0, 3) if r < 0.7 else rng.randi_range(4, 7), 0))
			if solid.has(p):
				if props.is_empty():
					continue
				var free_n := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if (dx != 0 or dy != 0) and not is_solid.call(x + dx, y + dy):
							free_n += 1
				var want := false
				if mm == 0:
					want = true  # obstáculo isolado: precisa aparecer
				elif not liquid and free_n > 0 and mm < 15:
					want = rng.randf() < chance
				elif not liquid and mm == 15 and ter.style == "tree":
					want = rng.randf() < 0.08
				if want:
					var s := Sprite2D.new()
					var tex: Texture2D = props[rng.randi_range(0, props.size() - 1)]
					s.texture = tex
					s.centered = false
					s.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
					s.position = Vector2(x * T + T / 2.0 + rng.randf_range(-2, 2), y * T + T - 2)
					s.flip_h = rng.randf() < 0.5
					props_parent.add_child(s)
			elif mm == 0:
				var r2 := rng.randf()
				if map.get("corrupted", false) and r2 < 0.05:
					deco.set_cell(p, 0, Vector2i(4 + rng.randi_range(0, 3), 3))
				elif r2 < 0.16:
					deco.set_cell(p, 0, Vector2i(8 + rng.randi_range(0, 7), 0))


static func _mask(corners: Dictionary, x: int, y: int) -> int:
	var m := 0
	if corners.has(Vector2i(x, y)):
		m |= 1
	if corners.has(Vector2i(x + 1, y)):
		m |= 2
	if corners.has(Vector2i(x, y + 1)):
		m |= 4
	if corners.has(Vector2i(x + 1, y + 1)):
		m |= 8
	return m
