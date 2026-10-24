extends Screen
## Depot: monstros guardados e itens guardados.

var tab := 0
var type_filter := ""
var sort_by := "level"   # level | quality | recent


func build() -> void:
	var b := make_layout(Loc.t("Depot"), "chest")
	b.add_child(tabs([Loc.t("Monstros"), Loc.t("Itens guardados")], tab, func(i): tab = i; rebuild()))
	var sc := UI.scroll(8)
	if tab == 0:
		var all_dep := Game.depot_monsters()
		b.add_child(type_filter_bar(type_filter, func(t): type_filter = t; rebuild()))
		var srow := UI.hbox(6)
		srow.add_child(UI.label(Loc.t("Ordenar:"), 17, UI.C_MUTED))
		for o in [["level", Loc.t("Nível")], ["quality", Loc.t("Raridade")], ["recent", Loc.t("Recentes")]]:
			var key: String = o[0]
			var sb := UI.button(o[1], func(): sort_by = key; rebuild(), 17, 52, "tab_on" if sort_by == key else "tab")
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			srow.add_child(sb)
		b.add_child(srow)
		var dep := _sorted(all_dep.filter(func(m): return type_filter == "" or MonsterLogic.type_of(m) == type_filter))
		var info := Loc.t("%d monstros guardados · troque-os por Essência no Altar") % all_dep.size()
		if type_filter != "":
			info = Loc.t("%d de %d monstros · %s") % [dep.size(), all_dep.size(), DataDB.type_name(type_filter)]
		b.add_child(UI.label(info, 18, UI.C_MUTED))
		b.add_child(sc[0])
		for m in dep:
			var p := UI.card(bool(m.shiny))
			var row := UI.hbox(8)
			p.add_child(row)
			row.add_child(UI.monster_frame(m, 60))
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
		if all_dep.is_empty():
			sc[1].add_child(empty_note(Loc.t("Vazio. Cada abate no Mundo 1 tem chance de recrutar o monstro.")))
		elif dep.is_empty():
			sc[1].add_child(empty_note(Loc.t("Nenhum monstro de %s no Depot.") % DataDB.type_name(type_filter)))
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


## Nível: maior primeiro. Raridade: shiny primeiro, depois qualidade e nível. Recentes: último recrutado primeiro.
func _sorted(arr: Array) -> Array:
	match sort_by:
		"quality":
			arr.sort_custom(func(a, b):
				if bool(a.shiny) != bool(b.shiny):
					return bool(a.shiny)
				if int(a.get("quality", 0)) != int(b.get("quality", 0)):
					return int(a.get("quality", 0)) > int(b.get("quality", 0))
				return int(a.level) > int(b.level))
		"recent":
			arr.sort_custom(func(a, b): return float(a.get("caught_at", 0)) > float(b.get("caught_at", 0)))
		_:
			arr.sort_custom(func(a, b):
				if int(a.level) != int(b.level):
					return int(a.level) > int(b.level)
				return int(a.get("quality", 0)) > int(b.get("quality", 0)))
	return arr
