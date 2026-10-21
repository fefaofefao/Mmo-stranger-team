extends Screen
## Detalhes do monstro: status, equipamentos, estrelas, habilidades e comportamento da IA.

var uid := ""
var choosing_slot := ""


func build() -> void:
	uid = params.get("uid", "")
	var m := Game.monster(uid)
	var b := make_layout("Monstro")
	if m.is_empty():
		b.add_child(UI.label("Monstro não encontrado.", 22))
		return
	var sc := UI.scroll(10)
	b.add_child(sc[0])
	var v: VBoxContainer = sc[1]
	var fid := MonsterLogic.form_id(m)
	var f := DataDB.form(fid)
	var fam: Dictionary = DataDB.families[m.family]
	var head := UI.hbox(12)
	v.add_child(head)
	head.add_child(UI.portrait(fid, bool(m.shiny), 128))
	var hv := UI.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	hv.add_child(UI.label(MonsterLogic.display_name(m), 30, UI.C_GOLD))
	var style_name := {"melee": "Corpo a corpo", "ranged": "Distância", "magic": "Mágico"}
	hv.add_child(UI.label("%s · %s · %s" % [DataDB.type_name(fam.type), ["Filhote", "Adolescente", "Adulto"][int(m.stage) - 1], style_name[fam.style]], 20, DataDB.type_color(fam.type).lightened(0.2)))
	var need := Formulas.xp_to_next(int(m.level))
	hv.add_child(UI.label("Nível %d · XP %s / %s" % [int(m.level), UI.fmt(m.xp), UI.fmt(need)], 20))
	var xb := UI.bar(float(m.xp) / max(1, need), Color(0.35, 0.6, 1.0), 300, 12)
	xb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(xb)
	var ev := MonsterLogic.evo_levels(m.family)
	if int(m.stage) < 3:
		var nxt := int(ev[int(m.stage) - 1])
		hv.add_child(UI.label("Evolui para %s no nível %d" % [DataDB.form(DataDB.form_for_stage(m.family, int(m.stage) + 1)).name, nxt], 18, UI.C_MUTED))
	v.add_child(UI.label(f.desc, 20, UI.C_TEXT, true))
	# atributos
	var st := Game.monster_stats(m)
	var sp := UI.panel()
	v.add_child(sp)
	var g := UI.grid(2, 6)
	sp.add_child(g)
	for pair in [["HP", int(st.hp)], ["Ataque", int(st.atk)], ["Defesa", int(st.def)], ["Velocidade", int(st.spd)],
			["Alcance", int(st.rng)], ["Crítico", "%d%%" % int(st.crit * 100)], ["Roubo de vida", "%d%%" % int(st.lifesteal * 100)],
			["Bônus XP", "%d%%" % int(st.xp_pct)], ["Poder", MonsterLogic.power(st)], ["Shiny", "Sim (+5%)" if m.shiny else "Não"]]:
		g.add_child(UI.label("%s: %s" % [pair[0], str(pair[1])], 20))
	# estrelas
	v.add_child(UI.label("Estrelas  " + "★".repeat(int(m.stars)) + "☆".repeat(5 - int(m.stars)), 24, UI.C_GOLD))
	v.add_child(UI.label("Cada estrela: +%d%% atributos. 3ª e 5ª estrelas: habilidades +%d%% de poder e −%d%% de recarga." % [
		int(float(DataDB.config.stars.stat_bonus_per_star) * 100), int(float(DataDB.config.stars.ability_power_per_upgrade) * 100),
		int(float(DataDB.config.stars.ability_cd_per_upgrade) * 100)], 18, UI.C_MUTED, true))
	var cost := EssenceLogic.star_cost(m)
	if cost > 0:
		var t: String = fam.type
		var have := int(Game.save.essences.get(t, 0))
		var sb := UI.button("Adicionar estrela (%d Essência de %s · você tem %d)" % [cost, DataDB.type_name(t), have], _buy_star, 20)
		sb.disabled = have < cost
		v.add_child(sb)
	# equipamentos
	v.add_child(UI.label("Equipamentos", 24, UI.C_GOLD))
	for s in DataDB.item_slots:
		v.add_child(_slot_row(m, s))
	if choosing_slot != "":
		_item_picker(v, m)
	# habilidades
	v.add_child(UI.label("Habilidades (usadas automaticamente pela IA)", 24, UI.C_GOLD))
	for ab_id in f.abilities:
		var ab: Dictionary = DataDB.abilities[ab_id]
		var kinds := {"strike": "golpe forte", "bolt": "projétil", "burst": "área ao redor", "blast": "explosão no alvo", "heal": "cura própria", "dot": "dano contínuo em área", "ult": "suprema em área"}
		v.add_child(UI.label("• %s — %s · poder %.1fx · recarga %.0fs%s" % [ab.name, kinds.get(ab.kind, ab.kind), float(ab.power) * st.ability_power_mult,
			float(ab.cooldown) * st.ability_cd_mult, (" · raio %d" % int(ab.radius)) if int(ab.radius) > 0 else ""], 19, UI.C_TEXT, true))
	v.add_child(UI.label("Comportamento da IA do grupo: %s" % ("Focar o mesmo alvo" if Game.save.ai_behavior == "focus" else "Espalhar alvos"), 20, UI.C_MUTED))
	v.add_child(UI.small_button("Alterar comportamento", func():
		Game.set_ai_behavior("spread" if Game.save.ai_behavior == "focus" else "focus")
		rebuild()))


func _slot_row(m: Dictionary, s: Dictionary) -> Control:
	var row := UI.hbox(8)
	var iu: String = m.equip.get(s.id, "")
	var it: Dictionary = Game.save.items.get(iu, {})
	var txt := "%s: %s" % [s.name, "—" if it.is_empty() else ItemLogic.display_name(it)]
	var l := UI.label(txt, 20, UI.C_MUTED if it.is_empty() else DataDB.rarity_color(it.rarity))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	row.add_child(l)
	var sid: String = s.id
	row.add_child(UI.small_button("Trocar", func(): choosing_slot = sid; rebuild()))
	if not it.is_empty():
		row.add_child(UI.small_button("Tirar", func(): Game.unequip(uid, sid); rebuild()))
	return row


func _item_picker(v: VBoxContainer, m: Dictionary) -> void:
	var p := UI.panel(Color("#24211d"), UI.C_GOLD)
	v.add_child(p)
	var pv := UI.vbox(6)
	p.add_child(pv)
	var top := UI.hbox()
	pv.add_child(top)
	top.add_child(UI.expand(UI.label("Escolher: %s" % ItemLogic.slot_name(choosing_slot), 22, UI.C_GOLD)))
	top.add_child(UI.small_button("Fechar", func(): choosing_slot = ""; rebuild()))
	var items: Array = []
	for it in Game.inv_items():
		if ItemLogic.base(it).slot == choosing_slot:
			items.append(it)
	items.sort_custom(func(a, b): return ItemLogic.power_score(a) > ItemLogic.power_score(b))
	if items.is_empty():
		pv.add_child(UI.label("Nenhum item desse tipo no inventário.", 20, UI.C_MUTED))
	for it in items:
		var b := ItemLogic.base(it)
		var row := UI.hbox(6)
		var desc := ItemLogic.describe(it, MonsterLogic.type_of(m))
		var l := UI.label("%s\n%s" % [ItemLogic.display_name(it), " · ".join(desc.slice(1, 4))], 18, DataDB.rarity_color(it.rarity), true)
		row.add_child(l)
		var iu: String = it.uid
		var eb := UI.small_button("Equipar", func():
			var r := Game.equip(uid, iu)
			if not r.ok:
				toast(r.error, UI.C_BAD)
			choosing_slot = ""
			rebuild())
		eb.disabled = int(b.level) > int(m.level)
		if eb.disabled:
			eb.text = "Nv %d" % int(b.level)
		row.add_child(eb)
		pv.add_child(row)


func _buy_star() -> void:
	var r: Dictionary = await Game.buy_star(uid)
	if r.get("ok", false):
		toast("Estrela adicionada!", UI.C_GOLD)
	else:
		toast(r.get("error", "Falhou"), UI.C_BAD)
	rebuild()
