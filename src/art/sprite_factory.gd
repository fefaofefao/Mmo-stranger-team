class_name SpriteFactory
extends RefCounted
## Spritesheets dos monstros.
##
## PADRÃO DO SPRITESHEET (vale para arte gerada e arte substituta):
##   10 colunas x 4 linhas de quadros do mesmo tamanho (qualquer tamanho, ex.: 32, 48 ou 64 px).
##   Linhas (direção):  0 = baixo, 1 = esquerda, 2 = direita, 3 = cima
##   Colunas (animação): 0-1 parado | 2-4 andar (3 quadros) | 5-6 ataque | 7-9 morte (9 = corpo no chão)
## Para trocar a arte, salve um PNG em res://assets/sprites/monsters/<form_id>.png
## (opcional: <form_id>_shiny.png). Se não existir, o placeholder é gerado por código:
## corpo pelo formato da família, traços do animal (data/families.json → features),
## acento do elemento (chama, gota, cristal...) e tamanho pelo estágio.

const COLS := 10
const ROWS := 4
const FRAME := 56
const DIR_DOWN := 0
const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 3
const ART_DIR := "res://assets/sprites/monsters/"
const SIZES := [25.0, 34.0, 45.0]

static var _cache := {}
static var _portrait_cache := {}


static func sheet(form_id: String, shiny := false) -> Texture2D:
	var key := form_id + ("_s" if shiny else "")
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	var path := ART_DIR + form_id + ("_shiny" if shiny else "") + ".png"
	if ResourceLoader.exists(path):
		tex = load(path)
	elif shiny and ResourceLoader.exists(ART_DIR + form_id + ".png"):
		var img: Image = (load(ART_DIR + form_id + ".png") as Texture2D).get_image()
		_shiny_recolor(img)
		tex = ImageTexture.create_from_image(img)
	else:
		tex = ImageTexture.create_from_image(generate_sheet(form_id, shiny))
	_cache[key] = tex
	return tex


## Retrato (1 quadro, parado olhando para baixo, recortado no conteúdo) para a UI.
static func portrait(form_id: String, shiny := false) -> Texture2D:
	var key := form_id + ("_s" if shiny else "")
	if _portrait_cache.has(key):
		return _portrait_cache[key]
	var fr: Image
	var custom := ResourceLoader.exists(ART_DIR + form_id + ("_shiny" if shiny else "") + ".png") or ResourceLoader.exists(ART_DIR + form_id + ".png")
	if custom:
		var img := sheet(form_id, shiny).get_image()
		fr = img.get_region(Rect2i(0, 0, img.get_width() / COLS, img.get_height() / ROWS))
	else:
		fr = _frame_image(form_id, shiny, DIR_DOWN, 0)
	var used := fr.get_used_rect()
	if used.size.x <= 0:
		used = Rect2i(Vector2i.ZERO, fr.get_size())
	var side := maxi(used.size.x, used.size.y) + 4
	var out := Image.create(side, side, false, Image.FORMAT_RGBA8)
	out.blit_rect(fr, used, Vector2i((side - used.size.x) / 2, (side - used.size.y) / 2))
	var tex := ImageTexture.create_from_image(out)
	_portrait_cache[key] = tex
	return tex


static func clear_cache() -> void:
	_cache.clear()
	_portrait_cache.clear()


static func palette(form_id: String, shiny: bool) -> Dictionary:
	var f := DataDB.form(form_id)
	var base := DataDB.type_color(f.get("type", "agua"))
	var h := fposmod(base.h + float(f.get("hue_shift", 0.0)), 1.0)
	var s := base.s
	var v := base.v
	if shiny:
		h = fposmod(h + 0.45, 1.0)
		s = clampf(s + 0.2, 0.35, 1.0)
		v = clampf(v + 0.1, 0.55, 1.0)
	s = maxf(s, 0.28)
	v = clampf(v, 0.5, 0.93)
	var col := Color.from_hsv(h, s, v)
	var t: String = f.get("type", "agua")
	var eye := Color(0.1, 0.08, 0.14)
	if t == "sombra":
		eye = Color(0.95, 0.25, 0.35)
	return {
		"base": col,
		"dark": col.darkened(0.32),
		"darker": col.darkened(0.55),
		"light": col.lightened(0.35),
		"belly": col.lightened(0.55),
		"outline": col.darkened(0.78),
		"accent": Color.from_hsv(fposmod(h + 0.1, 1.0), clampf(s * 0.9, 0, 1), clampf(v * 0.8, 0, 1)),
		"elem": _elem_color(t, shiny),
		"elem2": _elem_color2(t, shiny),
		"eye": eye,
		"white": Color(1, 1, 1),
		"blush": Color(1, 0.55, 0.65, 0.9),
		"type": t,
		"shiny": shiny,
	}


static func _elem_color(t: String, shiny: bool) -> Color:
	var c: Color = {"agua": Color("#7fd0ff"), "fogo": Color("#ff8a2a"), "gelo": Color("#dff8ff"), "planta": Color("#6fd650"),
		"terra": Color("#9c8a72"), "eletrico": Color("#ffe23a"), "vento": Color("#f2f8ff"), "luz": Color("#fff3a0"),
		"sombra": Color("#a06ae0")}.get(t, Color.WHITE)
	if shiny:
		c.h = fposmod(c.h + 0.45, 1.0)
	return c


static func _elem_color2(t: String, shiny: bool) -> Color:
	var c: Color = {"agua": Color("#3a8ad8"), "fogo": Color("#ffe04a"), "gelo": Color("#8fd8f0"), "planta": Color("#3a9a30"),
		"terra": Color("#6a5a48"), "eletrico": Color("#ffffff"), "vento": Color("#b8d0e8"), "luz": Color("#ffffff"),
		"sombra": Color("#5a2a90")}.get(t, Color.WHITE)
	if shiny:
		c.h = fposmod(c.h + 0.45, 1.0)
	return c


static func generate_sheet(form_id: String, shiny := false) -> Image:
	var img := Image.create(FRAME * COLS, FRAME * ROWS, false, Image.FORMAT_RGBA8)
	for row in ROWS:
		for col in COLS:
			var fr := _frame_image(form_id, shiny, row, col)
			img.blit_rect(fr, Rect2i(0, 0, FRAME, FRAME), Vector2i(col * FRAME, row * FRAME))
	return img


static func _frame_image(form_id: String, shiny: bool, dir: int, col: int) -> Image:
	var f := DataDB.form(form_id)
	var pal := palette(form_id, shiny)
	var img := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	var stage := int(f.get("stage", 1))
	var s: float = SIZES[clampi(stage - 1, 0, 2)]
	var p := {"bob": 0.0, "phase": 0.0, "lunge": 0.0, "dead": 0}
	if col <= 1:
		p.bob = float(col)
	elif col <= 4:
		p.phase = [-1.0, 0.0, 1.0][col - 2]
		p.bob = 0.0 if col == 3 else 1.0
	elif col <= 6:
		p.lunge = 2.0 if col == 5 else 4.0
	else:
		p.dead = col - 6
	var cx := FRAME / 2.0
	var by := FRAME - 4.0
	if p.dead > 0:
		_draw_dead(img, pal, s, cx, by, p.dead)
	else:
		var lx := 0.0
		var ly := 0.0
		match dir:
			DIR_DOWN: ly = p.lunge
			DIR_UP: ly = -p.lunge
			DIR_LEFT: lx = -p.lunge
			DIR_RIGHT: lx = p.lunge
		var ctx := {
			"img": img, "pal": pal, "s": s, "cx": cx + lx, "by": by + ly - p.bob, "dir": dir,
			"side": dir == DIR_LEFT or dir == DIR_RIGHT, "fx": -1.0 if dir == DIR_LEFT else 1.0,
			"ph": float(p.phase), "bob": float(p.bob), "stage": stage, "ft": f.get("features", {}),
			"type": f.get("type", "agua"), "attack": p.lunge > 0,
		}
		ellipse(img, cx + lx, by - 1, s * 0.4, s * 0.1, Color(0, 0, 0, 0.32))
		match f.get("shape", "blob"):
			"quadruped": _quadruped(ctx)
			"bird": _bird(ctx)
			"serpent": _serpent(ctx)
			"fish": _fish(ctx)
			"insect": _insect(ctx)
			"biped": _biped(ctx)
			"golem": _golem(ctx)
			"spirit": _spirit(ctx)
			_: _blob(ctx)
	_outline(img, pal.outline)
	if shiny and p.dead == 0:
		_sparkles(img, col + dir * 3)
	return img


# ================================================================== primitivas

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		if c.a >= 1.0:
			img.set_pixel(x, y, c)
		elif c.a > 0.0:
			img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


static func ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for y in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_px(img, x, y, c)


static func rect(img: Image, x: float, y: float, w: float, h: float, c: Color) -> void:
	for yy in range(int(round(y)), int(round(y + h))):
		for xx in range(int(round(x)), int(round(x + w))):
			_px(img, xx, yy, c)


static func tri(img: Image, a: Vector2, b: Vector2, c2: Vector2, c: Color) -> void:
	var minx := int(floor(min(a.x, min(b.x, c2.x))))
	var maxx := int(ceil(max(a.x, max(b.x, c2.x))))
	var miny := int(floor(min(a.y, min(b.y, c2.y))))
	var maxy := int(ceil(max(a.y, max(b.y, c2.y))))
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
			var d2 := (p.x - c2.x) * (b.y - c2.y) - (b.x - c2.x) * (p.y - c2.y)
			var d3 := (p.x - a.x) * (c2.y - a.y) - (c2.x - a.x) * (p.y - a.y)
			var neg := d1 < 0 or d2 < 0 or d3 < 0
			var pos := d1 > 0 or d2 > 0 or d3 > 0
			if not (neg and pos):
				_px(img, x, y, c)


static func line(img: Image, a: Vector2, b: Vector2, c: Color, w := 1) -> void:
	var steps := int(max(abs(b.x - a.x), abs(b.y - a.y))) + 1
	for i in steps + 1:
		var t = float(i) / max(1, steps)
		var p := a.lerp(b, t)
		if w <= 1:
			_px(img, int(p.x), int(p.y), c)
		else:
			rect(img, p.x - w / 2.0, p.y - w / 2.0, w, w, c)


static func _outline(img: Image, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var add: Array = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.1:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and img.get_pixel(q.x, q.y).a > 0.5:
					add.append(Vector2i(x, y))
					break
	for p in add:
		img.set_pixel(p.x, p.y, c)


static func _sparkles(img: Image, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 3:
		var x := rng.randi_range(6, FRAME - 7)
		var y := rng.randi_range(6, FRAME - 16)
		var c := Color(1, 1, 0.75)
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			_px(img, x + d.x, y + d.y, c)


static func _shiny_recolor(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				c.h = fposmod(c.h + 0.45, 1.0)
				img.set_pixel(x, y, c)


# ================================================================== rosto, cabeça e acentos

static func _ft(ctx: Dictionary, k: String, default = false):
	return ctx.ft.get(k, default)


## Olhos grandes e brilhantes (filhote fofo; adulto com sobrancelha brava).
static func _eyes(ctx: Dictionary, hx: float, hy: float, spread: float, r: float) -> void:
	var dir: int = ctx.dir
	if dir == DIR_UP:
		return
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var pts: Array = [hx - spread, hx + spread] if dir == DIR_DOWN else [hx + ctx.fx * spread * 0.7]
	for ex in pts:
		ellipse(img, ex, hy, r, r * 1.2, pal.eye)
		_px(img, int(ex - r * 0.35), int(hy - r * 0.45), pal.white)
		if r >= 2.2:
			_px(img, int(ex - r * 0.35) + 1, int(hy - r * 0.45), pal.white)
		if int(ctx.stage) == 3:
			var bx: float = ex - r - 0.5
			var inward := 1.0 if ex < hx else -1.0
			if dir != DIR_DOWN:
				inward = ctx.fx
			line(img, Vector2(ex - r, hy - r * 1.6 - (inward * 0.8)), Vector2(ex + r, hy - r * 1.6 + (inward * 0.8)), pal.darker)
	if int(ctx.stage) == 1 and dir == DIR_DOWN:
		_px(img, int(hx - spread - r), int(hy + r + 1), pal.blush)
		_px(img, int(hx + spread + r), int(hy + r + 1), pal.blush)


static func _mouth(ctx: Dictionary, x: float, y: float) -> void:
	if ctx.dir == DIR_UP:
		return
	var img: Image = ctx.img
	var c: Color = ctx.pal.darker
	if ctx.attack:
		ellipse(img, x, y + 0.5, 1.6, 1.2, Color(0.35, 0.05, 0.1))
	elif ctx.dir == DIR_DOWN:
		_px(img, int(x - 1), int(y), c)
		_px(img, int(x), int(y + 1), c)
		_px(img, int(x + 1), int(y), c)
	else:
		_px(img, int(x), int(y), c)


static func _ears(ctx: Dictionary, hx: float, hy: float, hr: float) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var kind: String = _ft(ctx, "ears", "none")
	var xs: Array = [hx - hr * 0.6, hx + hr * 0.6]
	if ctx.side:
		xs = [hx - ctx.fx * hr * 0.25]
	for ex in xs:
		match kind:
			"pointy":
				tri(img, Vector2(ex - hr * 0.35, hy - hr * 0.55), Vector2(ex + hr * 0.35, hy - hr * 0.55), Vector2(ex, hy - hr * 1.45), pal.base)
				tri(img, Vector2(ex - hr * 0.16, hy - hr * 0.65), Vector2(ex + hr * 0.16, hy - hr * 0.65), Vector2(ex, hy - hr * 1.15), pal.blush)
			"round":
				ellipse(img, ex, hy - hr * 0.8, hr * 0.32, hr * 0.32, pal.base)
				ellipse(img, ex, hy - hr * 0.8, hr * 0.16, hr * 0.16, pal.dark)
			"long":
				ellipse(img, ex + (ex - hx) * 0.2, hy - hr * 1.2, hr * 0.22, hr * 0.7, pal.base)
				ellipse(img, ex + (ex - hx) * 0.2, hy - hr * 1.2, hr * 0.1, hr * 0.5, pal.blush)
			"tufts":
				tri(img, Vector2(ex - hr * 0.25, hy - hr * 0.6), Vector2(ex + hr * 0.2, hy - hr * 0.6), Vector2(ex + (ex - hx) * 0.5, hy - hr * 1.3), pal.dark)


static func _horns(ctx: Dictionary, hx: float, hy: float, hr: float) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var horn := Color(0.95, 0.9, 0.78)
	var st := int(ctx.stage)
	match _ft(ctx, "horns", ""):
		"one":
			var bx: float = hx + (ctx.fx * hr * 0.35 if ctx.side else 0.0)
			tri(img, Vector2(bx - 1.5, hy - hr * 0.8), Vector2(bx + 1.5, hy - hr * 0.8), Vector2(bx + (ctx.fx * 2.0 if ctx.side else 0.0), hy - hr * (1.5 + 0.25 * st)), pal.elem)
		"curl":
			for sx in ([-1.0, 1.0] if not ctx.side else [ctx.fx * -0.3]):
				var x: float = hx + sx * hr * 0.75
				ellipse(img, x, hy - hr * 0.55, hr * 0.32, hr * 0.32, horn.darkened(0.15))
				ellipse(img, x, hy - hr * 0.55, hr * 0.15, hr * 0.15, horn.darkened(0.4))
		"tusks":
			if ctx.dir != DIR_UP:
				var y: float = hy + hr * 0.45
				if ctx.side:
					tri(img, Vector2(hx + ctx.fx * hr * 0.7, y), Vector2(hx + ctx.fx * hr * 0.9, y), Vector2(hx + ctx.fx * hr * 1.0, y - 3 - st), horn)
				else:
					tri(img, Vector2(hx - hr * 0.5, y), Vector2(hx - hr * 0.3, y), Vector2(hx - hr * 0.55, y - 3 - st), horn)
					tri(img, Vector2(hx + hr * 0.3, y), Vector2(hx + hr * 0.5, y), Vector2(hx + hr * 0.55, y - 3 - st), horn)
	if _ft(ctx, "antlers"):
		var c := Color(0.55, 0.38, 0.2)
		for sx in [-1.0, 1.0]:
			var bx: float = hx + sx * hr * 0.45
			var top: float = hy - hr * (1.3 + 0.3 * st)
			line(img, Vector2(bx, hy - hr * 0.7), Vector2(bx + sx * 2, top), c)
			line(img, Vector2(bx + sx * 1, hy - hr * 1.0), Vector2(bx + sx * 4, hy - hr * 1.2), c)
			ellipse(img, bx + sx * 2, top, 1.8, 1.4, pal.elem)


static func _snout(ctx: Dictionary, hx: float, hy: float, hr: float) -> void:
	if ctx.dir == DIR_UP:
		return
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var mx: float = hx + (ctx.fx * hr * 0.7 if ctx.side else 0.0)
	var my: float = hy + hr * 0.35
	var big: bool = _ft(ctx, "snout")
	ellipse(img, mx, my, hr * (0.42 if big else 0.3), hr * (0.3 if big else 0.22), pal.belly)
	ellipse(img, mx + (ctx.fx * hr * 0.2 if ctx.side else 0.0), my - hr * 0.08, hr * 0.12, hr * 0.09, pal.darker)
	_mouth(ctx, mx, my + hr * 0.12)
	if _ft(ctx, "whiskers"):
		for sy in [-1.0, 1.0]:
			if ctx.side:
				line(img, Vector2(mx, my + sy), Vector2(mx + ctx.fx * hr * 0.8, my + sy * 2), pal.white)
			else:
				line(img, Vector2(mx - hr * 0.3, my + sy), Vector2(mx - hr * 0.95, my + sy * 2), pal.white)
				line(img, Vector2(mx + hr * 0.3, my + sy), Vector2(mx + hr * 0.95, my + sy * 2), pal.white)


## Acento do elemento no topo da cabeça.
static func _accent(ctx: Dictionary, x: float, y: float, k := 1.0) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var st := float(ctx.stage)
	var z := (2.0 + st) * k
	match ctx.type:
		"fogo":
			tri(img, Vector2(x - z, y), Vector2(x + z, y), Vector2(x + ctx.ph * 0.6, y - z * 2.2), pal.elem)
			tri(img, Vector2(x - z * 0.5, y), Vector2(x + z * 0.5, y), Vector2(x, y - z * 1.3), pal.elem2)
		"agua":
			ellipse(img, x, y - z * 0.6, z * 0.75, z * 0.75, pal.elem)
			tri(img, Vector2(x - z * 0.6, y - z * 0.8), Vector2(x + z * 0.6, y - z * 0.8), Vector2(x, y - z * 2.0), pal.elem)
			_px(img, int(x - 1), int(y - z * 0.9), pal.white)
		"gelo":
			for i in 3:
				var ox := (i - 1) * z * 0.8
				tri(img, Vector2(x + ox - z * 0.35, y), Vector2(x + ox + z * 0.35, y), Vector2(x + ox, y - z * (1.2 + (0.6 if i == 1 else 0.0))), pal.elem)
		"planta":
			tri(img, Vector2(x, y), Vector2(x - z * 1.4, y - z * 0.9), Vector2(x - z * 0.3, y - z * 1.4), pal.elem)
			tri(img, Vector2(x, y), Vector2(x + z * 1.4, y - z * 0.9), Vector2(x + z * 0.3, y - z * 1.4), pal.elem2)
			line(img, Vector2(x, y), Vector2(x, y - z * 0.6), pal.elem2)
		"terra":
			ellipse(img, x, y - z * 0.4, z * 0.9, z * 0.6, pal.elem)
			ellipse(img, x - z * 0.3, y - z * 0.6, z * 0.35, z * 0.25, pal.elem.lightened(0.3))
		"eletrico":
			var pts := [Vector2(x - z * 0.3, y), Vector2(x + z * 0.5, y - z * 0.8), Vector2(x - z * 0.2, y - z * 1.0), Vector2(x + z * 0.6, y - z * 2.0)]
			for i in 3:
				line(img, pts[i], pts[i + 1], pal.elem, 2)
		"vento":
			for i in 6:
				var a := i * 0.9
				_px(img, int(x + cos(a) * z * (0.4 + i * 0.12)), int(y - z * 0.9 + sin(a) * z * (0.4 + i * 0.12)), pal.elem)
			ellipse(img, x, y - z * 0.9, 1, 1, pal.elem)
		"luz":
			var ring = pal.elem
			for i in 14:
				var a := TAU * i / 14
				_px(img, int(x + cos(a) * z * 1.1), int(y - z * 1.4 + sin(a) * z * 0.35), ring)
		"sombra":
			tri(img, Vector2(x - z * 0.8, y), Vector2(x - z * 0.1, y), Vector2(x - z * 0.6 + ctx.ph, y - z * 1.6), pal.elem)
			tri(img, Vector2(x + z * 0.1, y), Vector2(x + z * 0.8, y), Vector2(x + z * 0.5 - ctx.ph, y - z * 1.9), pal.elem2)


## Ponta de cauda com o elemento (chama, gota, raio...).
static func _tail_tip(ctx: Dictionary, x: float, y: float) -> void:
	var t: String = ctx.type
	if t in ["fogo", "eletrico", "luz", "sombra", "agua", "gelo"]:
		_accent(ctx, x, y + 2, 0.55)


static func _tail(ctx: Dictionary, x: float, y: float, dirx: float) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var s: float = ctx.s
	var wag: float = ctx.ph * 1.5
	match _ft(ctx, "tail", "none"):
		"fluffy":
			ellipse(img, x + dirx * s * 0.18, y - s * 0.12 + wag * 0.3, s * 0.2, s * 0.13, pal.base)
			ellipse(img, x + dirx * s * 0.3, y - s * 0.2 + wag * 0.3, s * 0.1, s * 0.08, pal.belly)
			_tail_tip(ctx, x + dirx * s * 0.34, y - s * 0.24)
		"thin":
			line(img, Vector2(x, y), Vector2(x + dirx * s * 0.35, y - s * 0.18 + wag), pal.dark, 2)
			_tail_tip(ctx, x + dirx * s * 0.36, y - s * 0.2 + wag)
		"fin":
			tri(img, Vector2(x, y - 2), Vector2(x + dirx * s * 0.3, y - s * 0.18 + wag), Vector2(x + dirx * s * 0.3, y + s * 0.08 + wag), pal.dark)
		"curl":
			for i in 8:
				var a := i * 0.75
				ellipse(img, x + dirx * (s * 0.12 + cos(a) * s * 0.08), y - s * 0.12 + sin(a) * s * 0.08, 1.2, 1.2, pal.dark)
		"puff":
			ellipse(img, x + dirx * s * 0.08, y - s * 0.06, s * 0.1, s * 0.1, pal.white)
		"tuft":
			line(img, Vector2(x, y), Vector2(x + dirx * s * 0.3, y - s * 0.25 + wag), pal.dark, 2)
			ellipse(img, x + dirx * s * 0.32, y - s * 0.27 + wag, s * 0.07, s * 0.07, pal.elem)


## Cabeça completa (orelhas, chifres, juba, rosto, acento do elemento).
static func _head(ctx: Dictionary, hx: float, hy: float, hr: float) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	if _ft(ctx, "mane"):
		for i in 10:
			var a := TAU * i / 10
			ellipse(img, hx + cos(a) * hr * 0.95, hy + sin(a) * hr * 0.9, hr * 0.38, hr * 0.38, pal.elem if i % 2 == 0 else pal.elem.darkened(0.15))
	if _ft(ctx, "wool"):
		for i in 7:
			var a := PI + PI * i / 6
			ellipse(img, hx + cos(a) * hr * 0.8, hy - hr * 0.2 + sin(a) * hr * 0.7, hr * 0.33, hr * 0.33, Color(0.98, 0.96, 0.85))
	_ears(ctx, hx, hy, hr)
	ellipse(img, hx, hy, hr, hr * 0.92, pal.base)
	ellipse(img, hx - hr * 0.3, hy - hr * 0.35, hr * 0.32, hr * 0.2, pal.light)
	_horns(ctx, hx, hy, hr)
	var eye_y := hy - hr * 0.08
	var spread := hr * 0.42
	var er: float = maxf(1.5, hr * (0.24 if int(ctx.stage) == 1 else 0.2))
	if ctx.side:
		_eyes(ctx, hx + ctx.fx * hr * 0.2, eye_y, spread, er)
	else:
		_eyes(ctx, hx, eye_y, spread, er)
	if _ft(ctx, "glasses") and ctx.dir != DIR_UP:
		var gx: Array = [hx - spread, hx + spread] if ctx.dir == DIR_DOWN else [hx + ctx.fx * spread * 0.7]
		for x in gx:
			for i in 12:
				var a := TAU * i / 12
				_px(img, int(x + cos(a) * (er + 1.5)), int(eye_y + sin(a) * (er + 1.5)), Color(0.15, 0.12, 0.1))
	_snout(ctx, hx, hy, hr)
	if _ft(ctx, "beard") and ctx.dir != DIR_UP:
		tri(img, Vector2(hx - 2, hy + hr * 0.7), Vector2(hx + 2, hy + hr * 0.7), Vector2(hx + (ctx.fx * 1 if ctx.side else 0.0), hy + hr * 1.3), Color(0.92, 0.92, 0.95))
	if not _ft(ctx, "mane") and not _ft(ctx, "antlers") and _ft(ctx, "horns", "") != "one":
		_accent(ctx, hx + (ctx.fx * -hr * 0.1 if ctx.side else 0.0), hy - hr * 0.85)


# ================================================================== corpos (formatos)

static func _legs4(ctx: Dictionary, bx: float, by: float, bw: float, leg_h: float) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var ph: float = ctx.ph
	if ctx.side:
		for i in 4:
			var lx := bx + bw * (-0.75 + 0.5 * i)
			var lo := ph * (1.8 if i % 2 == 0 else -1.8)
			rect(img, lx - 1.5 + lo, by, 3, leg_h, pal.dark if i % 2 == 0 else pal.base)
	else:
		for sx in [-1.0, 1.0]:
			var lo = ph * sx
			rect(img, bx + sx * bw * 0.5 - 2, by, 4, leg_h + lo * 0.5, pal.dark)
			ellipse(img, bx + sx * bw * 0.5, by + leg_h + lo * 0.5, 2.2, 1.2, pal.darker)


static func _quadruped(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var s: float = ctx.s
	var cx: float = ctx.cx
	var by: float = ctx.by
	var low: bool = _ft(ctx, "low")
	var leg_h := s * (0.12 if low else 0.2)
	var big_head := 0.3 if int(ctx.stage) == 1 else (0.27 if int(ctx.stage) == 2 else 0.24)
	var hr := s * big_head
	if ctx.side:
		var fx: float = ctx.fx
		var bw := s * 0.4
		var bh := s * 0.22
		var bcy := by - leg_h - bh * 0.8
		_tail(ctx, cx - fx * bw * 0.9, bcy - bh * 0.2, -fx)
		_legs4(ctx, cx, bcy + bh * 0.5, bw, leg_h)
		ellipse(img, cx, bcy, bw, bh, pal.base)
		if _ft(ctx, "belly"):
			ellipse(img, cx + fx * 2, bcy + bh * 0.45, bw * 0.6, bh * 0.4, pal.belly)
		_body_decor(ctx, cx, bcy, bw, bh)
		_head(ctx, cx + fx * bw * 0.85, bcy - bh * 0.9, hr)
	else:
		var bw := s * 0.3
		var bh := s * 0.24
		var bcy := by - leg_h - bh * 0.7
		if ctx.dir == DIR_DOWN:
			_tail(ctx, cx + bw * 0.6, bcy, 1.0)
			_legs4(ctx, cx, bcy + bh * 0.5, bw, leg_h)
			ellipse(img, cx, bcy, bw, bh, pal.base)
			if _ft(ctx, "belly"):
				ellipse(img, cx, bcy + bh * 0.25, bw * 0.55, bh * 0.6, pal.belly)
			_body_decor(ctx, cx, bcy, bw, bh)
			_head(ctx, cx, bcy - bh - hr * 0.55, hr)
		else:
			_head(ctx, cx, bcy - bh - hr * 0.55, hr)
			_legs4(ctx, cx, bcy + bh * 0.5, bw, leg_h)
			ellipse(img, cx, bcy, bw, bh, pal.base)
			_body_decor(ctx, cx, bcy, bw, bh)
			_tail(ctx, cx, bcy + bh * 0.2, 0.3)


## Detalhes de corpo: casco, espinhos, manchas, lã.
static func _body_decor(ctx: Dictionary, x: float, y: float, w: float, h: float) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	if _ft(ctx, "shell"):
		ellipse(img, x, y - h * 0.25, w * 0.95, h * 0.85, pal.elem.darkened(0.2))
		for i in 3:
			line(img, Vector2(x - w * 0.6 + i * w * 0.6, y - h), Vector2(x - w * 0.6 + i * w * 0.6, y + h * 0.4), pal.elem.darkened(0.5))
		ellipse(img, x - w * 0.3, y - h * 0.6, w * 0.25, h * 0.2, pal.elem.lightened(0.3))
	if _ft(ctx, "spikes"):
		var n := 3 + int(ctx.stage)
		for i in n:
			var sx = x - w * 0.8 + i * (w * 1.6 / max(1, n - 1))
			tri(img, Vector2(sx - 2, y - h * 0.7), Vector2(sx + 2, y - h * 0.7), Vector2(sx, y - h * 0.7 - 3 - int(ctx.stage)), pal.elem)
	if _ft(ctx, "spots"):
		for i in 4:
			ellipse(img, x - w * 0.5 + i * w * 0.33, y - h * 0.2 + (i % 2) * h * 0.4, 1.3, 1.1, pal.darker)
	if _ft(ctx, "wool"):
		for i in 6:
			var a := TAU * i / 6
			ellipse(img, x + cos(a) * w * 0.6, y + sin(a) * h * 0.55, w * 0.38, h * 0.45, Color(0.98, 0.96, 0.85))
		_accent(ctx, x, y - h * 0.2, 0.6)
	if ctx.type == "eletrico" and not _ft(ctx, "wool"):
		line(img, Vector2(x - w * 0.3, y - h * 0.3), Vector2(x, y), pal.elem)
		line(img, Vector2(x, y), Vector2(x - w * 0.1, y + h * 0.1), pal.elem)


static func _bird(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var s: float = ctx.s
	var cx: float = ctx.cx
	var by: float = ctx.by
	var fx: float = ctx.fx
	var flap: float = ctx.ph * 3.0
	var penguin: bool = _ft(ctx, "penguin")
	var bat: bool = _ft(ctx, "bat")
	var owl: bool = _ft(ctx, "owl")
	var body_r := s * (0.3 if not penguin else 0.33)
	var bcy := by - s * (0.34 if not penguin else 0.36) - (1.0 if ctx.bob > 0 and not penguin else 0.0)
	# pés
	rect(img, cx - 3, by - s * 0.08, 2, s * 0.08, Color(1, 0.7, 0.2))
	rect(img, cx + 1, by - s * 0.08, 2, s * 0.08, Color(1, 0.7, 0.2))
	# cauda
	if _ft(ctx, "peacock") and ctx.dir != DIR_UP:
		for i in 7:
			var a := PI + PI * (i + 0.5) / 7
			var ex := cx + cos(a) * s * 0.55
			var ey := bcy - s * 0.1 + sin(a) * s * 0.5
			ellipse(img, ex, ey, s * 0.09, s * 0.12, pal.elem)
			ellipse(img, ex, ey, s * 0.04, s * 0.05, pal.accent)
	elif _ft(ctx, "tail_feathers") or _ft(ctx, "swallow"):
		var tx := cx - (fx * body_r if ctx.side else 0.0)
		tri(img, Vector2(tx - 3, bcy + body_r * 0.4), Vector2(tx + 3, bcy + body_r * 0.4), Vector2(tx - (fx * s * 0.3 if ctx.side else 0.0) - 3, bcy + body_r + s * 0.12), pal.dark)
		if _ft(ctx, "swallow"):
			tri(img, Vector2(tx - 2, bcy + body_r * 0.4), Vector2(tx + 3, bcy + body_r * 0.4), Vector2(tx - (fx * s * 0.3 if ctx.side else 0.0) + 4, bcy + body_r + s * 0.15), pal.darker)
	# asas
	var wing := s * (0.38 if not penguin else 0.15)
	var wc: Color = pal.dark if not bat else pal.darker
	if bat:
		for sx in [-1.0, 1.0]:
			var wx: float = cx + sx * body_r * 0.8
			tri(img, Vector2(wx, bcy - body_r * 0.5), Vector2(wx, bcy + body_r * 0.4), Vector2(wx + sx * s * 0.55, bcy - s * 0.2 - flap * sx), wc)
			tri(img, Vector2(wx, bcy + body_r * 0.4), Vector2(wx + sx * s * 0.55, bcy - s * 0.2 - flap * sx), Vector2(wx + sx * s * 0.4, bcy + s * 0.15), wc)
	elif not ctx.side or penguin:
		for sx in [-1.0, 1.0]:
			tri(img, Vector2(cx + sx * body_r * 0.7, bcy - body_r * 0.3), Vector2(cx + sx * body_r * 0.7, bcy + body_r * 0.5),
				Vector2(cx + sx * (body_r + wing), bcy + (body_r * 0.3 if penguin else -wing * 0.3) - flap * sx), wc)
	# corpo
	ellipse(img, cx, bcy, body_r, body_r * (1.1 if penguin else 1.0), pal.base)
	if penguin or owl or ctx.dir == DIR_DOWN:
		ellipse(img, cx + (fx * body_r * 0.2 if ctx.side else 0.0), bcy + body_r * 0.2, body_r * 0.62, body_r * 0.7, pal.white if penguin else pal.belly)
	if ctx.side and not penguin and not bat:
		ellipse(img, cx - fx * body_r * 0.2, bcy, body_r * 0.6, body_r * 0.45, pal.dark)
		tri(img, Vector2(cx - fx * body_r * 0.6, bcy - 2), Vector2(cx + fx * body_r * 0.3, bcy - 3), Vector2(cx - fx * (body_r + wing * 0.6), bcy - wing * 0.5 - flap), pal.darker)
	# cabeça
	var hr := body_r * (0.75 if not owl else 0.95)
	var hx := cx + (fx * body_r * 0.35 if ctx.side else 0.0)
	var hy := bcy - body_r * (0.9 if not owl else 0.75)
	if bat:
		for sx in ([-1.0, 1.0] if not ctx.side else [-fx]):
			tri(img, Vector2(hx + sx * hr * 0.2, hy - hr * 0.5), Vector2(hx + sx * hr * 0.9, hy - hr * 0.3), Vector2(hx + sx * hr * 0.8, hy - hr * 1.5), pal.base)
	if owl:
		for sx in [-1.0, 1.0]:
			tri(img, Vector2(hx + sx * hr * 0.3, hy - hr * 0.6), Vector2(hx + sx * hr * 0.9, hy - hr * 0.5), Vector2(hx + sx * hr * 0.85, hy - hr * 1.3), pal.dark)
	ellipse(img, hx, hy, hr, hr * 0.92, pal.base if not penguin else pal.darker)
	if penguin and ctx.dir != DIR_UP:
		ellipse(img, hx, hy + hr * 0.15, hr * 0.7, hr * 0.6, pal.white)
	if owl and ctx.dir != DIR_UP:
		ellipse(img, hx - hr * 0.42, hy, hr * 0.42, hr * 0.42, pal.belly)
		ellipse(img, hx + hr * 0.42, hy, hr * 0.42, hr * 0.42, pal.belly)
	if _ft(ctx, "crest"):
		for i in 3:
			tri(img, Vector2(hx - 2 + i * 1.5, hy - hr * 0.8), Vector2(hx + i * 1.5, hy - hr * 0.8), Vector2(hx - 3 + i * 2.5 - fx * 2, hy - hr * (1.6 + 0.2 * i)), pal.elem if i == 1 else pal.accent)
	var er: float = maxf(1.5, hr * (0.3 if owl else 0.25))
	_eyes(ctx, hx + (fx * hr * 0.15 if ctx.side else 0.0), hy - hr * 0.05, hr * 0.42, er)
	# bico / presas
	if ctx.dir != DIR_UP:
		var bxp := hx + (fx * hr * 0.95 if ctx.side else 0.0)
		var byp := hy + hr * 0.3
		if bat:
			_px(img, int(bxp - 1), int(byp + 1), pal.white)
			_px(img, int(bxp + 1), int(byp + 1), pal.white)
		elif _ft(ctx, "hummingbird"):
			line(img, Vector2(bxp, byp), Vector2(bxp + (fx * s * 0.35 if ctx.side else 0.0), byp + (0.0 if ctx.side else s * 0.25)), Color(0.25, 0.2, 0.15), 1)
		else:
			var beak := Color(1, 0.72, 0.2)
			if ctx.side:
				tri(img, Vector2(bxp, byp - 2), Vector2(bxp, byp + 1), Vector2(bxp + fx * 4, byp), beak)
			else:
				tri(img, Vector2(bxp - 2, byp - 1), Vector2(bxp + 2, byp - 1), Vector2(bxp, byp + 3), beak)
	if not _ft(ctx, "crest") and not owl:
		_accent(ctx, hx, hy - hr * 0.85)
	elif owl and ctx.type != "gelo":
		_accent(ctx, hx, hy - hr * 0.9, 0.7)
	elif owl:
		_accent(ctx, hx, hy - hr * 0.9, 0.6)


static func _serpent(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var s: float = ctx.s
	var cx: float = ctx.cx
	var by: float = ctx.by
	var fx: float = ctx.fx
	var segs := 6 + int(ctx.stage)
	var cloud: bool = _ft(ctx, "cloud")
	for i in range(segs - 1, -1, -1):
		var t := float(i) / segs
		var wave := sin(t * 6.0 + ctx.ph * 1.2) * s * 0.12
		var sx := cx + (fx * (s * 0.42 - t * s * 0.85) if ctx.side else wave)
		var sy := by - s * 0.14 - (wave * 0.4 if ctx.side else 0.0) - (t * s * 0.22 if not ctx.side else 0.0)
		var r := s * (0.12 + 0.05 * (1.0 - t))
		if cloud:
			ellipse(img, sx, sy - r * 0.3, r * 1.3, r * 1.0, Color(0.97, 0.98, 1.0))
		ellipse(img, sx, sy, r, r * 0.85, pal.base if i % 2 == 0 else pal.dark)
		if _ft(ctx, "fin_back") and i % 2 == 1:
			tri(img, Vector2(sx - r * 0.6, sy - r * 0.7), Vector2(sx + r * 0.6, sy - r * 0.7), Vector2(sx, sy - r * 1.7), pal.elem)
	var hx := cx + (fx * s * 0.44 if ctx.side else 0.0)
	var hy := by - s * (0.36 if ctx.side else 0.44)
	var hr := s * 0.19
	ellipse(img, hx, hy, hr * 1.05, hr * 0.9, pal.base)
	ellipse(img, hx - hr * 0.3, hy - hr * 0.35, hr * 0.35, hr * 0.2, pal.light)
	if cloud or ctx.stage >= 3:
		for sx in [-1.0, 1.0]:
			line(img, Vector2(hx + sx * hr * 0.5, hy - hr * 0.6), Vector2(hx + sx * hr * 1.2, hy - hr * 1.5), Color(0.95, 0.9, 0.75), 1)
	_eyes(ctx, hx + (fx * hr * 0.2 if ctx.side else 0.0), hy - 1, hr * 0.45, maxf(1.4, hr * 0.26))
	_mouth(ctx, hx + (fx * hr * 0.7 if ctx.side else 0.0), hy + hr * 0.45)
	_accent(ctx, hx, hy - hr * 0.8)


static func _fish(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var s: float = ctx.s
	var cx: float = ctx.cx
	var by: float = ctx.by
	var fx: float = ctx.fx
	var seal: bool = _ft(ctx, "seal")
	var cy := by - s * 0.32 - (1.0 if ctx.bob > 0 else 0.0)
	if seal:
		cy = by - s * 0.25
	if ctx.side:
		tri(img, Vector2(cx - fx * s * 0.28, cy), Vector2(cx - fx * s * 0.55, cy - s * 0.2 + ctx.ph), Vector2(cx - fx * s * 0.55, cy + s * 0.18 + ctx.ph), pal.dark)
		ellipse(img, cx, cy, s * 0.38, s * (0.22 if not seal else 0.25), pal.base)
		ellipse(img, cx + fx * 2, cy + s * 0.1, s * 0.26, s * 0.09, pal.belly)
		if _ft(ctx, "fin_back"):
			tri(img, Vector2(cx - s * 0.1, cy - s * 0.18), Vector2(cx + s * 0.1, cy - s * 0.18), Vector2(cx - fx * s * 0.06, cy - s * 0.45), pal.dark)
		if seal:
			ellipse(img, cx + fx * s * 0.05, cy + s * 0.2, s * 0.12, s * 0.06, pal.dark)
		var hx := cx + fx * s * 0.22
		_eyes(ctx, hx, cy - s * 0.04, s * 0.06, maxf(1.5, s * 0.06))
		if _ft(ctx, "teeth"):
			for i in 3:
				_px(img, int(hx + fx * (s * 0.1 + i)), int(cy + s * 0.08), pal.white)
		if _ft(ctx, "whiskers"):
			line(img, Vector2(hx + fx * s * 0.12, cy + 1), Vector2(hx + fx * s * 0.3, cy + 3), pal.white)
		if _ft(ctx, "lure"):
			line(img, Vector2(hx, cy - s * 0.2), Vector2(hx + fx * s * 0.25, cy - s * 0.42), pal.darker)
			ellipse(img, hx + fx * s * 0.27, cy - s * 0.44, 2.5, 2.5, pal.elem)
		else:
			_accent(ctx, cx, cy - s * 0.22, 0.8)
	else:
		tri(img, Vector2(cx, cy + s * 0.12), Vector2(cx - s * 0.2 + ctx.ph, cy + s * 0.4), Vector2(cx + s * 0.2 + ctx.ph, cy + s * 0.4), pal.dark)
		if seal:
			for sx in [-1.0, 1.0]:
				ellipse(img, cx + sx * s * 0.3, cy + s * 0.15, s * 0.1, s * 0.06, pal.dark)
		ellipse(img, cx, cy, s * 0.28, s * 0.3, pal.base)
		if ctx.dir == DIR_DOWN:
			ellipse(img, cx, cy + s * 0.08, s * 0.17, s * 0.15, pal.belly)
		if _ft(ctx, "fin_back"):
			tri(img, Vector2(cx - 2, cy - s * 0.25), Vector2(cx + 2, cy - s * 0.25), Vector2(cx, cy - s * 0.5), pal.dark)
		_eyes(ctx, cx, cy - s * 0.06, s * 0.12, maxf(1.5, s * 0.065))
		if ctx.dir == DIR_DOWN:
			if _ft(ctx, "teeth"):
				for i in 4:
					_px(img, int(cx - 3 + i * 2), int(cy + s * 0.12), pal.white)
			else:
				_mouth(ctx, cx, cy + s * 0.1)
			if _ft(ctx, "whiskers"):
				line(img, Vector2(cx - 3, cy + s * 0.08), Vector2(cx - s * 0.3, cy + s * 0.12), pal.white)
				line(img, Vector2(cx + 3, cy + s * 0.08), Vector2(cx + s * 0.3, cy + s * 0.12), pal.white)
		if _ft(ctx, "lure"):
			line(img, Vector2(cx, cy - s * 0.28), Vector2(cx + 2, cy - s * 0.48), pal.darker)
			ellipse(img, cx + 2, cy - s * 0.5, 2.5, 2.5, pal.elem)
		else:
			_accent(ctx, cx, cy - s * 0.27, 0.8)


static func _insect(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var s: float = ctx.s
	var cx: float = ctx.cx
	var by: float = ctx.by
	var fx: float = ctx.fx
	var st := int(ctx.stage)
	var cy := by - s * 0.26
	var flap: float = ctx.ph * 2.0
	if _ft(ctx, "larva") and st < 3:
		# lagarta: segmentos em fila
		var n := 4 + st
		for i in range(n - 1, -1, -1):
			var t := float(i) / n
			var x := cx + (fx * (s * 0.35 - t * s * 0.7) if ctx.side else 0.0)
			var y := by - s * 0.12 - (0.0 if ctx.side else t * s * 0.3) + sin(i + ctx.ph) * 1.0
			ellipse(img, x, y, s * 0.13, s * 0.12, pal.base if i % 2 == 0 else pal.light)
			_px(img, int(x), int(y + s * 0.12), pal.darker)
		var hx := cx + (fx * s * 0.38 if ctx.side else 0.0)
		var hy := by - s * (0.2 if ctx.side else 0.45)
		ellipse(img, hx, hy, s * 0.16, s * 0.15, pal.base)
		_eyes(ctx, hx + (fx * 1.0 if ctx.side else 0.0), hy - 1, s * 0.07, maxf(1.4, s * 0.06))
		_accent(ctx, hx, hy - s * 0.12, 0.7)
		return
	if _ft(ctx, "spider"):
		for i in 4:
			for sx in [-1.0, 1.0]:
				var a := -0.6 + i * 0.4
				var lo = ctx.ph * (1.0 if i % 2 == 0 else -1.0)
				var p1 := Vector2(cx + sx * s * 0.12, cy - 1 + i)
				var p2 := Vector2(cx + sx * s * 0.38, cy - s * 0.12 + a * s * 0.25 + lo)
				var p3 := Vector2(cx + sx * s * 0.48, by - 2 + lo * 0.5)
				line(img, p1, p2, pal.darker)
				line(img, p2, p3, pal.darker)
		ellipse(img, cx - fx * (s * 0.12 if ctx.side else 0.0), cy + (s * 0.08 if ctx.dir == DIR_UP else -s * 0.02), s * 0.25, s * 0.22, pal.base)
		ellipse(img, cx, cy - s * 0.1, s * 0.08, s * 0.05, pal.elem)
		var hx := cx + (fx * s * 0.2 if ctx.side else 0.0)
		var hy := cy + (s * 0.12 if ctx.dir == DIR_DOWN else 0.0)
		ellipse(img, hx, hy, s * 0.13, s * 0.11, pal.dark)
		if ctx.dir != DIR_UP:
			for i in 4:
				_px(img, int(hx - 3 + i * 2), int(hy - 1 + (i % 2)), pal.eye)
		return
	if _ft(ctx, "scorpion"):
		# cauda curvada com ferrão
		var tx := cx - (fx * s * 0.2 if ctx.side else 0.0)
		for i in 5:
			var a := PI * 0.5 + i * 0.45
			var px := tx - (fx * cos(a) * s * 0.18 if ctx.side else 0.0) + (0.0 if ctx.side else sin(i) * 1.0)
			var py := cy - s * 0.1 - i * s * 0.08
			ellipse(img, px, py, s * 0.07, s * 0.06, pal.base if i % 2 == 0 else pal.dark)
		tri(img, Vector2(tx - 2, cy - s * 0.48), Vector2(tx + 2, cy - s * 0.48), Vector2(tx + fx * 3, cy - s * 0.58), pal.elem)
		for i in 3:
			for sx in [-1.0, 1.0]:
				line(img, Vector2(cx + sx * s * 0.1, cy + i * 2 - 2), Vector2(cx + sx * s * 0.32, cy + i * 2 + 2 + ctx.ph * sx), pal.darker)
		ellipse(img, cx, cy, s * 0.22, s * 0.15, pal.base)
		for sx in [-1.0, 1.0]:
			var clx = cx + (fx * s * 0.3 if ctx.side else sx * s * 0.28)
			var cly := cy + (0.0 if ctx.side else s * 0.12)
			ellipse(img, clx, cly, s * 0.08, s * 0.06, pal.dark)
			if ctx.side:
				break
		_eyes(ctx, cx + (fx * s * 0.12 if ctx.side else 0.0), cy - 1, s * 0.06, maxf(1.3, s * 0.05))
		return
	# asas atrás do corpo
	var wings: String = _ft(ctx, "wings", "")
	if wings != "":
		for sx in [-1.0, 1.0]:
			match wings:
				"butterfly":
					var wc: Color = pal.elem
					ellipse(img, cx + sx * s * 0.25, cy - s * 0.18 - flap, s * 0.22, s * 0.2, wc)
					ellipse(img, cx + sx * s * 0.2, cy + s * 0.06, s * 0.14, s * 0.12, wc.darkened(0.15))
					ellipse(img, cx + sx * s * 0.27, cy - s * 0.2 - flap, s * 0.07, s * 0.06, pal.accent)
				"dragonfly":
					var wc2 := Color(0.85, 0.95, 1.0, 0.75)
					ellipse(img, cx + sx * s * 0.32, cy - s * 0.12 - flap, s * 0.3, s * 0.07, wc2)
					ellipse(img, cx + sx * s * 0.28, cy + s * 0.02 + flap, s * 0.26, s * 0.06, wc2)
				"bee":
					var wc3 := Color(0.9, 0.97, 1.0, 0.7)
					ellipse(img, cx + sx * s * 0.17, cy - s * 0.2 - flap, s * 0.13, s * 0.09, wc3)
	# corpo segmentado
	var ab_x := cx - (fx * s * 0.16 if ctx.side else 0.0)
	var ab_y := cy + (s * 0.05 if ctx.dir != DIR_UP else -s * 0.04)
	var ab_c: Color = pal.base
	if _ft(ctx, "firefly"):
		ab_c = pal.elem
	ellipse(img, ab_x, ab_y + (s * 0.08 if not ctx.side else 0.0), s * 0.17, s * 0.15, ab_c)
	if _ft(ctx, "bee"):
		for i in 2:
			rect(img, ab_x - s * 0.15, ab_y + i * 4 - 1, s * 0.3, 2, pal.darker)
	if _ft(ctx, "firefly"):
		ellipse(img, ab_x, ab_y + s * 0.06, s * 0.1, s * 0.08, Color(1, 1, 0.85))
	if wings == "dragonfly":
		for i in 4:
			ellipse(img, cx - (fx * (s * 0.18 + i * 3) if ctx.side else 0.0), cy + (0.0 if ctx.side else s * 0.12 + i * 3), 1.8, 1.8, pal.dark)
	for i in 3:
		for sx in [-1.0, 1.0]:
			line(img, Vector2(cx + sx * s * 0.08, cy + i * 2), Vector2(cx + sx * s * 0.25, cy + i * 2 + s * 0.12 + ctx.ph * sx), pal.darker)
	ellipse(img, cx, cy - s * 0.04, s * 0.13, s * 0.12, pal.dark)
	var hx := cx + (fx * s * 0.2 if ctx.side else 0.0)
	var hy := cy - (s * 0.2 if ctx.dir == DIR_DOWN else s * 0.14)
	ellipse(img, hx, hy, s * 0.15, s * 0.14, pal.base)
	if _ft(ctx, "antennae"):
		for sx in [-1.0, 1.0]:
			line(img, Vector2(hx + sx * 2, hy - s * 0.1), Vector2(hx + sx * s * 0.18, hy - s * 0.32), pal.darker)
			ellipse(img, hx + sx * s * 0.18, hy - s * 0.33, 1.3, 1.3, pal.elem)
	_eyes(ctx, hx + (fx * 1.0 if ctx.side else 0.0), hy, s * 0.07, maxf(1.4, s * 0.06))
	if not _ft(ctx, "antennae"):
		_accent(ctx, hx, hy - s * 0.12, 0.7)


static func _biped(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var s: float = ctx.s
	var cx: float = ctx.cx
	var by: float = ctx.by
	var fx: float = ctx.fx
	var ph: float = ctx.ph
	var ape: bool = _ft(ctx, "ape")
	var hip := by - s * 0.24
	if _ft(ctx, "tail", "") != "":
		_tail(ctx, cx - (fx * s * 0.15 if ctx.side else -s * 0.1), hip, -fx if ctx.side else 1.0)
	rect(img, cx - s * 0.17 + ph, hip, s * 0.13, s * 0.24, pal.dark)
	rect(img, cx + s * 0.04 - ph, hip, s * 0.13, s * 0.24, pal.dark)
	var tw := s * (0.28 if ape else 0.23)
	ellipse(img, cx, hip - s * 0.1, tw, s * 0.22, pal.base)
	if ctx.dir == DIR_DOWN:
		ellipse(img, cx, hip - s * 0.06, tw * 0.6, s * 0.15, pal.belly)
	var arm_w := s * (0.13 if ape else 0.09)
	var arm_h := s * (0.32 if ape else 0.22)
	rect(img, cx - tw - arm_w * 0.6, hip - s * 0.25 - ph, arm_w, arm_h, pal.dark)
	rect(img, cx + tw - arm_w * 0.4, hip - s * 0.25 + ph, arm_w, arm_h, pal.dark)
	if ape:
		ellipse(img, cx - tw - arm_w * 0.1, hip - s * 0.25 - ph + arm_h, arm_w * 0.7, arm_w * 0.6, pal.darker)
		ellipse(img, cx + tw + arm_w * 0.1, hip - s * 0.25 + ph + arm_h, arm_w * 0.7, arm_w * 0.6, pal.darker)
	var hr := s * (0.24 if int(ctx.stage) == 1 else 0.21)
	var hx := cx + (fx * s * 0.04 if ctx.side else 0.0)
	var hy := hip - s * 0.36 - hr * 0.6
	if _ft(ctx, "gills"):
		for sx in [-1.0, 1.0]:
			for i in 3:
				line(img, Vector2(hx + sx * hr * 0.7, hy - hr * 0.2 + i * 2), Vector2(hx + sx * hr * 1.4, hy - hr * 0.6 + i * 3), pal.blush, 2)
	if _ft(ctx, "chameleon"):
		tri(img, Vector2(hx - hr * 0.6, hy - hr * 0.5), Vector2(hx + hr * 0.6, hy - hr * 0.5), Vector2(hx - (fx * hr * 0.4 if ctx.side else 0.0), hy - hr * 1.4), pal.elem)
	_head(ctx, hx, hy, hr)


static func _golem(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var s: float = ctx.s
	var cx: float = ctx.cx
	var by: float = ctx.by
	var fx: float = ctx.fx
	var ph: float = ctx.ph
	var shell: bool = _ft(ctx, "shell")
	var w := s * 0.6
	var hip := by - s * 0.18
	rect(img, cx - w * 0.4 + ph, hip, w * 0.28, s * 0.18, pal.dark)
	rect(img, cx + w * 0.12 - ph, hip, w * 0.28, s * 0.18, pal.dark)
	if shell:
		ellipse(img, cx - (fx * s * 0.06 if ctx.side else 0.0), hip - s * 0.18, w * 0.62, s * 0.26, pal.base)
		ellipse(img, cx - (fx * s * 0.06 if ctx.side else 0.0), hip - s * 0.24, w * 0.56, s * 0.22, pal.elem.darkened(0.25))
		for i in 3:
			ellipse(img, cx - w * 0.3 + i * w * 0.3, hip - s * 0.26, s * 0.06, s * 0.05, pal.elem.lightened(0.2))
		var hx := cx + (fx * w * 0.6 if ctx.side else 0.0)
		var hy := hip - (s * 0.2 if ctx.side else s * 0.42)
		if ctx.dir == DIR_DOWN:
			hy = hip - s * 0.12
		var hr := s * 0.2
		if ctx.dir == DIR_UP:
			hy = hip - s * 0.44
		_head(ctx, hx, hy, hr)
		if ctx.dir == DIR_UP:
			ellipse(img, cx, hip - s * 0.24, w * 0.56, s * 0.22, pal.elem.darkened(0.25))
		return
	ellipse(img, cx, hip - s * 0.22, w * 0.55, s * 0.3, pal.base)
	if ctx.dir == DIR_DOWN:
		ellipse(img, cx, hip - s * 0.16, w * 0.32, s * 0.2, pal.belly)
	rect(img, cx - w * 0.55 - s * 0.1, hip - s * 0.32 - ph, s * 0.14, s * 0.3, pal.dark)
	rect(img, cx + w * 0.55 - s * 0.04, hip - s * 0.32 + ph, s * 0.14, s * 0.3, pal.dark)
	var hr2 := s * 0.24
	_head(ctx, cx + (fx * s * 0.05 if ctx.side else 0.0), hip - s * 0.52 - hr2 * 0.5, hr2)


static func _blob(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var s: float = ctx.s
	var cx: float = ctx.cx
	var by: float = ctx.by
	var fx: float = ctx.fx
	var sq := 1.0 + (0.08 if ctx.bob > 0 else 0.0)
	if _ft(ctx, "octopus"):
		var n := 6
		for i in n:
			var t := float(i) / (n - 1)
			var x := cx - s * 0.36 + t * s * 0.72
			for k in 4:
				var yy := by - s * 0.22 + k * s * 0.06
				var xx := x + sin(k * 1.2 + i + ctx.ph * 1.5) * 1.5
				ellipse(img, xx, yy, s * 0.06, s * 0.05, pal.base if k < 3 else pal.light)
		ellipse(img, cx, by - s * 0.48, s * 0.36, s * 0.32, pal.base)
		ellipse(img, cx - s * 0.12, by - s * 0.6, s * 0.12, s * 0.07, pal.light)
		_eyes(ctx, cx + (fx * s * 0.08 if ctx.side else 0.0), by - s * 0.42, s * 0.13, maxf(1.6, s * 0.07))
		_mouth(ctx, cx + (fx * s * 0.12 if ctx.side else 0.0), by - s * 0.32)
		_accent(ctx, cx, by - s * 0.78)
		return
	if _ft(ctx, "frog"):
		for sx in [-1.0, 1.0]:
			ellipse(img, cx + sx * s * 0.34, by - s * 0.06, s * 0.13, s * 0.07, pal.dark)
		ellipse(img, cx, by - s * 0.26 / sq, s * 0.42 * sq, s * 0.26 / sq, pal.base)
		if _ft(ctx, "belly") and ctx.dir == DIR_DOWN:
			ellipse(img, cx, by - s * 0.18, s * 0.26, s * 0.13, pal.belly)
		var ey := by - s * 0.48
		var xs: Array = [cx - s * 0.2, cx + s * 0.2] if not ctx.side else [cx + fx * s * 0.12]
		for ex in xs:
			ellipse(img, ex, ey, s * 0.13, s * 0.13, pal.base)
		if ctx.dir != DIR_UP:
			_eyes(ctx, cx + (fx * s * 0.05 if ctx.side else 0.0), ey, s * 0.2 if not ctx.side else s * 0.1, maxf(1.6, s * 0.075))
			if ctx.dir == DIR_DOWN:
				line(img, Vector2(cx - s * 0.18, by - s * 0.26), Vector2(cx, by - s * 0.22), pal.darker)
				line(img, Vector2(cx, by - s * 0.22), Vector2(cx + s * 0.18, by - s * 0.26), pal.darker)
		_accent(ctx, cx, ey - s * 0.1, 0.8)
		return
	ellipse(img, cx, by - s * 0.36 / sq, s * 0.5 * sq, s * 0.38 / sq, pal.base)
	ellipse(img, cx - s * 0.15, by - s * 0.5, s * 0.16, s * 0.1, pal.light)
	_eyes(ctx, cx, by - s * 0.42, s * 0.16, maxf(1.5, s * 0.08))
	_mouth(ctx, cx, by - s * 0.28)
	_accent(ctx, cx, by - s * 0.7)


static func _spirit(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var pal: Dictionary = ctx.pal
	var s: float = ctx.s
	var cx: float = ctx.cx
	var by: float = ctx.by
	var cy := by - s * 0.55 - (1.5 if ctx.bob > 0 else 0.0)
	var col: Color = pal.base
	col.a = 0.9
	if _ft(ctx, "jelly"):
		for i in 5:
			var tx := cx - s * 0.24 + i * s * 0.12
			for k in 5:
				var yy := cy + s * 0.08 + k * s * 0.07
				_px(img, int(tx + sin(k * 1.3 + i + ctx.ph * 1.5) * 1.5), int(yy), pal.elem if k % 2 == 0 else col)
				_px(img, int(tx + sin(k * 1.3 + i + ctx.ph * 1.5) * 1.5) + 1, int(yy), pal.elem if k % 2 == 0 else col)
		ellipse(img, cx, cy, s * 0.34, s * 0.24, col)
		rect(img, cx - s * 0.34, cy, s * 0.68, s * 0.06, col)
		ellipse(img, cx - s * 0.12, cy - s * 0.1, s * 0.12, s * 0.07, Color(1, 1, 1, 0.7))
		for i in 3:
			ellipse(img, cx - s * 0.15 + i * s * 0.15, cy + s * 0.02, 1.2, 1.2, pal.elem)
		_eyes(ctx, cx, cy - s * 0.02, s * 0.12, maxf(1.5, s * 0.06))
		return
	ellipse(img, cx, cy + s * 0.05, s * 0.32, s * 0.3, col)
	for i in 4:
		var tx := cx - s * 0.24 + i * s * 0.16
		tri(img, Vector2(tx - s * 0.08, cy + s * 0.2), Vector2(tx + s * 0.08, cy + s * 0.2), Vector2(tx + ctx.ph * 1.5, cy + s * 0.45 + (i % 2) * 2), col)
	_eyes(ctx, cx, cy, s * 0.12, maxf(1.5, s * 0.07))
	_accent(ctx, cx, cy - s * 0.28)


static func _draw_dead(img: Image, pal: Dictionary, s: float, cx: float, by: float, stage: int) -> void:
	var gray: Color = pal.base.lerp(Color(0.45, 0.42, 0.4), 0.35 * stage)
	var dark: Color = pal.dark.lerp(Color(0.3, 0.28, 0.26), 0.35 * stage)
	match stage:
		1:
			ellipse(img, cx, by - s * 0.3, s * 0.42, s * 0.28, gray)
			line(img, Vector2(cx - 4, by - s * 0.35 - 2), Vector2(cx - 1, by - s * 0.35 + 1), Color.BLACK)
			line(img, Vector2(cx - 1, by - s * 0.35 - 2), Vector2(cx - 4, by - s * 0.35 + 1), Color.BLACK)
			line(img, Vector2(cx + 2, by - s * 0.35 - 2), Vector2(cx + 5, by - s * 0.35 + 1), Color.BLACK)
			line(img, Vector2(cx + 5, by - s * 0.35 - 2), Vector2(cx + 2, by - s * 0.35 + 1), Color.BLACK)
		2:
			ellipse(img, cx, by - s * 0.18, s * 0.5, s * 0.19, gray)
			ellipse(img, cx + s * 0.22, by - s * 0.22, s * 0.16, s * 0.12, dark)
		_:
			ellipse(img, cx, by - s * 0.1, s * 0.55, s * 0.14, Color(0.5, 0.05, 0.05, 0.6))
			ellipse(img, cx, by - s * 0.14, s * 0.45, s * 0.14, gray)
			ellipse(img, cx - s * 0.18, by - s * 0.16, s * 0.12, s * 0.07, dark)
