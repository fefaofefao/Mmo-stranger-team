class_name GridNav
extends RefCounted
## Navegação em grid: AStarGrid2D para paredes + mapa de ocupação de criaturas.

var astar := AStarGrid2D.new()
var size := Vector2i.ZERO
var solid: Dictionary = {}
var occ: Dictionary = {}


func setup(p_size: Vector2i, p_solid: Dictionary) -> void:
	size = p_size
	solid = p_solid
	occ.clear()
	astar = AStarGrid2D.new()
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for c in solid:
		astar.set_point_solid(c, true)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func walkable(c: Vector2i) -> bool:
	return in_bounds(c) and not solid.has(c)


func is_free(c: Vector2i) -> bool:
	return walkable(c) and not occ.has(c)


func occupy(c: Vector2i, who) -> void:
	occ[c] = who


func release(c: Vector2i, who) -> void:
	if occ.get(c) == who:
		occ.erase(c)


## Caminho de 'from' até 'to' (inclui o destino, exclui a origem).
## avoid_radius > 0 trata células ocupadas próximas como bloqueadas (para contornar criaturas).
func path(from: Vector2i, to: Vector2i, avoid_radius := 0, allow_occupied_dest := true) -> Array:
	if not in_bounds(from) or not in_bounds(to) or solid.has(to):
		return []
	var temp: Array = []
	if avoid_radius > 0:
		for c in occ:
			if c == from or (allow_occupied_dest and c == to):
				continue
			var d: Vector2i = (c - from).abs()
			if max(d.x, d.y) <= avoid_radius:
				astar.set_point_solid(c, true)
				temp.append(c)
	var ids: Array = astar.get_id_path(from, to, true)
	for c in temp:
		astar.set_point_solid(c, false)
	if ids.size() > 0:
		ids.remove_at(0)
	return ids


func neighbors(c: Vector2i) -> Array:
	var out: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var q := c + Vector2i(dx, dy)
			if not walkable(q):
				continue
			# diagonal só se não cortar quina
			if dx != 0 and dy != 0 and (solid.has(Vector2i(c.x + dx, c.y)) or solid.has(Vector2i(c.x, c.y + dy))):
				continue
			out.append(q)
	return out


func nearest_free(c: Vector2i, max_r := 6) -> Vector2i:
	if is_free(c):
		return c
	for r in range(1, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if max(abs(dx), abs(dy)) != r:
					continue
				var q := c + Vector2i(dx, dy)
				if is_free(q):
					return q
	return c
