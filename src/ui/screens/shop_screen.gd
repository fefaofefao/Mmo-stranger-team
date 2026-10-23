extends Screen
## Loja NPC: 5 ofertas rotativas (renovam a cada 6 h ou com ouro) e venda de itens.

var tab := 0
var status: Dictionary = {}
var loading := false
var timer_label: Label


func build() -> void:
	var b := make_layout(Loc.t("Loja NPC"), "shop")
	b.add_child(tabs([Loc.t("Ofertas"), Loc.t("Vender")], tab, func(i): tab = i; rebuild()))
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	if tab == 0:
		if status.is_empty():
			if not loading:
				_load()
			sc[1].add_child(empty_note(Loc.t("Carregando ofertas..."), "clock"))
			return
		var head := UI.card()
		sc[1].add_child(head)
		var hv := UI.hbox(8)
		head.add_child(hv)
		hv.add_child(UI.icon("clock", 34))
		timer_label = UI.label("", 18, UI.C_TEXT, true)
		timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hv.add_child(timer_label)
		var rb := UI.icon_button("swap", Loc.t("Novas ofertas · %s") % UI.fmt(status.refresh_cost), _refresh, 17, 56)
		hv.add_child(rb)
		_tick()
		for i in status.slots.size():
			sc[1].add_child(_offer(i, status.slots[i]))
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


func _offer(i: int, s: Dictionary) -> Control:
	var it: Dictionary = s.item
	var sold: bool = s.sold
	var rar_i := int(DataDB.rarity_index.get(it.rarity, 0))
	var p := UI.card(rar_i >= 2 and not sold, sold)
	var v := UI.vbox(4)
	p.add_child(v)
	var hr := UI.hbox(8)
	v.add_child(hr)
	var nl := UI.label(ItemLogic.display_name(it), 21, DataDB.rarity_color(it.rarity))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	hr.add_child(nl)
	hr.add_child(UI.rarity_badge(it.rarity, 15))
	v.add_child(UI.label(" · ".join(ItemLogic.describe(it)), 15, UI.C_MUTED, true))
	var row := UI.hbox(8)
	v.add_child(row)
	row.add_child(UI.hspace())
	var bb: Button
	if sold:
		bb = UI.button(Loc.t("Vendido"), Callable(), 19, 56)
		bb.disabled = true
	else:
		bb = UI.icon_button("coin", UI.fmt(s.price), func(): _buy(i), 20, 56, "primary")
		bb.disabled = Game.save.gold < int(s.price)
	bb.custom_minimum_size = Vector2(180, 56)
	row.add_child(bb)
	return p


func _load() -> void:
	loading = true
	var r: Dictionary = await Game.shop_status()
	loading = false
	if r.get("ok", false):
		status = r
		status["local_t"] = Time.get_unix_time_from_system()
	if is_inside_tree():
		rebuild()


func _process(_d: float) -> void:
	if is_instance_valid(timer_label) and Engine.get_process_frames() % 30 == 0:
		_tick()


func _tick() -> void:
	if status.is_empty() or not is_instance_valid(timer_label):
		return
	var left := float(status.ends_at) - float(status.server_time) - (Time.get_unix_time_from_system() - float(status.local_t))
	if left <= 0.0 and not loading:
		status = {}
		_load()
		return
	timer_label.text = Loc.t("5 ofertas exclusivas. Novas em %s.") % UI.fmt_time(left)


func _buy(i: int) -> void:
	var s: Dictionary = status.slots[i]
	if int(DataDB.rarity_index.get(s.item.rarity, 0)) >= 2:
		if not await main.confirm(Loc.t("Comprar"), Loc.t("Comprar %s por %s de ouro?") % [ItemLogic.display_name(s.item), UI.fmt(s.price)]):
			return
	var r: Dictionary = await Game.shop_buy(i)
	if r.get("ok", false):
		toast(Loc.t("Comprado! Está no seu inventário."), UI.C_GOOD, "bag")
		s.sold = true
	else:
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)
	rebuild()


func _refresh() -> void:
	if Game.save.gold < int(status.refresh_cost):
		toast(Loc.t("Ouro insuficiente"), UI.C_BAD)
		return
	if not await main.confirm(Loc.t("Novas ofertas"), Loc.t("Trocar as 5 ofertas agora por %s de ouro?") % UI.fmt(status.refresh_cost)):
		return
	var r: Dictionary = await Game.shop_refresh()
	if r.get("ok", false):
		status = r
		status["local_t"] = Time.get_unix_time_from_system()
	else:
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)
	rebuild()


func _sell(uid: String) -> void:
	var it: Dictionary = Game.save.items.get(uid, {})
	if DataDB.rarity_index.get(it.rarity, 0) >= 2:
		if not await main.confirm(Loc.t("Vender"), Loc.t("Vender %s por %s de ouro? No Market ele pode valer mais.") % [ItemLogic.display_name(it), UI.fmt(ItemLogic.sell_price(it))]):
			return
	var r: Dictionary = await Game.sell_item(uid)
	toast((Loc.t("+%s ouro") % UI.fmt(r.get("gold_gained", 0))) if r.get("ok", false) else Loc.t(r.get("error", "Falhou")), UI.C_GOLD if r.get("ok", false) else UI.C_BAD)
	rebuild()
