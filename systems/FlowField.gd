class_name FFGrid
extends RefCounted

## 流场数据结构
##
## 存储二维网格，每个格子包含移动方向（Vector2）和累积代价值（float）。
## 支持任意场景复用，不依赖特定节点树。
##
## 使用方式：
##   var ff = FFGrid.new(width, height, 64.0, origin_pos)
##   var dir = ff.sample(unit.global_position)

# -------- 网格属性 --------

## 网格宽度（格子数）
var width: int
## 网格高度（格子数）
var height: int
## 每个格子的世界单位大小（像素）
var cell_size: float = 64.0
## 网格原点（grid[0][0] 对应的世界坐标）
var origin: Vector2 = Vector2.ZERO

# -------- 网格数据 --------

## 方向场：direction_grid[y][x] = Vector2（归一化方向）
## 不可达或障碍格子返回 Vector2.ZERO
var direction_grid: Array = []
## 代价值场：cost_grid[y][x] = float（从目标到该格子的累积通行代价）
## INF 表示不可达
var cost_grid: Array = []

# -------- 构造 --------

func _init(p_width: int, p_height: int, p_cell_size: float, p_origin: Vector2) -> void:
	width = p_width
	height = p_height
	cell_size = p_cell_size
	origin = p_origin

	direction_grid.clear()
	cost_grid.clear()
	for y in range(height):
		var dir_row: Array = []
		var cost_row: Array = []
		dir_row.resize(width)
		cost_row.resize(width)
		for x in range(width):
			dir_row[x] = Vector2.ZERO
			cost_row[x] = INF
		direction_grid.append(dir_row)
		cost_grid.append(cost_row)


# -------- 坐标转换 --------

## 世界坐标 → 网格坐标
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var rel: Vector2 = world_pos - origin
	var gx: int = int(floor(rel.x / cell_size))
	var gy: int = int(floor(rel.y / cell_size))
	return Vector2i(gx, gy)


## 网格坐标 → 世界坐标（格子中心）
func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		origin.x + (float(cell.x) + 0.5) * cell_size,
		origin.y + (float(cell.y) + 0.5) * cell_size
	)


# -------- 边界检查 --------

## 检查网格坐标是否在有效范围内
func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height


## 检查网格坐标是否可通行（非障碍）
func is_walkable(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	return cost_grid[cell.y][cell.x] < INF


# -------- 采样接口 --------

## 在世界坐标位置采样移动方向
##
## 如果该格子不可达，返回 Vector2.ZERO。
## 调用者应回退到直接指向目标的向量。
func sample(world_pos: Vector2) -> Vector2:
	var cell: Vector2i = world_to_grid(world_pos)
	if not is_in_bounds(cell):
		return Vector2.ZERO
	return direction_grid[cell.y][cell.x]


## 获取某格子的累积代价值
func get_cost(world_pos: Vector2) -> float:
	var cell: Vector2i = world_to_grid(world_pos)
	if not is_in_bounds(cell):
		return INF
	return cost_grid[cell.y][cell.x]


## 获取某格子的代价值（网格坐标版本）
func get_cell_cost(cell: Vector2i) -> float:
	if not is_in_bounds(cell):
		return INF
	return cost_grid[cell.y][cell.x]


# -------- 调试 --------

## 判断是否有有效数据（至少有一部分非 INF 的代价值）
func is_valid() -> bool:
	if width <= 0 or height <= 0:
		return false
	# 检查目标点是否可达（cost = 0 的格子）
	for y in range(height):
		for x in range(width):
			if cost_grid[y][x] == 0.0:
				return true
	return false


func _to_string() -> String:
	return "FFGrid(%dx%d, cell=%.1f, origin=%s)" % [width, height, cell_size, origin]
