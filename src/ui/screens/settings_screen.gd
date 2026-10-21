extends Screen
## Configurações: conta, nuvem, preferências, idioma, privacidade.


func build() -> void:
	var b := make_layout("Configurações")
	var sc := UI.scroll(10)
	b.add_child(sc[0])
	var v: VBoxContainer = sc[1]
	v.add_child(UI.label("Conta", 24, UI.C_GOLD))
	v.add_child(UI.label("Nome: %s\nServidor: %s (%s)" % [Game.save.player_name, Backend.mode_name(), "online" if Backend.is_online() else "offline"], 20, UI.C_TEXT, true))
	var row := UI.hbox(8)
	v.add_child(row)
	row.add_child(UI.expand(UI.small_button("Mudar nome", _rename)))
	row.add_child(UI.expand(UI.small_button("Vincular Google", _link)))
	v.add_child(UI.small_button("Sincronizar com a nuvem agora", func():
		await Game.cloud_sync()
		toast("Progresso enviado para a nuvem.", UI.C_GOOD)))
	v.add_child(UI.label("Jogo", 24, UI.C_GOLD))
	var s: Dictionary = Game.save.settings
	for opt in [["show_damage", "Mostrar números de dano"], ["auto_sell_comum", "Auto-vender itens Comuns"], ["auto_sell_incomum", "Auto-vender itens Incomuns"]]:
		var key: String = opt[0]
		v.add_child(UI.small_button(("☑ " if s.get(key, false) else "☐ ") + opt[1], func():
			s[key] = not s.get(key, false)
			rebuild()))
	v.add_child(UI.label("Idioma", 24, UI.C_GOLD))
	var lrow := UI.hbox(8)
	v.add_child(lrow)
	for lc in [["pt_BR", "Português"], ["en", "English (parcial)"]]:
		var code: String = lc[0]
		lrow.add_child(UI.expand(UI.small_button(("● " if s.get("locale", "pt_BR") == code else "○ ") + lc[1], func():
			s.locale = code
			TranslationServer.set_locale(code)
			rebuild())))
	v.add_child(UI.label("Privacidade", 24, UI.C_GOLD))
	v.add_child(UI.small_button("Rever consentimento de anúncios (GDPR)", _consent))
	v.add_child(UI.label("Estatísticas", 24, UI.C_GOLD))
	var st: Dictionary = Game.save.stats
	v.add_child(UI.label("Abates: %s · Mortes: %s · Grupo derrotado: %s" % [UI.fmt(st.get("kills", 0)), UI.fmt(st.get("deaths", 0)), UI.fmt(st.get("wipes", 0))], 19, UI.C_MUTED, true))
	v.add_child(UI.spacer(20))
	var reset := UI.small_button("Apagar progresso local", _reset)
	reset.modulate = Color(1, 0.6, 0.6)
	v.add_child(reset)
	v.add_child(UI.label("Bestiário Idle v%s · Arte placeholder gerada por código · Fonte DejaVu" % ProjectSettings.get_setting("application/config/version", "0.1"), 16, UI.C_MUTED, true))


func _rename() -> void:
	var dd := UIDialog.new()
	main.overlay.add_child(dd)
	dd.build("Nome", "Escolha seu nome no ranking (3 a 20 letras):", ["OK", "Cancelar"], true, Game.save.player_name)
	dd.line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	var le := dd.line_edit
	var i: int = await dd.chosen
	if i != 0:
		return
	var r: Dictionary = await Backend.request("set_name", {"name": le.text})
	if r.get("ok", false):
		Game.save.player_name = r.name
		toast("Nome alterado.", UI.C_GOOD)
	else:
		toast(r.get("error", "Falhou"), UI.C_BAD)
	rebuild()


func _link() -> void:
	var r: Dictionary = await Backend.request("link_google", {})
	toast(r.get("message", "Conta Google vinculada (simulado no mock)." if r.get("ok", false) else r.get("error", "Falhou")))


func _reset() -> void:
	if not await main.confirm("Apagar progresso", "Isso apaga o save LOCAL deste aparelho. O save na nuvem continua lá. Continuar?"):
		return
	Game.reset_all()
	get_tree().reload_current_scene()


func _consent() -> void:
	Game.save.settings.consent_answered = false
	if Ads.simulated:
		await Ads._simulated_consent()
	toast("Preferência registrada.")
