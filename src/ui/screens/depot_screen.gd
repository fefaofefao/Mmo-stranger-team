extends Screen
## Depot: monstros guardados e itens guardados.

var tab := 0


func build() -> void:
	var b := make_layout("Depot")
	b.add_child(tabs(["Monstros", "Itens guardados"], tab, func(i): tab = i; rebuild()))
	var sc := UI.scroll(6)
	if tab == 0:
		var dep := Game.depot_monsters()
		b.add_child(UI.label("%d monstros guardados. Troque-os por Essência no Altar." % dep.size(), 20, UI.C_MUTED))
		b.add_child(sc[0])
		for m in dep:
			var p := UI.panel()
			var row := UI.hbox(8)
			p.add_child(row)
			row.add_child(UI.portrait(MonsterLogic.form_id(m), bool(m.shiny), 60))
			var st := Game.monster_stats(m)
			row.add_child(UI.expand(UI.label("%s\nNv %d · %s · %s · Poder %d" % [MonsterLogic.display_name(m), int(m.level), DataDB.type_name(MonsterLogic.type_of(m)),
				"★".repeat(int(m.stars)), MonsterLogic.power(st)], 19, Color(1, 0.9, 0.5) if m.shiny else UI.C_TEXT)))
			var uid: String = m.uid
			row.add_child(UI.small_button("Ver", func(): main.goto("monster", {"uid": uid})))
			var add := UI.small_button("Ao grupo", func():
				if Game.save.party.size() < int(DataDB.config.party.max_size):
					Game.set_party_slot(Game.save.party.size(), uid)
				else:
					toast("Grupo cheio: troque um membro na tela de Grupo.")
				rebuild())
			row.add_child(add)
			sc[1].add_child(p)
		if dep.is_empty():
			sc[1].add_child(UI.label("Vazio. Cada abate no Mundo 1 tem chance de recrutar o monstro.", 20, UI.C_MUTED, true))
	else:
		var items := Game.depot_items()
		b.add_child(UI.label("%d / %d itens guardados" % [items.size(), int(DataDB.config.inventory.depot_cap)], 20, UI.C_MUTED))
		b.add_child(sc[0])
		for it in items:
			var row := UI.hbox(8)
			row.add_child(UI.expand(UI.label(ItemLogic.display_name(it) + " · " + DataDB.rarity(it.rarity).name, 20, DataDB.rarity_color(it.rarity))))
			var iu: String = it.uid
			row.add_child(UI.small_button("Pegar", func():
				var r := Game.move_item(iu, "inv")
				if not r.ok:
					toast(r.error, UI.C_BAD)
				rebuild()))
			sc[1].add_child(row)
