extends SceneTree
## Executor de testes headless:
##   godot --headless --path . -s tests/run_tests.gd
## Sai com código 1 se algum teste falhar.

var failures := 0
var passes := 0
var current := ""


func _initialize() -> void:
	DataDB.load_all()
	var suites := [
		preload("res://tests/test_types.gd"),
		preload("res://tests/test_formulas.gd"),
		preload("res://tests/test_party.gd"),
		preload("res://tests/test_loot.gd"),
		preload("res://tests/test_offline.gd"),
		preload("res://tests/test_essence.gd"),
		preload("res://tests/test_server.gd"),
		preload("res://tests/test_data.gd"),
		preload("res://tests/test_world.gd"),
		preload("res://tests/test_mastery.gd"),
		preload("res://tests/test_economy.gd"),
	]
	for s in suites:
		var inst = s.new()
		inst.runner = self
		for m in inst.get_method_list():
			var n: String = m.name
			if n.begins_with("test_"):
				current = "%s.%s" % [s.resource_path.get_file().get_basename(), n]
				inst.call(n)
	print("\n==== %d asserções OK, %d falhas ====" % [passes, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("FALHOU [%s]: %s" % [current, msg])


func near(a: float, b: float, eps: float, msg: String) -> void:
	check(absf(a - b) <= eps, "%s (obtido %s, esperado %s ± %s)" % [msg, a, b, eps])
