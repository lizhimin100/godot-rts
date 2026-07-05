class_name FFManager
extends Node

## 流场管理器 — NavigationWorld -> FFGrid 的集成层
##
## 职责：
##   1. 读取 NavigationWorld 的二进制网格
##   2. 通过 FlowFieldGenerator 转代价地图 -> 生成 FFGrid
##   3. 管理 FFGrid 实例缓存（目标变化时重建）
##   4. 将慢速单位标记为障碍，使流场自动绕行
##   5. 处理障碍变化信号（建筑/树木变化时重建）
##
## 使用方式：
##   FFManager.setup(navigation_world)
##   FFManager.request_update(target_pos)
##   var ff = FFManager.get_flow_field()
##   var dir = FFManager.get_direction(world_pos, target)

const DIAG: bool = false

signal flow_field_updated

static var instance: FFManager

var nav_world: NavigationWorld = null
var current_ff: FFGrid = null
var _cached_cost_map: Array = []
var _last_target_cell: Vector2i = Vector2i(-1, -1)
var _dirty: bool = true
var _tree: SceneTree = null

var _cached_all_units: Array = []
var _all_units_frame: int = -1
var _frame_counter: int = 0

var _requested_target: Vector2 = Vector2.ZERO
var _has_pending: bool = false

var _last_bfs_frame := 0
const BFS_THROTTLE_FRAMES := 6

var _integrate_timer: float = 0.0
var _stationary_dirty: bool = true
var _cached_merged: Array = []
var _stationary_cache_valid := false
var _last_stationary_hash := 0
const INTEGRATE_INTERVAL: float = 0.5
const TILE_SIZE_PX: float = 32.0

# B: 慢速单位流场障碍阈值 — 速度 < 8px/s 即视为障碍物
const UNIT_OBSTACLE_VEL_THRESHOLD_SQ: float = 64.0

var _nav_ready_checked: bool = false

func _init() -> void:
	instance = self

func _ready() -> void:
	_tree = get_tree()
	var nav: NavigationWorld = _find_navigation_world()
	if nav:
		if DIAG: print("[FF] Found NavigationWorld: ", nav.name)
		_setup(nav)
		await get_tree().process_frame
		await get_tree().process_frame
		if nav.ground_layer == null or nav.grid.is_empty():
			if DIAG: print("[FF] NavigationWorld not ready, forcing rebuild")
			nav._auto_find_layers()
		if not nav.grid.is_empty():
			if DIAG: print("[FF] NavigationWorld ready: grid=", nav.grid_width, "x", nav.grid_height)
			_dirty = true
		else:
			if DIAG: print("[FF] NavigationWorld grid empty")
	else:
		if DIAG: print("[FF] No NavigationWorld found in scene!")

func _process(delta: float) -> void:
	_frame_counter += 1
	_integrate_timer -= delta
	if _has_pending:
		if _frame_counter - _last_bfs_frame < BFS_THROTTLE_FRAMES:
			return
		_has_pending = false
		_last_bfs_frame = _frame_counter
		_execute_update(_requested_target)

func _find_navigation_world() -> NavigationWorld:
	if not _tree: return null
	return _recursive_find_nav(_tree.root)

func _recursive_find_nav(node: Node) -> NavigationWorld:
	if node is NavigationWorld: return node
	for child in node.get_children():
		var found: NavigationWorld = _recursive_find_nav(child)
		if found: return found
	return null

static func setup(world: NavigationWorld) -> void:
	if not instance: return
	instance._setup(world)

static func mark_dirty() -> void:
	if not instance: return
	instance._dirty = true
	instance._stationary_dirty = true

static func request_update(target: Vector2) -> void:
	if not instance: return
	instance._requested_target = target
	instance._has_pending = true

static func get_flow_field() -> FFGrid:
	if not instance: return null
	return instance.current_ff

static func get_direction(world_pos: Vector2, target: Vector2) -> Vector2:
	if not instance: return _fallback_dir(world_pos, target)
	return instance._get_direction(world_pos, target)

static func setup_nav(ground_layer = null, tree_layer = null) -> void:
	if not instance: return
	var nav: NavigationWorld = instance._find_navigation_world()
	if nav:
		if ground_layer: nav.ground_layer = ground_layer
		if tree_layer: nav.tree_layer = tree_layer
		nav.rebuild()
		instance._setup(nav)

static func is_obstacle(pos: Vector2) -> bool:
	if not instance or not instance.nav_world: return false
	return instance.nav_world.is_obstacle(pos)

static func has_valid() -> bool:
	if not instance: return false
	return instance.current_ff != null and instance.current_ff.is_valid()

static func get_all_units() -> Array:
	if not instance: return []
	return instance._get_all_units()

static func clear_cache() -> void:
	if not instance: return
	instance._clear()

func _setup(world: NavigationWorld) -> void:
	nav_world = world
	_dirty = true
	_cached_cost_map = []
	if world and not world.grid_changed.is_connected(_on_grid_changed):
		world.grid_changed.connect(_on_grid_changed)

func _execute_update(target: Vector2) -> void:
	if not nav_world or not _tree:
		if DIAG: print("[FF] skip _execute_update: nav_world=", nav_world)
		return
	if _dirty or _cached_cost_map.is_empty():
		if DIAG: print("[FF] rebuild nav_world")
		nav_world.rebuild()
		_cached_cost_map = FlowFieldGenerator.binary_to_cost(nav_world.grid, INF)
		_dirty = false
	if _cached_cost_map.is_empty() or _cached_cost_map[0].is_empty():
		if DIAG: print("[FF] cost map empty!")
		current_ff = null
		return
	var target_cell: Vector2i = nav_world.world_to_grid(target)
	if not _is_walkable(target_cell):
		target_cell = FlowFieldGenerator.find_nearest_walkable(_cached_cost_map, target_cell)
		if target_cell.x < 0 or target_cell.y < 0:
			current_ff = null
			return
	if _last_target_cell != Vector2i(-1, -1) and current_ff != null:
		var diff: Vector2i = target_cell - _last_target_cell
		if abs(diff.x) < 1 and abs(diff.y) < 1:
			return
	if target_cell == _last_target_cell and current_ff != null:
		return
	_last_target_cell = target_cell

	# Phase 7.3: 移除慢速单位障碍整合 — 禁止单位作为流场障碍物
	# ⚠ 慢速单位不应成为流场障碍物，否则会导致：
	#   1. 被推单位 C 成为 persistent obstacle → 其他单位流场绕行 → C 更被推
	#   2. 阻塞传播："C 跟着 A 走" 现象
	# 修复：不使用 _cached_merged（含单位障碍），改用纯地形 _cached_cost_map
	# 动态单位分离由 SeparationForceProvider 处理


	var cell_size: float = 64.0
	if nav_world.ground_layer and nav_world.ground_layer.tile_set:
		cell_size = float(nav_world.ground_layer.tile_set.tile_size.x)
	var origin: Vector2 = Vector2(
		nav_world.grid_offset.x * cell_size,
		nav_world.grid_offset.y * cell_size
	)
	current_ff = FlowFieldGenerator.generate(_cached_cost_map, target_cell, cell_size, origin)
	if DIAG: print("[FF] flow field generated: ", current_ff.width, "x", current_ff.height, " valid=", current_ff.is_valid())
	flow_field_updated.emit()

func _get_direction(world_pos: Vector2, target: Vector2) -> Vector2:
	if current_ff and current_ff.is_valid():
		var d: Vector2 = current_ff.sample(world_pos)
		if d != Vector2.ZERO: return d
	var raw: Vector2 = target - world_pos
	if raw.length_squared() < 0.0001: return Vector2.ZERO
	return raw.normalized()

## B: 计算"慢速单位"的hash，用于缓存判断
func _compute_unit_hash() -> int:
	var h: int = 0
	for u in _get_all_units():
		if not is_instance_valid(u): continue
		var vel: Vector2 = u.velocity if "velocity" in u else Vector2.ZERO
		if vel.length_squared() < UNIT_OBSTACLE_VEL_THRESHOLD_SQ:
			h = h * 31 + hash(snapped(u.global_position.x, 8.0))
			h = h * 31 + hash(snapped(u.global_position.y, 8.0))
	return h

## B: 整合慢速单位到流场代价网格（阈值 8px/s，让流场自动绕行）
func _integrate_slow_units(base_cost: Array, units: Array) -> Array:
	var positions: Array[Vector2] = []
	for u in units:
		if not is_instance_valid(u): continue
		var vel: Vector2 = u.velocity if "velocity" in u else Vector2.ZERO
		if vel.length_squared() < UNIT_OBSTACLE_VEL_THRESHOLD_SQ:
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
	return FlowFieldGenerator.integrate_units(base_cost, positions, cell_size, origin, INF)

func _is_walkable(cell: Vector2i) -> bool:
	var h: int = _cached_cost_map.size()
	if h <= 0: return false
	var w: int = _cached_cost_map[0].size() if _cached_cost_map[0] is Array else 0
	if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h: return false
	return _cached_cost_map[cell.y][cell.x] < INF

func _on_grid_changed() -> void:
	_dirty = true
	_cached_cost_map = []
	_stationary_dirty = true

func _get_all_units() -> Array:
	if _frame_counter == _all_units_frame and not _cached_all_units.is_empty():
		return _cached_all_units
	_all_units_frame = _frame_counter
	_cached_all_units = _tree.get_nodes_in_group("移动单位") if _tree else []
	return _cached_all_units

func _clear() -> void:
	current_ff = null
	_last_target_cell = Vector2i(-1, -1)
	_cached_cost_map = []
	_dirty = true
	_last_stationary_hash = 0
	_stationary_cache_valid = false
	_last_bfs_frame = 0

static func _fallback_dir(from: Vector2, to: Vector2) -> Vector2:
	var d: Vector2 = to - from
	if d.length_squared() < 0.001: return Vector2.ZERO
	return d.normalized()
