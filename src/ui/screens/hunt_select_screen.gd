extends Screen
## Seleção de hunts com estimativa de abates/XP por hora para o grupo atual.

const TABS := ["Filhotes", "Adolesc.", "Adultos", "Mistas", "Mundo 2"]
const CATS := ["filhote", "adolescente", "adulto", "mista", "mundo2"]
var tab := -1


func build() -> void:
	var b := make_layout("Hunts")
	if tab < 0:
		var cur: Dictionary = DataDB.hunts.get(Game.save.current_hunt, {})
		tab = maxi(0, CATS.find(cur.get("category", "filhote")))
	b.add_child(tabs(TABS, tab, func(i): tab = i; rebuild()))
	if tab == 4 and not Game.world2_unlocked():
		b.add_child(UI.label("O Mundo 2 é desbloqueado ao vencer o Desafio de nível 80. Biomas corrompidos, grupos mistos, sem recrutamento e drops exclusivos.", 22, UI.C_MUTED, true))
	var fighters := Game.fighter_stats()
	var main_lvl := Game.main_level()
	b.add_child(UI.label("Monstro principal: Nv %d · Lutando: %d" % [main_lvl, fighters.size()], 20, UI.C_MUTED))
	var sc := UI.scroll(8)
	b.add_child(sc[0])
	var list: VBoxContainer = sc[1]
	var cat: String = CATS[tab]
	var rec := Game.recommended_hunt()
	for h in DataDB.hunt_list:
		if h.category != cat:
			continue
		list.add_child(_hunt_row(h, fighters, main_lvl, rec))


func _hunt_row(h: Dictionary, fighters: Array, main_lvl: int, rec: Dictionary) -> Control:
	var current: bool = h.id == Game.save.current_hunt
	var p := UI.panel(Color("#3a3328") if current else UI.C_PANEL, UI.C_GOLD if current else UI.C_BORDER)
	var v := UI.vbox(4)
	p.add_child(v)
	var top := UI.hbox(8)
	v.add_child(top)
	var forms := {}
	for m in h.monsters:
		forms[m.form] = true
	for fid in forms.keys().slice(0, 4):
		var c: Dictionary = Game.save.collection.get(fid, {})
		var pr := UI.portrait(fid, false, 52)
		if not c.get("seen", false):
			pr.modulate = Color(0, 0, 0, 0.8)
		top.add_child(pr)
	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var name := "%s%s" % [h.name, "  ★ recomendada" if not rec.is_empty() and rec.id == h.id else ""]
	info.add_child(UI.label(name, 22, UI.C_GOLD if current else UI.C_TEXT))
	var types := []
	for t in h.types:
		types.append(DataDB.type_name(t))
	info.add_child(UI.label("Nv %d · %s · %s" % [int(h.level), DataDB.biomes[h.biome].name, "/".join(types)], 18, UI.C_MUTED))
	var lock := Game.hunt_lock_reason(h)
	var row := UI.hbox(8)
	v.add_child(row)
	if lock == "":
		var est := KillRate.estimate(fighters, h)
		var xph := KillRate.xp_per_hour(fighters, h, main_lvl) * Game.xp_boost_mult()
		var l := UI.label("~%s abates/h · ~%s XP/h · %s" % [UI.fmt(est.kills_per_hour), UI.fmt(xph), _danger(est)], 18, UI.C_TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if current:
			row.add_child(UI.label("Atual", 20, UI.C_GOLD))
		else:
			row.add_child(UI.small_button("Caçar", func(): _go(h)))
	else:
		row.add_child(UI.label("Bloqueada: " + lock, 18, UI.C_BAD))
	return p


func _danger(est: Dictionary) -> String:
	var d: float = est.deaths_per_hour
	if est.kills_per_hour < 60:
		return "Perigosa!"
	if d > 12:
		return "Arriscada"
	if d > 3:
		return "Desafiadora"
	return "Segura"


func _go(h: Dictionary) -> void:
	await Game.set_current_hunt(h.id)
	var hs = main.ensure_hunt_screen()
	if hs.in_challenge():
		toast("Termine o desafio primeiro.")
		return
	hs.load_current_hunt()
	main.goto("hunt")
