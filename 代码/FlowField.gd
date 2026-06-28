class_name FlowField
extends RefCounted

# 地图数据（0=可通行，1=障碍），二维数组
var grid : Array = []
var width : int = 0
var height : int = 0

# 积分距离场（每个格子到目标的距离）
var distance_field : Array = []

# 方向场（每个格子的最佳移动方向，Vector2i）
var direction_field : Array = []

# 目标位置（网格坐标）
var goal : Vector2i = Vector2i.ZERO

# 八方向偏移（包括对角线）
const DIRECTIONS = [
	Vector2i( 1,  0), Vector2i(-1,  0),
	Vector2i( 0,  1), Vector2i( 0, -1),
	Vector2i( 1,  1), Vector2i(-1, -1),
	Vector2i( 1, -1), Vector2i(-1,  1)
]


# 初始化地图并构建流场
func initialize(p_grid : Array, p_goal : Vector2i) -> void:
	grid = p_grid
	height = grid.size()
	if height > 0:
		width = grid[0].size()
	goal = p_goal
	build_distance_field()
	build_direction_field()


# 生成/更新距离场（全量构建）
func build_distance_field() -> void:
	distance_field = []
	for y in height:
		distance_field.append([])
		for x in width:
			distance_field[y].append(INF)

	var queue : Array = []
	distance_field[goal.y][goal.x] = 0.0
	queue.append(goal)

	while not queue.is_empty():
		var current : Vector2i = queue.pop_front()
		var dist = distance_field[current.y][current.x]

		for dir in DIRECTIONS:
			var neighbor = current + dir
			if not is_in_bounds(neighbor):
				continue
			if grid[neighbor.y][neighbor.x] == 1:  # 障碍
				continue
			var cost = 1.414 if dir.x != 0 and dir.y != 0 else 1.0
			var new_dist = dist + cost
			if new_dist < distance_field[neighbor.y][neighbor.x]:
				distance_field[neighbor.y][neighbor.x] = new_dist
				queue.append(neighbor)


# 基于距离场构建方向场
func build_direction_field() -> void:
	direction_field = []
	for y in height:
		direction_field.append([])
		for x in width:
			if grid[y][x] == 1 or distance_field[y][x] == INF:
				direction_field[y].append(Vector2i.ZERO)
			else:
				var best_dir = Vector2i.ZERO
				var best_dist = distance_field[y][x]
				for dir in DIRECTIONS:
					var neighbor = Vector2i(x, y) + dir
					if is_in_bounds(neighbor) and grid[neighbor.y][neighbor.x] == 0:
						if distance_field[neighbor.y][neighbor.x] < best_dist:
							best_dist = distance_field[neighbor.y][neighbor.x]
							best_dir = dir
				direction_field[y].append(best_dir)


# 局部更新距离场（当障碍物变化时调用）
func local_update(changed_cells : Array[Vector2i]) -> void:
	var queue : Array = []
	for cell in changed_cells:
		queue.append(cell)

	while not queue.is_empty():
		var current : Vector2i = queue.pop_front()
		var current_dist = distance_field[current.y][current.x]
		var min_neighbor_dist = INF
		for dir in DIRECTIONS:
			var neighbor = current + dir
			if is_in_bounds(neighbor) and grid[neighbor.y][neighbor.x] == 0:
				if distance_field[neighbor.y][neighbor.x] < min_neighbor_dist:
					min_neighbor_dist = distance_field[neighbor.y][neighbor.x]
		var expected = min_neighbor_dist + 1.0
		if abs(current_dist - expected) > 0.01:
			distance_field[current.y][current.x] = expected
			for dir in DIRECTIONS:
				var neighbor = current + dir
				if is_in_bounds(neighbor) and grid[neighbor.y][neighbor.x] == 0:
					queue.append(neighbor)

	build_direction_field()


# 获取指定格子的移动方向
func get_direction(pos : Vector2i) -> Vector2i:
	if not is_in_bounds(pos):
		return Vector2i.ZERO
	if grid[pos.y][pos.x] == 1:
		return Vector2i.ZERO
	if direction_field.size() == 0:
		return Vector2i.ZERO
	return direction_field[pos.y][pos.x]


# 检查坐标是否在地图内
func is_in_bounds(pos : Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height
