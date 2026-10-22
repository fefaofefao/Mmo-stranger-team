extends Screen
## Depot: monstros guardados e itens guardados.

var tab := 0


func build() -> void:
	var b := make_layout(Loc.t("Depot"), "chest")
	b.add_child(tabs([Loc.t("Monstros"), Loc.t("Itens guardados")], tab, func(i): tab = i; rebuild()))
	var sc := UI.scroll(8)
	if tab == 0:
		var dep := Game.depot_monsters()
		b.add_child(UI.label(Loc.t("%d monstros guardados · troque-os por Essência no Altar") % dep.size(), 18, UI.C_MUTED))
		b.add_child(sc[0])
		for m in dep:
			var p := UI.card(bool(m.shiny))
			var row := UI.hbox(8)
			p.add_child(row)
			row.add_child(UI.portrait_frame(MonsterLogic.form_id(m), bool(m.shiny), 60))
			var v := UI.vbox(3)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(v)
			var nl := UI.label(MonsterLogic.display_name(m), 21, Color(1, 0.88, 0.45) if m.shiny else UI.C_TEXT)
			nl.clip_text = true
			v.add_child(nl)
			var r := UI.hbox(4)
			r.add_child(UI.pill(Loc.t("Nv %d") % int(m.level), UI.C_GOLD, 14))
			r.add_child(UI.type_badge(MonsterLogic.type_of(m), 14))
			r.add_child(UI.quality_badge(m, 14))
			v.add_child(r)
			var uid: String = m.uid
			var bb := UI.vbox(4)
			row.add_child(bb)
			bb.add_child(UI.small_button(Loc.t("Ver"), func(): main.goto("monster", {"uid": uid})))
			bb.add_child(UI.small_button(Loc.t("Ao grupo"), func():
				if Game.save.party.size() < int(DataDB.config.party.max_size):
					Game.set_party_slot(Game.save.party.size(), uid)
				else:
					toast(Loc.t("Grupo cheio: troque um membro na tela de Grupo."), UI.C_BAD)
				rebuild(), "primary"))
			sc[1].add_child(p)
		if dep.is_empty():
			sc[1].add_child(empty_note(Loc.t("Vazio. Cada abate no Mundo 1 tem chance de recrutar o monstro.")))
	else:
		var items := Game.depot_items()
		b.add_child(UI.label(Loc.t("%d / %d itens guardados") % [items.size(), int(DataDB.config.inventory.depot_cap)], 18, UI.C_MUTED))
		b.add_child(sc[0])
		for it in items:
			var p := UI.card()
			var row := UI.hbox(8)
			p.add_child(row)
			var l := UI.label(ItemLogic.display_name(it), 20, DataDB.rarity_color(it.rarity))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			row.add_child(l)
			row.add_child(UI.rarity_badge(it.rarity, 14))
			var iu: String = it.uid
			row.add_child(UI.small_button(Loc.t("Pegar"), func():
				var r := Game.move_item(iu, "inv")
				if not r.ok:
					toast(Loc.t(r.error), UI.C_BAD)
				rebuild()))
			sc[1].add_child(p)
		if items.is_empty():
			sc[1].add_child(empty_note(Loc.t("Nenhum item guardado.")))
