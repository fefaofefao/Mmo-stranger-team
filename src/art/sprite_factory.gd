class_name SpriteFactory
extends RefCounted
## Spritesheets dos monstros.
##
## PADRÃO DO SPRITESHEET (vale para arte gerada e arte substituta):
##   10 colunas x 4 linhas de quadros do mesmo tamanho (qualquer tamanho, ex.: 32, 48 ou 64 px).
##   Linhas (direção):  0 = baixo, 1 = esquerda, 2 = direita, 3 = cima
##   Colunas (animação): 0-1 parado | 2-4 andar (3 quadros) | 5-6 ataque | 7-9 morte (9 = corpo no chão)
## Para trocar a arte, salve um PNG em res://assets/sprites/monsters/<form_id>.png
## (opcional: <form_id>_shiny.png). Se não existir, o placeholder é gerado por código.

const COLS := 10
const ROWS := 4
const FRAME := 48
const DIR_DOWN := 0
const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 3
const ART_DIR := "res://assets/sprites/monsters/"

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
		var sh := sheet(form_id, shiny)
		var img := sh.get_image()
		var fw := img.get_width() / COLS
		var fh := img.get_height() / ROWS
		fr = img.get_region(Rect2i(0, 0, fw, fh))
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
		s = clampf(s + 0.25, 0.3, 1.0)
		v = clampf(v + 0.1, 0.5, 1.0)
	# tipos muito claros (luz/vento) ganham um pouco de saturação para ter contraste
	s = maxf(s, 0.25)
	v = clampf(v, 0.45, 0.95)
	var col := Color.from_hsv(h, s, v)
	return {
		"base": col,
		"dark": col.darkened(0.35),
		"light": col.lightened(0.35),
		"outline": col.darkened(0.75),
		"accent": Color.from_hsv(fposmod(h + 0.08, 1.0), clampf(s * 0.8, 0, 1), clampf(v * 0.75, 0, 1)),
		"eye": Color(1, 1, 1),
		"pupil": Color(0.08, 0.06, 0.1),
		"shiny": shiny,
	}


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
	var size = [17.0, 25.0, 35.0][clampi(stage - 1, 0, 2)]
	var p := {"bob": 0.0, "phase": 0, "lunge": 0.0, "squash": 1.0, "dead": 0, "stage": stage}
	if col <= 1:
		p.bob = float(col)
	elif col <= 4:
		p.phase = [-1, 0, 1][col - 2]
		p.bob = 0.0 if col == 3 else 1.0
	elif col <= 6:
		p.lunge = 2.0 if col == 5 else 4.0
	else:
		p.dead = col - 6
	var shape: String = f.get("shape", "blob")
	var cx := FRAME / 2.0
	var by := FRAME - 4.0
	if p.dead > 0:
		_draw_dead(img, shape, pal, size, cx, by, p.dead)
	else:
		var lx := 0.0
		var ly := 0.0
		match dir:
			DIR_DOWN: ly = p.lunge
			DIR_UP: ly = -p.lunge
			DIR_LEFT: lx = -p.lunge
			DIR_RIGHT: lx = p.lunge
		_draw_shape(img, shape, pal, size, cx + lx, by + ly - p.bob, dir, p)
	_outline(img, pal.outline)
	if shiny and p.dead == 0:
		_sparkles(img, col + dir * 3)
	return img


# ------------------------------------------------------------------ primitivas

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		if c.a >= 1.0:
			img.set_pixel(x, y, c)
		else:
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


static func _eyes(img: Image, cx: float, cy: float, spread: float, dir: int, pal: Dictionary, r := 1.6) -> void:
	if dir == DIR_UP:
		return
	var off := 0.0
	if dir == DIR_LEFT:
		off = -spread * 0.6
	elif dir == DIR_RIGHT:
		off = spread * 0.6
	var pts: Array = []
	if dir == DIR_DOWN:
		pts = [cx - spread, cx + spread]
	else:
		pts = [cx + off]
	for ex in pts:
		ellipse(img, ex, cy, r, r * 1.15, pal.eye)
		var po := -0.6 if dir == DIR_LEFT else (0.6 if dir == DIR_RIGHT else 0.0)
		ellipse(img, ex + po, cy + 0.4, r * 0.55, r * 0.7, pal.pupil)


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
		var y := rng.randi_range(6, FRAME - 14)
		var c := Color(1, 1, 0.75)
		_px(img, x, y, c)
		_px(img, x + 1, y, c)
		_px(img, x - 1, y, c)
		_px(img, x, y + 1, c)
		_px(img, x, y - 1, c)


static func _shiny_recolor(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				c.h = fposmod(c.h + 0.45, 1.0)
				img.set_pixel(x, y, c)


# ------------------------------------------------------------------ formatos (famílias)

static func _draw_shape(img: Image, shape: String, pal: Dictionary, s: float, cx: float, by: float, dir: int, p: Dictionary) -> void:
	# sombra no chão
	ellipse(img, cx, by - 1, s * 0.42, s * 0.12, Color(0, 0, 0, 0.35))
	var side := dir == DIR_LEFT or dir == DIR_RIGHT
	var fx := -1.0 if dir == DIR_LEFT else 1.0
	var ph := float(p.phase)
	match shape:
		"blob":
			var sq := 1.0 + (0.08 if p.bob > 0 else 0.0)
			ellipse(img, cx, by - s * 0.36 / sq, s * 0.5 * sq, s * 0.38 / sq, pal.base)
			ellipse(img, cx - s * 0.15, by - s * 0.5, s * 0.16, s * 0.1, pal.light)
			ellipse(img, cx, by - s * 0.12, s * 0.4, s * 0.08, pal.dark)
			if p.stage >= 2:
				tri(img, Vector2(cx - 2, by - s * 0.7), Vector2(cx + 2, by - s * 0.7), Vector2(cx, by - s * 0.9), pal.accent)
			if p.stage >= 3:
				ellipse(img, cx - s * 0.45, by - s * 0.4, s * 0.12, s * 0.1, pal.base)
				ellipse(img, cx + s * 0.45, by - s * 0.4, s * 0.12, s * 0.1, pal.base)
			_eyes(img, cx, by - s * 0.42, s * 0.16, dir, pal, max(1.4, s * 0.08))
		"quadruped":
			var bw := s * (0.55 if side else 0.4)
			var bh := s * 0.28
			var bcy := by - s * 0.32
			for i in 4:
				var lx := cx + (bw * (-0.7 + 0.47 * i) if side else (-bw * 0.6 if i % 2 == 0 else bw * 0.6))
				var lo := ph * (2.0 if i % 2 == 0 else -2.0)
				rect(img, lx - 1.5 + (lo if side else 0.0), bcy + bh * 0.4, 3, s * 0.22 + (0.0 if side else lo * 0.5), pal.dark)
			ellipse(img, cx, bcy, bw, bh, pal.base)
			ellipse(img, cx - bw * 0.3, bcy - bh * 0.4, bw * 0.4, bh * 0.3, pal.light)
			if side:
				line(img, Vector2(cx - fx * bw, bcy), Vector2(cx - fx * (bw + s * 0.2), bcy - s * 0.2 + ph), pal.dark, 2)
			var hx := cx + (fx * bw * 0.9 if side else 0.0)
			var hy := bcy - s * (0.18 if dir != DIR_UP else 0.25)
			var hr := s * 0.24
			if dir == DIR_DOWN:
				hy = bcy - s * 0.05
			ellipse(img, hx, hy, hr, hr * 0.9, pal.base)
			tri(img, Vector2(hx - hr * 0.8, hy - hr * 0.5), Vector2(hx - hr * 0.3, hy - hr * 0.7), Vector2(hx - hr * 0.7, hy - hr * 1.4), pal.dark)
			tri(img, Vector2(hx + hr * 0.8, hy - hr * 0.5), Vector2(hx + hr * 0.3, hy - hr * 0.7), Vector2(hx + hr * 0.7, hy - hr * 1.4), pal.dark)
			if p.stage >= 3:
				line(img, Vector2(cx - bw * 0.5, bcy - bh), Vector2(cx + bw * 0.5, bcy - bh), pal.accent, 2)
			_eyes(img, hx, hy - hr * 0.1, hr * 0.42, dir, pal, max(1.2, s * 0.06))
		"bird":
			var bcy := by - s * 0.4 - (1.0 if p.bob > 0 else 0.0)
			rect(img, cx - 2, by - s * 0.18, 1, s * 0.16, pal.accent)
			rect(img, cx + 1, by - s * 0.18, 1, s * 0.16, pal.accent)
			var wing := s * 0.35
			var flap := ph * 3.0
			tri(img, Vector2(cx - s * 0.2, bcy), Vector2(cx - s * 0.2, bcy + s * 0.12), Vector2(cx - s * 0.2 - wing, bcy - wing * 0.4 + flap), pal.dark)
			tri(img, Vector2(cx + s * 0.2, bcy), Vector2(cx + s * 0.2, bcy + s * 0.12), Vector2(cx + s * 0.2 + wing, bcy - wing * 0.4 - flap), pal.dark)
			ellipse(img, cx, bcy, s * 0.28, s * 0.3, pal.base)
			ellipse(img, cx, bcy + s * 0.08, s * 0.18, s * 0.16, pal.light)
			var hy := bcy - s * 0.3
			ellipse(img, cx + (fx * s * 0.06 if side else 0.0), hy, s * 0.2, s * 0.19, pal.base)
			if dir != DIR_UP:
				var bx := cx + (fx * s * 0.25 if side else 0.0)
				tri(img, Vector2(bx - 2, hy + 1), Vector2(bx + 2, hy + 1), Vector2(bx + (fx * 4 if side else 0.0), hy + 4), Color(1, 0.75, 0.2))
			if p.stage >= 2:
				tri(img, Vector2(cx - 2, hy - s * 0.15), Vector2(cx + 2, hy - s * 0.15), Vector2(cx, hy - s * 0.35), pal.accent)
			_eyes(img, cx + (fx * s * 0.06 if side else 0.0), hy - 1, s * 0.09, dir, pal, max(1.1, s * 0.05))
		"serpent":
			var segs := 5 + int(p.stage)
			for i in range(segs - 1, -1, -1):
				var t := float(i) / segs
				var wave := sin(t * 6.0 + ph * 1.2) * s * 0.12
				var sx := cx + (fx * (s * 0.45 - t * s * 0.9) if side else wave)
				var sy := by - s * 0.15 - (wave * 0.4 if side else 0.0) - (t * s * 0.25 if not side else 0.0)
				var r := s * (0.13 + 0.05 * (1.0 - t))
				ellipse(img, sx, sy, r, r * 0.85, pal.base if i % 2 == 0 else pal.dark)
			var hx := cx + (fx * s * 0.45 if side else 0.0)
			var hy := by - s * (0.38 if side else 0.45)
			ellipse(img, hx, hy, s * 0.2, s * 0.17, pal.base)
			ellipse(img, hx - s * 0.05, hy - s * 0.06, s * 0.08, s * 0.05, pal.light)
			if p.stage >= 2:
				tri(img, Vector2(hx - s * 0.18, hy - 2), Vector2(hx + s * 0.18, hy - 2), Vector2(hx, hy - s * 0.35), pal.accent)
			_eyes(img, hx, hy - 1, s * 0.09, dir, pal, max(1.1, s * 0.05))
		"biped":
			var hip := by - s * 0.3
			rect(img, cx - s * 0.16 + ph, hip, s * 0.12, s * 0.28, pal.dark)
			rect(img, cx + s * 0.04 - ph, hip, s * 0.12, s * 0.28, pal.dark)
			ellipse(img, cx, hip - s * 0.12, s * 0.24, s * 0.22, pal.base)
			rect(img, cx - s * 0.36, hip - s * 0.22 - ph, s * 0.1, s * 0.25, pal.dark)
			rect(img, cx + s * 0.26, hip - s * 0.22 + ph, s * 0.1, s * 0.25, pal.dark)
			var hy := hip - s * 0.42
			ellipse(img, cx, hy, s * 0.2, s * 0.19, pal.base)
			ellipse(img, cx - s * 0.06, hy - s * 0.07, s * 0.07, s * 0.05, pal.light)
			for i in int(p.stage):
				tri(img, Vector2(cx - 4 + i * 3, hy - s * 0.15), Vector2(cx - 1 + i * 3, hy - s * 0.15), Vector2(cx - 2.5 + i * 3, hy - s * 0.32), pal.accent)
			_eyes(img, cx, hy, s * 0.08, dir, pal, max(1.1, s * 0.05))
		"insect":
			var cy := by - s * 0.28
			for i in 3:
				var lx := cx - s * 0.25 + i * s * 0.25
				var lo := ph * (1.5 if i % 2 == 0 else -1.5)
				line(img, Vector2(lx, cy), Vector2(lx - s * 0.32, cy + s * 0.2 + lo), pal.outline)
				line(img, Vector2(lx, cy), Vector2(lx + s * 0.32, cy + s * 0.2 - lo), pal.outline)
			var ax := -fx * s * 0.3 if side else 0.0
			var ay := s * 0.3 if dir == DIR_UP else (-s * 0.0 if side else -s * 0.3)
			ellipse(img, cx + ax, cy - ay * 0.0 + (s * 0.15 if dir == DIR_UP else (-s * 0.0)), s * 0.24, s * 0.2, pal.dark)
			ellipse(img, cx, cy - s * 0.05, s * 0.17, s * 0.15, pal.base)
			var hx := cx + (fx * s * 0.3 if side else 0.0)
			var hy := cy - (s * 0.25 if dir == DIR_DOWN else (s * 0.1 if side else s * 0.3))
			ellipse(img, hx, hy, s * 0.16, s * 0.14, pal.base)
			line(img, Vector2(hx - 2, hy - s * 0.1), Vector2(hx - s * 0.2, hy - s * 0.35), pal.outline)
			line(img, Vector2(hx + 2, hy - s * 0.1), Vector2(hx + s * 0.2, hy - s * 0.35), pal.outline)
			if p.stage >= 2:
				ellipse(img, cx, cy - s * 0.12, s * 0.3, s * 0.08, Color(pal.light.r, pal.light.g, pal.light.b, 0.7))
			_eyes(img, hx, hy, s * 0.07, dir, pal, max(1.0, s * 0.045))
		"fish":
			var cy := by - s * 0.38 - (1.0 if p.bob > 0 else 0.0)
			if side:
				tri(img, Vector2(cx - fx * s * 0.3, cy), Vector2(cx - fx * s * 0.55, cy - s * 0.2 + ph), Vector2(cx - fx * s * 0.55, cy + s * 0.2 + ph), pal.dark)
				ellipse(img, cx, cy, s * 0.38, s * 0.24, pal.base)
				tri(img, Vector2(cx - s * 0.1, cy - s * 0.2), Vector2(cx + s * 0.12, cy - s * 0.2), Vector2(cx - fx * s * 0.1, cy - s * 0.42), pal.accent)
				ellipse(img, cx, cy + s * 0.08, s * 0.25, s * 0.09, pal.light)
				_eyes(img, cx + fx * s * 0.15, cy - s * 0.04, s * 0.08, dir, pal, max(1.1, s * 0.05))
			else:
				tri(img, Vector2(cx, cy + s * 0.15), Vector2(cx - s * 0.2 + ph, cy + s * 0.42), Vector2(cx + s * 0.2 + ph, cy + s * 0.42), pal.dark)
				ellipse(img, cx, cy, s * 0.28, s * 0.3, pal.base)
				ellipse(img, cx, cy + s * 0.08, s * 0.16, s * 0.14, pal.light)
				tri(img, Vector2(cx - 2, cy - s * 0.25), Vector2(cx + 2, cy - s * 0.25), Vector2(cx, cy - s * 0.48), pal.accent)
				_eyes(img, cx, cy - s * 0.06, s * 0.12, dir, pal, max(1.1, s * 0.05))
		"golem":
			var w := s * 0.62
			var hip := by - s * 0.25
			rect(img, cx - w * 0.38 + ph, hip, w * 0.28, s * 0.25, pal.dark)
			rect(img, cx + w * 0.1 - ph, hip, w * 0.28, s * 0.25, pal.dark)
			rect(img, cx - w / 2, hip - s * 0.42, w, s * 0.45, pal.base)
			rect(img, cx - w / 2, hip - s * 0.42, w, s * 0.08, pal.light)
			rect(img, cx - w / 2 - s * 0.14, hip - s * 0.38 - ph, s * 0.14, s * 0.36, pal.dark)
			rect(img, cx + w / 2, hip - s * 0.38 + ph, s * 0.14, s * 0.36, pal.dark)
			var hy := hip - s * 0.58
			rect(img, cx - s * 0.17, hy - s * 0.1, s * 0.34, s * 0.24, pal.base)
			if p.stage >= 2:
				rect(img, cx - s * 0.1, hip - s * 0.3, s * 0.2, s * 0.12, pal.accent)
			if p.stage >= 3:
				tri(img, Vector2(cx - w / 2, hip - s * 0.42), Vector2(cx - w / 2 + 4, hip - s * 0.42), Vector2(cx - w / 2 - 2, hip - s * 0.6), pal.accent)
				tri(img, Vector2(cx + w / 2, hip - s * 0.42), Vector2(cx + w / 2 - 4, hip - s * 0.42), Vector2(cx + w / 2 + 2, hip - s * 0.6), pal.accent)
			_eyes(img, cx, hy, s * 0.08, dir, pal, max(1.0, s * 0.04))
		"spirit":
			var cy := by - s * 0.5 - (1.5 if p.bob > 0 else 0.0)
			var col: Color = pal.base
			col.a = 0.88
			ellipse(img, cx, cy + s * 0.05, s * 0.32, s * 0.3, col)
			for i in 4:
				var tx := cx - s * 0.24 + i * s * 0.16
				tri(img, Vector2(tx - s * 0.08, cy + s * 0.2), Vector2(tx + s * 0.08, cy + s * 0.2), Vector2(tx + ph * 1.5, cy + s * 0.45 + (i % 2) * 2), col)
			ellipse(img, cx - s * 0.1, cy - s * 0.1, s * 0.12, s * 0.09, Color(pal.light.r, pal.light.g, pal.light.b, 0.9))
			if p.stage >= 2:
				ellipse(img, cx, cy - s * 0.38, s * 0.22, s * 0.06, Color(1, 1, 0.8, 0.8))
			if p.stage >= 3:
				ellipse(img, cx - s * 0.42, cy, s * 0.08, s * 0.08, pal.accent)
				ellipse(img, cx + s * 0.42, cy, s * 0.08, s * 0.08, pal.accent)
			_eyes(img, cx, cy, s * 0.12, dir, pal, max(1.2, s * 0.06))
		_:
			ellipse(img, cx, by - s * 0.4, s * 0.4, s * 0.4, pal.base)
			_eyes(img, cx, by - s * 0.45, s * 0.15, dir, pal)


static func _draw_dead(img: Image, shape: String, pal: Dictionary, s: float, cx: float, by: float, stage: int) -> void:
	var gray: Color = pal.base.lerp(Color(0.45, 0.42, 0.4), 0.35 * stage)
	var dark: Color = pal.dark.lerp(Color(0.3, 0.28, 0.26), 0.35 * stage)
	match stage:
		1:
			ellipse(img, cx, by - s * 0.3, s * 0.45, s * 0.3, gray)
			line(img, Vector2(cx - 4, by - s * 0.35 - 2), Vector2(cx - 1, by - s * 0.35 + 1), Color.BLACK)
			line(img, Vector2(cx - 1, by - s * 0.35 - 2), Vector2(cx - 4, by - s * 0.35 + 1), Color.BLACK)
		2:
			ellipse(img, cx, by - s * 0.18, s * 0.52, s * 0.2, gray)
			ellipse(img, cx + s * 0.2, by - s * 0.22, s * 0.16, s * 0.12, dark)
		_:
			# corpo no chão (fica alguns segundos)
			ellipse(img, cx, by - s * 0.1, s * 0.55, s * 0.14, Color(0.5, 0.05, 0.05, 0.6))
			ellipse(img, cx, by - s * 0.14, s * 0.45, s * 0.14, gray)
			ellipse(img, cx - s * 0.18, by - s * 0.16, s * 0.12, s * 0.07, dark)
