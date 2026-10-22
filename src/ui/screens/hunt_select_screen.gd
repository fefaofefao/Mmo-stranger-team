extends Screen
## Seleção de hunts com estimativa de abates/XP por hora para o grupo atual.

const CATS := ["filhote", "adolescente", "adulto", "mista", "mundo2"]
var tab := -1
var type_filter := ""


func build() -> void:
	var b := make_layout(Loc.t("Hunts"), "map")
	if tab < 0:
		var cur: Dictionary = DataDB.hunts.get(Game.save.current_hunt, {})
		tab = maxi(0, CATS.find(cur.get("category", "filhote")))
	b.add_child(tabs([Loc.t("Filhotes"), Loc.t("Adolesc."), Loc.t("Adultos"), Loc.t("Mistas"), Loc.t("Mundo 2")], tab, func(i): tab = i; rebuild()))
	b.add_child(_type_filter())
	var fighters := Game.fighter_stats()
	var main_lvl := Game.main_level()
	var info := UI.hbox(8)
	info.add_child(UI.chip("paw", Loc.t("Principal Nv %d") % main_lvl, UI.C_TEXT, 18))
	info.add_child(UI.chip("sword", Loc.t("Em campo: %d") % fighters.size(), UI.C_TEXT, 18))
	if Game.xp_boost_active():
		info.add_child(UI.chip("play", "2x XP", UI.C_GOOD, 18))
	b.add_child(info)
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	var list: VBoxContainer = sc[1]
	if tab == 4 and not Game.world2_unlocked():
		list.add_child(empty_note(Loc.t("O Mundo 2 é desbloqueado ao vencer o Desafio de nível 80: biomas corrompidos, grupos mistos, sem recrutamento e drops exclusivos."), "lock"))
	var cat: String = CATS[tab]
	var rec := Game.recommended_hunt()
	var shown := 0
	for h in DataDB.hunt_list:
		if h.category == cat and (type_filter == "" or h.types.has(type_filter)):
			list.add_child(_hunt_row(h, fighters, main_lvl, rec))
			shown += 1
	if shown == 0 and not (tab == 4 and not Game.world2_unlocked()):
		list.add_child(empty_note(Loc.t("Nenhuma hunt de %s nesta aba. Tente outra aba ou tire o filtro.") % DataDB.type_name(type_filter), "map"))


## Barra com os 9 tipos: tocar filtra as hunts que têm monstros daquele tipo.
func _type_filter() -> Control:
	var row := UI.hbox(4)
	var all := UI.button(Loc.t("Todos"), func(): type_filter = ""; rebuild(), 16, 58, "tab_on" if type_filter == "" else "tab")
	all.custom_minimum_size = Vector2(84, 58)
	row.add_child(all)
	for t in DataDB.type_ids:
		var tid: String = t
		var on := type_filter == tid
		var b := UI.button("", func(): type_filter = "" if type_filter == tid else tid; rebuild(), 16, 58, "tab_on" if on else "tab")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58)
		b.tooltip_text = DataDB.type_name(tid)
		var ic := UI.icon("t_" + tid, 38)
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 4
		ic.offset_right = -4
		ic.offset_top = 6
		ic.offset_bottom = -6
		if type_filter != "" and not on:
			ic.modulate = Color(1, 1, 1, 0.45)
		b.add_child(ic)
		if on:
			var sb := StyleBoxFlat.new()
			sb.bg_color = DataDB.type_color(tid).darkened(0.55)
			sb.border_color = DataDB.type_color(tid)
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(6)
			for st in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(st, sb)
		row.add_child(b)
	return row


func _hunt_row(h: Dictionary, fighters: Array, main_lvl: int, rec: Dictionary) -> Control:
	var current: bool = h.id == Game.save.current_hunt
	var lock := Game.hunt_lock_reason(h)
	var p := UI.card(current, lock != "")
	var v := UI.vbox(6)
	p.add_child(v)
	var top := UI.hbox(8)
	v.add_child(top)
	var forms := {}
	for m in h.monsters:
		forms[m.form] = true
	var pics := UI.hbox(2)
	for fid in forms.keys().slice(0, 3):
		var c: Dictionary = Game.save.collection.get(fid, {})
		pics.add_child(UI.portrait_frame(fid, false, 44, c.get("seen", false)))
	top.add_child(pics)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var nrow := UI.hbox(6)
	info.add_child(nrow)
	var nl := UI.label(DataDB.hunt_name(h), 22, UI.C_GOLD if current else UI.C_TEXT)
	nl.clip_text = true
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrow.add_child(nl)
	nrow.add_child(UI.pill(Loc.t("Nv %d") % int(h.level), UI.C_GOLD, 16))
	var trow := UI.hbox(4)
	info.add_child(trow)
	for t in h.types:
		trow.add_child(UI.icon("t_" + t, 26))
	var bl := UI.label(DataDB.biome_name(h.biome), 15, UI.C_MUTED)
	bl.clip_text = true
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(bl)
	if not rec.is_empty() and rec.id == h.id and not current:
		trow.add_child(UI.pill(Loc.t("Recomendada"), UI.C_GOOD, 14))
	var row := UI.hbox(8)
	v.add_child(row)
	if lock == "":
		var est := KillRate.estimate(fighters, h)
		var xph := KillRate.xp_per_hour(fighters, h, main_lvl) * Game.xp_boost_mult()
		var stats := UI.label(Loc.t("%s abates/h · %s XP/h") % [UI.fmt(est.kills_per_hour), UI.fmt(xph)], 17, UI.C_TEXT)
		stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.clip_text = true
		row.add_child(stats)
		var dg := _danger(est)
		row.add_child(UI.pill(dg[0], dg[1], 15))
		if current:
			row.add_child(UI.pill(Loc.t("Caçando"), UI.C_GOLD, 16))
		else:
			var go := UI.small_button(Loc.t("Caçar"), func(): _go(h), "primary")
			go.custom_minimum_size = Vector2(120, 52)
			row.add_child(go)
	else:
		row.add_child(UI.icon("lock", 26))
		row.add_child(UI.label(lock, 18, UI.C_BAD))
	return p


func _danger(est: Dictionary) -> Array:
	var d: float = est.deaths_per_hour
	if est.kills_per_hour < 60:
		return [Loc.t("Perigosa"), UI.C_BAD]
	if d > 12:
		return [Loc.t("Arriscada"), Color("#ff9a4a")]
	if d > 3:
		return [Loc.t("Desafiadora"), Color("#ffd24a")]
	return [Loc.t("Segura"), UI.C_GOOD]


func _go(h: Dictionary) -> void:
	var hs = main.ensure_hunt_screen()
	if hs.in_boss_fight():
		toast(Loc.t("Termine a luta contra o chefe primeiro."), UI.C_BAD)
		return
	await Game.set_current_hunt(h.id)
	hs.load_current_hunt()
	main.goto("hunt")
