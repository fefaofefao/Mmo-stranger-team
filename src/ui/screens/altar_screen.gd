extends Screen
## Altar de Essências: trocar monstros do Depot por Essência e aprimorar itens.

var tab := 0
var busy := false


func build() -> void:
	var b := make_layout("Altar de Essências")
	var eg := UI.grid(3, 6)
	b.add_child(eg)
	for t in DataDB.type_ids:
		eg.add_child(UI.label("%s: %s" % [DataDB.type_name(t), UI.fmt(Game.save.essences.get(t, 0))], 19, DataDB.type_color(t).lightened(0.3)))
	b.add_child(tabs(["Trocar monstros", "Aprimorar itens"], tab, func(i): tab = i; rebuild()))
	var sc := UI.scroll(6)
	b.add_child(sc[0])
	if tab == 0:
		var dep := Game.depot_monsters()
		if dep.is_empty():
			sc[1].add_child(UI.label("Nenhum monstro no Depot. Monstros do grupo precisam sair do grupo antes.", 20, UI.C_MUTED, true))
		for m in dep:
			var row := UI.hbox(8)
			row.add_child(UI.portrait(MonsterLogic.form_id(m), bool(m.shiny), 52))
			var val := EssenceLogic.essence_value(m)
			row.add_child(UI.expand(UI.label("%s Nv %d\n→ %d Essência de %s" % [MonsterLogic.display_name(m), int(m.level), val, DataDB.type_name(MonsterLogic.type_of(m))], 19,
				Color(1, 0.9, 0.5) if m.shiny else UI.C_TEXT)))
			var uid: String = m.uid
			row.add_child(UI.small_button("Trocar", func(): _convert(uid)))
			sc[1].add_child(row)
	else:
		var items: Array = []
		for it in Game.save.items.values():
			if it.get("loc", "inv") != "depot":
				items.append(it)
		items.sort_custom(func(a, c): return DataDB.rarity_index[a.rarity] > DataDB.rarity_index[c.rarity])
		sc[1].add_child(UI.label("+1 a +5 sempre têm sucesso. A partir do +6 pode falhar, mas o item NUNCA é destruído.", 19, UI.C_MUTED, true))
		for it in items:
			var p := UI.panel()
			var row := UI.hbox(8)
			p.add_child(row)
			var enh := int(it.enh)
			var info := "%s%s\n" % [ItemLogic.display_name(it), "  (equipado)" if it.loc == "equip" else ""]
			if enh >= int(DataDB.config.enhance.max):
				info += "Aprimoramento máximo"
			else:
				var c := EssenceLogic.enhance_cost(it)
				info += "+%d→+%d · %d%% · %d Essência de %s + %s ouro" % [enh, enh + 1, int(EssenceLogic.enhance_chance(enh) * 100), int(c.essence), DataDB.type_name(c.essence_type), UI.fmt(c.gold)]
			row.add_child(UI.expand(UI.label(info, 18, DataDB.rarity_color(it.rarity), true)))
			var iu: String = it.uid
			var bt := UI.small_button("Aprimorar", func(): _enhance(iu))
			bt.disabled = enh >= int(DataDB.config.enhance.max)
			row.add_child(bt)
			sc[1].add_child(p)


func _convert(uid: String) -> void:
	if busy:
		return
	var m := Game.monster(uid)
	var val := EssenceLogic.essence_value(m)
	if not await main.confirm("Trocar monstro", "Trocar %s (Nv %d) por %d Essência de %s?\nO monstro fica registrado na Coleção." % [MonsterLogic.display_name(m), int(m.level), val, DataDB.type_name(MonsterLogic.type_of(m))]):
		return
	if m.shiny and not await main.confirm("ATENÇÃO: SHINY", "Este monstro é SHINY (1 em 5000)! Tem certeza ABSOLUTA? Não há como desfazer.", "Trocar mesmo", "Cancelar"):
		return
	busy = true
	var r: Dictionary = await Game.convert_monster(uid)
	busy = false
	if r.get("ok", false):
		toast("+%d Essência de %s" % [int(r.amount), DataDB.type_name(r.essence_type)], UI.C_GOLD)
	else:
		toast(r.get("error", "Falhou"), UI.C_BAD)
	rebuild()


func _enhance(uid: String) -> void:
	if busy:
		return
	busy = true
	var r: Dictionary = await Game.enhance_item(uid)
	busy = false
	if not r.get("ok", false):
		toast(r.get("error", "Falhou"), UI.C_BAD)
	elif r.get("success", false):
		toast("Sucesso! Item aprimorado.", UI.C_GOOD)
	else:
		toast("Falhou... o item continua intacto.", UI.C_BAD)
	rebuild()
