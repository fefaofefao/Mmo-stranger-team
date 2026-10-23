class_name CreatureAI
extends RefCounted
## IA 100% automática. O jogador não controla nada: só define o comportamento (focar/espalhar).

const REPATH := 0.45
const GCD := 0.5


# ------------------------------------------------------------------ monstros do jogador

static func player_tick(w, c: Creature, dt: float) -> void:
	_cooldowns(c, dt)
	if c.moving:
		return
	# 1) sair de áreas de perigo (mecânicas de chefe)
	if w.is_danger(c.cell):
		var safe := _find_safe_cell(w, c)
		if safe != c.cell:
			_step_to(w, c, safe)
			return
	# 2) escolher alvo
	if not _valid_target(c):
		c.target = choose_player_target(w, c)
		c.path.clear()
	if c.target == null:
		_idle_wander(w, c, dt, true)
		return
	# 3) habilidades
	if c.gcd <= 0.0 and try_ability(w, c):
		return
	# 4) ataque básico ou aproximação
	var d := c.dist_to(c.target)
	if d <= c.attack_range():
		c.face_towards(c.target.cell)
		if c.attack_cd <= 0.0:
			basic_attack(w, c, c.target)
		return
	_chase(w, c, c.target.cell, dt)


static func choose_player_target(w, c: Creature) -> Creature:
	var enemies: Array = w.enemies
	if enemies.is_empty():
		return null
	var behavior: String = w.ai_behavior
	# focar: segue o alvo do líder
	if behavior == "focus" and c.party_index > 0:
		var leader: Creature = w.party[0] if not w.party.is_empty() else null
		if leader and leader.alive and _valid_target(leader):
			return leader.target
	# quem está me atacando tem prioridade (evita ficar cercado ignorando inimigos)
	var best: Creature = null
	var best_score := INF
	for e in enemies:
		if not e.alive or e.demo:
			continue
		var score := float(c.dist_to(e))
		if e.target == c and c.dist_to(e) <= 1:
			score -= 4.0
		if behavior == "spread":
			for p in w.party:
				if p != c and p.alive and p.target == e:
					score += 6.0
		if e.is_boss:
			score -= 1.0
		if score < best_score:
			best_score = score
			best = e
	return best


static func _valid_target(c: Creature) -> bool:
	return c.target != null and is_instance_valid(c.target) and c.target.alive


static func try_ability(w, c: Creature) -> bool:
	for ab_id in c.abilities:
		if float(c.ability_cd.get(ab_id, 0.0)) > 0.0:
			continue
		var ab: Dictionary = DataDB.abilities.get(ab_id, {})
		if ab.is_empty():
			continue
		var use := false
		var tgt: Creature = c.target
		match ab.target:
			"self":
				use = c.hp_ratio() < 0.55
			"self_area":
				var n: int = w.count_hostiles_near(c, c.cell, int(ab.radius))
				use = n >= (2 if ab.kind == "ult" else 1) or (n >= 1 and (tgt != null and tgt.is_boss))
			"enemy", "enemy_area":
				use = tgt != null and c.dist_to(tgt) <= max(int(ab.range), c.attack_range())
		if use:
			w.use_ability(c, ab, tgt)
			var cd := float(ab.cooldown) * float(c.stats.get("ability_cd_mult", 1.0))
			c.ability_cd[ab_id] = cd
			c.gcd = GCD
			c.play_attack()
			return true
	return false


static func basic_attack(w, c: Creature, t: Creature) -> void:
	c.attack_cd = c.attack_interval()
	c.play_attack()
	if c.attack_range() <= 1:
		w.deal_damage(c, t, 1.0, false)
		w.fx.add_effect("slash", t.position, Color(1, 1, 1), 0.0, 0.2, {"dir": (t.position - c.position).normalized()})
	else:
		w.launch_projectile(c, t, 1.0, DataDB.type_color(c.type_id).lightened(0.2))


static func _cooldowns(c: Creature, dt: float) -> void:
	c.attack_cd -= dt
	c.gcd -= dt
	c.path_timer -= dt
	for k in c.ability_cd:
		c.ability_cd[k] = float(c.ability_cd[k]) - dt


static func _chase(w, c: Creature, goal: Vector2i, dt: float) -> void:
	if c.path.is_empty() or c.path_timer <= 0.0 or c.path[c.path.size() - 1] != goal:
		c.path = w.nav.path(c.cell, goal, 0)
		c.path_timer = REPATH
	if c.path.is_empty():
		return
	var nxt: Vector2i = c.path[0]
	if nxt == goal and w.nav.occ.has(goal):
		# o alvo está lá: não dá para pisar, aguarda (ou já está no alcance)
		return
	if w.nav.is_free(nxt):
		c.path.remove_at(0)
		_step_to(w, c, nxt)
		c.blocked_timer = 0.0
	else:
		c.blocked_timer += dt
		if c.blocked_timer > 0.3:
			c.blocked_timer = 0.0
			c.path = w.nav.path(c.cell, goal, 4)
			c.path_timer = REPATH


static func _step_to(w, c: Creature, to: Vector2i) -> void:
	if not w.nav.is_free(to):
		return
	w.nav.release(c.cell, c)
	w.nav.occupy(to, c)
	c.start_move(to)


static func _find_safe_cell(w, c: Creature) -> Vector2i:
	var best := c.cell
	var best_d := 99
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := c.cell + Vector2i(dx, dy)
				if not w.nav.is_free(q) or w.is_danger(q):
					continue
				var d: int = max(abs(dx), abs(dy))
				if d < best_d:
					best_d = d
					best = q
		if best != c.cell:
			# devolve o primeiro passo em direção à célula segura
			var p: Array = w.nav.path(c.cell, best, 2)
			return p[0] if not p.is_empty() and w.nav.is_free(p[0]) else c.cell
	return c.cell


static func _idle_wander(w, c: Creature, dt: float, player: bool) -> void:
	c.wander_timer -= dt
	if c.wander_timer > 0.0:
		return
	c.wander_timer = randf_range(1.0, 2.5) if player else randf_range(2.0, 5.0)
	var opts: Array = w.nav.neighbors(c.cell)
	var radius := 8 if player else 3
	var valid: Array = []
	for q in opts:
		var d: Vector2i = (q - c.home).abs()
		if max(d.x, d.y) <= radius and w.nav.is_free(q):
			valid.append(q)
	if not valid.is_empty():
		_step_to(w, c, valid[randi() % valid.size()])


# ------------------------------------------------------------------ selvagens / chefe

static func enemy_tick(w, c: Creature, dt: float) -> void:
	if c.demo:
		return  # shiny do tutorial: só posa para a foto
	_cooldowns(c, dt)
	if c.moving:
		return
	var cb: Dictionary = DataDB.config.combat
	if not _valid_target(c):
		c.target = null
		var aggro := int(cb.aggro_range) + (99 if (c.is_boss or c.is_summon) else 0)
		var best: Creature = null
		var bd := 999
		for p in w.party:
			if not p.alive:
				continue
			var d := c.dist_to(p)
			if d <= aggro and d < bd:
				bd = d
				best = p
		c.target = best
		c.path.clear()
	if c.target == null:
		var dh: Vector2i = (c.cell - c.home).abs()
		if max(dh.x, dh.y) > 4:
			_chase(w, c, c.home, dt)
		else:
			_idle_wander(w, c, dt, false)
		return
	# coleira: não persegue longe demais do ponto de spawn
	var dhome: Vector2i = (c.cell - c.home).abs()
	if not c.is_boss and not c.is_summon and max(dhome.x, dhome.y) > int(cb.leash_range):
		c.target = null
		c.path.clear()
		return
	var d2 := c.dist_to(c.target)
	if d2 <= c.attack_range():
		c.face_towards(c.target.cell)
		if c.attack_cd <= 0.0:
			basic_attack(w, c, c.target)
		return
	_chase(w, c, c.target.cell, dt)
