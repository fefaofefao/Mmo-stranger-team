extends Screen
## Seleção de hunts com estimativa de abates/XP por hora para o grupo atual.

## Abas: Mundo 1 dividido por nível (Iniciante até 40, Intermediário até 70, Avançado até 110), depois Mundos 2 e 3.
const CATS := ["iniciante", "intermediario", "avancado", "mundo2", "mundo3"]
var tab := -1
var type_filter := ""


func build() -> void:
	var b := make_layout(Loc.t("Hunts"), "map")
	if tab < 0:
		var cur: Dictionary = DataDB.hunts.get(Game.save.current_hunt, {})
		tab = maxi(0, CATS.find(_cat_of(cur))) if not cur.is_empty() else 0
	# mundos (cada um com o seu foco) e, no Mundo 1, as categorias
	var world := 3 if tab == 4 else (2 if tab == 3 else 1)
	var wrow := UI.hbox(6)
	b.add_child(wrow)
	for wi in 3:
		var wn := wi + 1
		var wl := Loc.t("Mundo %d") % wn
		var wb := UI.button(wl, func(): tab = [0, 3, 4][wn - 1]; rebuild(), 19, 58, "tab_on" if world == wn else "tab")
		wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not Game.world_unlocked(wn):
			wb.icon = Icons.tex("lock")
			wb.expand_icon = true
			wb.add_theme_constant_override("icon_max_width", 26)
		wrow.add_child(wb)
	if world == 1:
		b.add_child(tabs([Loc.t("Iniciante"), Loc.t("Intermediário"), Loc.t("Avançado")], tab, func(i): tab = i; rebuild()))
	var focus: String = [Loc.t("Mundo 1 · níveis 1 a 110 · 1 monstro em campo · Iniciante até 40, Intermediário até 70, Avançado até 110"), Loc.t("Mundo 2 (Abismo) · 110 a 210 · 2 monstros em campo · mais inimigos"), Loc.t("Mundo 3 (Reino Astral) · 210+ · 3 monstros em campo · hordas")][world - 1]
	b.add_child(UI.label(focus, 15, UI.C_MUTED, true))
	b.add_child(type_filter_bar(type_filter, func(t): type_filter = t; rebuild()))
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
	var locked_world := world >= 2 and not Game.world_unlocked(world)
	if locked_world:
		list.add_child(empty_note(Loc.t("O Mundo 2 é liberado ao derrotar o Chefe de Mundo do nível 110 (Desafios). Biomas do Abismo, mais monstros por mapa, sem recrutamento e drops exclusivos.") if world == 2
			else Loc.t("O Mundo 3 é liberado ao derrotar o Chefe de Mundo do nível 210 (Desafios). Reino Astral, hordas de monstros e os melhores drops."), "lock"))
	var cat: String = CATS[tab]
	var rec := Game.recommended_hunt()
	var shown := 0
	for h in DataDB.hunt_list:
		if _cat_of(h) == cat and (type_filter == "" or h.types.has(type_filter)):
			list.add_child(_hunt_row(h, fighters, main_lvl, rec))
			shown += 1
	if shown == 0 and not locked_world:
		list.add_child(empty_note(Loc.t("Nenhuma hunt de %s nesta aba. Tente outra aba ou tire o filtro.") % DataDB.type_name(type_filter), "map"))


## Aba de uma hunt: Mundo 1 vai pela faixa de nível, os outros mundos pela categoria.
static func _cat_of(h: Dictionary) -> String:
	if int(h.get("world", 1)) != 1:
		return h.get("category", "mundo2")
	var lvl := int(h.get("level", 1))
	return "iniciante" if lvl <= 40 else ("intermediario" if lvl <= 70 else "avancado")


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
