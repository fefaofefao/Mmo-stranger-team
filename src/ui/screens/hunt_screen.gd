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
# painel de Marcos de Caça
var mastery_panel: PanelContainer
var m_port: TextureRect
var m_name: Label
var m_count: Label
var m_bar: ProgressBar
var m_next: Label
var m_earned: Label
var m_icon: TextureRect
var _m_form := ""
var _m_dirty := true


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	zoom = float(Game.save.settings.get("zoom", 2.0))
	_build()
	Game.feed.connect(_on_feed)
	Game.party_changed.connect(_on_party_changed)
	Game.monsters_changed.connect(rebuild_hud)
	Game.boosts_changed.connect(refresh_hud)
	Game.fighting_changed.connect(_on_party_changed)
	Game.wallet_changed.connect(_update_gold)
	Game.mastery_progress.connect(_on_mastery_progress)
	Game.mastery_reached.connect(_on_mastery_reached)
	load_current_hunt()


func in_challenge() -> bool:
	return mode == "challenge"


func in_boss_fight() -> bool:
	return mode != "hunt"


func _build() -> void:
	var root := UI.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_build_mastery(tv)
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
	var dc := CenterContainer.new()
	dc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dc)
	down_panel = UI.panel("toast")
	down_panel.visible = false
	dc.add_child(down_panel)
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


## Faixa com o Marco de Caça do monstro abatido por último: abates até o próximo marco,
## bônus que ele dá e bônus já conquistado. Tocar abre a lista das formas da hunt.
func _build_mastery(parent: Control) -> void:
	mastery_panel = UI.panel("inset")
	mastery_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	mastery_panel.gui_input.connect(_on_mastery_tap)
	parent.add_child(mastery_panel)
	var row := UI.hbox(8)
	mastery_panel.add_child(row)
	m_port = UI.tex(null, 40)
	row.add_child(m_port)
	var col := UI.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var r1 := UI.hbox(6)
	col.add_child(r1)
	r1.add_child(UI.icon("trophy", 20))
	m_name = UI.label("", 16, UI.C_GOLD)
	m_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_name.clip_text = true
	r1.add_child(m_name)
	m_count = UI.label("", 15, UI.C_TEXT)
	r1.add_child(m_count)
	m_bar = UI.bar(0.0, Color("#f4c542"), 200, 9)
	m_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(m_bar)
	var r2 := UI.hbox(8)
	col.add_child(r2)
	m_next = UI.label("", 14, UI.C_GOOD)
	m_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_next.clip_text = true
	r2.add_child(m_next)
	m_earned = UI.label("", 14, UI.C_MUTED)
	r2.add_child(m_earned)
	m_icon = UI.icon("heart", 34)
	row.add_child(m_icon)
	for c in [row, col, r1, r2]:
		_ignore_mouse(c)


func _on_mastery_progress(form_id: String) -> void:
	if mode != "hunt":
		return
	_m_form = form_id
	_m_dirty = true


func _on_mastery_reached(form_id: String, tier: int) -> void:
	if visible and mode == "hunt":
		var info := Mastery.form_info(form_id, Game.form_kills(form_id))
		main.toast(Loc.t("Marco %s atingido: %s!") % [Mastery.tier_name(tier), DataDB.form_name(form_id)] + "\n" + Loc.t("Bônus total desta forma: %s") % Mastery.fmt_bonus(info.stat, info.earned), Mastery.tier_color(tier), "trophy")


func _update_mastery() -> void:
	if not is_instance_valid(mastery_panel):
		return
	mastery_panel.visible = mode == "hunt"
	if mode != "hunt" or not _m_dirty:
		return
	_m_dirty = false
	var h: Dictionary = DataDB.hunts.get(Game.save.current_hunt, {})
	if _m_form == "" or not _hunt_has_form(h, _m_form):
		_m_form = h.monsters[0].form if not h.is_empty() else ""
	if _m_form == "":
		return
	var info := Mastery.form_info(_m_form, Game.form_kills(_m_form))
	m_port.texture = SpriteFactory.portrait(_m_form)
	m_icon.texture = Icons.tex(Mastery.stat_icon(info.stat))
	var tier: int = info.tier
	m_name.text = "%s · %s" % [DataDB.form_name(_m_form), Mastery.tier_name(tier) if tier > 0 else Loc.t("rumo ao Bronze")]
	m_name.add_theme_color_override("font_color", Mastery.tier_color(tier) if tier > 0 else UI.C_TEXT)
	m_bar.value = info.progress
	(m_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Mastery.tier_color(mini(tier + 1, 6))
	if info.max:
		m_count.text = Loc.t("%s abates · MÁX") % UI.fmt(info.kills)
		m_next.text = Loc.t("Todos os marcos conquistados!")
	else:
		m_count.text = "%s/%s" % [UI.fmt(info.kills), UI.fmt(info.next_at)]
		m_next.text = Loc.t("Próximo: %s") % Mastery.fmt_bonus(info.stat, info.next_gain)
	m_earned.text = Loc.t("Atual: %s") % Mastery.fmt_bonus(info.stat, info.earned) if tier > 0 else Loc.t("Atual: —")


func _hunt_has_form(h: Dictionary, fid: String) -> bool:
	for m in h.get("monsters", []):
		if m.form == fid:
			return true
	return false


func _on_mastery_tap(e: InputEvent) -> void:
	if not (e is InputEventMouseButton) or e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		_press_pos = e.position
		return
	if e.position.distance_to(_press_pos) > 24.0:
		return
	var h: Dictionary = DataDB.hunts.get(Game.save.current_hunt, {})
	var lines: Array = []
	var seen := {}
	for m in h.get("monsters", []):
		if seen.has(m.form):
			continue
		seen[m.form] = true
		var info := Mastery.form_info(m.form, Game.form_kills(m.form))
		var nxt: String = Loc.t("todos os marcos!") if info.max else Loc.t("%s abates → %s") % [UI.fmt(info.next_at), Mastery.fmt_bonus(info.stat, info.next_gain)]
		lines.append("%s — %s (%s)\n%s · %s" % [DataDB.form_name(m.form), Mastery.tier_name(info.tier), UI.fmt(info.kills), Loc.t("Atual: %s") % Mastery.fmt_bonus(info.stat, info.earned), Loc.t("Próximo: %s") % nxt])
	lines.append("")
	lines.append(Loc.t("Os marcos valem para a conta inteira. Veja o total na Coleção."))
	main.dialog(Loc.t("Marcos desta hunt"), "\n\n".join(lines), [Loc.t("OK")], "trophy")


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
	_m_form = ""
	_m_dirty = true
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
	var party := Game.party_monsters()
	for i in party.size():
		var m: Dictionary = party[i]
		var slot := i
		var tap := PanelContainer.new()
		tap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		tap.mouse_filter = Control.MOUSE_FILTER_STOP
		tap.gui_input.connect(func(e): _on_hud_tap(e, slot))
		hud_box.add_child(tap)
		var row := UI.hbox(8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tap.add_child(row)
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
		if mode == "hunt":
			var sw := UI.icon("swap", 28)
			sw.modulate = Color(1, 1, 1, 0.75)
			sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(sw)
		_ignore_mouse(row)
		hud_rows.append({"uid": m.uid, "name": nm, "status": st, "hp": hp, "xp": xp})
	refresh_hud()


func _ignore_mouse(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(c)


var _press_pos := Vector2.ZERO


## Tocar num monstro do HUD abre a troca rápida por um monstro do Depot.
func _on_hud_tap(e: InputEvent, slot: int) -> void:
	if not (e is InputEventMouseButton) or e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		_press_pos = e.position
		return
	if e.position.distance_to(_press_pos) > 24.0:
		return
	if mode != "hunt":
		main.toast(Loc.t("Não dá para trocar monstros durante a luta contra o chefe."), UI.C_BAD, "lock")
		return
	var party := Game.party_monsters()
	if slot >= party.size():
		return
	var cur: Dictionary = party[slot]
	var picker := MonsterPicker.open(main.overlay, Loc.t("Trocar %s") % MonsterLogic.display_name(cur), cur)
	var uid: String = await picker.chosen
	if uid == "":
		return
	Game.set_party_slot(slot, uid)
	main.toast(Loc.t("%s entrou no grupo!") % MonsterLogic.display_name(Game.monster(uid)), UI.C_GOOD, "swap")


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
	_update_mastery()
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
