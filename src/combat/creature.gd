class_name Creature
extends Node2D
## Uma criatura no mapa (monstro do jogador, selvagem ou chefe).
## A lógica (IA, movimento) é executada pelo HuntWorld em passo fixo; este nó cuida da apresentação.

const TILE := 32

var world  # HuntWorld
var is_player := false
var is_boss := false
var is_summon := false
var demo := false  # shiny de demonstração do tutorial: não luta, não dá recompensa, não recruta
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
# posição lógica (passo fixo) e anterior: o desenho interpola entre as duas para andar liso a 60 fps
var vis_prev := Vector2.ZERO
var vis_cur := Vector2.ZERO
var _carry := 0.0
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
	_setup_glow()
	_update_frame()


var aura: Sprite2D
var _glow_tier := 0


## Brilho do treino (+5/+10/+15): aura pulsante atrás do monstro e faíscas subindo.
func _setup_glow() -> void:
	var tr := int(stats.get("train", 0))
	_glow_tier = 0
	for lv in DataDB.config.train.glow_levels:
		if tr >= int(lv):
			_glow_tier += 1
	if _glow_tier == 0:
		return
	var col := UI.glow_color(type_id, _glow_tier)
	aura = Sprite2D.new()
	aura.texture = UI.glow_texture()
	aura.modulate = Color(col.r, col.g, col.b, 0.5)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	aura.material = mat
	aura.position = Vector2(0, sprite.position.y + frame_h * 0.12)
	aura.scale = Vector2.ONE * (0.75 + 0.18 * _glow_tier)
	add_child(aura)
	move_child(aura, 0)
	if _glow_tier >= 2:
		var pt := CPUParticles2D.new()
		pt.amount = 6 if _glow_tier == 2 else 12
		pt.lifetime = 1.2
		pt.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		pt.emission_rect_extents = Vector2(10, 6)
		pt.position = Vector2(0, -4)
		pt.direction = Vector2.UP
		pt.spread = 15
		pt.initial_velocity_min = 10
		pt.initial_velocity_max = 22
		pt.gravity = Vector2.ZERO
		pt.scale_amount_min = 1.0
		pt.scale_amount_max = 2.0
		pt.color = col.lightened(0.3)
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 1, 1, 0))
		pt.color_ramp = ramp
		pt.material = mat
		add_child(pt)


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
	_carry = 0.0
	position = world.cell_center(c)
	vis_prev = position
	vis_cur = position


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
		_carry = 0.0
		return
	# um passo que começa logo após outro aproveita o tempo que "sobrou" do anterior (sem micro-paradas)
	if move_t == 0.0:
		dt += _carry
		_carry = 0.0
	var diag := (cell - from_cell).abs()
	var len := 1.41 if diag.x + diag.y == 2 else 1.0
	var spd := move_speed() / len
	move_t += dt * spd
	if move_t >= 1.0:
		_carry = minf((move_t - 1.0) / maxf(spd, 0.001), 0.1)
		move_t = 1.0
		moving = false
	vis_cur = world.cell_center(from_cell).lerp(world.cell_center(cell), move_t)


## Posição desenhada: interpola entre os dois últimos passos da simulação.
func interp_position(alpha: float) -> Vector2:
	return vis_prev.lerp(vis_cur, alpha)


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
	if aura:
		aura.visible = alive
		aura.modulate.a = 0.38 + 0.12 * _glow_tier + 0.18 * sin(_anim_t * 3.0)
	if world:
		position = interp_position(world.interp_alpha())
	if moving:
		_walk_phase = fmod(_walk_phase + delta * move_speed() * (world.sim_speed() if world else 1.0), 1.0)
		_walk_anim = 0.12
	elif _walk_anim > 0.0:
		_walk_anim -= delta
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


var _walk_phase := 0.0
var _walk_anim := 0.0


func _update_frame() -> void:
	var col := 0
	if not alive:
		col = _death_frame
	elif _attack_anim > 0.0:
		col = 5 if _attack_anim > 0.15 else 6
	elif moving or _walk_anim > 0.0:
		col = 2 + int(_walk_phase * 3.0) % 3
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
	var r := hp_ratio()
	var col := Color(0.3, 0.88, 0.3)
	if not is_player:
		col = Color(0.92, 0.25, 0.22) if r > 0.3 else Color(0.7, 0.08, 0.08)
	elif r < 0.3:
		col = Color(0.98, 0.78, 0.15)
	# moldura escura, fundo, preenchimento com brilho no topo
	draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), Color(0.06, 0.04, 0.03, 0.9))
	draw_rect(Rect2(x, y, w, h), Color(0.22, 0.16, 0.14, 0.9))
	draw_rect(Rect2(x, y, w * r, h), col)
	draw_rect(Rect2(x, y, w * r, 1), col.lightened(0.45))
	if is_player and party_index == 0:
		draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), Color(1, 0.85, 0.35, 0.9), false, 1.0)
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
	return [24.0, 32.0, 42.0][clampi(st - 1, 0, 2)] * size_scale * float(frame_h) / 48.0
