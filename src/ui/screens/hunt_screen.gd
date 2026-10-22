extends Control
## Tela principal: mapa (SubViewport) + HUD do grupo + feed + navegação.
## Também roda Desafios ("challenge") e o Chefe Diário ("daily").

var main
var world: HuntWorld
var viewport: SubViewport
var vp_container: SubViewportContainer
var hud_box: VBoxContainer
var hud_rows: Array = []
var feed_box: VBoxContainer
var title_label: Label
var level_chip: PanelContainer
var gold_chip: PanelContainer
var boost_btn: Button
var boss_btn: Button
var down_panel: PanelContainer
var down_label: Label
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var boss_label: Label
var zoom := 2.0
var mode := "hunt"
var _challenge: Dictionary = {}
var _daily_token := ""
var _hud_timer := 0.0
var _suggest_open := false
var _suggest_mute_until := 0
var _daily_left := -1


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	zoom = float(Game.save.settings.get("zoom", 2.0))
	_build()
	Game.feed.connect(_on_feed)
	Game.party_changed.connect(_on_party_changed)
	Game.monsters_changed.connect(refresh_hud)
	Game.boosts_changed.connect(refresh_hud)
	Game.fighting_changed.connect(_on_party_changed)
	Game.wallet_changed.connect(_update_gold)
	load_current_hunt()


func in_challenge() -> bool:
	return mode == "challenge"


func in_boss_fight() -> bool:
	return mode != "hunt"


func _build() -> void:
	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# ---------------- HUD superior
	var top := UI.panel("hud")
	root.add_child(top)
	var tv := UI.vbox(6)
	top.add_child(tv)
	var trow := UI.hbox(8)
	tv.add_child(trow)
	trow.add_child(UI.icon("map", 30))
	title_label = UI.label("", 22, UI.C_GOLD)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	trow.add_child(title_label)
	level_chip = UI.chip("", "", UI.C_TEXT, 18)
	trow.add_child(level_chip)
	gold_chip = UI.chip("coin", "", UI.C_GOLD, 20)
	trow.add_child(gold_chip)
	hud_box = UI.vbox(4)
	tv.add_child(hud_box)
	boss_box = UI.vbox(2)
	boss_box.visible = false
	tv.add_child(boss_box)
	var brow := UI.hbox(6)
	boss_box.add_child(brow)
	brow.add_child(UI.icon("crown", 26))
	boss_label = UI.label("", 19, UI.C_BAD)
	boss_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_label.clip_text = true
	brow.add_child(boss_label)
	boss_bar = UI.bar(1.0, Color(0.85, 0.2, 0.2), 680, 18)
	boss_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_box.add_child(boss_bar)
	# ---------------- mapa
	vp_container = SubViewportContainer.new()
	vp_container.stretch = true
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(vp_container)
	viewport = SubViewport.new()
	viewport.handle_input_locally = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	vp_container.add_child(viewport)
	world = HuntWorld.new()
	viewport.add_child(world)
	world.kill_reward.connect(_on_kill_reward)
	world.suggest_easier.connect(_on_suggest_easier)
	world.challenge_finished.connect(_on_boss_finished)
	world.boss_message.connect(func(t): _on_feed(t, Color(1, 0.55, 0.35)))
	world.player_died.connect(func(_c): rebuild_hud())
	world.party_updated.connect(_update_hud_values)
	var zbox := UI.vbox(8)
	zbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	zbox.position = Vector2(-84, 10)
	vp_container.add_child(zbox)
	for z in [["plus", 0.5], ["minus", -0.5]]:
		var dz: float = z[1]
		var b := UI.icon_button(z[0], "", func(): _set_zoom(zoom + dz), 20, 60)
		b.custom_minimum_size = Vector2(68, 60)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.modulate = Color(1, 1, 1, 0.85)
		zbox.add_child(b)
	# aviso de time caído
	down_panel = UI.panel("toast")
	down_panel.visible = false
	down_panel.set_anchors_preset(Control.PRESET_CENTER)
	down_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	down_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	vp_container.add_child(down_panel)
	var dv := UI.vbox(8)
	down_panel.add_child(dv)
	var dh := UI.hbox(8)
	dh.alignment = BoxContainer.ALIGNMENT_CENTER
	dh.add_child(UI.icon("skull", 34))
	down_label = UI.label("", 22, UI.C_BAD)
	dh.add_child(down_label)
	dv.add_child(dh)
	dv.add_child(UI.icon_button("play", Loc.t("Reviver agora"), _on_revive, 22, 64, "ad"))
	# ---------------- painel inferior: feed + navegação
	var bottom := UI.panel("hud")
	root.add_child(bottom)
	var bv := UI.vbox(8)
	bottom.add_child(bv)
	var feed_panel := UI.panel("inset")
	feed_panel.custom_minimum_size = Vector2(0, 122)
	bv.add_child(feed_panel)
	feed_box = UI.vbox(0)
	feed_panel.add_child(feed_box)
	var nav := UI.hbox(6)
	bv.add_child(nav)
	nav.add_child(UI.tile_button("house", Loc.t("Hub"), func(): main.goto("hub"), 36, Vector2(0, 92)))
	nav.add_child(UI.tile_button("map", Loc.t("Hunts"), func(): main.goto("hunts"), 36, Vector2(0, 92)))
	nav.add_child(UI.tile_button("paw", Loc.t("Grupo"), func(): main.goto("party"), 36, Vector2(0, 92)))
	boss_btn = UI.tile_button("crown", Loc.t("Chefe"), func(): main.goto("daily"), 36, Vector2(0, 92))
	nav.add_child(boss_btn)
	boost_btn = UI.tile_button("play", "2x XP", _on_boost, 36, Vector2(0, 92), "ad")
	nav.add_child(boost_btn)


func set_map_rendering(on: bool) -> void:
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func on_show() -> void:
	set_map_rendering(true)
	refresh_hud()
	_refresh_daily_badge()


func _refresh_daily_badge() -> void:
	var r: Dictionary = await Game.daily_status()
	if r.get("ok", false):
		_daily_left = int(r.entries) - int(r.used)
		var l := _tile_label(boss_btn)
		if l:
			l.text = Loc.t("Chefe") + " %d/%d" % [_daily_left, int(r.entries)]


func _tile_label(b: Button) -> Label:
	for c in b.get_children():
		if c is VBoxContainer:
			for cc in c.get_children():
				if cc is Label:
					return cc
	return null


func _set_zoom(z: float) -> void:
	zoom = clampf(z, 1.0, 4.0)
	Game.save.settings.zoom = zoom
	if world and world.camera:
		world.camera.zoom = Vector2(zoom, zoom)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMagnifyGesture:
		_set_zoom(zoom * event.factor)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom + 0.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom - 0.25)


func load_current_hunt(biome_override := "") -> void:
	mode = "hunt"
	Ads.context = ""
	var h: Dictionary = DataDB.hunts.get(Game.save.current_hunt, {})
	if h.is_empty():
		h = Game.recommended_hunt()
		if h.is_empty():
			h = DataDB.hunt_list[0]
		Game.save.current_hunt = h.id
	world.setup_hunt(h, biome_override)
	world.camera.zoom = Vector2(zoom, zoom)
	boss_box.visible = false
	title_label.text = DataDB.hunt_name(h)
	if biome_override != "":
		title_label.text += " [%s]" % DataDB.biome_name(biome_override)
	(level_chip.find_child("Value", true, false) as Label).text = Loc.t("Nv %d") % int(h.level)
	level_chip.visible = true
	rebuild_hud()


func start_challenge(c: Dictionary) -> void:
	await Game.flush_claims()
	mode = "challenge"
	_challenge = c
	Ads.context = "challenge"
	world.setup_challenge(c)
	world.camera.zoom = Vector2(zoom, zoom)
	title_label.text = Loc.t("Desafio %d") % int(c.level)
	level_chip.visible = false
	boss_box.visible = true
	rebuild_hud()


func start_daily(start: Dictionary) -> void:
	await Game.flush_claims()
	mode = "daily"
	_daily_token = start.token
	_challenge = {"time_limit": float(DataDB.config.daily_boss.time_limit)}
	Ads.context = "challenge"
	world.setup_daily(start.boss)
	world.camera.zoom = Vector2(zoom, zoom)
	title_label.text = Loc.t("Chefe Diário")
	level_chip.visible = false
	boss_box.visible = true
	rebuild_hud()


func _on_boss_finished(won: bool, seconds: float) -> void:
	if mode == "daily":
		await _finish_daily(won, seconds)
		return
	var c := _challenge
	var r: Dictionary = await Game.finish_challenge(c.id, won, seconds)
	Ads.context = ""
	var text := ""
	if won:
		if r.get("ok", false):
			var parts: Array = [Loc.t("Tempo: %s") % UI.fmt_time(seconds), Loc.t("Ouro: +%s") % UI.fmt(r.get("gold_gained", 0))]
			for t in r.get("essence_gained", {}):
				parts.append(Loc.t("Essência de %s: +%d") % [DataDB.type_name(t), int(r.essence_gained[t])])
			for it in r.get("items", []):
				parts.append("%s: %s" % [DataDB.rarity_name(it.rarity), ItemLogic.display_name(it)])
			if r.get("unlocks", "") == "world2" and r.get("first", false):
				parts.append("\n" + Loc.t("MUNDO 2 DESBLOQUEADO!"))
			elif r.get("first", false):
				parts.append("\n" + Loc.t("Novo bloco de hunts desbloqueado!"))
			text = "\n".join(parts)
		else:
			text = Loc.t("Vitória, mas o servidor recusou: %s") % r.get("error", "?")
	else:
		text = Loc.t("Seu grupo foi derrotado. Tente de novo em %ds ou fortaleça o grupo.") % int(DataDB.challenge_fail_cooldown)
	var d: UIDialog = main.dialog(Loc.t("Vitória!") if won else Loc.t("Derrota"), text, [Loc.t("OK")], "trophy" if won else "skull")
	await d.chosen
	load_current_hunt()


func _finish_daily(won: bool, seconds: float) -> void:
	var frac := world.boss_damage_fraction()
	var r: Dictionary = await Game.daily_claim(_daily_token, frac, seconds, won)
	Ads.context = ""
	var lines: Array = []
	if r.get("ok", false):
		lines.append(Loc.t("Dano causado: %d%%") % int(round(float(r.fraction) * 100.0)))
		lines.append(Loc.t("Ouro: +%s") % UI.fmt(r.gold_gained))
		lines.append(Loc.t("Essência de %s: +%d") % [DataDB.type_name(r.essence_type), int(r.essence_gained)])
		for it in r.get("items", []):
			lines.append("%s: %s" % [DataDB.rarity_name(it.rarity), ItemLogic.display_name(it)])
	else:
		lines.append(str(r.get("error", "?")))
	var d: UIDialog = main.dialog(Loc.t("Chefe derrotado!") if r.get("won", false) else Loc.t("Fim da batalha"), "\n".join(lines), [Loc.t("OK")], "crown")
	await d.chosen
	load_current_hunt()
	_refresh_daily_badge()


func _on_party_changed() -> void:
	if mode == "hunt" and world and not world.map.is_empty():
		world.refresh_party()
	rebuild_hud()


func rebuild_hud() -> void:
	UI.clear(hud_box)
	hud_rows.clear()
	for m in Game.party_monsters():
		var row := UI.hbox(8)
		hud_box.add_child(row)
		row.add_child(UI.portrait_frame(MonsterLogic.form_id(m), bool(m.shiny), 40))
		var col := UI.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var nrow := UI.hbox(6)
		col.add_child(nrow)
		var nm := UI.label("", 18, UI.C_TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nrow.add_child(nm)
		var st := UI.label("", 15, UI.C_MUTED)
		nrow.add_child(st)
		var hp := UI.bar(1.0, Color(0.3, 0.82, 0.32), 300, 12)
		hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(hp)
		var xp := UI.bar(0.0, Color(0.38, 0.62, 1.0), 300, 7)
		xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(xp)
		hud_rows.append({"uid": m.uid, "name": nm, "status": st, "hp": hp, "xp": xp})
	refresh_hud()


func refresh_hud() -> void:
	if not is_instance_valid(gold_chip):
		return
	_update_gold()
	_update_boost()
	_update_hud_values()


func _update_gold() -> void:
	if is_instance_valid(gold_chip):
		(gold_chip.find_child("Value", true, false) as Label).text = UI.fmt(Game.save.gold + Game.pending_gold)


func _update_boost() -> void:
	var l := _tile_label(boost_btn)
	if l == null:
		return
	var boost := Game.xp_boost_remaining()
	l.text = UI.fmt_time(boost) if boost > 0 else "2x XP"


func _update_hud_values() -> void:
	if not visible:
		return
	for r in hud_rows:
		var m := Game.monster(r.uid)
		if m.is_empty():
			continue
		r.name.text = "%s · %s" % [MonsterLogic.display_name(m), Loc.t("Nv %d") % int(m.level)]
		var need := Formulas.xp_to_next(int(m.level))
		r.xp.value = float(m.xp) / need if need > 0 else 1.0
		var c: Creature = world.creature_for(r.uid)
		if world.fallen.has(r.uid):
			r.hp.value = 0.0
			r.status.text = Loc.t("Caído")
			r.status.add_theme_color_override("font_color", UI.C_BAD)
		elif c and c.alive:
			r.hp.value = c.hp_ratio()
			r.status.text = Loc.t("Em campo")
			r.status.add_theme_color_override("font_color", UI.C_GOOD)
		else:
			r.hp.value = 1.0
			r.status.text = Loc.t("Reserva")
			r.status.add_theme_color_override("font_color", UI.C_MUTED)
	var revive := world.team_revive_remaining()
	down_panel.visible = mode == "hunt" and revive > 0.0
	if down_panel.visible:
		down_label.text = Loc.t("Time caído! Renasce em %ds") % int(ceil(revive))
	_update_gold()
	if mode != "hunt" and world.boss:
		boss_bar.value = world.boss.hp_ratio()
		boss_label.text = "%s · %s / %s" % [world.boss.display_name, UI.fmt_time(world.elapsed), UI.fmt_time(float(_challenge.get("time_limit", 240)))]
	_hud_timer += 0.2
	if _hud_timer > 1.0:
		_hud_timer = 0.0
		_update_boost()


func _on_feed(text: String, color: Color) -> void:
	var row := UI.hbox(6)
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var l := UI.label(text, 18, color)
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	feed_box.add_child(row)
	while feed_box.get_child_count() > 4:
		var first := feed_box.get_child(0)
		feed_box.remove_child(first)
		first.queue_free()
	var n := feed_box.get_child_count()
	for i in n:
		(feed_box.get_child(i) as Control).modulate.a = 0.55 + 0.45 * float(i + 1) / n


func _on_kill_reward(info: Dictionary) -> void:
	if not info.drop.is_empty():
		var it: Dictionary = info.drop
		_on_feed(Loc.t("Coletado: %s") % ItemLogic.display_name(it), DataDB.rarity_color(it.rarity))


func _on_boost() -> void:
	if Game.xp_boost_active():
		main.toast(Loc.t("2x XP ativo por mais %s. Assistir de novo soma +30 min.") % UI.fmt_time(Game.xp_boost_remaining()), UI.C_INFO, "clock")
	var ok: bool = await Ads.show_rewarded(Loc.t("2x XP por 30 minutos"))
	if ok:
		Game.grant_xp_boost()
		refresh_hud()


func _on_revive() -> void:
	var ok: bool = await Ads.show_rewarded(Loc.t("Reviver instantâneo"))
	if ok:
		world.revive_all_now()
		rebuild_hud()


func _on_suggest_easier() -> void:
	if _suggest_open or Time.get_ticks_msec() < _suggest_mute_until:
		return
	var h := Game.suggest_easier_hunt(Game.save.current_hunt)
	if h.is_empty():
		main.toast(Loc.t("Seu grupo está sofrendo! Fortaleça-o com itens e Estrelas."), UI.C_BAD, "skull")
		_suggest_mute_until = Time.get_ticks_msec() + 60000
		return
	_suggest_open = true
	var go: bool = await main.confirm(Loc.t("Hunt difícil demais"),
		Loc.t("Seu grupo caiu várias vezes seguidas.\nQuer ir para %s (nível %d)?") % [DataDB.hunt_name(h), int(h.level)], Loc.t("Ir"), Loc.t("Ficar"))
	_suggest_open = false
	if go:
		await Game.set_current_hunt(h.id)
		load_current_hunt()
	else:
		# o jogador quer ficar: não perguntar de novo por 60 s
		_suggest_mute_until = Time.get_ticks_msec() + 60000
