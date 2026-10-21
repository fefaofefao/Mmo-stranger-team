extends Screen
## Loja NPC: compra de equipamentos Comuns e venda de itens.

var tab := 0


func build() -> void:
	var b := make_layout("Loja NPC")
	b.add_child(tabs(["Comprar", "Vender"], tab, func(i): tab = i; rebuild()))
	var sc := UI.scroll(6)
	b.add_child(sc[0])
	if tab == 0:
		var lvl := Game.main_level()
		sc[1].add_child(UI.label("Equipamentos Comuns (vinculados) até o seu nível. Itens melhores vêm de drops e do Market.", 19, UI.C_MUTED, true))
		var bases: Array = []
		for bid in DataDB.item_bases:
			var bs: Dictionary = DataDB.item_bases[bid]
			if int(bs.level) <= lvl and not bs.world2_only:
				bases.append(bs)
		bases.sort_custom(func(a, c): return int(a.tier) * 100 + DataDB.type_index[a.type] > int(c.tier) * 100 + DataDB.type_index[c.type])
		for bs in bases.slice(0, 72):
			var row := UI.hbox(6)
			var it := {"base": bs.id, "rarity": "comum", "enh": 0, "affixes": []}
			row.add_child(UI.expand(UI.label("%s (Nv %d)\n%s" % [bs.name, int(bs.level), " · ".join(ItemLogic.describe(it).slice(1, 2))], 18)))
			var bid: String = bs.id
			row.add_child(UI.small_button("%s ◉" % UI.fmt(ItemLogic.shop_price(bid)), func(): _buy(bid)))
			sc[1].add_child(row)
	else:
		for it in Game.inv_items():
			var row := UI.hbox(6)
			row.add_child(UI.expand(UI.label(ItemLogic.display_name(it) + ("  [travado]" if it.get("locked", false) else ""), 19, DataDB.rarity_color(it.rarity))))
			var iu: String = it.uid
			var bt := UI.small_button("Vender %s" % UI.fmt(ItemLogic.sell_price(it)), func(): _sell(iu))
			bt.disabled = it.get("locked", false)
			row.add_child(bt)
			sc[1].add_child(row)


func _buy(bid: String) -> void:
	var r: Dictionary = await Game.buy_from_shop(bid)
	toast("Comprado!" if r.get("ok", false) else r.get("error", "Falhou"), UI.C_GOOD if r.get("ok", false) else UI.C_BAD)
	rebuild()


func _sell(uid: String) -> void:
	var it: Dictionary = Game.save.items.get(uid, {})
	if DataDB.rarity_index.get(it.rarity, 0) >= 2:
		if not await main.confirm("Vender", "Vender %s por %s de ouro? No Market ele pode valer mais." % [ItemLogic.display_name(it), UI.fmt(ItemLogic.sell_price(it))]):
			return
	var r: Dictionary = await Game.sell_item(uid)
	toast(("+%s ouro" % UI.fmt(r.get("gold_gained", 0))) if r.get("ok", false) else r.get("error", "Falhou"), UI.C_GOLD if r.get("ok", false) else UI.C_BAD)
	rebuild()
