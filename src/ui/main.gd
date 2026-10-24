extends Control
## Cena principal: navegação entre telas, área do banner, avisos, diálogos e menu de debug.

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
	"daily": preload("res://src/ui/screens/daily_boss_screen.gd"),
	"settings": preload("res://src/ui/screens/settings_screen.gd"),
	"boosts": preload("res://src/ui/screens/boosts_screen.gd"),
	"diamonds": preload("res://src/ui/screens/diamonds_screen.gd"),
}
const HuntScreen := preload("res://src/ui/screens/hunt_screen.gd")
const DebugMenu := preload("res://src/debug/debug_menu.gd")

var content: Control
var host: Control
var banner_area: PanelContainer
var overlay: Control
var notify: NotifyCenter
var hunt_screen: Control = null
var stack: Array = []
var current: Control = null
var banner_h := 0.0


func _ready() -> void:
	theme = UI.theme()
	ThemeDB.fallback_font = UI.font()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.background())
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(host)
	banner_area = UI.panel("card_dim")
	banner_area.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	banner_area.visible = false
	var bl := UI.label("", 18, UI.C_MUTED)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_area.add_child(bl)
	add_child(banner_area)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	notify = NotifyCenter.new()
	overlay.add_child(notify)
	Ads.banner_visibility_changed.connect(_on_banner)
	get_tree().set_auto_accept_quit(false)
	get_tree().quit_on_go_back = false
	if OS.is_debug_build():
		var dbg = DebugMenu.new()
		dbg.main = self
		overlay.add_child(dbg)
	goto("title", {}, false)
	Billing.set_overlay(overlay)
	await Ads.init_ads(overlay)


func _on_banner(visible_b: bool, h: float) -> void:
	banner_h = h if visible_b else 0.0
	banner_area.visible = visible_b
	banner_area.offset_top = -banner_h
	banner_area.offset_bottom = 0
	var lbl: Label = banner_area.get_child(0)
	lbl.text = Loc.t("Banner AdMob — teste simulado") if Ads.simulated else ""
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
	if not Game.session_started or not Game.has_starter() or (hunt_screen and hunt_screen.in_boss_fight()):
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
	_maybe_tip(name)
	if name in ["title", "starter"]:
		Ads.hide_banner()
	else:
		Ads.show_banner()
	# sem anúncio em tela cheia ao abrir o Hub: foco em retenção (ficam o banner e os premiados opcionais)


## Explicação curta que aparece só na primeira visita a cada área do Hub.
func _maybe_tip(name: String) -> void:
	var tips := {
		"hub": ["house", Loc.t("Hub"), Loc.t("Daqui você chega a todas as áreas do jogo. Toque em Caçar para voltar ao mapa a qualquer momento.")],
		"hunts": ["map", Loc.t("Hunts"), Loc.t("Cada hunt tem um bioma, monstros e nível. A etiqueta mostra o risco para o seu grupo e a estimativa de abates e XP por hora. Use a barra de elementos para filtrar.")],
		"party": ["paw", Loc.t("Grupo"), Loc.t("Até 3 monstros. Só o primeiro luta até o nível 110; depois 2, e no 210 os 3. Se um cair, o próximo entra. A reserva também ganha XP.")],
		"monster": ["bolt", Loc.t("Monstro"), Loc.t("Equipe itens, compre Estrelas com Essência e Treine com ouro: cada treino dá +Ataque e +Defesa, e em +5, +10 e +15 o monstro ganha um brilho especial.")],
		"depot": ["chest", Loc.t("Depot"), Loc.t("Monstros recrutados ficam aqui. Coloque no grupo, troque no Altar ou guarde para a Coleção. Itens guardados também ficam aqui.")],
		"altar": ["altar", Loc.t("Altar de Essências"), Loc.t("Troque monstros por Essência do tipo deles (qualidade alta rende mais) e aprimore itens. Dá para trocar vários de uma vez.")],
		"collection": ["book", Loc.t("Coleção"), Loc.t("Todas as 135 formas. Os Marcos de Caça de cada espécie dão bônus permanentes para a conta inteira — o resumo fica no topo.")],
		"inventory": ["bag", Loc.t("Inventário"), Loc.t("Equipe, trave, guarde no Depot ou venda (inclusive em lote). Itens travados nunca são vendidos por engano.")],
		"shop": ["shop", Loc.t("Loja"), Loc.t("5 ofertas que mudam a cada 6 horas — às vezes aparece um Épico ou Lendário (bem caros!). Você pode pagar em ouro para trocar as ofertas.")],
		"market": ["scales", Loc.t("Market"), Loc.t("Compre e venda com outros jogadores de todos os idiomas. Itens Raros ou melhores e Essências podem ser negociados.")],
		"rankings": ["trophy", Loc.t("Rankings"), Loc.t("Compare nível, coleção, shinies, estrelas e tempos de Desafio — no geral e na semana.")],
		"challenges": ["skull", Loc.t("Desafios"), Loc.t("Chefes com mecânicas especiais. Vencer libera novas hunts e dá recompensas garantidas. Leve monstros com vantagem de tipo!")],
		"boosts": ["boost", Loc.t("Bônus"), Loc.t("Cada bônus dobra algo: XP, chance de shiny, recrutamento, drop ou ouro. Assista a um anúncio para 15 minutos grátis ou use diamantes para 8 horas.")],
		"daily": ["crown", Loc.t("Chefe Diário"), Loc.t("Um chefe novo por dia e 3 entradas. Quanto mais dano, mais ouro e Essência; vencer garante um item Raro ou melhor.")],
	}
	if not tips.has(name) or not Game.has_starter():
		return
	var seen: Dictionary = Game.save.settings.get("tips_seen", {})
	if seen.get(name, false):
		return
	seen[name] = true
	Game.save.settings.tips_seen = seen
	var t: Array = tips[name]
	dialog(t[1], t[2], [Loc.t("Entendi")], t[0])


func _close_current() -> void:
	if current:
		current.queue_free()
		current = null


func back() -> void:
	for ch in overlay.get_children():
		if ch is UIDialog:
			ch._choose(-1)
			return
	if current == null:
		if hunt_screen and hunt_screen.visible and not hunt_screen.in_boss_fight():
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
	goto(prev.name, prev.params, false)


func refresh_current() -> void:
	if current:
		current.rebuild()


func toast(text: String, color := UI.C_TEXT, icon_name := "") -> void:
	notify.push(text, color, icon_name)


func dialog(t: String, text: String, buttons: Array, icon_name := "") -> UIDialog:
	return UI.dialog(overlay, t, text, buttons, icon_name)


func confirm(t: String, text: String, yes := "", no := "") -> bool:
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
	lines.append(Loc.t("Tempo fora: %s") % UI.fmt_time(float(s.get("seconds", 0))))
	lines.append(Loc.t("Abates: %s") % UI.fmt(s.kills))
	lines.append(Loc.t("Ouro: +%s") % UI.fmt(s.gold))
	var party := Game.party_monsters()
	for i in mini(party.size(), s.xp.size()):
		var m: Dictionary = party[i]
		var lv: int = s.levels[i] if i < s.levels.size() else 0
		var extra := (Loc.t(" (+%d níveis)") % lv) if lv > 0 else ""
		lines.append(Loc.t("%s: +%s XP") % [MonsterLogic.display_name(m), UI.fmt(s.xp[i])] + extra)
	lines.append(Loc.t("Itens Comuns/Incomuns: %d") % int(s.local_items))
	if int(s.local_lost) > 0:
		lines.append(Loc.t("%d itens perdidos (inventário cheio)") % int(s.local_lost))
	for it in s.get("items", []):
		lines.append("%s: %s" % [DataDB.rarity_name(it.rarity), ItemLogic.display_name(it)])
	for rec in s.get("recruits", []):
		lines.append(Loc.t("Recrutado: %s%s (qualidade %d%%)") % ["✦ " if rec.shiny else "", DataDB.form_name(rec.form), int(rec.get("quality", 0))])
	if int(s.get("shinies", 0)) > 0:
		lines.append(Loc.t("Shinies encontrados: %d") % int(s.shinies))
	var d := dialog(Loc.t("Bem-vindo de volta!"), "\n".join(lines), [Loc.t("Dobrar ▶"), Loc.t("Coletar")], "chest")
	var choice: int = await d.chosen
	Ads.context = ""
	if choice == 0:
		var ok: bool = await Ads.show_rewarded(Loc.t("Dobrar recompensa offline"))
		if ok:
			var r: Dictionary = await Game.double_offline_reward()
			if not r.is_empty():
				toast(Loc.t("Recompensa offline dobrada! +%s ouro") % UI.fmt(r.gold), UI.C_GOLD, "coin")
			else:
				toast(Loc.t("Não foi possível dobrar agora."), UI.C_BAD)
	if hunt_screen:
		hunt_screen.refresh_hud()
