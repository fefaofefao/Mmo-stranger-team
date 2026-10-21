class_name Screen
extends Control
## Base das telas de menu. Cada tela constrói sua UI em build().

var main  # Main
var params: Dictionary = {}
var body: VBoxContainer
var gold_label: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(p_main, p: Dictionary) -> void:
	main = p_main
	params = p
	rebuild()


func rebuild() -> void:
	UI.clear(self)
	var bg := ColorRect.new()
	bg.color = UI.C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	build()


func build() -> void:
	pass


## Cabeçalho padrão (voltar + título + ouro) e corpo com margem. Retorna o VBox do corpo.
func make_layout(p_title: String, show_back := true) -> VBoxContainer:
	var root := UI.vbox(10)
	var mc := UI.margin(root, 14)
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mc)
	var top := UI.hbox(10)
	root.add_child(top)
	if show_back:
		var b := UI.button("◀", func(): main.back(), 28, 64)
		b.custom_minimum_size = Vector2(80, 64)
		top.add_child(b)
	var t := UI.title(p_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	gold_label = UI.label("", 22, UI.C_GOLD)
	top.add_child(gold_label)
	_update_gold()
	if not Game.wallet_changed.is_connected(_update_gold):
		Game.wallet_changed.connect(_update_gold)
	body = UI.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	return body


func _update_gold() -> void:
	if is_instance_valid(gold_label):
		gold_label.text = "◉ %s" % UI.fmt(Game.save.gold)


func on_show() -> void:
	pass


func toast(text: String, color := UI.C_TEXT) -> void:
	main.toast(text, color)


## Barra de abas simples. Retorna o HBox; on_select(index).
func tabs(names: Array, current: int, on_select: Callable) -> HBoxContainer:
	var h := UI.hbox(6)
	for i in names.size():
		var idx := i
		var b := UI.small_button(names[i], func(): on_select.call(idx))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == current:
			b.add_theme_stylebox_override("normal", UI.sb(Color("#6a5838"), UI.C_GOLD))
		h.add_child(b)
	return h
