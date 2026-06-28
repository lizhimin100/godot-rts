extends Node2D
class_name 流场寻路

## 流场寻路适配器（旧接口，委托给新系统）
##
## 保留旧 API 供 建筑放置管理器.gd、城堡.gd 等调用。
## 内部优先使用 NavigationWorld + FlowFieldManager。
## 如果新系统未初始化，回退使用旧版内部网格。

## 用法：
##   流场寻路.初始化(地面层, 树林层)
##   流场寻路.计算流场(target_global_pos)
##   var dir = 流场寻路.获取方向(unit_global_pos, fallback_target)

# ═══ 旧版内部状态（回退用） ═══
static var _ff: FlowField = null
static var _地面层: TileMapLayer = null
static var _树林层: TileMapLayer = null
static var _grid: Array = []
static var _grid_width: int = 0
static var _grid_height: int = 0
static var _grid_offset: Vector2i = Vector2i.ZERO
static var _cache_dirty: bool = true
static var _上次目标世界: Vector2 = Vector2.ZERO


# ═══ 初始化 ═══

## 初始化（获取地面/树林层引用）
static func 初始化(地面层: TileMapLayer, 树林层: TileMapLayer = null) -> void:
	# 优先尝试注册到新系统
	var nav_world: NavigationWorld = _查找导航世界()
	if nav_world:
		nav_world.ground_layer = 地面层
		nav_world.tree_layer = 树林层
		nav_world.rebuild()
		FlowFieldManager.setup(nav_world)
		return

	# 回退到旧版内部网格
	_地面层 = 地面层
	_树林层 = 树林层
	_cache_dirty = true


## 刷新障碍列表（建造/拆除后调用）
static func 刷新障碍() -> void:
	# 优先通知新系统
	FlowFieldManager.mark_dirty()

	# 旧版回退
	_cache_dirty = true


## 计算流场
static func 计算流场(目标世界坐标: Vector2) -> bool:
	# 新系统不需要此调用（FlowFieldManager 自动管理）
	if FlowFieldManager.instance and FlowFieldManager.instance.nav_world:
		return true

	# 旧版回退
	if not _地面层:
		return false
	if _cache_dirty or _grid.is_empty():
		_重建网格()
	if 目标世界坐标.distance_to(_上次目标世界) < 1.0 and _ff != null:
		return true
	_上次目标世界 = 目标世界坐标
	if _grid.is_empty() or _grid_width <= 0 or _grid_height <= 0:
		return false
	var 目标格 = _世界转网格(目标世界坐标)
	if 目标格.x < 0 or 目标格.y < 0 or 目标格.x >= _grid_width or 目标格.y >= _grid_height or _grid[目标格.y][目标格.x] == 1:
		目标格 = _找最近可行格(目标格)
	if 目标格.x < 0 or 目标格.y < 0:
		return false
	_ff = FlowField.new()
	_ff.initialize(_grid, 目标格)
	return true


## 获取方向
static func 获取方向(世界坐标: Vector2, fallback_target: Vector2 = Vector2.ZERO) -> Vector2:
	# 优先使用新系统
	var dir: Vector2 = FlowFieldManager.get_direction(世界坐标, fallback_target)
	if dir != Vector2.ZERO:
		return dir

	# 旧版回退
	if _ff == null:
		if fallback_target != Vector2.ZERO:
			var 方向 = (fallback_target - 世界坐标).normalized()
			if 方向 != Vector2.ZERO:
				return 方向
		return Vector2.ZERO
	var 格 = _世界转网格(世界坐标)
	var flow_dir = _ff.get_direction(格)
	if flow_dir != Vector2i.ZERO:
		return Vector2(flow_dir.x, flow_dir.y).normalized()
	if fallback_target != Vector2.ZERO:
		var 方向 = (fallback_target - 世界坐标).normalized()
		if 方向 != Vector2.ZERO:
			return 方向
	return Vector2.ZERO


## 判断世界坐标是否在障碍上
static func 是障碍(世界坐标: Vector2) -> bool:
	# 优先使用新系统
	var nav_world: NavigationWorld = _查找导航世界()
	if nav_world:
		return nav_world.is_obstacle(世界坐标)

	# 旧版回退
	if _cache_dirty or _grid.is_empty():
		_重建网格()
	var 格 = _世界转网格(世界坐标)
	if 格.x < 0 or 格.y < 0 or 格.x >= _grid_width or 格.y >= _grid_height:
		return false
	return _grid[格.y][格.x] == 1


# ═══ 旧版内部方法（回退用） ═══

static func _查找导航世界() -> NavigationWorld:
	# 通过场景树查找 NavigationWorld 实例
	if not _地面层 or not _地面层.is_inside_tree():
		return null
	var tree: SceneTree = _地面层.get_tree()
	if not tree:
		return null
	var root: Node = tree.root
	if not root:
		return null
	# 递归查找
	return _递归查找_nav_world(root)


static func _递归查找_nav_world(node: Node) -> NavigationWorld:
	if node is NavigationWorld:
		return node
	for child in node.get_children():
		var result = _递归查找_nav_world(child)
		if result:
			return result
	return null


static func _重建网格() -> void:
	_cache_dirty = false
	if not _地面层:
		return
	var 所有格 = _地面层.get_used_cells()
	if 所有格.is_empty():
		return
	var 最小 = 所有格[0]
	var 最大 = 所有格[0]
	for 格 in 所有格:
		最小.x = min(最小.x, 格.x)
		最小.y = min(最小.y, 格.y)
		最大.x = max(最大.x, 格.x)
		最大.y = max(最大.y, 格.y)
	_grid_offset = 最小
	_grid_width = 最大.x - 最小.x + 1
	_grid_height = 最大.y - 最小.y + 1
	_grid = []
	for y in range(_grid_height):
		_grid.append([])
		for x in range(_grid_width):
			_grid[y].append(0)
	if _树林层:
		for 树格 in _树林层.get_used_cells():
			var gx = 树格.x - _grid_offset.x
			var gy = 树格.y - _grid_offset.y
			if gx >= 0 and gx < _grid_width and gy >= 0 and gy < _grid_height:
				_grid[gy][gx] = 1
	for 建筑 in _地面层.get_tree().get_nodes_in_group("建筑"):
		if not is_instance_valid(建筑):
			continue
		var 格 = _地面层.local_to_map(建筑.global_position)
		var gx = 格.x - _grid_offset.x
		var gy = 格.y - _grid_offset.y
		if gx >= 0 and gx < _grid_width and gy >= 0 and gy < _grid_height:
			_grid[gy][gx] = 1


static func _世界转网格(世界坐标: Vector2) -> Vector2i:
	if not _地面层:
		return Vector2i(-1, -1)
	var 格 = _地面层.local_to_map(世界坐标)
	return Vector2i(格.x - _grid_offset.x, 格.y - _grid_offset.y)


static func _找最近可行格(起点: Vector2i) -> Vector2i:
	var 搜索半径: int = 0
	while 搜索半径 < max(_grid_width, _grid_height):
		搜索半径 += 1
		for dx in range(-搜索半径, 搜索半径 + 1):
			for dy in range(-搜索半径, 搜索半径 + 1):
				var 格 = 起点 + Vector2i(dx, dy)
				if 格.x >= 0 and 格.x < _grid_width and 格.y >= 0 and 格.y < _grid_height:
					if _grid[格.y][格.x] == 0:
						return 格
	return Vector2i(-1, -1)
