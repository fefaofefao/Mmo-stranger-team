extends Screen
## Market entre jogadores (único para todos os idiomas): listagem por ouro, taxa de 5%, filtros,
## cancelamento e limite de listagens. Só ids trafegam; cada jogador vê os nomes no próprio idioma.

var tab := 0
var filters := {"kind": "item", "slot": "", "rarity": "", "min_enh": 0, "stat": "", "essence_type": "", "sort": "price_asc"}
var results: Array = []
var mine: Array = []
var loading := false
var loaded_tab := -1


func build() -> void:
	var b := make_layout(Loc.t("Market"), "scales")
	var m: Dictionary = DataDB.config.market
	var chips := UI.hbox(6)
	chips.add_child(UI.chip("coin", Loc.t("Taxa %d%%") % int(float(m.fee) * 100), UI.C_TEXT, 16))
	chips.add_child(UI.chip("bag", Loc.t("Até %d listagens") % int(m.max_listings), UI.C_TEXT, 16))
	chips.add_child(UI.chip("globe", Loc.t("Global"), UI.C_INFO, 16))
	b.add_child(chips)
	b.add_child(tabs([Loc.t("Comprar"), Loc.t("Vender"), Loc.t("Minhas")], tab, func(i): tab = i; loaded_tab = -1; rebuild()))
	match tab:
		0: _buy_tab(b)
		1: _sell_tab(b)
		2: _mine_tab(b)


func _opt(items: Array, current: String, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.add_theme_font_size_override("font_size", 19)
	o.custom_minimum_size = Vector2(0, 54)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.focus_mode = Control.FOCUS_NONE
	o.clip_text = true
	var sel := 0
	for i in items.size():
		o.add_item(items[i][1])
		if items[i][0] == current:
			sel = i
	o.select(sel)
	o.item_selected.connect(func(i): cb.call(items[i][0]))
	return o


func _buy_tab(b: VBoxContainer) -> void:
	var fp := UI.panel("inset")
	b.add_child(fp)
	var fv := UI.vbox(6)
	fp.add_child(fv)
	var r1 := UI.hbox(6)
	fv.add_child(r1)
	r1.add_child(_opt([["item", Loc.t("Itens")], ["essence", Loc.t("Essências")]], filters.kind, func(v): filters.kind = v; loaded_tab = -1; rebuild()))
	r1.add_child(_opt([["price_asc", Loc.t("Menor preço")], ["price_desc", Loc.t("Maior preço")], ["newest", Loc.t("Mais recentes")]], filters.sort, func(v): filters.sort = v; loaded_tab = -1; rebuild()))
	if filters.kind == "item":
		var slots := [["", Loc.t("Todo slot")]]
		for s in DataDB.item_slots:
			slots.append([s.id, Loc.tx(s.name)])
		var rars := [["", Loc.t("Toda raridade")]]
		for r in DataDB.rarities:
			if r.server:
				rars.append([r.id, Loc.tx(r.name)])
		var r2 := UI.hbox(6)
		fv.add_child(r2)
		r2.add_child(_opt(slots, filters.slot, func(v): filters.slot = v; loaded_tab = -1; rebuild()))
		r2.add_child(_opt(rars, filters.rarity, func(v): filters.rarity = v; loaded_tab = -1; rebuild()))
		var r3 := UI.hbox(6)
		fv.add_child(r3)
		var enhs := []
		for e in [0, 1, 3, 5, 7, 9]:
			enhs.append([str(e), (Loc.t("Aprim. +%d ou mais") % e) if e > 0 else Loc.t("Qualquer aprim.")])
		r3.add_child(_opt(enhs, str(filters.min_enh), func(v): filters.min_enh = int(v); loaded_tab = -1; rebuild()))
		var stats := [["", Loc.t("Qualquer atributo")]]
		for k in ["hp", "atk", "def", "spd_pct", "crit", "lifesteal", "cdr", "xp_pct", "gold_pct", "hp_pct", "atk_pct", "def_pct"]:
			stats.append([k, ItemLogic.stat_name(k)])
		r3.add_child(_opt(stats, filters.stat, func(v): filters.stat = v; loaded_tab = -1; rebuild()))
	else:
		var ts := [["", Loc.t("Todo tipo")]]
		for t in DataDB.type_ids:
			ts.append([t, DataDB.type_name(t)])
		fv.add_child(_opt(ts, filters.essence_type, func(v): filters.essence_type = v; loaded_tab = -1; rebuild()))
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	if loaded_tab != 0:
		sc[1].add_child(empty_note(Loc.t("Carregando..."), "clock"))
		_load_search()
		return
	if results.is_empty():
		sc[1].add_child(empty_note(Loc.t("Nenhuma oferta com esses filtros."), "scales"))
	for l in results:
		sc[1].add_child(_listing_row(l, true))


func _listing_row(l: Dictionary, buy: bool) -> Control:
	var p := UI.card()
	var row := UI.hbox(8)
	p.add_child(row)
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	if l.kind == "item":
		var hr := UI.hbox(6)
		var nl := UI.label(ItemLogic.display_name(l.item), 20, DataDB.rarity_color(l.item.rarity))
		nl.clip_text = true
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hr.add_child(nl)
		hr.add_child(UI.rarity_badge(l.item.rarity, 13))
		v.add_child(hr)
		v.add_child(UI.label(" · ".join(ItemLogic.describe(l.item).slice(1, 5)), 15, UI.C_MUTED, true))
	else:
		v.add_child(UI.label(Loc.t("%d Essência de %s") % [int(l.amount), DataDB.type_name(l.essence_type)], 20, DataDB.type_color(l.essence_type).lightened(0.3)))
		v.add_child(UI.label(Loc.t("%s ouro cada") % ("%.1f" % (float(l.price) / max(1, int(l.amount)))), 15, UI.C_MUTED))
	if buy:
		v.add_child(UI.label(Loc.t("Vendedor: %s") % l.seller_name, 14, UI.C_MUTED))
	var lid: String = str(l.id)
	if buy:
		var bt := UI.icon_button("coin", UI.fmt(l.price), func(): _buy(lid, int(l.price)), 19, 60, "primary")
		bt.custom_minimum_size = Vector2(150, 60)
		bt.disabled = Game.save.gold < int(l.price)
		row.add_child(bt)
	else:
		var col := UI.vbox(4)
		row.add_child(col)
		col.add_child(UI.chip("coin", UI.fmt(l.price), UI.C_GOLD, 18))
		col.add_child(UI.small_button(Loc.t("Cancelar"), func(): _cancel(lid), "danger"))
	return p


func _load_search() -> void:
	if loading:
		return
	loading = true
	var r: Dictionary = await Backend.request("market_search", {"filters": filters.duplicate()})
	loading = false
	results = r.get("listings", []) if r.get("ok", false) else []
	if not r.get("ok", false):
		toast(Loc.t(r.get("error", "Market indisponível")), UI.C_BAD)
	loaded_tab = 0
	if is_inside_tree():
		rebuild()


func _buy(lid: String, price: int) -> void:
	if not await main.confirm(Loc.t("Comprar"), Loc.t("Comprar por %s de ouro?") % UI.fmt(price)):
		return
	var r: Dictionary = await Game.market_buy(lid)
	toast(Loc.t("Compra concluída!") if r.get("ok", false) else Loc.t(r.get("error", "Falhou")), UI.C_GOOD if r.get("ok", false) else UI.C_BAD)
	loaded_tab = -1
	rebuild()


func _sell_tab(b: VBoxContainer) -> void:
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	var v: VBoxContainer = sc[1]
	v.add_child(UI.section(Loc.t("Itens negociáveis (Raro+)"), "gem"))
	var any := false
	for it in Game.save.items.values():
		if it.get("bound", false) or it.get("loc", "inv") == "equip":
			continue
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
		var bt := UI.small_button(Loc.t("Listar"), func(): _list_item(iu), "primary")
		bt.disabled = it.get("locked", false)
		row.add_child(bt)
		v.add_child(p)
	if not any:
		v.add_child(empty_note(Loc.t("Nenhum item negociável livre (desequipe/destrave para listar)."), "lock"))
	v.add_child(UI.section(Loc.t("Essências"), "gem"))
	for t in DataDB.type_ids:
		var have := int(Game.save.essences.get(t, 0))
		var p := UI.card()
		var row := UI.hbox(6)
		p.add_child(row)
		row.add_child(UI.expand(UI.label("%s: %s" % [DataDB.type_name(t), UI.fmt(have)], 19, DataDB.type_color(t).lightened(0.3))))
		var tt: String = t
		var bt := UI.small_button(Loc.t("Listar"), func(): _list_essence(tt))
		bt.disabled = have <= 0
		row.add_child(bt)
		v.add_child(p)


func _list_item(uid: String) -> void:
	var it: Dictionary = Game.save.items.get(uid, {})
	var price: int = await main.ask_number(Loc.t("Preço"), Loc.t("Preço em ouro para %s (você recebe %d%% após a taxa):") % [ItemLogic.display_name(it), 100 - int(float(DataDB.config.market.fee) * 100)], ItemLogic.sell_price(it) * 2)
	if price <= 0:
		return
	var r: Dictionary = await Game.market_list_item(uid, price)
	toast(Loc.t("Listado!") if r.get("ok", false) else Loc.t(r.get("error", "Falhou")), UI.C_GOOD if r.get("ok", false) else UI.C_BAD)
	rebuild()


func _list_essence(t: String) -> void:
	var have := int(Game.save.essences.get(t, 0))
	var amount: int = await main.ask_number(Loc.t("Quantidade"), Loc.t("Quanta Essência de %s listar? (você tem %d)") % [DataDB.type_name(t), have], have)
	if amount <= 0:
		return
	var price: int = await main.ask_number(Loc.t("Preço"), Loc.t("Preço total em ouro por %d Essência:") % amount, amount * 12)
	if price <= 0:
		return
	var r: Dictionary = await Game.market_list_essence(t, amount, price)
	toast(Loc.t("Listado!") if r.get("ok", false) else Loc.t(r.get("error", "Falhou")), UI.C_GOOD if r.get("ok", false) else UI.C_BAD)
	rebuild()


func _mine_tab(b: VBoxContainer) -> void:
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	if loaded_tab != 2:
		sc[1].add_child(empty_note(Loc.t("Carregando..."), "clock"))
		_load_mine()
		return
	sc[1].add_child(UI.label(Loc.t("%d / %d listagens ativas") % [mine.size(), int(DataDB.config.market.max_listings)], 18, UI.C_MUTED))
	for l in mine:
		sc[1].add_child(_listing_row(l, false))
	if mine.is_empty():
		sc[1].add_child(empty_note(Loc.t("Você não tem listagens ativas."), "scales"))


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
	toast(Loc.t("Listagem cancelada; item devolvido.") if r.get("ok", false) else Loc.t(r.get("error", "Falhou")), UI.C_GOOD if r.get("ok", false) else UI.C_BAD)
	loaded_tab = -1
	rebuild()
