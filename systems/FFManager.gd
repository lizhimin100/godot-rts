class_name FFManager
extends Node

## 流场管理器 — NavigationWorld → FFGrid 的集成层
##
## 职责：
##   1. 读取 NavigationWorld 的二进制网格
##   2. 通过 FlowFieldGenerator 转代价地图 → 生成 FFGrid
##   3. 管理 FFGrid 实例缓存（目标变化时重建）
##   4. 将静止单位标记为障碍，使流场自动绕行
##   5. 处理障碍变化信号（建筑/树木变化时重建）
##
## 使用方式（单例模式）：
##   FFManager.setup(navigation_world)
##   FFManager.update_target(target_pos, units)
##   var ff = FFManager.get_flow_field()
##   var dir = FFManager.get_direction(world_pos, target)
##
## 或直接实例化（放在场景顶层）：
##   var mgr = FFManager.new()
##   add_child(mgr)
##   mgr.setup(nav_world)

signal flow_field_updated

static var instance: FFManager

# -------- 依赖 --------

var nav_world: NavigationWorld = null

# -------- 缓存 --------

var current_ff: FFGrid = null
var _cached_cost_map: Array = []
var _last_target_cell: Vector2i = Vector2i(-1, -1)
var _dirty: bool = true
var _tree: SceneTree = null


func _init() -> void:
	instance = self


func _ready() -> void:
	_tree = get_tree()
	# 自动发现并绑定 NavigationWorld
	var nav: NavigationWorld = _find_navigation_world()
	if nav:
		_setup(nav)


func _find_navigation_world() -> NavigationWorld:
	if not _tree:
		return null
	return _recursive_find_nav(_tree.root)


func _recursive_find_nav(node: Node) -> NavigationWorld:
	if node is NavigationWorld:
		return node
	for child in node.get_children():
		var found: NavigationWorld = _recursive_find_nav(child)
		if found:
			return found
	return null


# -------- 静态接口 --------

static func setup(world: NavigationWorld) -> void:
	if not instance:
		return
	instance._setup(world)


static func mark_dirty() -> void:
	if not instance:
		return
	instance._dirty = true


static func update_target(target: Vector2, units: Array = []) -> void:
	if not instance:
		return
	instance._update_target(target, units)


static func get_flow_field() -> FFGrid:
	if not instance:
		return null
	return instance.current_ff


static func get_direction(world_pos: Vector2, target: Vector2) -> Vector2:
	if not instance:
		return _fallback_dir(world_pos, target)
	return instance._get_direction(world_pos, target)


static func has_valid() -> bool:
	if not instance:
		return false
	return instance.current_ff != null and instance.current_ff.is_valid()


static func clear_cache() -> void:
	if not instance:
		return
	instance._clear()


# -------- 实例方法 --------

func _setup(world: NavigationWorld) -> void:
	nav_world = world
	_dirty = true
	_cached_cost_map = []
	if world and not world.grid_changed.is_connected(_on_grid_changed):
		world.grid_changed.connect(_on_grid_changed)


func _update_target(target: Vector2, units: Array = []) -> void:
	if not nav_world or not _tree:
		return

	# 1. 障碍变化？→ 重建代价网格
	if _dirty or _cached_cost_map.is_empty():
		nav_world.rebuild()
		_cached_cost_map = FlowFieldGenerator.binary_to_cost(nav_world.grid, INF)
		_dirty = false

	if _cached_cost_map.is_empty() or _cached_cost_map[0].is_empty():
		current_ff = null
		return

	# 2. 目标网格坐标
	var target_cell: Vector2i = nav_world.world_to_grid(target)

	# 目标在障碍上 → 螺旋搜索最近可行格
	if not _is_walkable(target_cell):
		target_cell = FlowFieldGenerator.find_nearest_walkable(_cached_cost_map, target_cell)
		if target_cell.x < 0 or target_cell.y < 0:
			current_ff = null
			return

	# 目标未变 + 无脏标记 → 复用缓存
	if target_cell == _last_target_cell and current_ff != null:
		return

	_last_target_cell = target_cell

	# 3. 整合静止单位障碍
	var merged: Array = _cached_cost_map
	if not units.is_empty():
		merged = _integrate_stationary_units(_cached_cost_map, units)

	# 4. 生成流场
	var cell_size: float = 64.0
	if nav_world.ground_layer and nav_world.ground_layer.tile_set:
		cell_size = float(nav_world.ground_layer.tile_set.tile_size.x)

	var origin: Vector2 = Vector2(
		nav_world.grid_offset.x * cell_size,
		nav_world.grid_offset.y * cell_size
	)

	current_ff = FlowFieldGenerator.generate(merged, target_cell, cell_size, origin)
	flow_field_updated.emit()


func _get_direction(world_pos: Vector2, target: Vector2) -> Vector2:
	if current_ff and current_ff.is_valid():
		var d: Vector2 = current_ff.sample(world_pos)
		if d != Vector2.ZERO:
			return d

	var raw: Vector2 = target - world_pos
	if raw.length_squared() < 0.0001:
		return Vector2.ZERO
	return raw.normalized()


func _integrate_stationary_units(base_cost: Array, units: Array) -> Array:
	var positions: Array[Vector2] = []

	for u in units:
		if not is_instance_valid(u):
			continue
		var vel: Vector2 = u.velocity if "velocity" in u else Vector2.ZERO
		if vel.length_squared() < 4.0:  # < 2 px/s
			positions.append(u.global_position)

	if positions.is_empty():
		return base_cost

	var cell_size: float = 64.0
	if nav_world and nav_world.ground_layer and nav_world.ground_layer.tile_set:
		cell_size = float(nav_world.ground_layer.tile_set.tile_size.x)
	var origin: Vector2 = Vector2(
		nav_world.grid_offset.x * cell_size,
		nav_world.grid_offset.y * cell_size
	)

	return FlowFieldGenerator.integrate_units(
		base_cost, positions, cell_size, origin, 20.0
	)


func _is_walkable(cell: Vector2i) -> bool:
	var h: int = _cached_cost_map.size()
	if h <= 0:
		return false
	var w: int = _cached_cost_map[0].size() if _cached_cost_map[0] is Array else 0
	if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h:
		return false
	return _cached_cost_map[cell.y][cell.x] < INF


func _on_grid_changed() -> void:
	_dirty = true
	_cached_cost_map = []


func _clear() -> void:
	current_ff = null
	_last_target_cell = Vector2i(-1, -1)
	_cached_cost_map = []
	_dirty = true


static func _fallback_dir(from: Vector2, to: Vector2) -> Vector2:
	var d: Vector2 = to - from
	if d.length_squared() < 0.001:
		return Vector2.ZERO
	return d.normalized()
