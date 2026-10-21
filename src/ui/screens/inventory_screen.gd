extends Screen
## Inventário: equipar, vender (com trava contra venda acidental), guardar no Depot e expandir.

var slot_filter := 0
var equip_item := ""


func build() -> void:
	var b := make_layout("Inventário")
	var top := UI.hbox(8)
	b.add_child(top)
	top.add_child(UI.expand(UI.label("%d / %d itens" % [Game.inv_count(), Game.inv_cap()], 22)))
	if Game.inv_cap() < int(DataDB.config.inventory.max_cap):
		top.add_child(UI.small_button("+%d vagas (%s ouro)" % [int(DataDB.config.inventory.expand_step), UI.fmt(Game.inventory_expand_cost())], _expand))
	var names := ["Todos"]
	for s in DataDB.item_slots:
		names.append(s.name)
	b.add_child(tabs(names, slot_filter, func(i): slot_filter = i; rebuild()))
	var auto := UI.hbox(8)
	b.add_child(auto)
	for r in ["comum", "incomum"]:
		var key = "auto_sell_" + r
		var on: bool = Game.save.settings.get(key, false)
		var bt := UI.small_button(("☑" if on else "☐") + " Auto-vender %s" % DataDB.rarity(r).name, func():
			Game.save.settings[key] = not Game.save.settings.get(key, false)
			rebuild())
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		auto.add_child(bt)
	if equip_item != "":
		_equip_picker(b)
	var sc := UI.scroll(6)
	b.add_child(sc[0])
	var items := Game.inv_items()
	items.sort_custom(func(a, c): return DataDB.rarity_index[a.rarity] * 1000 + ItemLogic.base(a).tier > DataDB.rarity_index[c.rarity] * 1000 + ItemLogic.base(c).tier)
	for it in items:
		var bs := ItemLogic.base(it)
		if slot_filter > 0 and bs.slot != DataDB.item_slots[slot_filter - 1].id:
			continue
		sc[1].add_child(_row(it))
	if items.is_empty():
		sc[1].add_child(UI.label("Inventário vazio. Itens caem dos monstros durante a caçada.", 20, UI.C_MUTED, true))


func _row(it: Dictionary) -> Control:
	var p := UI.panel()
	var v := UI.vbox(4)
	p.add_child(v)
	var desc := ItemLogic.describe(it)
	v.add_child(UI.label("%s%s" % [ItemLogic.display_name(it), "  [travado]" if it.get("locked", false) else ""], 21, DataDB.rarity_color(it.rarity)))
	v.add_child(UI.label(" · ".join(desc), 17, UI.C_MUTED, true))
	var row := UI.hbox(6)
	v.add_child(row)
	var iu: String = it.uid
	row.add_child(UI.small_button("Equipar", func(): equip_item = iu; rebuild()))
	var sell := UI.small_button("Vender %s" % UI.fmt(ItemLogic.sell_price(it)), func(): _sell(iu))
	sell.disabled = it.get("locked", false)
	row.add_child(sell)
	row.add_child(UI.small_button("Destravar" if it.get("locked", false) else "Travar", func(): Game.toggle_lock(iu); rebuild()))
	row.add_child(UI.small_button("Depot", func():
		var r := Game.move_item(iu, "depot")
		if not r.ok:
			toast(r.error, UI.C_BAD)
		rebuild()))
	return p


func _equip_picker(b: VBoxContainer) -> void:
	var it: Dictionary = Game.save.items.get(equip_item, {})
	var p := UI.panel(Color("#24211d"), UI.C_GOLD)
	b.add_child(p)
	var v := UI.vbox(6)
	p.add_child(v)
	v.add_child(UI.label("Equipar %s em:" % ItemLogic.display_name(it), 21, UI.C_GOLD))
	for m in Game.party_monsters() + Game.depot_monsters().slice(0, 6):
		var row := UI.hbox(6)
		row.add_child(UI.portrait(MonsterLogic.form_id(m), bool(m.shiny), 44))
		row.add_child(UI.expand(UI.label("%s Nv %d" % [MonsterLogic.display_name(m), int(m.level)], 20)))
		var uid: String = m.uid
		row.add_child(UI.small_button("Equipar", func():
			var r := Game.equip(uid, equip_item)
			toast("Equipado!" if r.ok else r.error, UI.C_GOOD if r.ok else UI.C_BAD)
			equip_item = ""
			rebuild()))
		v.add_child(row)
	v.add_child(UI.small_button("Cancelar", func(): equip_item = ""; rebuild()))


func _sell(uid: String) -> void:
	var it: Dictionary = Game.save.items.get(uid, {})
	if DataDB.rarity_index.get(it.rarity, 0) >= 2:
		if not await main.confirm("Vender", "Vender %s (%s) por %s de ouro?" % [ItemLogic.display_name(it), DataDB.rarity(it.rarity).name, UI.fmt(ItemLogic.sell_price(it))]):
			return
	var r: Dictionary = await Game.sell_item(uid)
	if r.get("ok", false):
		toast("+%s ouro" % UI.fmt(r.get("gold_gained", 0)), UI.C_GOLD)
	else:
		toast(r.get("error", "Falhou"), UI.C_BAD)
	rebuild()


func _expand() -> void:
	var r: Dictionary = await Game.expand_inventory()
	if not r.get("ok", false):
		toast(r.get("error", "Falhou"), UI.C_BAD)
	rebuild()
