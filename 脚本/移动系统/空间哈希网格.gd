extends Node
## 空间哈希网格 — O(1) 邻居查询
##
## 每帧将所有单位划入 CELL_SIZE 网格桶，
## 避障查询只检 3×3 九宫格，替代 O(n²) 全量遍历。
##
## ⚠ 关键约束：
##   - 每帧开始时必须调用 清空()
##   - 所有单位（含静止单位）必须插入
##   - neighbor query 返回 9 cells 内所有单位
##   - 调用方负责排除 self

func _diag() -> bool: return 调试配置.DEBUG_MOVE

static var 实例: Node = null

## 网格单元大小（px）
## 避障半径 32px → 64px 格子保证大多数查询只扫 3×3
const CELL_SIZE: float = 64.0

## 网格数据: "cx,cy" → Array[Node2D]
var _grid: Dictionary = {}
## 已插入单位集合（防同一单位多次插入同一格）
var _已插入: Dictionary = {}

## 统计：本帧插入的单位总数
var _帧插入计数: int = 0
## 统计：本帧查询计数
var _帧查询计数: int = 0


func _enter_tree() -> void:
	实例 = self

func _exit_tree() -> void:
	if 实例 == self:
		实例 = null


## 计算网格键
func _cell_key(pos: Vector2) -> String:
	var cx = floori(pos.x / CELL_SIZE)
	var cy = floori(pos.y / CELL_SIZE)
	return "%d,%d" % [cx, cy]


## 插入一个单位到网格
## 安全：单位无效 / 已在本帧插入过 → 跳过
func 插入单位(单位: Node2D) -> void:
	if not is_instance_valid(单位):
		return
	if _已插入.has(单位):
		return
	_已插入[单位] = true
	_帧插入计数 += 1

	var key = _cell_key(单位.global_position)
	if not _grid.has(key):
		_grid[key] = []
	_grid[key].append(单位)


## 批量插入
func 批量插入(单位列表: Array[Node2D]) -> void:
	for 单位 in 单位列表:
		插入单位(单位)


## 清空网格（每帧开始时调用一次）
func 清空() -> void:
	_grid.clear()
	_已插入.clear()

	if _diag() and _帧插入计数 > 0:
		pass  # 不在这里打日志，由调用方在重建后输出
	_帧插入计数 = 0
	_帧查询计数 = 0


## 查询九宫格内所有单位（不剪裁距离）
## 返回 9 cells 中所有有效单位
func 查询9宫格(位置: Vector2) -> Array[Node2D]:
	var cx = floori(位置.x / CELL_SIZE)
	var cy = floori(位置.y / CELL_SIZE)
	var 结果: Array[Node2D] = []

	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var key = "%d,%d" % [cx + dx, cy + dy]
			var 格子 = _grid.get(key)
			if 格子:
				for 单位 in 格子:
					if is_instance_valid(单位):
						结果.append(单位)

	_帧查询计数 += 1

	# ⭐ 调试验证：查询应有结果
	if _diag() and _帧查询计数 == 1 and 结果.is_empty():
		pass  # 第一个查询在运动服务中可能是单位自身，等运动服务日志

	return 结果


## 获取本帧的插入总数（调试用）
func 获取插入总数() -> int:
	return _帧插入计数


## 获取本帧查询次数（调试用）
func 获取查询次数() -> int:
	return _帧查询计数


## 查询半径内所有单位（九宫格 + 距离剪裁）
func 查询半径(位置: Vector2, 半径: float) -> Array[Node2D]:
	var 候选 = 查询9宫格(位置)
	var 半径平方 = 半径 * 半径
	var 结果: Array[Node2D] = []

	for 单位 in 候选:
		if 单位.global_position.distance_squared_to(位置) <= 半径平方:
			结果.append(单位)

	return 结果


## 获取九宫格中的敌对单位
func 查询敌对(位置: Vector2, 己方: Node2D, 半径: float) -> Array[Node2D]:
	var 候选 = 查询半径(位置, 半径)
	var 结果: Array[Node2D] = []

	for 单位 in 候选:
		if 单位 == 己方: continue
		if 己方.has_method("是敌对") and 己方.是敌对(单位):
			结果.append(单位)

	return 结果
