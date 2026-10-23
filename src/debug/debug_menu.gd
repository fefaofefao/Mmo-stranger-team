extends Control
## Menu de debug (somente build debug). Botão discreto no canto inferior esquerdo.

var main
var panel: PanelContainer
var btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn = Button.new()
	btn.text = "dbg"
	btn.add_theme_font_size_override("font_size", 14)
	btn.modulate = Color(1, 1, 1, 0.35)
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn.position = Vector2(4, -330)
	btn.size = Vector2(52, 40)
	btn.pressed.connect(_toggle)
	add_child(btn)


func _process(_d: float) -> void:
	# mantém o botão acima do banner e do painel inferior
	btn.position = Vector2(4, get_viewport_rect().size.y * 0.45)


func _toggle() -> void:
	if panel and is_instance_valid(panel):
		panel.queue_free()
		panel = null
		return
	_build()


func _hs():
	return main.hunt_screen


func _build() -> void:
	panel = UI.panel("panel_gold")
	panel.position = Vector2(20, 120)
	panel.custom_minimum_size = Vector2(680, 900)
	panel.size = Vector2(680, 900)
	add_child(panel)
	var sc := UI.scroll(6)
	panel.add_child(sc[0])
	var v: VBoxContainer = sc[1]
	v.add_child(UI.label("DEBUG · servidor: %s" % Backend.mode_name(), 22, Color("#d8a8ff")))
	v.add_child(UI.label("Nível do grupo", 20, UI.C_GOLD))
	var g := UI.grid(4, 6)
	v.add_child(g)
	for lv in [1, 10, 16, 35, 60, 80, 110, 150, 200, 210, 300]:
		var l: int = lv
		g.add_child(UI.small_button("Nv %d" % l, func(): _level(l)))
	g.add_child(UI.small_button("+10 níveis", func(): _level(Game.main_level() + 10)))
	v.add_child(UI.label("Velocidade do tempo: x%d" % int(Game.time_scale), 20, UI.C_GOLD))
	var tr := UI.hbox(6)
	v.add_child(tr)
	for s in DataDB.config.debug.time_scales:
		var sp := float(s)
		tr.add_child(UI.expand(UI.small_button("x%d" % int(sp), func(): Game.time_scale = sp; _rebuild())))
	v.add_child(UI.small_button("Simular 8h offline agora", _offline))
	v.add_child(UI.label("Forçar (servidor mock)", 20, UI.C_GOLD))
	var fr := UI.grid(3, 6)
	v.add_child(fr)
	fr.add_child(UI.small_button("Próximo shiny", func(): _force({"shiny": 1}, "Próximo spawn será shiny")))
	fr.add_child(UI.small_button("Próx. recrut.", func(): _force({"recruit": 1}, "Próximo abate recruta")))
	for r in ["raro", "epico", "lendario", "mitico"]:
		var rr: String = r
		fr.add_child(UI.small_button("Drop %s" % DataDB.rarity_name(r), func(): _force({"drop": rr}, "Próximo abate dropa %s" % DataDB.rarity_name(rr))))
	fr.add_child(UI.small_button("Drop Incomum", func(): Game.debug_force_local_drop = "incomum"; main.toast("Próximo drop local: Incomum")))
	v.add_child(UI.label("Recursos", 20, UI.C_GOLD))
	var rr2 := UI.hbox(6)
	v.add_child(rr2)
	rr2.add_child(UI.expand(UI.small_button("+100k ouro", func(): Game.debug_grant(100000, 0); main.toast("+100k ouro"))))
	rr2.add_child(UI.expand(UI.small_button("+1000 Essência (todas)", func(): Game.debug_grant(0, 1000); main.toast("+1000 de cada Essência"))))
	v.add_child(UI.small_button("+1000 diamantes (só servidor mock)", func(): Game.debug_grant(0, 0, 1000); main.toast("+1000 diamantes")))
	v.add_child(UI.small_button("Desbloquear todas as hunts e desafios", func():
		Game.save.debug_unlock_all = true
		main.toast("Tudo desbloqueado")))
	v.add_child(UI.small_button("Recrutar 3 monstros aleatórios", _recruit3))
	v.add_child(UI.small_button("Recrutar 1 SHINY (próximo abate)", func(): _force({"shiny": 1, "recruit": 1}, "Próximo spawn shiny + recrutamento")))
	v.add_child(UI.small_button("Chefe Diário: restaurar entradas", _daily_reset))
	v.add_child(UI.small_button("Marcos: +500 abates nas formas desta hunt", _mastery_boost))
	v.add_child(UI.label("Spawnar monstro na hunt", 20, UI.C_GOLD))
	var sp_grid := UI.grid(3, 6)
	v.add_child(sp_grid)
	var hunt: Dictionary = DataDB.hunts.get(Game.save.current_hunt, {})
	var forms: Array = []
	for m in hunt.get("monsters", []):
		if not forms.has(m.form):
			forms.append(m.form)
	forms.append_array(["fogo_1_3", "agua_2_3", "sombra_5_3"])
	for f in forms:
		var ff: String = f
		sp_grid.add_child(UI.small_button("%s x5" % DataDB.form_name(ff), func(): _spawn(ff)))
	v.add_child(UI.label("Trocar bioma do mapa atual", 20, UI.C_GOLD))
	var bg := UI.grid(3, 6)
	v.add_child(bg)
	for b in DataDB.biomes.values():
		var bid: String = b.id
		bg.add_child(UI.small_button(DataDB.biome_name(bid).substr(0, 14), func(): _biome(bid)))
	v.add_child(UI.small_button("Exportar spritesheets placeholder (user://)", _export_art))
	v.add_child(UI.small_button("RESETAR TUDO (save + servidor mock)", _reset_all))
	v.add_child(UI.small_button("Fechar", _toggle))


func _rebuild() -> void:
	_toggle()
	_toggle()


func _level(l: int) -> void:
	await Game.debug_set_level(l)
	main.toast("Grupo no nível %d" % l)
	if _hs():
		_hs().world.refresh_party()
		_hs().rebuild_hud()


func _force(d: Dictionary, msg: String) -> void:
	if not Backend.is_mock():
		main.toast("Disponível apenas com o servidor mock", UI.C_BAD)
		return
	await Backend.request("debug_force", d)
	if d.has("shiny"):
		Game.tickets.clear()
	main.toast(msg, Color("#d8a8ff"))


func _offline() -> void:
	if not Backend.is_mock():
		main.toast("Disponível apenas com o servidor mock", UI.C_BAD)
		return
	var st: Dictionary = (Backend.impl as MockBackend).logic.p()
	st.last_seen_at = float(st.last_seen_at) - 8 * 3600.0
	var s: Dictionary = await Game.claim_offline()
	if s.is_empty():
		main.toast("Nada a receber (sem hunt atual?)")
	else:
		_toggle()
		main.show_offline_summary(s)


func _recruit3() -> void:
	if not Backend.is_mock():
		return
	await Backend.request("debug_force", {"recruit": 3})
	main.toast("Os próximos 3 abates recrutam")


func _spawn(f: String) -> void:
	if _hs() and not _hs().in_challenge():
		_hs().world.debug_spawn(f, 5)
		main.toast("5x %s" % DataDB.form_name(f))


func _biome(bid: String) -> void:
	if _hs() and not _hs().in_challenge():
		_hs().load_current_hunt(bid)
		_toggle()
		main.goto("hunt")


func _export_art() -> void:
	DirAccess.make_dir_recursive_absolute("user://placeholder_art/monsters")
	DirAccess.make_dir_recursive_absolute("user://placeholder_art/tilesets")
	for f in DataDB.form_list:
		SpriteFactory.generate_sheet(f.form_id).save_png("user://placeholder_art/monsters/%s.png" % f.form_id)
	for b in DataDB.biomes:
		TileFactory.generate_atlas(b).save_png("user://placeholder_art/tilesets/%s.png" % b)
		for i in 3:
			TileFactory.generate_prop(b, i).save_png("user://placeholder_art/tilesets/%s_prop%d.png" % [b, i])
	main.toast("Exportado para %s" % ProjectSettings.globalize_path("user://placeholder_art"))


func _reset_all() -> void:
	if not await main.confirm("Resetar tudo", "Apaga o save local E o servidor mock (carteira, itens, market). Continuar?"):
		return
	if Backend.is_mock():
		await Backend.request("debug_reset")
		Backend.persist()
	Game.reset_all()
	Game.time_scale = 1.0
	get_tree().reload_current_scene()


func _daily_reset() -> void:
	if not Backend.is_mock():
		return
	var p: Dictionary = (Backend.impl as MockBackend).logic.p()
	p.erase("daily")
	main.toast("Entradas do Chefe Diário restauradas")


## Soma 500 abates em cada forma da hunt atual (cliente e servidor mock) para testar os Marcos.
func _mastery_boost() -> void:
	var h: Dictionary = DataDB.hunts.get(Game.save.current_hunt, {})
	for m in h.get("monsters", []):
		Game._add_form_kills(m.form, 500)
		if Backend.is_mock():
			(Backend.impl as MockBackend).logic._add_mastery(m.form, 500)
	main.toast("Marcos: +500 abates em cada forma da hunt")
