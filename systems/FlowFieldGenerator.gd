class_name FlowFieldGenerator
extends RefCounted

## 流场生成器 — BFS Dijkstra 算法实现
##
## 根据目标位置和通行代价地图，生成全局流场。
## 支持障碍整合：障碍物增加通行代价，INF 表示不可通行。
##
## 使用方式：
##   var cost_map = FlowFieldGenerator.binary_to_cost(nav_grid, 100.0)
##   var ff = FlowFieldGenerator.generate(cost_map, target_cell, 64.0, origin)

## 八方向偏移
const DIRS_8: Array[Vector2i] = [
	Vector2i( 1,  0), Vector2i(-1,  0), Vector2i(0,  1), Vector2i(0, -1),
	Vector2i( 1,  1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1,  1)
]

## 方向代价值：[cardinal, diagonal]
const DIR_COST: Array[float] = [1.0, 1.41421356]  # sqrt(2)


# -------- 主生成接口 --------

## 生成流场
##
## @param cost_map   二维 float 数组 cost_map[y][x]
##                    0.0 = 正常通行, >0 = 额外代价, INF = 不可通行
## @param target_cell  目标网格坐标
## @param cell_size    每个格子的世界单位大小（像素）
## @param origin       网格原点 world pos
## @return             生成的 FlowField 实例
static func generate(
	cost_map: Array,
	target_cell: Vector2i,
	cell_size: float,
	origin: Vector2
) -> FFGrid:

	var h: int = cost_map.size()
	var w: int = cost_map[0].size() if h > 0 else 0
	var ff: FFGrid = FFGrid.new(w, h, cell_size, origin)

	if w <= 0 or h <= 0:
		return ff

	# 检查目标是否可达
	if not _is_valid_target(cost_map, target_cell, w, h):
		return ff

	# ---- 1. BFS Dijkstra 传播代价 ----
	ff.cost_grid[target_cell.y][target_cell.x] = 0.0

	# 使用数组模拟队列（pop_front 在数组小的时候够快）
	var queue: Array[Vector2i] = [target_cell]
	var head: int = 0

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_cost: float = ff.cost_grid[current.y][current.x]

		for i in range(8):
			var dir: Vector2i = DIRS_8[i]
			var neighbor: Vector2i = current + dir

			if not _in_bounds(neighbor, w, h):
				continue

			var cell_cost: float = cost_map[neighbor.y][neighbor.x]
			if cell_cost >= INF:
				continue  # 不可通行

			var move_cost: float = DIR_COST[1 if (dir.x != 0 and dir.y != 0) else 0]
			var total: float = current_cost + move_cost * (1.0 + cell_cost)

			if total < ff.cost_grid[neighbor.y][neighbor.x]:
				ff.cost_grid[neighbor.y][neighbor.x] = total
				queue.append(neighbor)

	# ---- 2. 构建方向场 ----
	for y in range(h):
		for x in range(w):
			if ff.cost_grid[y][x] >= INF:
				ff.direction_grid[y][x] = Vector2.ZERO
				continue

			var best_dir: Vector2 = Vector2.ZERO
			var best_cost: float = ff.cost_grid[y][x]

			for i in range(8):
				var dir: Vector2i = DIRS_8[i]
				var neighbor: Vector2i = Vector2i(x, y) + dir

				if not _in_bounds(neighbor, w, h):
					continue
				if cost_map[neighbor.y][neighbor.x] >= INF:
					continue

				var nc: float = ff.cost_grid[neighbor.y][neighbor.x]
				if nc < best_cost:
					best_cost = nc
					best_dir = Vector2(dir.x, dir.y)

			if best_dir != Vector2.ZERO:
				ff.direction_grid[y][x] = best_dir.normalized()

	return ff


# -------- 增量更新 --------

## 增量更新流场（当障碍变化时）
##
## 只重新计算受影响区域的代价，比全量生成快。
## @param changed_cells  发生变化的网格坐标列表
static func local_update(ff: FFGrid, cost_map: Array, changed_cells: Array[Vector2i]) -> void:
	if not ff or not ff.is_valid():
		return

	var w: int = ff.width
	var h: int = ff.height
	var queue: Array[Vector2i] = []

	for cell in changed_cells:
		if _in_bounds(cell, w, h):
			queue.append(cell)

	# 重新传播代价
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_cost: float = ff.cost_grid[current.y][current.x]

		# 从邻居中找最小代价（除自身外）
		var min_neighbor: float = INF
		for i in range(8):
			var n: Vector2i = current + DIRS_8[i]
			if _in_bounds(n, w, h) and cost_map[n.y][n.x] < INF:
				min_neighbor = minf(min_neighbor, ff.cost_grid[n.y][n.x])

		if min_neighbor >= INF:
			continue

		var expected: float = min_neighbor + DIR_COST[0]
		if absf(current_cost - expected) > 0.01:
			ff.cost_grid[current.y][current.x] = expected
			# 扩散到邻居
			for i in range(8):
				var n: Vector2i = current + DIRS_8[i]
				if _in_bounds(n, w, h) and cost_map[n.y][n.x] < INF:
					queue.append(n)

	# 重建方向场（仅影响有变动的区域）
	for y in range(h):
		for x in range(w):
			if ff.cost_grid[y][x] >= INF:
				ff.direction_grid[y][x] = Vector2.ZERO
				continue

			var best_dir: Vector2 = Vector2.ZERO
			var best_cost: float = ff.cost_grid[y][x]

			for i in range(8):
				var dir: Vector2i = DIRS_8[i]
				var n: Vector2i = Vector2i(x, y) + dir
				if _in_bounds(n, w, h) and cost_map[n.y][n.x] < INF:
					var nc: float = ff.cost_grid[n.y][n.x]
					if nc < best_cost:
						best_cost = nc
						best_dir = Vector2(dir.x, dir.y)

			if best_dir != Vector2.ZERO:
				ff.direction_grid[y][x] = best_dir.normalized()


# -------- 辅助工具 --------

## 将二进制网格转换为代价网格
##
## 二进制网格约定（来自 NavigationWorld）：
##   0 = 可通行, 1 = 障碍
##
## @param binary_grid    二维 int/float 数组 (0/1)
## @param obstacle_cost  障碍代价值（默认 INF = 不可通行）
##                       设为有限值如 50.0 可实现"尽量避开但可穿越"
## @return               二维 float 代价数组
static func binary_to_cost(binary_grid: Array, obstacle_cost: float = INF) -> Array:
	var h: int = binary_grid.size()
	if h <= 0:
		return []
	var w: int = binary_grid[0].size() if binary_grid[0] is Array else 0
	if w <= 0:
		return []

	var result: Array = []
	for y in range(h):
		var row: Array = []
		row.resize(w)
		for x in range(w):
			row[x] = 0.0 if binary_grid[y][x] == 0 else obstacle_cost
		result.append(row)
	return result


## 将单位位置信息整合到代价网格中
##
## 静止单位标记为高代价区域，使流场自动绕行。
##
## @param base_cost_map  基础代价网格
## @param unit_positions  单位位置列表（Vector2）
## @param cell_size       格子大小
## @param origin          网格原点
## @param unit_obstacle_cost  单位占用的代价值
## @return                更新后的代价网格（深拷贝，不影响原数据）
static func integrate_units(
	base_cost_map: Array,
	unit_positions: Array[Vector2],
	cell_size: float,
	origin: Vector2,
	unit_obstacle_cost: float = 20.0
) -> Array:
	var h: int = base_cost_map.size()
	if h <= 0:
		return base_cost_map
	var w: int = base_cost_map[0].size() if base_cost_map[0] is Array else 0
	if w <= 0:
		return base_cost_map

	# 深拷贝
	var result: Array = []
	for y in range(h):
		var row: Array = []
		row.resize(w)
		for x in range(w):
			row[x] = base_cost_map[y][x]
		result.append(row)

	# 标记单位占用
	for pos in unit_positions:
		var rel: Vector2 = pos - origin
		var gx: int = int(floor(rel.x / cell_size))
		var gy: int = int(floor(rel.y / cell_size))
		if gx >= 0 and gx < w and gy >= 0 and gy < h:
			if result[gy][gx] < unit_obstacle_cost:
				result[gy][gx] = unit_obstacle_cost

	return result


## 螺旋搜索最近可通行格子
static func find_nearest_walkable(cost_map: Array, start: Vector2i) -> Vector2i:
	var h: int = cost_map.size()
	if h <= 0:
		return Vector2i(-1, -1)
	var w: int = cost_map[0].size() if cost_map[0] is Array else 0
	if w <= 0:
		return Vector2i(-1, -1)

	# 起点本身可通行
	if _in_bounds(start, w, h) and cost_map[start.y][start.x] < INF:
		return start

	var max_radius: int = maxi(w, h)
	for radius in range(1, max_radius):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var cell: Vector2i = start + Vector2i(dx, dy)
				if _in_bounds(cell, w, h) and cost_map[cell.y][cell.x] < INF:
					return cell
	return Vector2i(-1, -1)


# -------- 内部工具 --------

static func _in_bounds(cell: Vector2i, w: int, h: int) -> bool:
	return cell.x >= 0 and cell.x < w and cell.y >= 0 and cell.y < h


static func _is_valid_target(cost_map: Array, target: Vector2i, w: int, h: int) -> bool:
	if not _in_bounds(target, w, h):
		return false
	if cost_map[target.y][target.x] >= INF:
		return false
	return true
