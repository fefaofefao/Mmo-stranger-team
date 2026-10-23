extends Screen
## Altar de Essências: trocar monstros do Depot por Essência e aprimorar itens.

var tab := 0
var busy := false
var sel := {}          # uid -> true (troca em lote)
var sel_bar: Button
var sel_boxes := {}    # uid -> Button


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
		var info := UI.card()
		var iv := UI.vbox(2)
		info.add_child(iv)
		iv.add_child(UI.label(Loc.t("Para que serve a Essência?"), 18, UI.C_GOLD))
		iv.add_child(UI.label(Loc.t("• Estrelas: cada estrela dá +%d%% em todos os atributos de um monstro do mesmo tipo.") % int(float(DataDB.config.stars.stat_bonus_per_star) * 100), 15, UI.C_TEXT, true))
		iv.add_child(UI.label(Loc.t("• Aprimorar itens: cada nível dá +%d%% no atributo principal do item.") % int(float(DataDB.config.enhance.stat_per_level) * 100), 15, UI.C_TEXT, true))
		iv.add_child(UI.label(Loc.t("• Vender no Market para outros jogadores."), 15, UI.C_TEXT, true))
		sc[1].add_child(info)
		var dep := Game.depot_monsters()
		sel_boxes.clear()
		for u in sel.keys():
			if Game.monster(u).is_empty() or Game.save.party.has(u):
				sel.erase(u)
		if dep.is_empty():
			sc[1].add_child(empty_note(Loc.t("Nenhum monstro no Depot. Monstros do grupo precisam sair do grupo antes."), "altar"))
		else:
			# seleção rápida + ação em lote fixa (fora da rolagem)
			var qs := UI.hbox(6)
			for q in [[Loc.t("Todos (sem shiny)"), 101], [Loc.t("Qualidade < 40%"), 40], [Loc.t("Qualidade < 70%"), 70]]:
				var lim: int = q[1]
				var qb := UI.small_button(q[0], func(): _select_quality(dep, lim))
				qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				qb.add_theme_font_size_override("font_size", 16)
				qs.add_child(qb)
			var cb := UI.small_button(Loc.t("Limpar"), func(): _set_all(dep, false))
			cb.add_theme_font_size_override("font_size", 16)
			qs.add_child(cb)
			b.add_child(qs)
			b.move_child(qs, sc[0].get_index())
			sel_bar = UI.icon_button("gem", "", _convert_selected, 21, 66, "primary")
			b.add_child(sel_bar)
		for m in dep:
			var p := UI.card(bool(m.shiny))
			var row := UI.hbox(8)
			p.add_child(row)
			var uid: String = m.uid
			var box := UI.check_box(sel.has(uid), func(): _toggle(uid))
			sel_boxes[uid] = box
			row.add_child(box)
			row.add_child(UI.portrait_frame(MonsterLogic.form_id(m), bool(m.shiny), 52))
			var v := UI.vbox(2)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(v)
			var nl := UI.label("%s · %s" % [MonsterLogic.display_name(m), Loc.t("Nv %d") % int(m.level)], 19, Color(1, 0.88, 0.45) if m.shiny else UI.C_TEXT)
			nl.clip_text = true
			v.add_child(nl)
			var r := UI.hbox(4)
			r.add_child(UI.quality_badge(m, 14))
			r.add_child(UI.label("→ %d %s" % [EssenceLogic.essence_value(m), Loc.t("Essência de %s") % DataDB.type_name(MonsterLogic.type_of(m))], 16, DataDB.type_color(MonsterLogic.type_of(m)).lightened(0.3)))
			v.add_child(r)
			row.add_child(UI.small_button(Loc.t("Trocar"), func(): _convert(uid), "danger" if m.shiny else ""))
			sc[1].add_child(p)
		_update_bar()
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
				for g in ItemLogic.enhance_gain(it):
					v.add_child(UI.label(Loc.t("Ganho: %s") % g.text, 17, UI.C_GOOD, true))
				v.add_child(UI.label(Loc.t("+%d → +%d · chance %d%% · custo: %d Essência de %s + %s ouro") % [enh, enh + 1, int(EssenceLogic.enhance_chance(enh) * 100), int(c.essence), DataDB.type_name(c.essence_type), UI.fmt(c.gold)], 15, UI.C_MUTED, true))
			var iu: String = it.uid
			var bt := UI.small_button(Loc.t("Aprimorar"), func(): _enhance(iu), "primary")
			bt.disabled = enh >= int(DataDB.config.enhance.max)
			row.add_child(bt)
			sc[1].add_child(p)


func _toggle(uid: String) -> void:
	if sel.has(uid):
		sel.erase(uid)
	else:
		sel[uid] = true
	if sel_boxes.has(uid):
		UI.set_checked(sel_boxes[uid], sel.has(uid))
	_update_bar()


func _set_all(dep: Array, on: bool) -> void:
	for m in dep:
		if on:
			sel[m.uid] = true
		else:
			sel.erase(m.uid)
		if sel_boxes.has(m.uid):
			UI.set_checked(sel_boxes[m.uid], sel.has(m.uid))
	_update_bar()


## Seleciona todos os não-shiny com qualidade abaixo do limite (101 = todos).
func _select_quality(dep: Array, limit: int) -> void:
	for m in dep:
		var on: bool = not m.shiny and int(m.get("quality", 0)) < limit
		if on:
			sel[m.uid] = true
		else:
			sel.erase(m.uid)
		if sel_boxes.has(m.uid):
			UI.set_checked(sel_boxes[m.uid], on)
	_update_bar()


func _selection_totals() -> Dictionary:
	var totals := {}
	for uid in sel:
		var m := Game.monster(uid)
		if m.is_empty():
			continue
		var t := MonsterLogic.type_of(m)
		totals[t] = int(totals.get(t, 0)) + EssenceLogic.essence_value(m)
	return totals


func _update_bar() -> void:
	if not is_instance_valid(sel_bar):
		return
	var total := 0
	for v in _selection_totals().values():
		total += int(v)
	sel_bar.text = Loc.t("Trocar selecionados (%d) → %s Essência") % [sel.size(), UI.fmt(total)]
	sel_bar.disabled = sel.is_empty()


func _convert_selected() -> void:
	if busy or sel.is_empty():
		return
	var lines: Array = []
	var shinies := 0
	for uid in sel:
		if Game.monster(uid).get("shiny", false):
			shinies += 1
	var totals := _selection_totals()
	for t in totals:
		lines.append("+%s %s" % [UI.fmt(totals[t]), Loc.t("Essência de %s") % DataDB.type_name(t)])
	if not await main.confirm(Loc.t("Trocar em lote"), Loc.t("Trocar %d monstros?") % sel.size() + "\n" + "\n".join(lines) + "\n" + Loc.t("Todos ficam registrados na Coleção.")):
		return
	if shinies > 0 and not await main.confirm(Loc.t("ATENÇÃO: SHINY"), Loc.t("A seleção tem %d SHINY! Tem certeza ABSOLUTA? Não há como desfazer.") % shinies, Loc.t("Trocar mesmo"), Loc.t("Cancelar")):
		return
	busy = true
	var r: Dictionary = await Game.convert_monsters(sel.keys())
	busy = false
	sel.clear()
	if r.get("ok", false):
		toast(Loc.t("%d monstros trocados por Essência!") % int(r.converted), UI.C_GOLD, "gem")
	else:
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)
	rebuild()


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
	var before: Dictionary = Game.save.items.get(uid, {}).duplicate(true)
	var gains := ItemLogic.enhance_gain(before)
	var r: Dictionary = await Game.enhance_item(uid)
	busy = false
	if not r.get("ok", false):
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)
	elif r.get("success", false):
		var lines: Array = [Loc.t("%s agora é +%d.") % [ItemLogic.display_name(Game.save.items.get(uid, before)), int(before.get("enh", 0)) + 1]]
		for g in gains:
			lines.append(g.text)
		var holder := _wearer(uid)
		if holder != "":
			lines.append("\n" + Loc.t("%s, que está usando o item, ficou mais forte!") % holder)
		else:
			lines.append("\n" + Loc.t("Equipe o item em um monstro para usar o bônus."))
		main.dialog(Loc.t("Aprimorado!"), "\n".join(lines), [Loc.t("OK")], "sparkle")
	else:
		main.dialog(Loc.t("Não foi desta vez"), Loc.t("O aprimoramento falhou (chance de %d%%). O item continua intacto; só o custo foi gasto. Tente de novo!") % int(EssenceLogic.enhance_chance(int(before.get("enh", 0))) * 100), [Loc.t("OK")], "cross")
	rebuild()


## Nome do monstro que está usando o item ("" se nenhum).
func _wearer(item_uid: String) -> String:
	for m in Game.save.monsters.values():
		if m.get("equip", {}).values().has(item_uid):
			return MonsterLogic.display_name(m)
	return ""
