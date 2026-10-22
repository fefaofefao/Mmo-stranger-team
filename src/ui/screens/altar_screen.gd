extends Screen
## Altar de Essências: trocar monstros do Depot por Essência e aprimorar itens.

var tab := 0
var busy := false


func build() -> void:
	var b := make_layout(Loc.t("Altar de Essências"), "altar")
	var ep := UI.panel("inset")
	b.add_child(ep)
	var eg := UI.grid(3, 6)
	ep.add_child(eg)
	for t in DataDB.type_ids:
		var c := UI.hbox(4)
		var dot := ColorRect.new()
		dot.color = DataDB.type_color(t)
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.add_child(dot)
		c.add_child(UI.label("%s %s" % [DataDB.type_name(t), UI.fmt(Game.save.essences.get(t, 0))], 17, DataDB.type_color(t).lightened(0.35)))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eg.add_child(c)
	b.add_child(tabs([Loc.t("Trocar monstros"), Loc.t("Aprimorar itens")], tab, func(i): tab = i; rebuild()))
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	if tab == 0:
		var dep := Game.depot_monsters()
		if dep.is_empty():
			sc[1].add_child(empty_note(Loc.t("Nenhum monstro no Depot. Monstros do grupo precisam sair do grupo antes."), "altar"))
		for m in dep:
			var p := UI.card(bool(m.shiny))
			var row := UI.hbox(8)
			p.add_child(row)
			row.add_child(UI.portrait_frame(MonsterLogic.form_id(m), bool(m.shiny), 52))
			var v := UI.vbox(2)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(v)
			v.add_child(UI.label("%s · %s" % [MonsterLogic.display_name(m), Loc.t("Nv %d") % int(m.level)], 19, Color(1, 0.88, 0.45) if m.shiny else UI.C_TEXT))
			var r := UI.hbox(4)
			r.add_child(UI.quality_badge(m, 14))
			r.add_child(UI.label("→ %d %s" % [EssenceLogic.essence_value(m), Loc.t("Essência de %s") % DataDB.type_name(MonsterLogic.type_of(m))], 16, DataDB.type_color(MonsterLogic.type_of(m)).lightened(0.3)))
			v.add_child(r)
			var uid: String = m.uid
			row.add_child(UI.small_button(Loc.t("Trocar"), func(): _convert(uid), "danger" if m.shiny else ""))
			sc[1].add_child(p)
	else:
		var items: Array = []
		for it in Game.save.items.values():
			if it.get("loc", "inv") != "depot":
				items.append(it)
		items.sort_custom(func(a, c): return DataDB.rarity_index[a.rarity] > DataDB.rarity_index[c.rarity])
		sc[1].add_child(empty_note(Loc.t("+1 a +5 sempre funcionam. A partir do +6 pode falhar, mas o item NUNCA é destruído."), "sparkle"))
		for it in items:
			var p := UI.card()
			var row := UI.hbox(8)
			p.add_child(row)
			var enh := int(it.enh)
			var v := UI.vbox(2)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(v)
			var nl := UI.label(ItemLogic.display_name(it) + ("  (%s)" % Loc.t("equipado") if it.loc == "equip" else ""), 19, DataDB.rarity_color(it.rarity))
			nl.clip_text = true
			v.add_child(nl)
			if enh >= int(DataDB.config.enhance.max):
				v.add_child(UI.label(Loc.t("Aprimoramento máximo"), 16, UI.C_GOLD))
			else:
				var c := EssenceLogic.enhance_cost(it)
				v.add_child(UI.label(Loc.t("+%d → +%d · %d%% · %d Essência de %s + %s ouro") % [enh, enh + 1, int(EssenceLogic.enhance_chance(enh) * 100), int(c.essence), DataDB.type_name(c.essence_type), UI.fmt(c.gold)], 15, UI.C_MUTED, true))
			var iu: String = it.uid
			var bt := UI.small_button(Loc.t("Aprimorar"), func(): _enhance(iu), "primary")
			bt.disabled = enh >= int(DataDB.config.enhance.max)
			row.add_child(bt)
			sc[1].add_child(p)


func _convert(uid: String) -> void:
	if busy:
		return
	var m := Game.monster(uid)
	var val := EssenceLogic.essence_value(m)
	if not await main.confirm(Loc.t("Trocar monstro"), Loc.t("Trocar %s (Nv %d, qualidade %d%%) por %d Essência de %s?\nEle fica registrado na Coleção.") % [MonsterLogic.display_name(m), int(m.level), int(m.get("quality", 0)), val, DataDB.type_name(MonsterLogic.type_of(m))]):
		return
	if m.shiny and not await main.confirm(Loc.t("ATENÇÃO: SHINY"), Loc.t("Este monstro é SHINY (1 em 5000)! Tem certeza ABSOLUTA? Não há como desfazer."), Loc.t("Trocar mesmo"), Loc.t("Cancelar")):
		return
	busy = true
	var r: Dictionary = await Game.convert_monster(uid)
	busy = false
	if r.get("ok", false):
		toast(Loc.t("+%d Essência de %s") % [int(r.amount), DataDB.type_name(r.essence_type)], UI.C_GOLD, "gem")
	else:
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)
	rebuild()


func _enhance(uid: String) -> void:
	if busy:
		return
	busy = true
	var r: Dictionary = await Game.enhance_item(uid)
	busy = false
	if not r.get("ok", false):
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)
	elif r.get("success", false):
		toast(Loc.t("Sucesso! Item aprimorado."), UI.C_GOOD, "sparkle")
	else:
		toast(Loc.t("Falhou... o item continua intacto."), UI.C_BAD)
	rebuild()
