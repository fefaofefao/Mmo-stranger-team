class_name HuntWorld
extends Node2D
## Mapa de hunt/desafio: tiles do bioma, spawns, criaturas, combate e efeitos.
## Simulação em passo fixo (STEP) — o "acelerar tempo" do debug apenas roda mais passos por quadro.

signal party_updated
signal kill_reward(info: Dictionary)
signal party_wiped(count: int)
signal suggest_easier
signal challenge_finished(won: bool, seconds: float)
signal boss_message(text: String)
signal player_died(creature: Creature)

const STEP := 0.05
const TILE := 32

var mode := "hunt"
var hunt: Dictionary = {}
var challenge: Dictionary = {}
var biome_id := ""
var corrupted := false
var map: Dictionary = {}
var nav := GridNav.new()
var rng := RandomNumberGenerator.new()

var ground: TileMapLayer
var corpses_node: Node2D
var entities: Node2D
var fx: FxLayer
var camera: Camera2D

var party: Array = []
var enemies: Array = []
var slots: Array = []
var corpses: Array = []
var dots: Array = []
var dangers: Array = []
var ai_behavior := "focus"
var elapsed := 0.0
var finished := false
var boss: Creature = null
var boss_timers := {}
var boss_phase := 0
var wipe_times: Array = []
var headless := false
var max_steps_per_frame := 400

var _accum := 0.0
var _ui_timer := 0.0
var _cam_target: Creature = null
var _spawn_point := Vector2i.ZERO
var _team_revive_timer := -1.0
var _field_check := 0.0
## uids caídos neste ciclo (só voltam quando o time inteiro renasce)
var fallen := {}
## uids que entraram em campo neste ciclo: recebem XP de quem luta mesmo se caírem
var participants: Array = []
var daily: Dictionary = {}


func _ready() -> void:
	rng.randomize()


func sim_speed() -> float:
	return Game.time_scale if Game else 1.0


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE / 2.0)


func _build_nodes() -> void:
	for ch in get_children():
		ch.queue_free()
	ground = TileMapLayer.new()
	ground.name = "Ground"
	add_child(ground)
	corpses_node = Node2D.new()
	corpses_node.name = "Corpses"
	add_child(corpses_node)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	fx = FxLayer.new()
	fx.name = "Fx"
	add_child(fx)
	fx.show_damage = Game.save.settings.get("show_damage", true) if Game else true
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)


# ------------------------------------------------------------------ montagem

func setup_hunt(p_hunt: Dictionary, biome_override := "") -> void:
	mode = "hunt"
	hunt = p_hunt
	biome_id = biome_override if biome_override != "" else hunt.biome
	corrupted = hunt.get("corrupted", false)
	var sz := Vector2i(int(hunt.map_size[0]), int(hunt.map_size[1]))
	map = MapGenerator.generate(biome_id, sz, int(hunt.seed), corrupted, int(hunt.density) + 8)
	_build_world()
	_spawn_party(map.start)
	slots.clear()
	var spawns: Array = map.spawns
	for i in int(hunt.density):
		slots.append({"cell": spawns[i % spawns.size()], "timer": 0.3 + i * 0.12, "creature": null})


func setup_challenge(p_challenge: Dictionary) -> void:
	mode = "challenge"
	challenge = p_challenge
	biome_id = challenge.biome
	corrupted = false
	var sz := Vector2i(int(challenge.map_size[0]), int(challenge.map_size[1]))
	map = MapGenerator.generate(biome_id, sz, int(challenge.seed), false, 4)
	# arena aberta no centro
	var c: Vector2i = sz / 2
	for y in range(c.y - 7, c.y + 8):
		for x in range(c.x - 7, c.x + 8):
			var p := Vector2i(x, y)
			if x > 0 and y > 0 and x < sz.x - 1 and y < sz.y - 1:
				map.solid.erase(p)
				if map.tiles.get(p, 0) in [MapGenerator.T_WALL_A, MapGenerator.T_WALL_B, MapGenerator.T_BORDER]:
					map.tiles[p] = 0
	_build_world()
	_spawn_party(Vector2i(c.x, c.y + 5))
	slots.clear()
	# chefe
	var lvl := int(challenge.boss_level)
	var st := Formulas.enemy_stats(challenge.boss_form, lvl, 1)
	st.hp *= float(challenge.hp_mult)
	st.atk *= float(challenge.atk_mult)
	st.def *= float(challenge.def_mult)
	st.rng = max(1, int(st.rng))
	boss = _make_creature(challenge.boss_form, lvl, st, false, false)
	boss.is_boss = true
	boss.display_name = DataDB.challenge_name(challenge)
	boss.set_size_scale(float(challenge.get("scale", 1.6)))
	_place_creature(boss, Vector2i(c.x, c.y - 4))
	boss.home = boss.cell
	enemies.append(boss)
	boss_timers.clear()
	boss_phase = 0
	if Game:
		Game.mark_seen(challenge.boss_form)


## Chefe Diário: arena com um chefe que acompanha o nível do jogador.
func setup_daily(def: Dictionary) -> void:
	var cfg: Dictionary = DataDB.config.daily_boss
	var subs := DataDB.sub_biomes(def.type)
	var c := {
		"id": "daily", "name": DataDB.form_name(def.form), "boss_form": def.form, "type": def.type,
		"biome": subs[int(def.day) % subs.size()] if not subs.is_empty() else "praia",
		"boss_level": int(def.level), "hp_mult": float(cfg.hp_mult), "atk_mult": float(cfg.atk_mult),
		"def_mult": float(cfg.def_mult), "scale": float(cfg.scale), "mechanics": cfg.mechanics.duplicate(true),
		"phases": [{"hp_below": 0.5, "atk_mult": 1.25, "spd_mult": 1.15, "say": {"pt_BR": "O chefe se enfurece!", "en": "The boss is enraged!", "es": "¡El jefe se enfurece!"}}],
		"time_limit": float(cfg.time_limit), "map_size": cfg.map_size, "seed": 5000 + int(def.day),
	}
	if c.mechanics.has("summon"):
		var same_type: Array = []
		for f in DataDB.form_list:
			if f.type == def.type and int(f.stage) == 2:
				same_type.append(f.form_id)
		c.mechanics.summon["form"] = same_type[int(def.day) % same_type.size()]
	daily = def
	setup_challenge(c)
	mode = "daily"


func boss_damage_fraction() -> float:
	if boss == null:
		return 0.0
	return clampf(1.0 - boss.hp / boss.max_hp, 0.0, 1.0)


func _build_world() -> void:
	_build_nodes()
	nav.setup(map.size, map.solid)
	ground.tile_set = TileFactory.tileset(biome_id, corrupted)
	for c in map.tiles:
		ground.set_cell(c, 0, Vector2i(int(map.tiles[c]), 0))
	party.clear()
	fallen.clear()
	participants.clear()
	_team_revive_timer = -1.0
	enemies.clear()
	corpses.clear()
	dots.clear()
	dangers.clear()
	fx.dangers = dangers
	elapsed = 0.0
	finished = false
	ai_behavior = Game.save.get("ai_behavior", "focus") if Game else "focus"
	camera.limit_left = 0
	camera.limit_top = -TILE * 2
	camera.limit_right = map.size.x * TILE
	camera.limit_bottom = map.size.y * TILE + TILE * 2


## Coloca em campo os monstros do grupo que devem lutar (nível do principal define quantos).
func _spawn_party(start: Vector2i) -> void:
	_spawn_point = start
	_ensure_field()
	if not party.is_empty():
		_cam_target = party[0]
		camera.position = party[0].position
		camera.reset_smoothing()


## Recria os monstros do grupo (troca de grupo/equipamento, mudança de quantos lutam).
func refresh_party() -> void:
	var start: Vector2i = _spawn_point
	for c in party:
		if c.alive:
			start = c.cell
			break
	for c in party:
		nav.release(c.cell, c)
		c.queue_free()
	party.clear()
	fallen.clear()
	participants.clear()
	_team_revive_timer = -1.0
	for e in enemies:
		e.target = null
	_spawn_party(start)
	party_updated.emit()


func field_wanted() -> int:
	if Game == null:
		return 0
	return PartyLogic.fighting_count(Game.main_level(), Game.party_monsters().size())


func alive_on_field() -> int:
	var n := 0
	for c in party:
		if c.alive:
			n += 1
	return n


func creature_for(uid: String) -> Creature:
	for c in party:
		if c.mon_uid == uid:
			return c
	return null


## Garante o número certo de monstros vivos em campo. Quem cai é substituído pelo próximo
## membro do grupo ainda de pé; o time só renasce quando todos caem.
func _ensure_field() -> void:
	if Game == null or _team_revive_timer >= 0.0:
		return
	var wanted := field_wanted()
	var members: Array = Game.party_monsters()
	var on_field := {}
	for c in party:
		on_field[c.mon_uid] = c
	# membro removido do grupo: tira do mapa
	var valid := {}
	for m in members:
		valid[m.uid] = true
	for c in party.duplicate():
		if not valid.has(c.mon_uid):
			nav.release(c.cell, c)
			party.erase(c)
			c.queue_free()
	var alive := alive_on_field()
	if alive >= wanted:
		return
	var anchor: Vector2i = _spawn_point
	for c in party:
		if c.alive:
			anchor = c.cell
			break
	for i in members.size():
		if alive >= wanted:
			break
		var m: Dictionary = members[i]
		if fallen.has(m.uid):
			continue
		var existing: Creature = on_field.get(m.uid)
		if existing and existing.alive:
			continue
		if existing:
			party.erase(existing)
			existing.queue_free()
		var st: Dictionary = Game.monster_stats(m)
		var c := _make_creature(MonsterLogic.form_id(m), int(m.level), st, true, bool(m.shiny))
		c.mon_uid = m.uid
		c.party_index = i
		_place_creature(c, nav.nearest_free(anchor + Vector2i(alive, 0), 8))
		c.home = c.cell
		party.append(c)
		if not participants.has(m.uid):
			participants.append(m.uid)
		alive += 1
		if elapsed > 0.5 and not headless:
			fx.add_effect("spawn", c.position, Color(0.6, 1, 0.7), 0, 0.5)
	party.sort_custom(func(a, b): return a.party_index < b.party_index)
	if _cam_target == null or not is_instance_valid(_cam_target) or not _cam_target.alive:
		for c in party:
			if c.alive:
				_cam_target = c
				break


func _make_creature(form_id: String, level: int, stats: Dictionary, player: bool, shiny: bool) -> Creature:
	var c := Creature.new()
	entities.add_child(c)
	c.setup(self, form_id, level, stats, player, shiny)
	return c


func _place_creature(c: Creature, cell: Vector2i) -> void:
	var free := nav.nearest_free(cell, 8)
	c.place(free)
	nav.occupy(free, c)


func spawn_enemy(form_id: String, level: int, cell: Vector2i, slot := -1, summon := false) -> Creature:
	var world_n := int(hunt.get("world", 1)) if mode == "hunt" else 1
	var tk := {}
	if mode == "hunt" and not summon and Game:
		tk = Game.get_spawn_ticket(hunt.id)
	var shiny: bool = tk.get("shiny", false)
	var st := Formulas.enemy_stats(form_id, level, world_n, shiny)
	var c := _make_creature(form_id, level, st, false, shiny)
	c.ticket = tk.get("id", "")
	c.spawn_slot = slot
	c.is_summon = summon
	_place_creature(c, cell)
	c.home = c.cell
	c.wander_timer = rng.randf_range(0.5, 3.0)
	enemies.append(c)
	fx.add_effect("spawn", c.position, Color(1, 1, 1, 0.8), 0, 0.4)
	if Game:
		Game.mark_seen(form_id)
	if shiny and Game:
		Game.feed.emit(Loc.t("✦ Um %s SHINY apareceu!") % DataDB.form_name(form_id), Color(1, 0.9, 0.3))
	return c


func _pick_hunt_form() -> String:
	var total := 0.0
	for m in hunt.monsters:
		total += float(m.weight)
	var r := rng.randf() * total
	for m in hunt.monsters:
		r -= float(m.weight)
		if r <= 0:
			return m.form
	return hunt.monsters[0].form


# ------------------------------------------------------------------ laço principal

func _process(delta: float) -> void:
	if map.is_empty():
		return
	_accum += delta * sim_speed()
	var steps := 0
	while _accum >= STEP and steps < max_steps_per_frame:
		_accum -= STEP
		step(STEP)
		steps += 1
	if steps >= max_steps_per_frame:
		_accum = 0.0
	if not headless:
		fx.update_fx(delta * min(sim_speed(), 3.0))
		if _cam_target and is_instance_valid(_cam_target):
			camera.position = _cam_target.position
	_ui_timer += delta
	if _ui_timer > 0.2:
		_ui_timer = 0.0
		party_updated.emit()


func step(dt: float) -> void:
	if finished:
		return
	elapsed += dt
	var regen := float(DataDB.config.combat.regen_pct_per_sec)
	if _team_revive_timer >= 0.0:
		_team_revive_timer -= dt
		if _team_revive_timer <= 0.0:
			_team_revive()
	else:
		_field_check -= dt
		if _field_check <= 0.0:
			_field_check = 0.5
			if alive_on_field() != field_wanted():
				if alive_on_field() > field_wanted():
					refresh_party()
				else:
					_ensure_field()
	for c in party:
		if not c.alive:
			continue
		c.hp = minf(c.max_hp, c.hp + c.max_hp * regen * dt)
		CreatureAI.player_tick(self, c, dt)
	for e in enemies:
		if e.alive:
			e.hp = minf(e.max_hp, e.hp + e.max_hp * regen * dt * (0.0 if e.is_boss else 1.0))
			CreatureAI.enemy_tick(self, e, dt)
	for c in party:
		if c.alive:
			c.tick_move(dt)
	for e in enemies:
		if e.alive:
			e.tick_move(dt)
	_update_projectiles(dt)
	_update_dots(dt)
	_update_dangers(dt)
	_update_corpses(dt)
	if mode == "hunt":
		_update_slots(dt)
	else:
		_update_boss(dt)


func _update_slots(dt: float) -> void:
	for i in slots.size():
		var s: Dictionary = slots[i]
		var cr = s.creature
		if cr != null and is_instance_valid(cr) and cr.alive:
			continue
		s.creature = null
		s.timer = float(s.timer) - dt
		if s.timer <= 0.0:
			var spread := int(DataDB.config.enemy_level_spread)
			var lvl := maxi(1, int(hunt.level) + rng.randi_range(-spread, spread))
			s.creature = spawn_enemy(_pick_hunt_form(), lvl, s.cell, i)
			s.timer = float(hunt.respawn)


# ------------------------------------------------------------------ combate

func hostiles_of(c: Creature) -> Array:
	return enemies if c.is_player else party


func count_hostiles_near(c: Creature, cell: Vector2i, radius: int) -> int:
	var n := 0
	for h in hostiles_of(c):
		if h.alive:
			var d: Vector2i = (h.cell - cell).abs()
			if max(d.x, d.y) <= radius:
				n += 1
	return n


func deal_damage(src: Creature, dst: Creature, power: float, is_ability: bool, true_damage := -1.0) -> void:
	if not dst.alive or finished:
		return
	var dmg := 0.0
	var crit := false
	var tm := 1.0
	if true_damage >= 0.0:
		dmg = true_damage
	else:
		tm = TypeChart.multiplier(src.type_id, dst.type_id)
		tm *= 1.0 + float(src.stats.get("type_dmg", {}).get(dst.type_id, 0.0)) / 100.0
		var r := Formulas.roll_damage(float(src.stats.atk) * src.atk_mult, float(dst.stats.def), power, tm, rng, float(src.stats.get("crit", 0.05)))
		dmg = r.dmg
		crit = r.crit
	dst.hp -= dmg
	dst.take_hit_flash()
	dst.mark_bar_dirty()
	if src != null and src.alive:
		var ls := float(src.stats.get("lifesteal", 0.0))
		if ls > 0.0:
			src.hp = minf(src.max_hp, src.hp + dmg * ls)
		if dst.target == null and not dst.is_player:
			dst.target = src
		dst.last_hit_by = src
	if not headless:
		var col := Color(1, 0.3, 0.3) if dst.is_player else Color(1, 1, 1)
		var txt := str(int(dmg))
		var size := 11
		if crit:
			col = Color(1, 0.6, 0.1)
			size = 14
			txt += "!"
		elif tm > 1.01:
			col = Color(1, 0.95, 0.3) if not dst.is_player else col
		elif tm < 0.99 and not dst.is_player:
			col = Color(0.7, 0.7, 0.7)
		fx.add_text(dst.position, txt, col, size)
		if not is_ability:
			fx.add_effect("hit", dst.position + Vector2(0, -8), DataDB.type_color(src.type_id) if src else Color.WHITE, 0, 0.2)
	if dst.hp <= 0.0:
		_on_death(dst, src)


func heal(c: Creature, amount: float) -> void:
	c.hp = minf(c.max_hp, c.hp + amount)
	c.mark_bar_dirty()
	if not headless:
		fx.add_text(c.position, "+%d" % int(amount), Color(0.4, 1, 0.4))


func launch_projectile(src: Creature, dst: Creature, power: float, color: Color, is_ability := false, on_hit: Callable = Callable()) -> void:
	var start := src.position + Vector2(0, -10)
	fx.projectiles.append({"src": src, "dst": dst, "pos": start, "power": power, "color": color,
		"speed": float(DataDB.config.combat.ranged_projectile_speed) * TILE, "ability": is_ability,
		"dir": (dst.position - start).normalized(), "on_hit": on_hit})


func _update_projectiles(dt: float) -> void:
	var i := 0
	var arr: Array = fx.projectiles
	while i < arr.size():
		var p: Dictionary = arr[i]
		var dst: Creature = p.dst
		if not is_instance_valid(dst) or not dst.alive:
			arr.remove_at(i)
			continue
		var to: Vector2 = dst.position + Vector2(0, -8)
		var dir: Vector2 = to - p.pos
		var stepd: float = p.speed * dt
		if dir.length() <= stepd:
			arr.remove_at(i)
			var src: Creature = p.src if is_instance_valid(p.src) else null
			if src:
				deal_damage(src, dst, p.power, p.ability)
			var cb: Callable = p.on_hit
			if cb.is_valid():
				cb.call()
			continue
		p.dir = dir.normalized()
		p.pos += p.dir * stepd
		i += 1


func use_ability(c: Creature, ab: Dictionary, tgt: Creature) -> void:
	var power := float(ab.power) * float(c.stats.get("ability_power_mult", 1.0))
	var col := DataDB.type_color(ab.type)
	var radius := int(ab.radius)
	match ab.kind:
		"strike":
			if tgt:
				deal_damage(c, tgt, power, true)
				fx.add_effect("slash", tgt.position, col, 0, 0.3, {"dir": (tgt.position - c.position).normalized()})
		"bolt":
			if tgt:
				launch_projectile(c, tgt, power, col, true)
		"burst", "ult":
			for h in hostiles_of(c).duplicate():
				if h.alive:
					var d: Vector2i = (h.cell - c.cell).abs()
					if max(d.x, d.y) <= radius:
						deal_damage(c, h, power, true)
			fx.add_effect("nova" if ab.kind == "ult" else "ring", c.position, col, (radius + 0.5) * TILE, 0.45)
		"blast":
			if tgt:
				var center := tgt.cell
				var pos := tgt.position
				launch_projectile(c, tgt, 0.0, col, true, func():
					_area_damage(c, center, radius, power)
					fx.add_effect("explosion", pos, col, (radius + 0.5) * TILE, 0.4))
		"dot":
			if tgt:
				dots.append({"src": c, "cell": tgt.cell, "radius": radius, "ticks": int(ab.get("ticks", 4)),
					"timer": 0.0, "power": power, "color": col, "pos": tgt.position})
		"heal":
			heal(c, c.max_hp * power)
			fx.add_effect("heal", c.position, Color(0.4, 1, 0.5), 0, 0.7)
	if not headless:
		fx.add_text(c.position + Vector2(0, -16), Loc.tx(ab.name), col.lightened(0.4), 9)


func _area_damage(src: Creature, center: Vector2i, radius: int, power: float) -> void:
	if not is_instance_valid(src):
		return
	for h in hostiles_of(src).duplicate():
		if h.alive:
			var d: Vector2i = (h.cell - center).abs()
			if max(d.x, d.y) <= radius:
				deal_damage(src, h, power, true)


func _update_dots(dt: float) -> void:
	var i := 0
	while i < dots.size():
		var d: Dictionary = dots[i]
		d.timer = float(d.timer) - dt
		if d.timer <= 0.0:
			d.timer = 1.0
			d.ticks = int(d.ticks) - 1
			if is_instance_valid(d.src):
				_area_damage(d.src, d.cell, d.radius, d.power)
			fx.add_effect("rain", d.pos, d.color, (int(d.radius) + 0.5) * TILE, 0.9)
		if int(d.ticks) <= 0:
			dots.remove_at(i)
		else:
			i += 1


# ------------------------------------------------------------------ morte, corpos e loot

func _on_death(c: Creature, killer: Creature) -> void:
	c.die()
	nav.release(c.cell, c)
	if c.is_player:
		_on_player_death(c)
		return
	enemies.erase(c)
	for p in party:
		if p.target == c:
			p.target = null
	# corpo fica no chão alguns segundos
	c.reparent(corpses_node)
	corpses.append({"node": c, "t": 0.0})
	if c.is_boss:
		_finish_challenge(true)
		return
	if mode != "hunt" or c.is_summon or Game == null:
		return
	var res: Dictionary = Game.on_kill(hunt, c.form_id, c.level, c.ticket, c.shiny, participants)
	var main: Creature = killer if killer and killer.is_player else (party[0] if not party.is_empty() else null)
	if main and not headless:
		var xp_main: float = res.xp[0] if not res.xp.is_empty() else 0.0
		fx.add_text(main.position + Vector2(0, -12), "+%d XP" % int(xp_main), Color(0.55, 0.85, 1.0), 10)
		fx.add_loot(c.position, main, Color(1, 0.85, 0.2))
		if not res.drop.is_empty():
			fx.add_loot(c.position, main, DataDB.rarity_color(res.drop.rarity))
	kill_reward.emit({"form": c.form_id, "level": c.level, "shiny": c.shiny, "drop": res.drop, "xp": res.xp})


func _update_corpses(dt: float) -> void:
	var dur := float(DataDB.config.combat.corpse_seconds)
	var i := 0
	while i < corpses.size():
		var co: Dictionary = corpses[i]
		co.t = float(co.t) + dt
		var n: Creature = co.node
		if float(co.t) > dur - 1.0:
			n.modulate.a = clampf(dur - float(co.t), 0.0, 1.0)
		if float(co.t) >= dur:
			n.queue_free()
			corpses.remove_at(i)
		else:
			i += 1


func _on_player_death(c: Creature) -> void:
	fallen[c.mon_uid] = true
	for e in enemies:
		if e.target == c:
			e.target = null
	if Game:
		Game.save.stats.deaths = int(Game.save.stats.get("deaths", 0)) + 1
	# substituto entra em campo
	_ensure_field()
	player_died.emit(c)
	if alive_on_field() > 0:
		return
	if mode != "hunt":
		_finish_challenge(false)
		return
	_team_revive_timer = float(DataDB.config.combat.revive_seconds)
	wipe_times.append(elapsed)
	var window := float(DataDB.config.combat.wipe_window_seconds)
	while not wipe_times.is_empty() and elapsed - float(wipe_times[0]) > window:
		wipe_times.pop_front()
	if Game:
		Game.save.stats.wipes = int(Game.save.stats.get("wipes", 0)) + 1
	party_wiped.emit(wipe_times.size())
	if wipe_times.size() >= int(DataDB.config.combat.wipe_suggest_count):
		wipe_times.clear()
		suggest_easier.emit()


## O time inteiro renasce junto (depois que todos caíram).
func _team_revive() -> void:
	_team_revive_timer = -1.0
	var where: Vector2i = map.start
	for c in party:
		nav.release(c.cell, c)
		c.queue_free()
	party.clear()
	fallen.clear()
	participants.clear()
	_spawn_point = where
	_ensure_field()
	for c in party:
		fx.add_effect("heal", c.position, Color(1, 1, 0.6), 0, 0.8)
	if not party.is_empty():
		_cam_target = party[0]


func revive_all_now() -> void:
	if mode != "hunt":
		return
	_team_revive()


func team_revive_remaining() -> float:
	return maxf(0.0, _team_revive_timer)


# ------------------------------------------------------------------ chefe / desafios

func is_danger(cell: Vector2i) -> bool:
	for d in dangers:
		if d.cells.has(cell):
			return true
	return false


func _update_boss(dt: float) -> void:
	if boss == null or not boss.alive:
		return
	if elapsed > float(challenge.get("time_limit", 240)):
		boss_message.emit(Loc.t("Tempo esgotado!"))
		_finish_challenge(false)
		return
	var mech: Dictionary = challenge.get("mechanics", {})
	for key in mech:
		var m: Dictionary = mech[key]
		boss_timers[key] = float(boss_timers.get(key, float(m.every) * 0.6)) - dt
		if float(boss_timers[key]) <= 0.0:
			boss_timers[key] = float(m.every)
			if key == "summon":
				_boss_summon(m)
			elif key == "aoe":
				_boss_aoe(m)
	var phases: Array = challenge.get("phases", [])
	if boss_phase < phases.size():
		var ph: Dictionary = phases[boss_phase]
		if boss.hp_ratio() <= float(ph.hp_below):
			boss_phase += 1
			boss.atk_mult *= float(ph.get("atk_mult", 1.0))
			boss.spd_mult *= float(ph.get("spd_mult", 1.0))
			boss_message.emit(Loc.tx(ph.get("say", "O chefe muda de fase!")))
			fx.add_effect("nova", boss.position, Color(1, 0.3, 0.2), TILE * 3, 0.8)


func _boss_summon(m: Dictionary) -> void:
	var alive_summons := 0
	for e in enemies:
		if e.is_summon and e.alive:
			alive_summons += 1
	if alive_summons >= 6:
		return
	for i in int(m.count):
		var cell := nav.nearest_free(boss.cell + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2)), 4)
		spawn_enemy(m.form, max(1, int(challenge.boss_level) - int(m.get("level_offset", 8))), cell, -1, true)
	boss_message.emit(Loc.t("%s invoca reforços!") % boss.display_name)


func _boss_aoe(m: Dictionary) -> void:
	var cells: Array = []
	var r := int(m.radius)
	var alive_party: Array = []
	for p in party:
		if p.alive:
			alive_party.append(p)
	if alive_party.is_empty():
		return
	for i in int(m.count):
		var p: Creature = alive_party[i % alive_party.size()]
		var center: Vector2i = p.cell + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := center + Vector2i(dx, dy)
				if nav.walkable(q) and not cells.has(q):
					cells.append(q)
	dangers.append({"cells": cells, "t": 0.0, "telegraph": float(m.telegraph), "dmg_pct": float(m.dmg_pct), "world": self})


func _update_dangers(dt: float) -> void:
	var i := 0
	while i < dangers.size():
		var d: Dictionary = dangers[i]
		d.t = float(d.t) + dt
		if float(d.t) >= float(d.telegraph):
			for p in party:
				if p.alive and d.cells.has(p.cell):
					deal_damage(boss, p, 0.0, true, p.max_hp * float(d.dmg_pct))
			for c in d.cells:
				if rng.randf() < 0.3:
					fx.add_effect("explosion", cell_center(c), Color(1, 0.4, 0.1), TILE * 0.6, 0.35)
			dangers.remove_at(i)
		else:
			i += 1


func _finish_challenge(won: bool) -> void:
	if finished:
		return
	finished = true
	challenge_finished.emit(won, elapsed)


# ------------------------------------------------------------------ debug

func debug_spawn(form_id: String, count := 1) -> void:
	if party.is_empty():
		return
	var lvl = int(hunt.get("level", party[0].level)) if mode == "hunt" else party[0].level
	for i in count:
		var cell := nav.nearest_free(party[0].cell + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4)), 6)
		spawn_enemy(form_id, lvl, cell, -1)


func alive_enemy_count() -> int:
	var n := 0
	for e in enemies:
		if e.alive:
			n += 1
	return n
