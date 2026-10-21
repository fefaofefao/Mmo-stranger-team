extends Screen
## Grupo: ordem, substituição e comportamento da IA.

var picking := -1


func build() -> void:
	var b := make_layout("Grupo")
	var party := Game.party_monsters()
	var lvl := Game.main_level()
	var fighting := PartyLogic.fighting_count(lvl, party.size())
	var pc: Dictionary = DataDB.config.party
	b.add_child(UI.label("Lutando no mapa: %d. Nível %d do principal libera 2 lutando; nível %d libera 3. Quem não luta recebe %d%% da XP." % [
		fighting, int(pc.unlock_2), int(pc.unlock_3), int(float(pc.bench_xp_share) * 100)], 20, UI.C_MUTED, true))
	for i in int(pc.max_size):
		b.add_child(_slot(i, party, fighting))
	b.add_child(UI.label("Comportamento da IA (com 2 ou 3 em campo):", 22, UI.C_GOLD))
	var row := UI.hbox(8)
	b.add_child(row)
	var cur: String = Game.save.ai_behavior
	for opt in [["focus", "Focar o mesmo alvo"], ["spread", "Espalhar alvos"]]:
		var key: String = opt[0]
		var btn := UI.button(("● " if cur == key else "○ ") + opt[1], func(): Game.set_ai_behavior(key); rebuild(), 22)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
	if picking >= 0:
		_picker(b)


func _slot(i: int, party: Array, fighting: int) -> Control:
	var p := UI.panel()
	var row := UI.hbox(10)
	p.add_child(row)
	if i >= party.size():
		var l := UI.label("Vaga %d livre" % (i + 1), 22, UI.C_MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.small_button("Adicionar", func(): picking = i; rebuild()))
		return p
	var m: Dictionary = party[i]
	row.add_child(UI.portrait(MonsterLogic.form_id(m), bool(m.shiny), 72))
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UI.label("%s%s" % [MonsterLogic.display_name(m), "  (principal)" if i == 0 else ""], 22, UI.C_GOLD if i == 0 else UI.C_TEXT))
	var st := Game.monster_stats(m)
	v.add_child(UI.label("Nv %d · %s · %s · Poder %d" % [int(m.level), DataDB.type_name(MonsterLogic.type_of(m)), "★".repeat(int(m.stars)) + "☆".repeat(5 - int(m.stars)), MonsterLogic.power(st)], 18, UI.C_MUTED))
	v.add_child(UI.label("Em campo (100% XP)" if i < fighting else "Reserva (50% XP)", 18, UI.C_GOOD if i < fighting else UI.C_MUTED))
	var btns := UI.vbox(4)
	row.add_child(btns)
	var r1 := UI.hbox(4)
	btns.add_child(r1)
	var up := UI.small_button("▲", func(): Game.move_party(m.uid, -1); rebuild())
	up.disabled = i == 0
	r1.add_child(up)
	var dn := UI.small_button("▼", func(): Game.move_party(m.uid, 1); rebuild())
	dn.disabled = i >= party.size() - 1
	r1.add_child(dn)
	var r2 := UI.hbox(4)
	btns.add_child(r2)
	r2.add_child(UI.small_button("Ver", func(): main.goto("monster", {"uid": m.uid})))
	r2.add_child(UI.small_button("Trocar", func(): picking = i; rebuild()))
	if party.size() > 1:
		r2.add_child(UI.small_button("✗", func(): Game.remove_from_party(m.uid); rebuild()))
	return p


func _picker(b: VBoxContainer) -> void:
	var p := UI.panel(Color("#24211d"), UI.C_GOLD)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_child(p)
	var v := UI.vbox(6)
	p.add_child(v)
	var top := UI.hbox()
	v.add_child(top)
	top.add_child(UI.expand(UI.label("Escolha do Depot para a vaga %d" % (picking + 1), 22, UI.C_GOLD)))
	top.add_child(UI.small_button("Fechar", func(): picking = -1; rebuild()))
	var sc := UI.scroll(6)
	v.add_child(sc[0])
	var dep := Game.depot_monsters()
	if dep.is_empty():
		sc[1].add_child(UI.label("Nenhum monstro no Depot. Recrute monstros caçando no Mundo 1 (chance por abate).", 20, UI.C_MUTED, true))
	for m in dep:
		var row := UI.hbox(8)
		row.add_child(UI.portrait(MonsterLogic.form_id(m), bool(m.shiny), 52))
		row.add_child(UI.expand(UI.label("%s · Nv %d · %s" % [MonsterLogic.display_name(m), int(m.level), DataDB.type_name(MonsterLogic.type_of(m))], 20)))
		var uid: String = m.uid
		row.add_child(UI.small_button("Escolher", func(): Game.set_party_slot(picking, uid); picking = -1; rebuild()))
		sc[1].add_child(row)
