extends Screen
## Market entre jogadores: listagem por ouro, taxa de 5%, filtros, cancelamento e limite de listagens.

var tab := 0
var filters := {"kind": "item", "slot": "", "rarity": "", "min_enh": 0, "stat": "", "essence_type": "", "sort": "price_asc"}
var results: Array = []
var mine: Array = []
var loading := false
var loaded_tab := -1


func build() -> void:
	var b := make_layout("Market")
	var m: Dictionary = DataDB.config.market
	b.add_child(UI.label("Taxa de %d%% sobre a venda · até %d listagens · monstros não podem ser vendidos" % [int(float(m.fee) * 100), int(m.max_listings)], 18, UI.C_MUTED, true))
	b.add_child(tabs(["Comprar", "Vender", "Minhas listagens"], tab, func(i): tab = i; loaded_tab = -1; rebuild()))
	match tab:
		0: _buy_tab(b)
		1: _sell_tab(b)
		2: _mine_tab(b)


func _opt(items: Array, current: String, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.add_theme_font_size_override("font_size", 20)
	o.custom_minimum_size = Vector2(0, 52)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.focus_mode = Control.FOCUS_NONE
	var sel := 0
	for i in items.size():
		o.add_item(items[i][1])
		if items[i][0] == current:
			sel = i
	o.select(sel)
	o.item_selected.connect(func(i): cb.call(items[i][0]))
	return o


func _buy_tab(b: VBoxContainer) -> void:
	var r1 := UI.hbox(6)
	b.add_child(r1)
	r1.add_child(_opt([["item", "Itens"], ["essence", "Essências"]], filters.kind, func(v): filters.kind = v; loaded_tab = -1; rebuild()))
	r1.add_child(_opt([["price_asc", "Menor preço"], ["price_desc", "Maior preço"], ["newest", "Mais recentes"]], filters.sort, func(v): filters.sort = v; loaded_tab = -1; rebuild()))
	if filters.kind == "item":
		var slots := [["", "Todo slot"]]
		for s in DataDB.item_slots:
			slots.append([s.id, s.name])
		var rars := [["", "Toda raridade"]]
		for r in DataDB.rarities:
			if r.server:
				rars.append([r.id, r.name])
		var r2 := UI.hbox(6)
		b.add_child(r2)
		r2.add_child(_opt(slots, filters.slot, func(v): filters.slot = v; loaded_tab = -1; rebuild()))
		r2.add_child(_opt(rars, filters.rarity, func(v): filters.rarity = v; loaded_tab = -1; rebuild()))
		var r3 := UI.hbox(6)
		b.add_child(r3)
		var enhs := []
		for e in [0, 1, 3, 5, 7, 9]:
			enhs.append([str(e), "Aprim. +%d ou mais" % e if e > 0 else "Qualquer aprim."])
		r3.add_child(_opt(enhs, str(filters.min_enh), func(v): filters.min_enh = int(v); loaded_tab = -1; rebuild()))
		var stats := [["", "Qualquer atributo"]]
		for k in ["hp", "atk", "def", "spd_pct", "crit", "lifesteal", "cdr", "xp_pct", "gold_pct", "hp_pct", "atk_pct", "def_pct"]:
			stats.append([k, ItemLogic.STAT_NAMES[k].trim_prefix("% ").trim_prefix("%")])
		r3.add_child(_opt(stats, filters.stat, func(v): filters.stat = v; loaded_tab = -1; rebuild()))
	else:
		var ts := [["", "Todo tipo"]]
		for t in DataDB.type_ids:
			ts.append([t, DataDB.type_name(t)])
		b.add_child(_opt(ts, filters.essence_type, func(v): filters.essence_type = v; loaded_tab = -1; rebuild()))
	var sc := UI.scroll(6)
	b.add_child(sc[0])
	if loaded_tab != 0:
		sc[1].add_child(UI.label("Carregando...", 20, UI.C_MUTED))
		_load_search()
		return
	if results.is_empty():
		sc[1].add_child(UI.label("Nenhuma oferta com esses filtros.", 20, UI.C_MUTED))
	for l in results:
		sc[1].add_child(_listing_row(l, true))


func _listing_row(l: Dictionary, buy: bool) -> Control:
	var p := UI.panel()
	var row := UI.hbox(8)
	p.add_child(row)
	var txt := ""
	var col := UI.C_TEXT
	if l.kind == "item":
		txt = "%s\n%s" % [ItemLogic.display_name(l.item), " · ".join(ItemLogic.describe(l.item).slice(0, 4))]
		col = DataDB.rarity_color(l.item.rarity)
	else:
		txt = "%d Essência de %s\n(%s ouro cada)" % [int(l.amount), DataDB.type_name(l.essence_type), "%.1f" % (float(l.price) / max(1, int(l.amount)))]
		col = DataDB.type_color(l.essence_type).lightened(0.3)
	if buy:
		txt += "\nVendedor: %s" % l.seller_name
	row.add_child(UI.expand(UI.label(txt, 17, col, true)))
	var lid: String = l.id
	if buy:
		var bt := UI.small_button("%s ◉" % UI.fmt(l.price), func(): _buy(lid, int(l.price)))
		bt.disabled = Game.save.gold < int(l.price)
		row.add_child(bt)
	else:
		row.add_child(UI.label("%s ◉" % UI.fmt(l.price), 20, UI.C_GOLD))
		row.add_child(UI.small_button("Cancelar", func(): _cancel(lid)))
	return p


func _load_search() -> void:
	if loading:
		return
	loading = true
	var f := filters.duplicate()
	var r: Dictionary = await Backend.request("market_search", {"filters": f})
	loading = false
	results = r.get("listings", []) if r.get("ok", false) else []
	if not r.get("ok", false):
		toast(r.get("error", "Market indisponível"), UI.C_BAD)
	loaded_tab = 0
	if is_inside_tree():
		rebuild()


func _buy(lid: String, price: int) -> void:
	if not await main.confirm("Comprar", "Comprar por %s de ouro?" % UI.fmt(price)):
		return
	var r: Dictionary = await Game.market_buy(lid)
	toast("Compra concluída!" if r.get("ok", false) else r.get("error", "Falhou"), UI.C_GOOD if r.get("ok", false) else UI.C_BAD)
	loaded_tab = -1
	rebuild()


func _sell_tab(b: VBoxContainer) -> void:
	var sc := UI.scroll(6)
	b.add_child(sc[0])
	var v: VBoxContainer = sc[1]
	v.add_child(UI.label("Itens negociáveis (Raro ou superior, criados pelo servidor):", 21, UI.C_GOLD))
	var any := false
	for it in Game.save.items.values():
		if it.get("bound", false) or it.get("loc", "inv") == "equip":
			continue
		any = true
		var row := UI.hbox(6)
		row.add_child(UI.expand(UI.label("%s%s" % [ItemLogic.display_name(it), "  [travado]" if it.get("locked", false) else ""], 19, DataDB.rarity_color(it.rarity))))
		var iu: String = it.uid
		var bt := UI.small_button("Listar", func(): _list_item(iu))
		bt.disabled = it.get("locked", false)
		row.add_child(bt)
		v.add_child(row)
	if not any:
		v.add_child(UI.label("Nenhum item negociável livre (desequipe/destrave para listar).", 19, UI.C_MUTED, true))
	v.add_child(UI.label("Essências:", 21, UI.C_GOLD))
	for t in DataDB.type_ids:
		var have := int(Game.save.essences.get(t, 0))
		var row := UI.hbox(6)
		row.add_child(UI.expand(UI.label("%s: %d" % [DataDB.type_name(t), have], 19, DataDB.type_color(t).lightened(0.3))))
		var tt: String = t
		var bt := UI.small_button("Listar", func(): _list_essence(tt))
		bt.disabled = have <= 0
		row.add_child(bt)
		v.add_child(row)


func _list_item(uid: String) -> void:
	var it: Dictionary = Game.save.items.get(uid, {})
	var suggested := ItemLogic.sell_price(it) * 2
	var price: int = await main.ask_number("Preço", "Preço em ouro para %s (você recebe %d%% após a taxa):" % [ItemLogic.display_name(it), 100 - int(float(DataDB.config.market.fee) * 100)], suggested)
	if price <= 0:
		return
	var r: Dictionary = await Game.market_list_item(uid, price)
	toast("Listado!" if r.get("ok", false) else r.get("error", "Falhou"), UI.C_GOOD if r.get("ok", false) else UI.C_BAD)
	rebuild()


func _list_essence(t: String) -> void:
	var have := int(Game.save.essences.get(t, 0))
	var amount: int = await main.ask_number("Quantidade", "Quanta Essência de %s listar? (você tem %d)" % [DataDB.type_name(t), have], have)
	if amount <= 0:
		return
	var price: int = await main.ask_number("Preço", "Preço total em ouro por %d Essência:" % amount, amount * 12)
	if price <= 0:
		return
	var r: Dictionary = await Game.market_list_essence(t, amount, price)
	toast("Listado!" if r.get("ok", false) else r.get("error", "Falhou"), UI.C_GOOD if r.get("ok", false) else UI.C_BAD)
	rebuild()


func _mine_tab(b: VBoxContainer) -> void:
	var sc := UI.scroll(6)
	b.add_child(sc[0])
	if loaded_tab != 2:
		sc[1].add_child(UI.label("Carregando...", 20, UI.C_MUTED))
		_load_mine()
		return
	sc[1].add_child(UI.label("%d / %d listagens ativas" % [mine.size(), int(DataDB.config.market.max_listings)], 20, UI.C_MUTED))
	for l in mine:
		sc[1].add_child(_listing_row(l, false))


func _load_mine() -> void:
	if loading:
		return
	loading = true
	var r: Dictionary = await Game.market_my()
	loading = false
	mine = r.get("listings", []) if r.get("ok", false) else []
	loaded_tab = 2
	if is_inside_tree():
		rebuild()


func _cancel(lid: String) -> void:
	var r: Dictionary = await Game.market_cancel(lid)
	toast("Listagem cancelada; item devolvido." if r.get("ok", false) else r.get("error", "Falhou"), UI.C_GOOD if r.get("ok", false) else UI.C_BAD)
	loaded_tab = -1
	rebuild()
