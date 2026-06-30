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
## 🔥 性能约定（2024-06）：
##   - request_update 是唯一入口，每帧最多执行 1 次
##   - target 抖动锁定：< 1 tile 的变化被忽略
##   - integrate_stationary_units 每 0.5s 刷新一次，非每帧
##
## 使用方式（单例模式）：
##   FFManager.setup(navigation_world)
##   FFManager.request_update(target_pos)       # ← 唯一入口
##   var ff = FFManager.get_flow_field()
##   var dir = FFManager.get_direction(world_pos, target)

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

# -------- 帧缓存（get_all_units 去重） --------
var _cached_all_units: Array = []
var _all_units_frame: int = -1
var _frame_counter: int = 0

# -------- ① 单帧收敛：request_update 仅记录，_process 统一执行 --------
var _requested_target: Vector2 = Vector2.ZERO
var _has_pending: bool = false

# -------- ①ⓑ 帧级 BFS 节流：限制 _execute_update 真实执行频率 --------
var _last_bfs_frame := 0
const BFS_THROTTLE_FRAMES := 6  # 60 FPS → max 10 FPS BFS

# -------- ② 静止单位障碍缓存（非每帧刷新） --------
var _integrate_timer: float = 0.0
var _stationary_dirty: bool = true
var _cached_merged: Array = []
var _stationary_cache_valid := false
var _last_stationary_hash := 0
const INTEGRATE_INTERVAL: float = 0.5  # 每 0.5s 刷新一次
const TILE_SIZE_PX: float = 32.0


func _init() -> void:
	instance = self


func _ready() -> void:
	_tree = get_tree()
	var nav: NavigationWorld = _find_navigation_world()
	if nav:
		_setup(nav)


func _process(delta: float) -> void:
	_frame_counter += 1
	_integrate_timer -= delta
	if _has_pending:
		# ⭐ 帧级 BFS 节流：每 BFS_THROTTLE_FRAMES 帧最多执行一次 _execute_update
		#    节流中不消费 _has_pending（保留请求，target 随最新命令更新）
		if _frame_counter - _last_bfs_frame < BFS_THROTTLE_FRAMES:
			return
		_has_pending = false
		_last_bfs_frame = _frame_counter
		_execute_update(_requested_target)


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
	instance._stationary_dirty = true


## request_update: 唯一的 update_target 入口
## 仅记录目标，_process 统一执行（每帧最多 1 次）
static func request_update(target: Vector2) -> void:
	if not instance:
		return
	instance._requested_target = target
	instance._has_pending = true


static func get_flow_field() -> FFGrid:
	if not instance:
		return null
	return instance.current_ff


static func get_direction(world_pos: Vector2, target: Vector2) -> Vector2:
	if not instance:
		return _fallback_dir(world_pos, target)
	return instance._get_direction(world_pos, target)


static func setup_nav(地面层 = null, 树图层 = null) -> void:
	if not instance:
		return
	var nav: NavigationWorld = instance._find_navigation_world()
	if nav:
		if 地面层:
			nav.ground_layer = 地面层
		if 树图层:
			nav.tree_layer = 树图层
		nav.rebuild()
		instance._setup(nav)


static func is_obstacle(pos: Vector2) -> bool:
	if not instance or not instance.nav_world:
		return false
	return instance.nav_world.is_obstacle(pos)


static func has_valid() -> bool:
	if not instance:
		return false
	return instance.current_ff != null and instance.current_ff.is_valid()


# 获取帧级缓存的"移动单位"列表
# 每帧只执行 1 次 scene tree 查询
static func get_all_units() -> Array:
	if not instance:
		return []
	return instance._get_all_units()


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


func _execute_update(target: Vector2) -> void:
	var _t = Tracer.start()
	if not nav_world or not _tree:
		return

	Tracer.trace("FFManager", "_execute_update", "target=(%.0f,%.0f)" % [target.x, target.y], 0.0, Tracer.SideEffect.BFS)

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

	# ② 抖动锁定：单元格变化 < 1 tile → 忽略，保持 last_target_cell 稳定
	if _last_target_cell != Vector2i(-1, -1) and current_ff != null:
		var diff: Vector2i = target_cell - _last_target_cell
		if abs(diff.x) < 1 and abs(diff.y) < 1:
			Tracer.trace("FFManager", "_execute_update_SKIP", "jitter_lock", Tracer.stop(_t), 0)
			return

	# 目标未变 + 无脏标记 → 复用缓存
	if target_cell == _last_target_cell and current_ff != null:
		return

	_last_target_cell = target_cell

	# 3. 整合静止单位障碍（缓存化：每 INTEGRATE_INTERVAL 秒 或 dirty 才重算）
	#    ⭐ 增加 hash 检查：静态单位无变化时完全跳过 integrate_stationary
	if _integrate_timer <= 0.0 or _stationary_dirty:
		var new_hash := _compute_stationary_hash()
		if new_hash != _last_stationary_hash or _cached_merged.is_empty():
			var all_u: Array = _get_all_units()
			_cached_merged = _integrate_stationary_units(_cached_cost_map, all_u)
			_last_stationary_hash = new_hash
		_integrate_timer = INTEGRATE_INTERVAL
		_stationary_dirty = false
	# 否则复用 _cached_merged（不重走 integrate）

	# 4. 生成流场
	var cell_size: float = 64.0
	if nav_world.ground_layer and nav_world.ground_layer.tile_set:
		cell_size = float(nav_world.ground_layer.tile_set.tile_size.x)

	var origin: Vector2 = Vector2(
		nav_world.grid_offset.x * cell_size,
		nav_world.grid_offset.y * cell_size
	)

	current_ff = FlowFieldGenerator.generate(_cached_merged, target_cell, cell_size, origin)
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


func _compute_stationary_hash() -> int:
	## 计算静止单位位置 hash，用于判断是否需要重新 integrate_stationary
	var h: int = 0
	for u in _get_all_units():
		if not is_instance_valid(u):
			continue
		var vel: Vector2 = u.velocity if "velocity" in u else Vector2.ZERO
		if vel.length_squared() < 4.0:
			# 对位置取整后 hash，防止微小抖动导致缓存失效
			h = h * 31 + hash(snapped(u.global_position.x, 8.0))
			h = h * 31 + hash(snapped(u.global_position.y, 8.0))
	return h


func _integrate_stationary_units(base_cost: Array, units: Array) -> Array:
	var _t = Tracer.start()
	var positions: Array[Vector2] = []

	for u in units:
		if not is_instance_valid(u):
			continue
		var vel: Vector2 = u.velocity if "velocity" in u else Vector2.ZERO
		if vel.length_squared() < 4.0:
			positions.append(u.global_position)

	if positions.is_empty():
		Tracer.trace("FFManager", "integrate_stationary", "no stationary units", Tracer.stop(_t), 0)
		return base_cost

	var cell_size: float = 64.0
	if nav_world and nav_world.ground_layer and nav_world.ground_layer.tile_set:
		cell_size = float(nav_world.ground_layer.tile_set.tile_size.x)
	var origin: Vector2 = Vector2(
		nav_world.grid_offset.x * cell_size,
		nav_world.grid_offset.y * cell_size
	)

	var _ret_int = FlowFieldGenerator.integrate_units(
		base_cost, positions, cell_size, origin, 20.0
	)
	Tracer.trace("FFManager", "integrate_stationary", "n_stationary=%d" % positions.size(), Tracer.stop(_t), 0)
	return _ret_int


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
	if d.length_squared() < 0.001:
		return Vector2.ZERO
	return d.normalized()
