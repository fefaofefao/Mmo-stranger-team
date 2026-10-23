extends Screen
## Configurações: idioma, conta, nuvem, preferências e privacidade.


func build() -> void:
	var b := make_layout(Loc.t("Configurações"), "gear")
	var sc := UI.scroll(10)
	b.add_child(sc[0])
	var v: VBoxContainer = sc[1]
	v.add_child(UI.section(Loc.t("Idioma"), "globe"))
	var lrow := UI.hbox(8)
	v.add_child(lrow)
	for l in Loc.LANGS:
		var code: String = l
		lrow.add_child(UI.expand(UI.button(Loc.LANG_NAMES[l], func():
			Game.save.settings.locale = code
			Loc.set_locale(code)
			Game.save_local()
			main.ensure_hunt_screen().queue_free()
			main.hunt_screen = null
			rebuild(), 20, 60, "tab_on" if Loc.locale == l else "tab")))
	v.add_child(UI.label(Loc.t("O Market é o mesmo para todos os idiomas."), 16, UI.C_MUTED, true))
	v.add_child(UI.icon_button("book", Loc.t("Rever tutorial e dicas"), func():
		Game.save.settings.tutorial_done = false
		Game.save.settings.tips_seen = {}
		Game.save.settings.tutorial_force = true
		toast(Loc.t("O tutorial aparece na próxima caçada."), UI.C_GOOD, "check")
		main.goto("hunt"), 19, 60))
	v.add_child(UI.section(Loc.t("Conta"), "user"))
	var card := UI.card()
	v.add_child(card)
	var cv := UI.vbox(6)
	card.add_child(cv)
	cv.add_child(UI.label(Loc.t("Nome: %s") % Game.save.player_name, 20))
	cv.add_child(UI.label(Loc.t("Servidor: %s (%s)") % [Backend.mode_name(), Loc.t("online") if Backend.is_online() else Loc.t("offline")], 17, UI.C_MUTED))
	var row := UI.hbox(8)
	cv.add_child(row)
	row.add_child(UI.expand(UI.small_button(Loc.t("Mudar nome"), _rename)))
	row.add_child(UI.expand(UI.small_button(Loc.t("Vincular Google"), _link)))
	cv.add_child(UI.icon_button("cloud", Loc.t("Sincronizar com a nuvem agora"), func():
		await Game.cloud_sync()
		toast(Loc.t("Progresso enviado para a nuvem."), UI.C_GOOD, "cloud"), 19, 60))
	v.add_child(UI.section(Loc.t("Jogo"), "sword"))
	var s: Dictionary = Game.save.settings
	for opt in [["show_damage", Loc.t("Mostrar números de dano")], ["auto_sell_comum", Loc.t("Auto-vender itens Comuns")], ["auto_sell_incomum", Loc.t("Auto-vender itens Incomuns")]]:
		var key: String = opt[0]
		var on: bool = s.get(key, false)
		v.add_child(UI.button(("☑  " if on else "☐  ") + opt[1], func():
			s[key] = not s.get(key, false)
			rebuild(), 20, 60, "tab_on" if on else "tab"))
	v.add_child(UI.section(Loc.t("Privacidade"), "lock"))
	v.add_child(UI.small_button(Loc.t("Rever consentimento de anúncios (GDPR)"), _consent))
	v.add_child(UI.section(Loc.t("Estatísticas"), "trophy"))
	var st: Dictionary = Game.save.stats
	v.add_child(UI.label(Loc.t("Abates: %s · Quedas: %s · Time derrotado: %s · Chefes diários: %s") % [UI.fmt(st.get("kills", 0)), UI.fmt(st.get("deaths", 0)), UI.fmt(st.get("wipes", 0)), UI.fmt(st.get("daily_boss", 0))], 17, UI.C_MUTED, true))
	v.add_child(UI.spacer(16))
	v.add_child(UI.small_button(Loc.t("Apagar progresso local"), _reset, "danger"))
	v.add_child(UI.label("Bestiário Idle v%s · DejaVu Sans" % ProjectSettings.get_setting("application/config/version", "0.1"), 15, UI.C_MUTED, true))


func _rename() -> void:
	var dd := UIDialog.new()
	main.overlay.add_child(dd)
	dd.build(Loc.t("Nome"), Loc.t("Seu nome no ranking (3 a 20 letras):"), [Loc.t("OK"), Loc.t("Cancelar")], true, Game.save.player_name)
	dd.line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	var le := dd.line_edit
	var i: int = await dd.chosen
	if i != 0:
		return
	var r: Dictionary = await Backend.request("set_name", {"name": le.text})
	if r.get("ok", false):
		Game.save.player_name = r.name
		toast(Loc.t("Nome alterado."), UI.C_GOOD)
	else:
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)
	rebuild()


func _link() -> void:
	var r: Dictionary = await Backend.request("link_google", {})
	if r.get("ok", false):
		toast(Loc.t(r.get("message", "Conta Google vinculada.")), UI.C_GOOD, "user")
	else:
		toast(Loc.t(r.get("error", "Falhou")), UI.C_BAD)


func _consent() -> void:
	Game.save.settings.consent_answered = false
	if Ads.simulated:
		await Ads._simulated_consent()
	toast(Loc.t("Preferência registrada."))


func _reset() -> void:
	if not await main.confirm(Loc.t("Apagar progresso"), Loc.t("Isso apaga o save LOCAL deste aparelho. O save na nuvem continua lá e será restaurado. Continuar?")):
		return
	Game.reset_all()
	get_tree().reload_current_scene()
