extends RefCounted
## Shared, static floor navigation. Only public level geometry enters this service.
## Grid coordinates are XZ; paths and steering stay in world coordinates.

var cell_size: float = 1.0
var actor_clearance: float = 0.45
var bounds: Rect2 = Rect2(-56.0, -44.0, 112.0, 88.0)
var grid: AStarGrid2D
var obstacles: Array[Rect2] = []
var _cache: Dictionary = {}
var query_count: int = 0
var failed_queries: int = 0


func setup(level) -> void:
	bounds = level.nav_bounds
	obstacles.clear()
	_cache.clear()
	for value in level.nav_obstacles:
		var rect: Rect2 = value
		obstacles.append(rect.grow(actor_clearance))
	grid = AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(ceili(bounds.size.x / cell_size), ceili(bounds.size.y / cell_size)))
	grid.cell_size = Vector2.ONE * cell_size
	grid.offset = bounds.position + Vector2.ONE * cell_size * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for z in range(grid.region.size.y):
		for x in range(grid.region.size.x):
			var point: Vector2 = grid.get_point_position(Vector2i(x, z))
			if not _point_clear(point):
				grid.set_point_solid(Vector2i(x, z), true)


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	query_count += 1
	var result: PackedVector3Array = PackedVector3Array()
	if grid == null:
		return result
	var start: Vector2i = _nearest_open(_cell(from))
	var finish: Vector2i = _nearest_open(_cell(to))
	if start.x < 0 or finish.x < 0:
		failed_queries += 1
		return result
	var key: String = "%d,%d:%d,%d" % [start.x, start.y, finish.x, finish.y]
	var points: PackedVector2Array
	if _cache.has(key):
		points = _cache[key]
	else:
		points = grid.get_point_path(start, finish, false)
		if _cache.size() > 384:
			_cache.clear()
		_cache[key] = points
	if points.is_empty():
		failed_queries += 1
		return result
	# Greedy line simplification uses the same inflated obstacles as the grid.
	# It cannot cut diagonally through a corner merely because two cells connect.
	var anchor: Vector2 = Vector2(from.x, from.z)
	var next_index: int = 0
	while next_index < points.size():
		var farthest: int = next_index
		for candidate in range(next_index + 1, mini(points.size(), next_index + 32)):
			if _line_clear(anchor, points[candidate]):
				farthest = candidate
			else:
				break
		var point: Vector2 = points[farthest]
		result.append(Vector3(point.x, 0.0, point.y))
		anchor = point
		next_index = farthest + 1
	if is_walkable(to) and _line_clear(anchor, Vector2(to.x, to.z)):
		if result.is_empty() or result[-1].distance_to(to) > 0.15:
			result.append(Vector3(to.x, 0.0, to.z))
	return result


func is_walkable(position: Vector3) -> bool:
	if grid == null:
		return false
	var point: Vector2 = Vector2(position.x, position.z)
	var id: Vector2i = _cell(position)
	return grid.is_in_boundsv(id) and not grid.is_point_solid(id) and _point_clear(point)


func segment_walkable(from: Vector3, to: Vector3) -> bool:
	return _line_clear(Vector2(from.x, from.z), Vector2(to.x, to.z))


func nearest_walkable(position: Vector3) -> Vector3:
	if grid == null:
		return position
	var id: Vector2i = _nearest_open(_cell(position))
	if id.x < 0:
		return position
	var point: Vector2 = grid.get_point_position(id)
	return Vector3(point.x, 0.0, point.y)


func _cell(position: Vector3) -> Vector2i:
	return Vector2i(floori((position.x - bounds.position.x) / cell_size), floori((position.z - bounds.position.y) / cell_size))


func _nearest_open(origin: Vector2i) -> Vector2i:
	var clipped: Vector2i = Vector2i(clampi(origin.x, 0, grid.region.size.x - 1), clampi(origin.y, 0, grid.region.size.y - 1))
	if not grid.is_point_solid(clipped):
		return clipped
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for radius in range(1, 10):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if absi(x) != radius and absi(z) != radius:
					continue
				var test: Vector2i = clipped + Vector2i(x, z)
				if not grid.is_in_boundsv(test) or grid.is_point_solid(test):
					continue
				var distance: float = Vector2(test - origin).length_squared()
				if distance < best_distance:
					best_distance = distance
					best = test
		if best.x >= 0:
			return best
	return best


func _point_clear(point: Vector2) -> bool:
	if not bounds.grow(-actor_clearance).has_point(point):
		return false
	for obstacle in obstacles:
		if obstacle.has_point(point):
			return false
	return true


func _line_clear(from: Vector2, to: Vector2) -> bool:
	var count: int = maxi(1, ceili(from.distance_to(to) / (cell_size * 0.3)))
	for step in range(count + 1):
		if not _point_clear(from.lerp(to, float(step) / float(count))):
			return false
	return true
