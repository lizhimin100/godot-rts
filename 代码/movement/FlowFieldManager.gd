class_name FlowFieldManager
extends Node

## 流场管理器 — 流场缓存与全局管理
##
## 职责：
##   1. 维护全局 NavigationWorld 引用
##   2. 管理 FlowField 实例（目标变化时重建）
##   3. 提供静态接口供各单位查询方向
##   4. 静止单位标记为障碍，FlowField 自动绕行
##
## 用法：
##   在场景的 Autoload 或顶层节点放置此管理器
##   FlowFieldManager.setup(navigation_world)
##   var dir = FlowFieldManager.get_direction(unit_pos, target_pos)
##
## 缓存策略：
##   - 目标位置变化 < 1px 时不重新计算流场 → 避免重复 BFS
##   - 障碍变化时调用 mark_dirty() 触发网格重建

static var instance: FlowFieldManager

# 导航世界引用
var nav_world: NavigationWorld

# 当前流场
var _current_field: FlowField = null

# 上次计算的目标（世界坐标）
var _last_target: Vector2 = Vector2.ZERO

# 上次计算的目标（网格坐标，用于缓存命中判断）
var _last_target_cell: Vector2i = Vector2i.ZERO

# 需要重建标记
var _dirty: bool = true


func _init() -> void:
	instance = self


## 设置 NavigationWorld 引用
static func setup(world: NavigationWorld) -> void:
	if not instance:
		return
	instance.nav_world = world
	instance._dirty = true
	if not world.grid_changed.is_connected(instance._on_grid_changed):
		world.grid_changed.connect(instance._on_grid_changed)


## 标记障碍变化（建筑建造/拆除后调用）
static func mark_dirty() -> void:
	if not instance:
		return
	instance._dirty = true


## 获取单位在当前位置的行走方向
static func get_direction(world_pos: Vector2, target: Vector2) -> Vector2:
	if not instance or not instance.nav_world:
		return _fallback_direction(world_pos, target)
	return instance._get_direction(world_pos, target)


static func _fallback_direction(from: Vector2, to: Vector2) -> Vector2:
	var dir: Vector2 = (to - from)
	if dir.length_squared() < 0.001:
		return Vector2.ZERO
	return dir.normalized()


func _get_direction(world_pos: Vector2, target: Vector2) -> Vector2:
	var g: Array = nav_world.grid
	if g.is_empty() or g[0].is_empty():
		return _fallback_direction(world_pos, target)

	if _dirty:
		nav_world.rebuild()
		_dirty = false
		_current_field = null

	var target_cell: Vector2i = nav_world.world_to_grid(target)

	if _is_cell_obstacle(target_cell):
		target_cell = _find_nearest_walkable(target_cell)

	if target_cell.x < 0 or target_cell.y < 0:
		return _fallback_direction(world_pos, target)

	# 目标变化超过 1 格 → 重建流场
	if _current_field == null or target_cell != _last_target_cell:
		_last_target_cell = target_cell
		var merged_grid: Array = _build_grid_with_stationary_obstacles()
		_current_field = FlowField.new()
		_current_field.initialize(merged_grid, target_cell)

	var pos_cell: Vector2i = nav_world.world_to_grid(world_pos)
	var dir: Vector2i = _current_field.get_direction(pos_cell)

	if dir == Vector2i.ZERO:
		return _fallback_direction(world_pos, target)

	return Vector2(dir.x, dir.y).normalized()


## 构建含静止单位障碍的合并网格
## 静止单位（velocity < 2px/s）在网格中标记为 1（障碍）
## FlowField BFS 自动绕行，移动单位绕行静止单位
func _build_grid_with_stationary_obstacles() -> Array:
	var src: Array = nav_world.grid
	if src.is_empty() or src[0].is_empty():
		return src

	var w: int = src[0].size()
	var h: int = src.size()

	# 深拷贝基准网格
	var result: Array = []
	for y in range(h):
		result.append([])
		for x in range(w):
			result[y].append(src[y][x])

	# 标记静止单位为障碍
	var tree: SceneTree = get_tree()
	if not tree:
		return result

	for node in tree.get_nodes_in_group("移动单位"):
		if not is_instance_valid(node) or not "velocity" in node:
			continue
		if node.velocity.length_squared() >= 4.0:
			continue
		var g_pos: Vector2i = nav_world.world_to_grid(node.global_position)
		if g_pos.x >= 0 and g_pos.x < w and g_pos.y >= 0 and g_pos.y < h:
			result[g_pos.y][g_pos.x] = 1

	return result


## 判断网格坐标是否为障碍
func _is_cell_obstacle(cell: Vector2i) -> bool:
	var g: Array = nav_world.grid
	if cell.x < 0 or cell.y < 0 or cell.x >= nav_world.grid_width \
			or cell.y >= nav_world.grid_height:
		return true
	return g[cell.y][cell.x] == 1


## 螺旋搜索最近可行格
func _find_nearest_walkable(start: Vector2i) -> Vector2i:
	var g: Array = nav_world.grid
	var max_radius: int = max(nav_world.grid_width, nav_world.grid_height)
	for radius in range(1, max_radius):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var cell: Vector2i = start + Vector2i(dx, dy)
				if cell.x >= 0 and cell.x < nav_world.grid_width \
						and cell.y >= 0 and cell.y < nav_world.grid_height:
					if g[cell.y][cell.x] == 0:
						return cell
	return Vector2i(-1, -1)


func _on_grid_changed() -> void:
	_dirty = true
	_current_field = null
