extends Control
## Tela principal: mapa da hunt (SubViewport) + mini-HUD do grupo + feed de drops.
## Também roda os Desafios (modo "challenge").

var main
var world: HuntWorld
var viewport: SubViewport
var vp_container: SubViewportContainer
var hud_box: VBoxContainer
var hud_rows: Array = []
var feed_box: VBoxContainer
var title_label: Label
var info_label: Label
var boost_btn: Button
var revive_btn: Button
var boss_bar: ProgressBar
var boss_label: Label
var zoom := 2.0
var mode := "hunt"
var _challenge: Dictionary = {}
var _hud_timer := 0.0
var _suggest_open := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	zoom = float(Game.save.settings.get("zoom", 2.0))
	_build()
	Game.feed.connect(_on_feed)
	Game.party_changed.connect(_on_party_changed)
	Game.monsters_changed.connect(refresh_hud)
	Game.boosts_changed.connect(refresh_hud)
	load_current_hunt()


func in_challenge() -> bool:
	return mode == "challenge"


func _build() -> void:
	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# --- HUD superior
	var top := UI.panel(Color("#1f1c19"), Color("#5a4e3a"))
	root.add_child(top)
	var tv := UI.vbox(4)
	top.add_child(tv)
	var trow := UI.hbox(8)
	tv.add_child(trow)
	title_label = UI.label("", 22, UI.C_GOLD)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	trow.add_child(title_label)
	info_label = UI.label("", 20, UI.C_TEXT)
	trow.add_child(info_label)
	hud_box = UI.vbox(4)
	tv.add_child(hud_box)
	boss_label = UI.label("", 20, UI.C_BAD)
	boss_label.visible = false
	tv.add_child(boss_label)
	boss_bar = UI.bar(1.0, Color(0.85, 0.2, 0.2), 680, 16)
	boss_bar.visible = false
	tv.add_child(boss_bar)
	# --- mapa
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
	world.challenge_finished.connect(_on_challenge_finished)
	world.boss_message.connect(func(t): _on_feed(t, Color(1, 0.5, 0.3)))
	world.player_died.connect(func(_c): refresh_hud())
	world.party_updated.connect(_update_hud_values)
	# botões sobre o mapa (zoom)
	var zbox := UI.vbox(6)
	zbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	zbox.position = Vector2(-80, 8)
	vp_container.add_child(zbox)
	zbox.add_child(UI.button("+", func(): _set_zoom(zoom + 0.5), 28, 56))
	zbox.add_child(UI.button("−", func(): _set_zoom(zoom - 0.5), 28, 56))
	for b in zbox.get_children():
		b.custom_minimum_size = Vector2(64, 56)
		b.modulate = Color(1, 1, 1, 0.8)
	# --- painel inferior: feed + ações
	var bottom := UI.panel(Color("#1f1c19"), Color("#5a4e3a"))
	root.add_child(bottom)
	var bv := UI.vbox(6)
	bottom.add_child(bv)
	feed_box = UI.vbox(0)
	feed_box.custom_minimum_size = Vector2(0, 130)
	bv.add_child(feed_box)
	var actions := UI.hbox(8)
	bv.add_child(actions)
	actions.add_child(UI.expand(UI.button("Hub", func(): main.goto("hub"))))
	actions.add_child(UI.expand(UI.button("Hunts", func(): main.goto("hunts"))))
	actions.add_child(UI.expand(UI.button("Grupo", func(): main.goto("party"))))
	boost_btn = UI.expand(UI.button("2x XP ▶", _on_boost, 22))
	actions.add_child(boost_btn)
	revive_btn = UI.button("Reviver já ▶", _on_revive, 22)
	revive_btn.visible = false
	bv.add_child(revive_btn)


func set_map_rendering(on: bool) -> void:
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func on_show() -> void:
	set_map_rendering(true)
	refresh_hud()


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
	var h: Dictionary = DataDB.hunts.get(Game.save.current_hunt, {})
	if h.is_empty():
		h = Game.recommended_hunt()
		if h.is_empty():
			h = DataDB.hunt_list[0]
		Game.save.current_hunt = h.id
	world.setup_hunt(h, biome_override)
	world.camera.zoom = Vector2(zoom, zoom)
	boss_bar.visible = false
	boss_label.visible = false
	title_label.text = "%s · Nv %d" % [h.name, int(h.level)]
	if biome_override != "":
		title_label.text += " [%s]" % DataDB.biomes[biome_override].name
	rebuild_hud()


func start_challenge(c: Dictionary) -> void:
	await Game.flush_claims()
	mode = "challenge"
	_challenge = c
	Ads.context = "challenge"
	world.setup_challenge(c)
	world.camera.zoom = Vector2(zoom, zoom)
	title_label.text = "Desafio %d · %s" % [int(c.level), c.name]
	boss_bar.visible = true
	boss_label.visible = true
	revive_btn.visible = false
	rebuild_hud()


func _on_challenge_finished(won: bool, seconds: float) -> void:
	var c := _challenge
	var r: Dictionary = await Game.finish_challenge(c.id, won, seconds)
	Ads.context = ""
	var text := ""
	if won:
		if r.get("ok", false):
			var parts: Array = ["Tempo: %s" % UI.fmt_time(seconds), "Ouro: +%s" % UI.fmt(r.get("gold_gained", 0))]
			for t in r.get("essence_gained", {}):
				parts.append("Essência de %s: +%d" % [DataDB.type_name(t), int(r.essence_gained[t])])
			for it in r.get("items", []):
				parts.append("%s: %s" % [DataDB.rarity(it.rarity).name, ItemLogic.display_name(it)])
			if r.get("unlocks", "") == "world2" and r.get("first", false):
				parts.append("\nMUNDO 2 DESBLOQUEADO!")
			elif r.get("first", false):
				parts.append("\nNovo bloco de hunts desbloqueado!")
			text = "\n".join(parts)
		else:
			text = "Vitória, mas o servidor recusou: %s" % r.get("error", "?")
	else:
		text = "Seu grupo foi derrotado. Tente novamente em %ds ou fortaleça o grupo." % int(DataDB.challenge_fail_cooldown)
	var d: UIDialog = main.dialog("Vitória!" if won else "Derrota", text, ["OK"])
	await d.chosen
	load_current_hunt()


func _on_party_changed() -> void:
	if mode == "hunt" and world and not world.map.is_empty():
		world.refresh_party()
	rebuild_hud()


func rebuild_hud() -> void:
	UI.clear(hud_box)
	hud_rows.clear()
	var party := Game.party_monsters()
	var fighting := PartyLogic.fighting_count(Game.main_level(), party.size())
	for i in party.size():
		var m: Dictionary = party[i]
		var row := UI.hbox(8)
		hud_box.add_child(row)
		row.add_child(UI.portrait(MonsterLogic.form_id(m), bool(m.shiny), 48))
		var col := UI.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var nm := UI.label("%s  Nv %d%s" % [MonsterLogic.display_name(m), int(m.level), "" if i < fighting else "  (reserva 50%)"], 19,
			UI.C_TEXT if i < fighting else UI.C_MUTED)
		col.add_child(nm)
		var hp := UI.bar(1.0, Color(0.25, 0.8, 0.3), 400, 12)
		hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(hp)
		var xp := UI.bar(0.0, Color(0.35, 0.6, 1.0), 400, 8)
		xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(xp)
		hud_rows.append({"uid": m.uid, "name": nm, "hp": hp, "xp": xp, "fighting": i < fighting})
	refresh_hud()


func refresh_hud() -> void:
	if not is_instance_valid(info_label):
		return
	var boost := Game.xp_boost_remaining()
	boost_btn.text = ("2x XP %s" % UI.fmt_time(boost)) if boost > 0 else "2x XP ▶"
	info_label.text = "◉ %s" % UI.fmt(Game.save.gold + Game.pending_gold)
	for r in hud_rows:
		var m := Game.monster(r.uid)
		if m.is_empty():
			continue
		r.name.text = "%s  Nv %d%s" % [MonsterLogic.display_name(m), int(m.level), "" if r.fighting else "  (reserva 50%)"]
	_update_hud_values()


func _update_hud_values() -> void:
	if not visible:
		return
	var by_uid := {}
	for c in world.party:
		by_uid[c.mon_uid] = c
	var any_dead := false
	for r in hud_rows:
		var m := Game.monster(r.uid)
		if m.is_empty():
			continue
		var need := Formulas.xp_to_next(int(m.level))
		r.xp.value = float(m.xp) / need if need > 0 else 1.0
		var c: Creature = by_uid.get(r.uid)
		if c:
			r.hp.value = c.hp_ratio() if c.alive else 0.0
			if not c.alive:
				any_dead = true
				r.name.text = "%s  — revive em %ds" % [MonsterLogic.display_name(m), int(ceil(c.revive_timer))] if mode == "hunt" else "%s  — derrotado" % MonsterLogic.display_name(m)
			elif r.name.text.contains("revive em"):
				r.name.text = "%s  Nv %d" % [MonsterLogic.display_name(m), int(m.level)]
		else:
			r.hp.value = 1.0
	revive_btn.visible = any_dead and mode == "hunt"
	info_label.text = "◉ %s" % UI.fmt(Game.save.gold + Game.pending_gold)
	if mode == "challenge" and world.boss:
		boss_bar.value = world.boss.hp_ratio()
		boss_label.text = "%s  ·  %s / %s" % [world.boss.display_name, UI.fmt_time(world.elapsed), UI.fmt_time(float(_challenge.get("time_limit", 240)))]
	_hud_timer += 0.2
	if _hud_timer > 1.0:
		_hud_timer = 0.0
		var boost := Game.xp_boost_remaining()
		boost_btn.text = ("2x XP %s" % UI.fmt_time(boost)) if boost > 0 else "2x XP ▶"


func _on_feed(text: String, color: Color) -> void:
	var l := UI.label(text, 19, color)
	l.clip_text = true
	feed_box.add_child(l)
	while feed_box.get_child_count() > 5:
		var first := feed_box.get_child(0)
		feed_box.remove_child(first)
		first.queue_free()


func _on_kill_reward(info: Dictionary) -> void:
	if not info.drop.is_empty():
		var it: Dictionary = info.drop
		_on_feed("Coletado: %s (%s)" % [ItemLogic.display_name(it), DataDB.rarity(it.rarity).name], DataDB.rarity_color(it.rarity))


func _on_boost() -> void:
	if Game.xp_boost_active():
		main.toast("2x XP ativo por mais %s. Assistir de novo soma +30 min." % UI.fmt_time(Game.xp_boost_remaining()))
	var ok: bool = await Ads.show_rewarded("2x XP por 30 minutos")
	if ok:
		Game.grant_xp_boost()
		refresh_hud()


func _on_revive() -> void:
	var ok: bool = await Ads.show_rewarded("Reviver instantâneo")
	if ok:
		world.revive_all_now()
		refresh_hud()


func _on_suggest_easier() -> void:
	if _suggest_open:
		return
	var h := Game.suggest_easier_hunt(Game.save.current_hunt)
	if h.is_empty():
		main.toast("Seu grupo está sofrendo! Fortaleça-o com itens e Estrelas.", UI.C_BAD)
		return
	_suggest_open = true
	var go: bool = await main.confirm("Hunt difícil demais",
		"Seu grupo foi derrotado várias vezes seguidas.\nQuer ir para %s (nível %d)?" % [h.name, int(h.level)], "Ir", "Ficar")
	_suggest_open = false
	if go:
		await Game.set_current_hunt(h.id)
		load_current_hunt()
