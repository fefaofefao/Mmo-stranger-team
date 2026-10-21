class_name Creature
extends Node2D
## Uma criatura no mapa (monstro do jogador, selvagem ou chefe).
## A lógica (IA, movimento) é executada pelo HuntWorld em passo fixo; este nó cuida da apresentação.

const TILE := 32

var world  # HuntWorld
var is_player := false
var is_boss := false
var is_summon := false
var form_id := ""
var display_name := ""
var level := 1
var shiny := false
var ticket := ""
var mon_uid := ""
var party_index := 0
var stats: Dictionary = {}
var type_id := ""
var style := "melee"
var abilities: Array = []

var hp := 1.0
var max_hp := 1.0
var alive := true
var dead_timer := 0.0
var revive_timer := 0.0

var cell := Vector2i.ZERO
var from_cell := Vector2i.ZERO
var move_t := 1.0
var moving := false
var facing := 0
var path: Array = []
var path_timer := 0.0
var blocked_timer := 0.0
var home := Vector2i.ZERO
var spawn_slot := -1
var wander_timer := 0.0

var target: Creature = null
var attack_cd := 0.0
var ability_cd := {}
var gcd := 0.0
var last_hit_by: Creature = null
var in_combat_timer := 0.0
var atk_mult := 1.0
var spd_mult := 1.0

var sprite: Sprite2D
var _anim_t := 0.0
var _attack_anim := 0.0
var _hurt_flash := 0.0
var _death_frame := 7
var frame_w := 48
var frame_h := 48
var _bar_dirty := true
var _sparkle_t := 0.0
var size_scale := 1.0


func setup(p_world, p_form: String, p_level: int, p_stats: Dictionary, p_player: bool, p_shiny := false) -> void:
	world = p_world
	form_id = p_form
	level = p_level
	stats = p_stats
	is_player = p_player
	shiny = p_shiny
	var f := DataDB.form(form_id)
	display_name = f.get("name", "?")
	type_id = f.get("type", "agua")
	style = f.get("style", "melee")
	abilities = stats.get("abilities", f.get("abilities", []))
	max_hp = max(1.0, float(stats.hp))
	hp = max_hp
	sprite = Sprite2D.new()
	sprite.texture = SpriteFactory.sheet(form_id, shiny)
	sprite.hframes = SpriteFactory.COLS
	sprite.vframes = SpriteFactory.ROWS
	frame_w = sprite.texture.get_width() / SpriteFactory.COLS
	frame_h = sprite.texture.get_height() / SpriteFactory.ROWS
	sprite.centered = true
	add_child(sprite)
	set_size_scale(1.0)
	_update_frame()


func set_size_scale(s: float) -> void:
	size_scale = s
	# alinha a base do quadro com a base do tile
	sprite.scale = Vector2(s, s)
	sprite.position = Vector2(0, TILE / 2.0 - frame_h * s / 2.0 - 2.0)


func place(c: Vector2i) -> void:
	cell = c
	from_cell = c
	move_t = 1.0
	moving = false
	position = world.cell_center(c)


func attack_range() -> int:
	return int(stats.get("rng", 1))


func move_speed() -> float:
	var spd := float(stats.get("spd", 100.0)) * spd_mult
	return Formulas.move_speed(spd) if is_player else Formulas.enemy_move_speed(spd)


func attack_interval() -> float:
	var spd := float(stats.get("spd", 100.0)) * spd_mult
	return Formulas.attack_interval(spd) if is_player else Formulas.enemy_attack_interval(spd)


func hp_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


func dist_to(o: Creature) -> int:
	var d: Vector2i = (o.cell - cell).abs()
	return max(d.x, d.y)


func face_towards(c: Vector2i) -> void:
	var d := c - cell
	if d == Vector2i.ZERO:
		return
	if abs(d.x) > abs(d.y):
		facing = SpriteFactory.DIR_RIGHT if d.x > 0 else SpriteFactory.DIR_LEFT
	else:
		facing = SpriteFactory.DIR_DOWN if d.y > 0 else SpriteFactory.DIR_UP


## Começa a andar para uma célula vizinha (reserva a célula de destino).
func start_move(to: Vector2i) -> void:
	face_towards(to)
	from_cell = cell
	cell = to
	move_t = 0.0
	moving = true


func tick_move(dt: float) -> void:
	if not moving:
		return
	var diag := (cell - from_cell).abs()
	var len := 1.41 if diag.x + diag.y == 2 else 1.0
	move_t += dt * move_speed() / len
	if move_t >= 1.0:
		move_t = 1.0
		moving = false
	position = world.cell_center(from_cell).lerp(world.cell_center(cell), move_t)


func play_attack() -> void:
	_attack_anim = 0.3


func take_hit_flash() -> void:
	_hurt_flash = 0.15
	_bar_dirty = true


func die() -> void:
	alive = false
	moving = false
	target = null
	path.clear()
	dead_timer = 0.0
	_death_frame = 7
	_bar_dirty = true
	queue_redraw()


func revive_at(c: Vector2i) -> void:
	alive = true
	hp = max_hp
	place(c)
	modulate = Color(1, 1, 1, 1)
	_bar_dirty = true
	queue_redraw()


func _process(delta: float) -> void:
	_anim_t += delta
	if _attack_anim > 0.0:
		_attack_anim -= delta
	if _hurt_flash > 0.0:
		_hurt_flash -= delta
		sprite.modulate = Color(1.6, 0.7, 0.7) if _hurt_flash > 0.0 else Color.WHITE
	if not alive:
		dead_timer += delta * world.sim_speed()
		_death_frame = 7 + mini(2, int(dead_timer / 0.18))
	_update_frame()
	z_index = 0
	if shiny and alive:
		_sparkle_t += delta
		if _sparkle_t > 0.25:
			_sparkle_t = 0.0
			queue_redraw()
	elif _bar_dirty:
		_bar_dirty = false
		queue_redraw()


func _update_frame() -> void:
	var col := 0
	if not alive:
		col = _death_frame
	elif _attack_anim > 0.0:
		col = 5 if _attack_anim > 0.15 else 6
	elif moving:
		col = 2 + int(move_t * 3.0) % 3
	else:
		col = int(_anim_t * 2.0) % 2
	sprite.frame = facing * SpriteFactory.COLS + col


func mark_bar_dirty() -> void:
	_bar_dirty = true


func _draw() -> void:
	if not alive:
		return
	var top := sprite.position.y - frame_h * size_scale / 2.0 + (frame_h * size_scale - _visual_height()) - 4.0
	var w := 26.0 if not is_boss else 54.0
	var h := 4.0 if not is_boss else 6.0
	var x := -w / 2.0
	var y := minf(top, -18.0)
	draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), Color(0, 0, 0, 0.85))
	var r := hp_ratio()
	var col := Color(0.2, 0.85, 0.25)
	if not is_player:
		col = Color(0.9, 0.2, 0.2) if r > 0.3 else Color(0.6, 0.05, 0.05)
	elif r < 0.3:
		col = Color(0.95, 0.75, 0.1)
	draw_rect(Rect2(x, y, w * r, h), col)
	if is_boss:
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-60, y - 4), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 9, 3, Color.BLACK)
		draw_string(font, Vector2(-60, y - 4), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 9, Color(1, 0.85, 0.4))
	if shiny:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_anim_t * 4.0) + get_instance_id()
		for i in 2:
			var p := Vector2(rng.randf_range(-14, 14), rng.randf_range(-30, 6))
			draw_rect(Rect2(p.x, p.y, 2, 2), Color(1, 1, 0.6))
			draw_rect(Rect2(p.x - 1, p.y + 0.5, 4, 1), Color(1, 1, 0.8, 0.7))


func _visual_height() -> float:
	var st := int(DataDB.form(form_id).get("stage", 1))
	return [20.0, 28.0, 38.0][clampi(st - 1, 0, 2)] * size_scale * float(frame_h) / 48.0
