extends Screen
## Grupo: ordem, substituição e comportamento da IA.

var picking := -1


func build() -> void:
	var b := make_layout(Loc.t("Grupo"), "paw")
	var party := Game.party_monsters()
	var lvl := Game.main_level()
	var fighting := PartyLogic.fighting_count(lvl, party.size())
	var pc: Dictionary = DataDB.config.party
	var info := UI.card()
	b.add_child(info)
	var iv := UI.vbox(4)
	info.add_child(iv)
	iv.add_child(UI.label(Loc.t("Em campo: %d · Nível %d libera 2 · Nível %d libera 3") % [fighting, int(pc.unlock_2), int(pc.unlock_3)], 19, UI.C_TEXT, true))
	iv.add_child(UI.label(Loc.t("Se um monstro cair, o próximo do grupo entra no lugar. O time só renasce quando todos caem. Quem participou ganha XP completa, mesmo caído; a reserva ganha %d%%.") % int(float(pc.bench_xp_share) * 100), 17, UI.C_MUTED, true))
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	var list: VBoxContainer = sc[1]
	for i in int(pc.max_size):
		list.add_child(_slot(i, party, fighting))
	list.add_child(UI.section(Loc.t("Comportamento da IA (2 ou 3 em campo)"), "gear"))
	var row := UI.hbox(8)
	list.add_child(row)
	var cur: String = Game.save.ai_behavior
	for opt in [["focus", Loc.t("Focar o mesmo alvo")], ["spread", Loc.t("Espalhar alvos")]]:
		var key: String = opt[0]
		var btn := UI.button(opt[1], func(): Game.set_ai_behavior(key); rebuild(), 20, 64, "tab_on" if cur == key else "tab")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
	if picking >= 0:
		_picker(list)


func _slot(i: int, party: Array, fighting: int) -> Control:
	var p := UI.card(i == 0 and i < party.size())
	var row := UI.hbox(10)
	p.add_child(row)
	if i >= party.size():
		row.add_child(UI.icon("plus", 40))
		var l := UI.label(Loc.t("Vaga %d livre") % (i + 1), 22, UI.C_MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.small_button(Loc.t("Adicionar"), func(): picking = i; rebuild(), "primary"))
		return p
	var m: Dictionary = party[i]
	row.add_child(UI.portrait_frame(MonsterLogic.form_id(m), bool(m.shiny), 72))
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var nl := UI.label(MonsterLogic.display_name(m), 22, UI.C_GOLD if i == 0 else UI.C_TEXT)
	nl.clip_text = true
	v.add_child(nl)
	var r1 := UI.hbox(4)
	v.add_child(r1)
	r1.add_child(UI.pill(Loc.t("Nv %d") % int(m.level), UI.C_GOLD, 15))
	r1.add_child(UI.type_badge(MonsterLogic.type_of(m), 15))
	r1.add_child(UI.quality_badge(m, 15))
	var r2 := UI.hbox(6)
	v.add_child(r2)
	r2.add_child(UI.stars(int(m.stars), 18))
	r2.add_child(UI.label(Loc.t("Em campo") if i < fighting else Loc.t("Reserva"), 16, UI.C_GOOD if i < fighting else UI.C_MUTED))
	var btns := UI.grid(2, 4)
	row.add_child(btns)
	var up := UI.small_button("▲", func(): Game.move_party(m.uid, -1); rebuild())
	up.disabled = i == 0
	btns.add_child(up)
	var dn := UI.small_button("▼", func(): Game.move_party(m.uid, 1); rebuild())
	dn.disabled = i >= party.size() - 1
	btns.add_child(dn)
	btns.add_child(UI.small_button(Loc.t("Ver"), func(): main.goto("monster", {"uid": m.uid})))
	btns.add_child(UI.small_button(Loc.t("Trocar"), func(): picking = i; rebuild()))
	if party.size() > 1:
		var rm := UI.small_button(Loc.t("Tirar"), func(): Game.remove_from_party(m.uid); rebuild(), "danger")
		btns.add_child(rm)
	return p


func _picker(list: VBoxContainer) -> void:
	list.add_child(UI.section(Loc.t("Escolha do Depot para a vaga %d") % (picking + 1), "chest"))
	var dep := Game.depot_monsters()
	if dep.is_empty():
		list.add_child(empty_note(Loc.t("Nenhum monstro no Depot. Cada abate no Mundo 1 tem chance de recrutar o monstro.")))
	for m in dep:
		var p := UI.card()
		var row := UI.hbox(8)
		p.add_child(row)
		row.add_child(UI.portrait_frame(MonsterLogic.form_id(m), bool(m.shiny), 52))
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		v.add_child(UI.label(MonsterLogic.display_name(m), 20))
		var r := UI.hbox(4)
		r.add_child(UI.pill(Loc.t("Nv %d") % int(m.level), UI.C_GOLD, 14))
		r.add_child(UI.type_badge(MonsterLogic.type_of(m), 14))
		r.add_child(UI.quality_badge(m, 14))
		v.add_child(r)
		var uid: String = m.uid
		row.add_child(UI.small_button(Loc.t("Escolher"), func(): Game.set_party_slot(picking, uid); picking = -1; rebuild(), "primary"))
		list.add_child(p)
	list.add_child(UI.small_button(Loc.t("Fechar"), func(): picking = -1; rebuild()))
