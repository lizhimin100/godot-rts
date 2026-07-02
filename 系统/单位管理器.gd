extends Node

## 单位管理器 — 全局单位管理与空间分区
##
## 职责：
##   1. 按阵营分组管理所有单位
##   2. 空间网格分区（Spatial Grid），优化邻近查询
##   3. 批量更新入口（movement/combat/vision）
##   4. 提供高效的半径内单位查询
##
## 使用方式（Autoload）：
##   单位管理器.注册单位(unit)
##   单位管理器.获取半径内单位(position, radius)

signal 单位已注册(unit)
signal 单位已注销(unit)

static var 实例: 单位管理器 = null

# ========== 按阵营分组 ==========
## 阵营单位表: team_id -> Array[Node2D]
var 阵营单位表: Dictionary = {}

# ========== 空间网格 ==========
var 空间网格: Dictionary = {}  # "cx,cy" -> Array[Node2D]
var 网格大小: float = 128.0    # 每个网格单元格像素大小

# ========== 全量单位列表（快速迭代用） ==========
var 所有单位: Array[Node2D] = []

# ========== 帧缓存 ==========
var _帧计数: int = 0


func _enter_tree() -> void:
	实例 = self


func _exit_tree() -> void:
	if 实例 == self:
		实例 = null


func _process(_delta: float) -> void:
	_帧计数 += 1

	# 每半秒更新一次所有单位的空间网格位置（移动后格子会过时）
	if _帧计数 % 30 == 0:
		for unit in 所有单位:
			if is_instance_valid(unit):
				更新单位位置(unit)


# ============================================================
# 注册/注销
# ============================================================

## 注册单位到管理器（单位 _ready 时调用）
func 注册单位(unit: Node2D) -> void:
	if not is_instance_valid(unit):
		return

	# 避免重复注册
	if unit in 所有单位:
		return

	所有单位.append(unit)

	# 按阵营分组
	var team_id = _获取阵营ID(unit)
	if not 阵营单位表.has(team_id):
		阵营单位表[team_id] = []
	阵营单位表[team_id].append(unit)

	# 空间网格注册
	_更新网格注册(unit)

	单位已注册.emit(unit)


## 注销单位（单位 _exit_tree 时调用）
func 注销单位(unit: Node2D) -> void:
	if not is_instance_valid(unit):
		return

	所有单位.erase(unit)

	# 从阵营表移除
	var team_id = _获取阵营ID(unit)
	if 阵营单位表.has(team_id):
		阵营单位表[team_id].erase(unit)
		if 阵营单位表[team_id].is_empty():
			阵营单位表.erase(team_id)

	# 从空间网格移除
	if unit.has_meta("网格键"):
		var key: String = unit.get_meta("网格键")
		if 空间网格.has(key):
			空间网格[key].erase(unit)
			if 空间网格[key].is_empty():
				空间网格.erase(key)

	单位已注销.emit(unit)


## 更新单位在空间网格中的位置（每帧移动后调用）
func 更新单位位置(unit: Node2D) -> void:
	if not is_instance_valid(unit):
		return
	_更新网格注册(unit)


# ============================================================
# 查询
# ============================================================

## 获取指定阵营的所有单位
func 获取阵营单位(team_id: int) -> Array:
	return 阵营单位表.get(team_id, []).duplicate()


## 获取半径内所有单位（基于空间网格，不全局遍历）
func 获取半径内单位(中心: Vector2, 半径: float) -> Array[Node2D]:
	var 结果: Array[Node2D] = []
	var 半径平方: float = 半径 * 半径
	# ⭐ 去重：跨网格边界的单位可能同时出现在两个格子中
	var seen: Dictionary = {}

	# 计算覆盖的网格范围
	var min_cx: int = int((中心.x - 半径) / 网格大小)
	var max_cx: int = int((中心.x + 半径) / 网格大小)
	var min_cy: int = int((中心.y - 半径) / 网格大小)
	var max_cy: int = int((中心.y + 半径) / 网格大小)

	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			var key: String = "%d,%d" % [cx, cy]
			if not 空间网格.has(key):
				continue
			for unit in 空间网格[key]:
				if not is_instance_valid(unit):
					continue
				if seen.has(unit):
					continue
				var dist_sq: float = 中心.distance_squared_to(unit.global_position)
				if dist_sq <= 半径平方:
					seen[unit] = true
					结果.append(unit)

	return 结果


## 获取半径内单位计数（效率更高，不创建数组）
func 获取半径内单位数(中心: Vector2, 半径: float) -> int:
	var 计数: int = 0
	var 半径平方: float = 半径 * 半径

	var min_cx: int = int((中心.x - 半径) / 网格大小)
	var max_cx: int = int((中心.x + 半径) / 网格大小)
	var min_cy: int = int((中心.y - 半径) / 网格大小)
	var max_cy: int = int((中心.y + 半径) / 网格大小)

	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			var key: String = "%d,%d" % [cx, cy]
			if not 空间网格.has(key):
				continue
			for unit in 空间网格[key]:
				if not is_instance_valid(unit):
					continue
				if 中心.distance_squared_to(unit.global_position) <= 半径平方:
					计数 += 1
	return 计数


## 获取所有单位（全量列表）
func 获取所有单位() -> Array[Node2D]:
	return 所有单位.duplicate()


## 获取所有单位计数
func 获取单位总数() -> int:
	return 所有单位.size()


# ============================================================
# 内部
# ============================================================

func _获取阵营ID(unit: Node2D) -> int:
	if unit.has_method("获取阵营"):
		return unit.获取阵营()
	if "阵营" in unit:
		return unit.阵营
	return 0


func _计算网格键(pos: Vector2) -> String:
	var cx: int = int(pos.x / 网格大小)
	var cy: int = int(pos.y / 网格大小)
	return "%d,%d" % [cx, cy]


func _更新网格注册(unit: Node2D) -> void:
	var old_key: String = unit.get_meta("网格键", "")
	var new_key: String = _计算网格键(unit.global_position)

	if old_key == new_key and old_key != "":
		return  # 没跨格，不更新

	# 从旧格移除
	if old_key != "" and 空间网格.has(old_key):
		空间网格[old_key].erase(unit)
		if 空间网格[old_key].is_empty():
			空间网格.erase(old_key)

	# 注册到新格
	if not 空间网格.has(new_key):
		空间网格[new_key] = []
	空间网格[new_key].append(unit)
	unit.set_meta("网格键", new_key)
