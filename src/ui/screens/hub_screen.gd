extends Screen
## Hub central em menu (sem personagem andando).


func build() -> void:
	var b := make_layout("Hub")
	var art := UI.tex(HubArt.texture(), 300)
	art.custom_minimum_size = Vector2(0, 300)
	b.add_child(art)
	var main_m := Game.main_monster()
	if not main_m.is_empty():
		var info := UI.label("%s Nv %d · Coleção %d/135 · Essências: %s" % [MonsterLogic.display_name(main_m), int(main_m.level),
			Game.collection_count(), _ess_total()], 20, UI.C_MUTED, true)
		b.add_child(info)
	var g := UI.grid(2, 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_child(g)
	var items := [
		["⚔ Voltar à Hunt", "hunt"], ["⚑ Hunts", "hunts"],
		["☠ Desafios", "challenges"], ["♥ Grupo", "party"],
		["▣ Depot", "depot"], ["♦ Inventário", "inventory"],
		["● Loja NPC", "shop"], ["⚖ Market", "market"],
		["✦ Altar de Essências", "altar"], ["☰ Coleção", "collection"],
		["★ Rankings", "rankings"], ["⚙ Configurações", "settings"],
	]
	for it in items:
		var target: String = it[1]
		var btn := UI.button(it[0], func(): main.goto(target), 24, 84)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(btn)


func _ess_total() -> String:
	var t := 0
	for k in Game.save.essences:
		t += int(Game.save.essences[k])
	return UI.fmt(t)
