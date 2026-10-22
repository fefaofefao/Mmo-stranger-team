extends Screen
## Inventário: equipar, vender (com trava contra venda acidental), guardar no Depot e expandir.

var slot_filter := 0
var equip_item := ""


func build() -> void:
	var b := make_layout(Loc.t("Inventário"), "bag")
	var top := UI.hbox(8)
	b.add_child(top)
	top.add_child(UI.chip("bag", "%d / %d" % [Game.inv_count(), Game.inv_cap()], UI.C_TEXT, 19))
	top.add_child(UI.hspace())
	if Game.inv_cap() < int(DataDB.config.inventory.max_cap):
		top.add_child(UI.icon_button("plus", Loc.t("+%d vagas · %s") % [int(DataDB.config.inventory.expand_step), UI.fmt(Game.inventory_expand_cost())], _expand, 18, 56))
	var names := [Loc.t("Todos")]
	for s in DataDB.item_slots:
		names.append(Loc.tx(s.name))
	b.add_child(tabs(names, slot_filter, func(i): slot_filter = i; rebuild()))
	var auto := UI.hbox(8)
	b.add_child(auto)
	for r in ["comum", "incomum"]:
		var key = "auto_sell_" + r
		var on: bool = Game.save.settings.get(key, false)
		var bt := UI.small_button(("☑ " if on else "☐ ") + Loc.t("Auto-vender %s") % DataDB.rarity_name(r), func():
			Game.save.settings[key] = not Game.save.settings.get(key, false)
			rebuild(), "tab_on" if on else "tab")
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		auto.add_child(bt)
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	if equip_item != "":
		_equip_picker(sc[1])
	var items := Game.inv_items()
	items.sort_custom(func(a, c): return DataDB.rarity_index[a.rarity] * 1000 + ItemLogic.base(a).tier > DataDB.rarity_index[c.rarity] * 1000 + ItemLogic.base(c).tier)
	var shown := 0
	for it in items:
		var bs := ItemLogic.base(it)
		if slot_filter > 0 and bs.slot != DataDB.item_slots[slot_filter - 1].id:
			continue
		sc[1].add_child(_row(it))
		shown += 1
	if shown == 0:
		sc[1].add_child(empty_note(Loc.t("Nada aqui. Itens caem dos monstros durante a caçada."), "bag"))


func _row(it: Dictionary) -> Control:
	var p := UI.card()
	var v := UI.vbox(4)
	p.add_child(v)
	var hr := UI.hbox(6)
	v.add_child(hr)
	var nl := UI.label(ItemLogic.display_name(it), 21, DataDB.rarity_color(it.rarity))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	hr.add_child(nl)
	if it.get("locked", false):
		hr.add_child(UI.icon("lock", 24))
	hr.add_child(UI.rarity_badge(it.rarity, 14))
	v.add_child(UI.label(" · ".join(ItemLogic.describe(it)), 16, UI.C_MUTED, true))
	var row := UI.hbox(6)
	v.add_child(row)
	var iu: String = it.uid
	row.add_child(UI.expand(UI.small_button(Loc.t("Equipar"), func(): equip_item = iu; rebuild(), "primary")))
	var sell := UI.expand(UI.small_button(Loc.t("Vender %s") % UI.fmt(ItemLogic.sell_price(it)), func(): _sell(iu)))
	sell.disabled = it.get("locked", false)
	row.add_child(sell)
	row.add_child(UI.expand(UI.small_button(Loc.t("Destravar") if it.get("locked", false) else Loc.t("Travar"), func(): Game.toggle_lock(iu); rebuild())))
	row.add_child(UI.expand(UI.small_button(Loc.t("Depot"), func():
		var r := Game.move_item(iu, "depot")
		if not r.ok:
			toast(Loc.t(r.error), UI.C_BAD)
		rebuild())))
	return p


func _equip_picker(list: VBoxContainer) -> void:
	var it: Dictionary = Game.save.items.get(equip_item, {})
	var p := UI.panel("panel_gold")
	list.add_child(p)
	var v := UI.vbox(6)
	p.add_child(v)
	v.add_child(UI.label(Loc.t("Equipar %s em:") % ItemLogic.display_name(it), 21, UI.C_GOLD))
	for m in Game.party_monsters() + Game.depot_monsters().slice(0, 6):
		var row := UI.hbox(6)
		row.add_child(UI.portrait_frame(MonsterLogic.form_id(m), bool(m.shiny), 44))
		row.add_child(UI.expand(UI.label("%s · %s" % [MonsterLogic.display_name(m), Loc.t("Nv %d") % int(m.level)], 19)))
		var uid: String = m.uid
		row.add_child(UI.small_button(Loc.t("Equipar"), func():
			var r := Game.equip(uid, equip_item)
			toast(Loc.t("Equipado!") if r.ok else Loc.t(r.error), UI.C_GOOD if r.ok else UI.C_BAD)
			equip_item = ""
			rebuild(), "primary"))
		v.add_child(row)
	v.add_child(UI.small_button(Loc.t("Cancelar"), func(): equip_item = ""; rebuild()))


func _sell(uid: String) -> void:
	var it: Dictionary = Game.save.items.get(uid, {})
	if DataDB.rarity_index.get(it.rarity, 0) >= 2:
		if not await main.confirm(Loc.t("Vender"), Loc.t("Vender %s (%s) por %s de ouro?") % [ItemLogic.display_name(it), DataDB.rarity_name(it.rarity), UI.fmt(ItemLogic.sell_price(it))]):
			return
	var r: Dictionary = await Game.sell_item(uid)
	if r.get("ok", false):
		toast(Loc.t("+%s ouro") % UI.fmt(r.get("gold_gained", 0)), UI.C_GOLD, "coin")
	else:
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)
	rebuild()


func _expand() -> void:
	var r: Dictionary = await Game.expand_inventory()
	if not r.get("ok", false):
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)
	rebuild()
