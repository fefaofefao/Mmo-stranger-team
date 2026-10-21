extends RefCounted
## Base das suítes de teste.

var runner


func check(cond: bool, msg: String) -> void:
	runner.check(cond, msg)


func near(a: float, b: float, eps: float, msg: String) -> void:
	runner.near(a, b, eps, msg)
