extends Screen
## Chefe Diário: um chefe por dia, 3 entradas. Recompensa proporcional ao dano; vitória garante item.

var status: Dictionary = {}


func build() -> void:
	var b := make_layout(Loc.t("Chefe Diário"), "crown")
	if status.is_empty():
		b.add_child(empty_note(Loc.t("Carregando..."), "clock"))
		_load()
		return
	if not status.get("ok", false):
		b.add_child(empty_note(Loc.t(status.get("error", "Indisponível")), "cross"))
		return
	var boss: Dictionary = status.boss
	var left := int(status.entries) - int(status.used)
	var hero := UI.panel("panel_gold")
	b.add_child(hero)
	var hv := UI.vbox(8)
	hero.add_child(hv)
	var pf := UI.portrait_frame(boss.form, false, 168)
	pf.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hv.add_child(pf)
	var t := UI.title(DataDB.form_name(boss.form), 34)
	hv.add_child(t)
	var pr := UI.hbox(6)
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.add_child(UI.type_badge(boss.type, 17))
	pr.add_child(UI.pill(Loc.t("Nv %d") % int(boss.level), UI.C_GOLD, 17))
	pr.add_child(UI.pill(Loc.t("Novo chefe em %s") % UI.fmt_time(float(status.resets_in)), UI.C_INFO, 17))
	hv.add_child(pr)
	var er := UI.hbox(6)
	er.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in int(status.entries):
		var ic := UI.icon("flame", 40)
		if i >= left:
			ic.modulate = Color(0.3, 0.3, 0.3, 0.7)
		er.add_child(ic)
	hv.add_child(er)
	var el := UI.label(Loc.t("Entradas hoje: %d de %d") % [left, int(status.entries)], 20, UI.C_TEXT)
	el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(el)
	var cfg: Dictionary = DataDB.config.daily_boss
	var rw := UI.card()
	b.add_child(rw)
	var rv := UI.vbox(4)
	rw.add_child(rv)
	rv.add_child(UI.section(Loc.t("Recompensas"), "chest"))
	var lvl := int(boss.level)
	rv.add_child(UI.label(Loc.t("• Até %s de ouro e %d Essência de %s (proporcional ao dano causado)") % [UI.fmt(float(cfg.gold_kills) * Formulas.gold_for_kill(lvl)), int(float(cfg.essence_base) + float(cfg.essence_per_level) * lvl), DataDB.type_name(boss.type)], 18, UI.C_TEXT, true))
	rv.add_child(UI.label(Loc.t("• Vitória: item garantido (Raro, chance de Épico e Lendário)"), 18, UI.C_TEXT, true))
	rv.add_child(UI.label(Loc.t("• Você leva pelo menos %d%% mesmo sem vencer") % int(float(cfg.min_reward_fraction) * 100), 18, UI.C_MUTED, true))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_child(sp)
	var go := UI.icon_button("sword", Loc.t("Enfrentar (%d/%d)") % [left, int(status.entries)], _start, 28, 88, "primary")
	go.disabled = left <= 0
	b.add_child(go)


func _load() -> void:
	status = await Game.daily_status()
	if status.is_empty():
		status = {"ok": false, "error": "Indisponível"}
	if is_inside_tree():
		rebuild()


func _start() -> void:
	var hs = main.ensure_hunt_screen()
	if hs.in_boss_fight():
		toast(Loc.t("Termine a luta atual primeiro."), UI.C_BAD)
		return
	var r: Dictionary = await Game.daily_start()
	if not r.get("ok", false):
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)
		return
	main.goto("hunt")
	hs.start_daily(r)
