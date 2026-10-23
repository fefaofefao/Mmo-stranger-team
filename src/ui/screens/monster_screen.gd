extends Screen
## Detalhes do monstro: status, qualidade, equipamentos, estrelas, habilidades e IA.

var uid := ""
var choosing_slot := ""

const SLOT_ICONS := {"amuleto": "heart", "garra": "sword", "armadura": "chest", "reliquia": "gem"}


func build() -> void:
	uid = params.get("uid", "")
	var m := Game.monster(uid)
	var b := make_layout(Loc.t("Monstro"), "paw")
	if m.is_empty():
		b.add_child(empty_note(Loc.t("Monstro não encontrado.")))
		return
	var sc := UI.scroll(10)
	b.add_child(sc[0])
	var v: VBoxContainer = sc[1]
	var fid := MonsterLogic.form_id(m)
	var fam: Dictionary = DataDB.families[m.family]
	var head := UI.panel("panel_gold")
	v.add_child(head)
	var hr := UI.hbox(12)
	head.add_child(hr)
	hr.add_child(UI.monster_frame(m, 132))
	var hv := UI.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(hv)
	hv.add_child(UI.label(MonsterLogic.display_name(m), 30, Color(1, 0.88, 0.45) if m.shiny else UI.C_GOLD))
	var pills := UI.hbox(4)
	pills.add_child(UI.type_badge(fam.type, 16))
	pills.add_child(UI.pill([Loc.t("Filhote"), Loc.t("Adolescente"), Loc.t("Adulto")][int(m.stage) - 1], UI.C_INFO, 16))
	pills.add_child(UI.pill(StarterStyle.name(fam.style), UI.C_MUTED, 16))
	hv.add_child(pills)
	var need := Formulas.xp_to_next(int(m.level))
	hv.add_child(UI.label(Loc.t("Nível %d · XP %s / %s") % [int(m.level), UI.fmt(m.xp), UI.fmt(need)], 19))
	var xb := UI.bar(float(m.xp) / max(1, need), Color(0.38, 0.62, 1.0), 300, 12)
	xb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(xb)
	var qrow := UI.hbox(6)
	hv.add_child(qrow)
	qrow.add_child(UI.label(Loc.t("Qualidade"), 18, UI.C_MUTED))
	var qb := UI.bar(int(m.get("quality", 0)) / 100.0, MonsterLogic.quality_color(m), 120, 12)
	qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qrow.add_child(qb)
	qrow.add_child(UI.quality_badge(m, 15))
	if int(m.stage) < 3:
		var ev := MonsterLogic.evo_levels(m.family)
		hv.add_child(UI.label(Loc.t("Evolui para %s no nível %d") % [DataDB.form_name(DataDB.form_for_stage(m.family, int(m.stage) + 1)), int(ev[int(m.stage) - 1])], 17, UI.C_MUTED))
	v.add_child(UI.label(DataDB.form_desc(fid), 20, UI.C_TEXT, true))
	# atributos
	v.add_child(UI.section(Loc.t("Atributos"), "sword"))
	var st := Game.monster_stats(m)
	var g := UI.grid(3, 6)
	v.add_child(g)
	for pair in [["HP", int(st.hp)], [Loc.t("Ataque"), int(st.atk)], [Loc.t("Defesa"), int(st.def)], [Loc.t("Velocidade"), int(st.spd)],
			[Loc.t("Alcance"), int(st.rng)], [Loc.t("Crítico"), "%d%%" % int(st.crit * 100)], [Loc.t("Roubo de vida"), "%d%%" % int(st.lifesteal * 100)],
			[Loc.t("Bônus XP"), "%d%%" % int(st.xp_pct)], [Loc.t("Poder"), MonsterLogic.power(st)]]:
		var c := UI.card()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UI.vbox(0)
		c.add_child(cv)
		cv.add_child(UI.label(str(pair[0]), 15, UI.C_MUTED))
		cv.add_child(UI.label(str(pair[1]), 22, UI.C_TEXT))
		g.add_child(c)
	# estrelas
	v.add_child(UI.section(Loc.t("Estrelas"), "star"))
	var srow := UI.hbox(10)
	v.add_child(srow)
	srow.add_child(UI.stars(int(m.stars), 34))
	v.add_child(UI.label(Loc.t("Cada estrela: +%d%% atributos. 3ª e 5ª estrelas: habilidades +%d%% de poder e −%d%% de recarga.") % [
		int(float(DataDB.config.stars.stat_bonus_per_star) * 100), int(float(DataDB.config.stars.ability_power_per_upgrade) * 100),
		int(float(DataDB.config.stars.ability_cd_per_upgrade) * 100)], 17, UI.C_MUTED, true))
	var cost := EssenceLogic.star_cost(m)
	if cost > 0:
		var m2: Dictionary = m.duplicate(true)
		m2.stars = int(m.stars) + 1
		var st2 := Game.monster_stats(m2)
		v.add_child(UI.label(Loc.t("Próxima estrela: HP %d → %d · Ataque %d → %d · Defesa %d → %d") % [int(st.hp), int(st2.hp), int(st.atk), int(st2.atk), int(st.def), int(st2.def)], 16, UI.C_GOOD, true))
		var t: String = fam.type
		var have := int(Game.save.essences.get(t, 0))
		var sb := UI.icon_button("star", Loc.t("Adicionar estrela · %d de %d Essência de %s") % [cost, have, DataDB.type_name(t)], _buy_star, 19, 64, "primary")
		sb.disabled = have < cost
		v.add_child(sb)
	# treino com ouro
	v.add_child(UI.section(Loc.t("Treino"), "bolt"))
	var tc: Dictionary = DataDB.config.train
	var tr := int(m.get("train", 0))
	var tcard := UI.card(MonsterLogic.glow_tier(m) > 0)
	v.add_child(tcard)
	var tv := UI.vbox(6)
	tcard.add_child(tv)
	var trow := UI.hbox(8)
	tv.add_child(trow)
	var tl := UI.label(Loc.t("Treino +%d/%d") % [tr, int(tc.max)], 22, UI.C_GOLD)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(tl)
	var gt := MonsterLogic.glow_tier(m)
	if gt > 0:
		trow.add_child(UI.pill([Loc.t("Brilho"), Loc.t("Brilho intenso"), Loc.t("Radiante")][gt - 1], UI.glow_color(fam.type, gt), 16))
	var tb := UI.bar(float(tr) / float(tc.max), Color("#f4c542"), 300, 12)
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(tb)
	tv.add_child(UI.label(Loc.t("Atual: +%d%% Ataque e Defesa, +%d%% Vida. Brilho em +%d, intenso em +%d e radiante em +%d.") % [
		int(round(float(tc.atk_def_per_level) * tr * 100)), int(round(float(tc.hp_per_level) * tr * 100)),
		int(tc.glow_levels[0]), int(tc.glow_levels[1]), int(tc.glow_levels[2])], 16, UI.C_MUTED, true))
	if tr < int(tc.max):
		var m3: Dictionary = m.duplicate(true)
		m3.train = tr + 1
		var st3 := Game.monster_stats(m3)
		tv.add_child(UI.label(Loc.t("Próximo treino: Ataque %d → %d · Defesa %d → %d · HP %d → %d") % [int(st.atk), int(st3.atk), int(st.def), int(st3.def), int(st.hp), int(st3.hp)], 16, UI.C_GOOD, true))
		var tcost := Game.train_cost(m)
		var tbtn := UI.icon_button("coin", Loc.t("Treinar (+%d%% ATQ/DEF) · %s") % [int(round(float(tc.atk_def_per_level) * 100)), UI.fmt(tcost)], _train, 19, 64, "primary")
		tbtn.disabled = Game.save.gold < tcost
		tv.add_child(tbtn)
	# equipamentos
	v.add_child(UI.section(Loc.t("Equipamentos"), "bag"))
	for s in DataDB.item_slots:
		v.add_child(_slot_row(m, s))
	if choosing_slot != "":
		_item_picker(v, m)
	# habilidades
	v.add_child(UI.section(Loc.t("Habilidades (usadas pela IA)"), "bolt"))
	var kinds := {"strike": Loc.t("golpe forte"), "bolt": Loc.t("projétil"), "burst": Loc.t("área ao redor"), "blast": Loc.t("explosão no alvo"),
		"heal": Loc.t("cura própria"), "dot": Loc.t("dano contínuo em área"), "ult": Loc.t("suprema em área")}
	for ab_id in DataDB.form(fid).abilities:
		var ab: Dictionary = DataDB.abilities[ab_id]
		var c := UI.card()
		var cv := UI.vbox(2)
		c.add_child(cv)
		cv.add_child(UI.label(DataDB.ability_name(ab_id), 20, DataDB.type_color(ab.type).lightened(0.3)))
		cv.add_child(UI.label(Loc.t("%s · poder %.1fx · recarga %.0fs") % [kinds.get(ab.kind, ab.kind), float(ab.power) * st.ability_power_mult, float(ab.cooldown) * st.ability_cd_mult]
			+ ((" · " + Loc.t("raio %d") % int(ab.radius)) if int(ab.radius) > 0 else ""), 16, UI.C_MUTED, true))
		v.add_child(c)
	v.add_child(UI.section(Loc.t("Comportamento da IA"), "gear"))
	var row := UI.hbox(8)
	v.add_child(row)
	for opt in [["focus", Loc.t("Focar o mesmo alvo")], ["spread", Loc.t("Espalhar alvos")]]:
		var key: String = opt[0]
		var btn := UI.button(opt[1], func(): Game.set_ai_behavior(key); rebuild(), 19, 60, "tab_on" if Game.save.ai_behavior == key else "tab")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)


func _slot_row(m: Dictionary, s: Dictionary) -> Control:
	var p := UI.card()
	var row := UI.hbox(8)
	p.add_child(row)
	row.add_child(UI.icon(SLOT_ICONS.get(s.id, "gem"), 36))
	var iu: String = m.equip.get(s.id, "")
	var it: Dictionary = Game.save.items.get(iu, {})
	var col := UI.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UI.label(Loc.tx(s.name), 15, UI.C_MUTED))
	var l := UI.label(Loc.t("vazio") if it.is_empty() else ItemLogic.display_name(it), 19, UI.C_MUTED if it.is_empty() else DataDB.rarity_color(it.rarity))
	l.clip_text = true
	col.add_child(l)
	var sid: String = s.id
	row.add_child(UI.small_button(Loc.t("Trocar"), func(): choosing_slot = sid; rebuild()))
	if not it.is_empty():
		row.add_child(UI.small_button(Loc.t("Tirar"), func(): Game.unequip(uid, sid); rebuild()))
	return p


func _item_picker(v: VBoxContainer, m: Dictionary) -> void:
	var p := UI.panel("panel_gold")
	v.add_child(p)
	var pv := UI.vbox(6)
	p.add_child(pv)
	var top := UI.hbox()
	pv.add_child(top)
	top.add_child(UI.expand(UI.label(Loc.t("Escolher: %s") % ItemLogic.slot_name(choosing_slot), 22, UI.C_GOLD)))
	top.add_child(UI.small_button(Loc.t("Fechar"), func(): choosing_slot = ""; rebuild()))
	var items: Array = []
	for it in Game.inv_items():
		if ItemLogic.base(it).slot == choosing_slot:
			items.append(it)
	items.sort_custom(func(a, b): return ItemLogic.power_score(a) > ItemLogic.power_score(b))
	if items.is_empty():
		pv.add_child(UI.label(Loc.t("Nenhum item desse tipo no inventário."), 19, UI.C_MUTED))
	for it in items:
		var b := ItemLogic.base(it)
		var row := UI.hbox(6)
		var desc := ItemLogic.describe(it, MonsterLogic.type_of(m))
		var l := UI.label("%s\n%s" % [ItemLogic.display_name(it), " · ".join(desc.slice(1, 4))], 17, DataDB.rarity_color(it.rarity), true)
		row.add_child(l)
		var iu: String = it.uid
		var eb := UI.small_button(Loc.t("Equipar"), func():
			var r := Game.equip(uid, iu)
			if not r.ok:
				toast(r.error, UI.C_BAD)
			choosing_slot = ""
			rebuild(), "primary")
		eb.disabled = int(b.level) > int(m.level)
		if eb.disabled:
			eb.text = Loc.t("Nv %d") % int(b.level)
		row.add_child(eb)
		pv.add_child(row)


func _train() -> void:
	var before := Game.monster_stats(Game.monster(uid))
	var r: Dictionary = await Game.train_monster(uid)
	if r.get("ok", false):
		var m := Game.monster(uid)
		var after := Game.monster_stats(m)
		var gain := Loc.t("Ataque %d → %d · Defesa %d → %d · HP %d → %d") % [int(before.atk), int(after.atk), int(before.def), int(after.def), int(before.hp), int(after.hp)]
		if r.get("new_glow", false):
			toast(Loc.t("%s ganhou um novo brilho!") % MonsterLogic.display_name(m) + "\n" + gain, UI.C_GOLD, "sparkle")
		else:
			toast(Loc.t("Treino +%d!") % int(r.train) + "\n" + gain, UI.C_GOOD, "bolt")
	else:
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)
	rebuild()


func _buy_star() -> void:
	var before := Game.monster_stats(Game.monster(uid))
	var r: Dictionary = await Game.buy_star(uid)
	if r.get("ok", false):
		var after := Game.monster_stats(Game.monster(uid))
		toast(Loc.t("Estrela adicionada!") + "\n" + Loc.t("HP %d → %d · Ataque %d → %d · Defesa %d → %d") % [int(before.hp), int(after.hp), int(before.atk), int(after.atk), int(before.def), int(after.def)], UI.C_GOLD, "star")
	else:
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)
	rebuild()
