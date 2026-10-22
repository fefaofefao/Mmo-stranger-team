extends Screen
## Loja NPC: compra de equipamentos Comuns e venda de itens.

var tab := 0


func build() -> void:
	var b := make_layout(Loc.t("Loja NPC"), "shop")
	b.add_child(tabs([Loc.t("Comprar"), Loc.t("Vender")], tab, func(i): tab = i; rebuild()))
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	if tab == 0:
		var lvl := Game.main_level()
		sc[1].add_child(empty_note(Loc.t("Equipamentos Comuns até o seu nível. Itens melhores vêm de drops e do Market."), "shop"))
		var bases: Array = []
		for bid in DataDB.item_bases:
			var bs: Dictionary = DataDB.item_bases[bid]
			if int(bs.level) <= lvl and not bs.world2_only:
				bases.append(bs)
		bases.sort_custom(func(a, c): return int(a.tier) * 100 + DataDB.type_index[a.type] > int(c.tier) * 100 + DataDB.type_index[c.type])
		for bs in bases.slice(0, 72):
			var p := UI.card()
			var row := UI.hbox(6)
			p.add_child(row)
			var it := {"base": bs.id, "rarity": "comum", "enh": 0, "affixes": []}
			var v := UI.vbox(0)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(v)
			v.add_child(UI.label("%s · %s" % [Loc.tx(bs.name), Loc.t("Nv %d") % int(bs.level)], 19))
			v.add_child(UI.label(" · ".join(ItemLogic.describe(it).slice(1, 2)), 15, UI.C_MUTED))
			var bid: String = bs.id
			var bb := UI.icon_button("coin", UI.fmt(ItemLogic.shop_price(bid)), func(): _buy(bid), 19, 56, "primary")
			bb.custom_minimum_size = Vector2(150, 56)
			row.add_child(bb)
			sc[1].add_child(p)
	else:
		var any := false
		for it in Game.inv_items():
			any = true
			var p := UI.card()
			var row := UI.hbox(6)
			p.add_child(row)
			var l := UI.label(ItemLogic.display_name(it), 19, DataDB.rarity_color(it.rarity))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			row.add_child(l)
			if it.get("locked", false):
				row.add_child(UI.icon("lock", 24))
			var iu: String = it.uid
			var bt := UI.icon_button("coin", UI.fmt(ItemLogic.sell_price(it)), func(): _sell(iu), 19, 56)
			bt.custom_minimum_size = Vector2(150, 56)
			bt.disabled = it.get("locked", false)
			row.add_child(bt)
			sc[1].add_child(p)
		if not any:
			sc[1].add_child(empty_note(Loc.t("Inventário vazio."), "bag"))


func _buy(bid: String) -> void:
	var r: Dictionary = await Game.buy_from_shop(bid)
	toast(Loc.t("Comprado!") if r.get("ok", false) else Loc.t(r.get("error", "Falhou")), UI.C_GOOD if r.get("ok", false) else UI.C_BAD)
	rebuild()


func _sell(uid: String) -> void:
	var it: Dictionary = Game.save.items.get(uid, {})
	if DataDB.rarity_index.get(it.rarity, 0) >= 2:
		if not await main.confirm(Loc.t("Vender"), Loc.t("Vender %s por %s de ouro? No Market ele pode valer mais.") % [ItemLogic.display_name(it), UI.fmt(ItemLogic.sell_price(it))]):
			return
	var r: Dictionary = await Game.sell_item(uid)
	toast((Loc.t("+%s ouro") % UI.fmt(r.get("gold_gained", 0))) if r.get("ok", false) else Loc.t(r.get("error", "Falhou")), UI.C_GOLD if r.get("ok", false) else UI.C_BAD)
	rebuild()
