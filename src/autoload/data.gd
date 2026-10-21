extends Node
## Autoload "Data": garante que os dados de balanceamento estejam carregados. Use DataDB para consultas.


func _ready() -> void:
	DataDB.ensure_loaded()
