class_name FxLayer
extends Node2D
## Desenha efeitos em pixel art, projéteis, números de dano e brilhos de loot em um único _draw().

var effects: Array = []
var texts: Array = []
var projectiles: Array = []
var loot: Array = []
var dangers: Array = []
var show_damage := true
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	z_index = 10


func add_text(pos: Vector2, text: String, color: Color, size := 11) -> void:
	if not show_damage and size <= 11:
		return
	if texts.size() > 60:
		texts.pop_front()
	texts.append({"pos": pos + Vector2(randf_range(-6, 6), -20), "text": text, "color": color, "t": 0.0, "dur": 0.9, "size": size})


func add_effect(kind: String, pos: Vector2, color: Color, radius := 0.0, dur := 0.4, extra: Dictionary = {}) -> void:
	if effects.size() > 80:
		effects.pop_front()
	var e := {"kind": kind, "pos": pos, "color": color, "radius": radius, "t": 0.0, "dur": dur}
	e.merge(extra)
	effects.append(e)


func add_loot(from: Vector2, to_node: Node2D, color: Color) -> void:
	loot.append({"from": from, "to": to_node, "t": 0.0, "dur": 0.6, "color": color})


func update_fx(dt: float) -> void:
	for arr in [effects, texts, loot]:
		var i := 0
		while i < arr.size():
			arr[i].t += dt
			if arr[i].t >= arr[i].dur:
				arr.remove_at(i)
			else:
				i += 1
	queue_redraw()


func _px_circle(center: Vector2, r: float, col: Color, step := 4.0) -> void:
	# anel "pixelado"
	var n := maxi(8, int(r * 0.8))
	for i in n:
		var a := TAU * i / n
		var p := center + Vector2(cos(a), sin(a)) * r
		draw_rect(Rect2(snappedf(p.x, 2) - step / 2, snappedf(p.y, 2) - step / 2, step, step), col)


func _draw() -> void:
	for d in dangers:
		var blink := 0.35 + 0.25 * sin(d.t * 18.0)
		for c in d.cells:
			var p: Vector2 = d.world.cell_center(c)
			draw_rect(Rect2(p.x - 15, p.y - 15, 30, 30), Color(1, 0.1, 0.05, blink))
			draw_rect(Rect2(p.x - 15, p.y - 15, 30, 30), Color(1, 0.4, 0.2, 0.9), false, 2.0)
	for e in effects:
		var k: float = e.t / e.dur
		var col: Color = e.color
		col.a = 1.0 - k * 0.8
		match e.kind:
			"slash":
				var dir: Vector2 = e.get("dir", Vector2.RIGHT)
				var perp := Vector2(-dir.y, dir.x)
				for i in 5:
					var t := (i - 2) / 2.0
					var p: Vector2 = e.pos + dir * (6 + 4 * (1.0 - abs(t))) + perp * t * 10 * (0.5 + k)
					draw_rect(Rect2(p.x - 2, p.y - 2, 4, 4), col)
			"hit":
				for i in 4:
					var a := TAU * i / 4 + k
					var p: Vector2 = e.pos + Vector2(cos(a), sin(a)) * (4 + 10 * k)
					draw_rect(Rect2(p.x - 1.5, p.y - 1.5, 3, 3), col)
			"ring", "nova":
				_px_circle(e.pos, 6 + e.radius * k, col, 4.0 if e.kind == "ring" else 6.0)
				if e.kind == "nova":
					_px_circle(e.pos, 2 + e.radius * k * 0.6, col.lightened(0.3), 4.0)
			"explosion":
				var r: float = e.radius * (0.3 + 0.7 * k)
				for i in 10:
					var a := TAU * i / 10 + i
					var p: Vector2 = e.pos + Vector2(cos(a), sin(a)) * r * (0.4 + 0.6 * fmod(i * 0.37, 1.0))
					draw_rect(Rect2(p.x - 3, p.y - 3, 6, 6), col if i % 2 == 0 else col.lightened(0.4))
			"rain":
				var r2: float = e.radius
				for i in 8:
					var px: float = e.pos.x + fmod(i * 37.0 + e.t * 50.0, r2 * 2) - r2
					var py: float = e.pos.y + fmod(i * 23.0 + e.t * 140.0, r2 * 2) - r2
					draw_rect(Rect2(px, py, 2, 5), col)
			"heal":
				for i in 4:
					var p: Vector2 = e.pos + Vector2((i - 1.5) * 7, -k * 24 - (i % 2) * 6)
					draw_rect(Rect2(p.x - 3, p.y - 1, 6, 2), col)
					draw_rect(Rect2(p.x - 1, p.y - 3, 2, 6), col)
			"spawn":
				_px_circle(e.pos, 14 * (1.0 - k) + 2, col, 3.0)
			"levelup":
				for i in 6:
					var p: Vector2 = e.pos + Vector2((i - 2.5) * 6, -k * 30 - (i % 3) * 4)
					draw_rect(Rect2(p.x - 1.5, p.y - 1.5, 3, 3), col)
			"warn":
				_px_circle(e.pos, e.radius, col, 3.0)
	for p in projectiles:
		var pos: Vector2 = p.pos
		var col2: Color = p.color
		draw_rect(Rect2(pos.x - 3, pos.y - 3, 6, 6), col2)
		draw_rect(Rect2(pos.x - 1.5, pos.y - 1.5, 3, 3), col2.lightened(0.5))
		var tail: Vector2 = pos - p.dir * 6
		draw_rect(Rect2(tail.x - 2, tail.y - 2, 4, 4), Color(col2.r, col2.g, col2.b, 0.5))
	for l in loot:
		var k2: float = l.t / l.dur
		if not is_instance_valid(l.to):
			continue
		var to: Vector2 = (l.to as Node2D).position + Vector2(0, -10)
		var p2: Vector2 = l.from.lerp(to, k2) + Vector2(0, -sin(k2 * PI) * 24)
		draw_rect(Rect2(p2.x - 2, p2.y - 2, 4, 4), l.color)
		draw_rect(Rect2(p2.x - 4, p2.y - 0.5, 8, 1), Color(1, 1, 1, 0.6))
	for t in texts:
		var k3: float = t.t / t.dur
		var pos3: Vector2 = t.pos + Vector2(0, -k3 * 22)
		var c3: Color = t.color
		c3.a = 1.0 - maxf(0.0, k3 - 0.6) * 2.5
		draw_string_outline(font, pos3 - Vector2(30, 0), t.text, HORIZONTAL_ALIGNMENT_CENTER, 60, t.size, 3, Color(0, 0, 0, c3.a))
		draw_string(font, pos3 - Vector2(30, 0), t.text, HORIZONTAL_ALIGNMENT_CENTER, 60, t.size, c3)
