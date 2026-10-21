extends Control
## Cena principal: navegação entre telas, área do banner, overlays (diálogos, toasts, debug).

const SCREENS := {
	"title": preload("res://src/ui/screens/title_screen.gd"),
	"starter": preload("res://src/ui/screens/starter_screen.gd"),
	"hub": preload("res://src/ui/screens/hub_screen.gd"),
	"hunts": preload("res://src/ui/screens/hunt_select_screen.gd"),
	"party": preload("res://src/ui/screens/party_screen.gd"),
	"monster": preload("res://src/ui/screens/monster_screen.gd"),
	"depot": preload("res://src/ui/screens/depot_screen.gd"),
	"altar": preload("res://src/ui/screens/altar_screen.gd"),
	"collection": preload("res://src/ui/screens/collection_screen.gd"),
	"inventory": preload("res://src/ui/screens/inventory_screen.gd"),
	"shop": preload("res://src/ui/screens/shop_screen.gd"),
	"market": preload("res://src/ui/screens/market_screen.gd"),
	"rankings": preload("res://src/ui/screens/rankings_screen.gd"),
	"challenges": preload("res://src/ui/screens/challenges_screen.gd"),
	"settings": preload("res://src/ui/screens/settings_screen.gd"),
}
const HuntScreen := preload("res://src/ui/screens/hunt_screen.gd")
const DebugMenu := preload("res://src/debug/debug_menu.gd")

var content: Control
var host: Control
var banner_area: PanelContainer
var overlay: Control
var hunt_screen: Control = null
var stack: Array = []
var current: Control = null
var banner_h := 0.0


func _ready() -> void:
	theme = UI.theme()
	ThemeDB.fallback_font = UI.font()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	host = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(host)
	banner_area = UI.panel(Color("#0d0c0b"), Color("#3a342b"))
	banner_area.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	banner_area.visible = false
	var bl := UI.label("", 18, UI.C_MUTED)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_area.add_child(bl)
	add_child(banner_area)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	Ads.banner_visibility_changed.connect(_on_banner)
	get_tree().set_auto_accept_quit(false)
	get_tree().quit_on_go_back = false
	if OS.is_debug_build():
		var dbg = DebugMenu.new()
		dbg.main = self
		overlay.add_child(dbg)
	goto("title", {}, false)
	await Ads.init_ads(overlay)


func _on_banner(visible_b: bool, h: float) -> void:
	banner_h = h if visible_b else 0.0
	banner_area.visible = visible_b
	banner_area.offset_top = -banner_h
	banner_area.offset_bottom = 0
	var lbl: Label = banner_area.get_child(0)
	lbl.text = "[ Banner AdMob — %s ]" % ("teste simulado" if Ads.simulated else "ID de teste" if DataDB.ads_cfg.get("use_test_ids", true) else "")
	content.offset_bottom = -banner_h


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_on_resumed()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save_local()
		Backend.persist()
		get_tree().quit()


## No Android o jogo fica pausado em segundo plano: ao voltar, recebe o progresso offline.
func _on_resumed() -> void:
	if not Game.session_started or not Game.has_starter() or (hunt_screen and hunt_screen.in_challenge()):
		return
	await Game.flush_claims()
	var s: Dictionary = await Game.claim_offline()
	if not s.is_empty():
		await show_offline_summary(s)


func ensure_hunt_screen() -> Control:
	if hunt_screen == null:
		hunt_screen = HuntScreen.new()
		hunt_screen.main = self
		content.add_child(hunt_screen)
		content.move_child(hunt_screen, 0)
	return hunt_screen


## Vai para uma tela. "hunt" mostra a tela principal (mapa).
func goto(name: String, params: Dictionary = {}, push := true) -> void:
	if name == "hunt":
		_close_current()
		stack.clear()
		var hs := ensure_hunt_screen()
		hs.visible = true
		hs.on_show()
		Ads.show_banner()
		return
	if push and current != null:
		stack.append({"name": current.get_meta("screen_name"), "params": current.params})
	_close_current()
	var scr: Screen = SCREENS[name].new()
	scr.set_meta("screen_name", name)
	host.add_child(scr)
	current = scr
	if hunt_screen:
		hunt_screen.visible = false
		hunt_screen.set_map_rendering(false)
	scr.open(self, params)
	if name in ["title", "starter"]:
		Ads.hide_banner()
	else:
		Ads.show_banner()
	if name == "hub":
		Ads.maybe_interstitial()


func _close_current() -> void:
	if current:
		current.queue_free()
		current = null


func back() -> void:
	if overlay.get_child_count() > 0:
		for ch in overlay.get_children():
			if ch is UIDialog:
				ch._choose(-1)
				return
	if current == null:
		if hunt_screen and hunt_screen.visible and not hunt_screen.in_challenge():
			goto("hub")
		return
	var nm: String = current.get_meta("screen_name")
	if nm in ["title", "starter"]:
		return
	if stack.is_empty():
		goto("hunt")
		return
	var prev: Dictionary = stack.pop_back()
	_close_current()
	if prev.name == "hunt":
		goto("hunt")
		return
	goto(prev.name, prev.params, false)


func refresh_current() -> void:
	if current:
		current.rebuild()


func toast(text: String, color := UI.C_TEXT) -> void:
	UI.toast(overlay, text, color)


func dialog(t: String, text: String, buttons: Array) -> UIDialog:
	return UI.dialog(overlay, t, text, buttons)


func confirm(t: String, text: String, yes := "Sim", no := "Não") -> bool:
	return await UIDialog.confirm(overlay, t, text, yes, no)


func ask_number(t: String, text: String, default_value: int) -> int:
	return await UIDialog.ask_number(overlay, t, text, default_value)


## Fluxo após o título: sessão, escolha do inicial ou resumo offline + hunt.
func start_game() -> void:
	var summary: Dictionary = await Game.start_session()
	if not Game.has_starter():
		goto("starter", {}, false)
		return
	goto("hunt")
	if not summary.is_empty():
		await show_offline_summary(summary)


func show_offline_summary(s: Dictionary) -> void:
	Ads.context = "offline_summary"
	var lines: Array = []
	lines.append("Tempo fora: %s" % UI.fmt_time(float(s.get("seconds", 0))))
	lines.append("Abates: %s" % UI.fmt(s.kills))
	lines.append("Ouro: +%s" % UI.fmt(s.gold))
	var party := Game.party_monsters()
	for i in mini(party.size(), s.xp.size()):
		var m: Dictionary = party[i]
		var lv: int = s.levels[i] if i < s.levels.size() else 0
		lines.append("%s: +%s XP%s" % [MonsterLogic.display_name(m), UI.fmt(s.xp[i]), (" (+%d níveis)" % lv) if lv > 0 else ""])
	lines.append("Itens Comuns/Incomuns: %d%s" % [int(s.local_items), (" (%d perdidos: inventário cheio)" % int(s.local_lost)) if int(s.local_lost) > 0 else ""])
	for it in s.get("items", []):
		lines.append("Drop %s: %s" % [DataDB.rarity(it.rarity).name, ItemLogic.display_name(it)])
	for rec in s.get("recruits", []):
		lines.append("Recrutado: %s%s" % ["✦ " if rec.shiny else "", DataDB.form(rec.form).name])
	if int(s.get("shinies", 0)) > 0:
		lines.append("Shinies encontrados: %d" % int(s.shinies))
	var d := dialog("Resumo Offline", "\n".join(lines), ["Dobrar (anúncio)", "OK"])
	var choice: int = await d.chosen
	Ads.context = ""
	if choice == 0:
		var ok: bool = await Ads.show_rewarded("Dobrar recompensa offline")
		if ok:
			var r: Dictionary = await Game.double_offline_reward()
			if not r.is_empty():
				toast("Recompensa offline dobrada! +%s ouro" % UI.fmt(r.gold), UI.C_GOLD)
			else:
				toast("Não foi possível dobrar agora.", UI.C_BAD)
	if hunt_screen:
		hunt_screen.refresh_hud()
