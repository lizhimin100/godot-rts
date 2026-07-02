extends Node

## 情报系统 — 阵营级情报跟踪
##
## 可见状态：
##   未知（0）— 从未见过该单位
##   曾见（1）— 曾经见过但当前不在视野
##   当前可见（2）— 当前在视野中
##
## 规则：
##   - 情报通过迷雾系统判定可见性
##   - 敌人不提供视野，但可以被看见
##   - 离开视野后保留最后已知数据（残影）
##   - UI 通过此系统读取数据，不直接访问单位

signal 情报更新(单位ID: int, 阵营ID: int, 状态: int)

static var 实例: 情报系统 = null

enum 可见状态 { 未知, 曾见, 当前可见 }

class 情报记录:
	var 单位ID: int
	var 阵营ID: int       # 单位所属阵营
	var 最后坐标: Vector2
	var 最后生命: float
	var 最后最大生命: float
	var 最后时间: float
	var 状态: int = 可见状态.未知

	func _to_string() -> String:
		var 状态名 = ["未知", "曾见", "可见"]
		return "情报(单位%d, 阵营%d, %s, pos=%s, hp=%.0f)" % [
			单位ID, 阵营ID, 状态名[状态], 最后坐标, 最后生命
		]

# 情报表：阵营ID → 单位ID → 情报记录
var _情报表: Dictionary = {}

# 单位实例ID → 逻辑ID映射
var _实例映射: Dictionary = {}
var _下一个ID: int = 1


func _enter_tree() -> void:
	实例 = self


func _exit_tree() -> void:
	if 实例 == self: 实例 = null


# ============================================================
# 核心查询接口
# ============================================================

## 获取指定单位对指定阵营的情报
func 获取情报(单位: Node2D, 查询阵营: int) -> 情报记录:
	if not is_instance_valid(单位):
		return null

	var 单位ID = _取单位ID(单位)
	if 单位ID == 0:
		return null

	var 阵营数据: Dictionary = _情报表.get(查询阵营, {})
	var 记录: 情报记录 = 阵营数据.get(单位ID, null)

	# 检查当前可见性
	var 当前可见: bool = 迷雾系统.实例 and 迷雾系统.实例.单位对阵营可见(单位, 查询阵营)

	if 当前可见:
		if not 记录:
			记录 = 情报记录.new()
			阵营数据[单位ID] = 记录
			_情报表[查询阵营] = 阵营数据

		# 更新实时数据
		记录.单位ID = 单位ID
		记录.阵营ID = _取阵营(单位)
		记录.最后坐标 = 单位.global_position
		记录.最后生命 = _取生命(单位)
		记录.最后最大生命 = _取最大生命(单位)
		记录.最后时间 = Time.get_ticks_msec() / 1000.0
		记录.状态 = 可见状态.当前可见

	elif 记录:
		# 刚从可见→离开视野
		if 记录.状态 == 可见状态.当前可见:
			记录.状态 = 可见状态.曾见
			# 记录离开时的最后数据（不更新实时数据）
			情报更新.emit(单位ID, 查询阵营, 可见状态.曾见)

	else:
		return null  # 从未见过

	return 记录


## 单位对指定阵营是否"当前可见"（只看是否在视野内）
func 是否可见(单位: Node2D, 查询阵营: int) -> bool:
	return 迷雾系统.实例 and 迷雾系统.实例.单位对阵营可见(单位, 查询阵营)


## 单位对指定阵营是否"曾见"（曾经见过但不在视野）
func 是否曾见(单位: Node2D, 查询阵营: int) -> bool:
	if not is_instance_valid(单位):
		return false
	var 单位ID = _取单位ID(单位)
	var 阵营数据 = _情报表.get(查询阵营, {})
	var 记录: 情报记录 = 阵营数据.get(单位ID, null)
	return 记录 != null and 记录.状态 == 可见状态.曾见


## 获取阵营当前可见的单位列表
func 获取可见单位(阵营ID: int) -> Array:
	var 结果: Array = []
	var 阵营数据 = _情报表.get(阵营ID, {})
	for 单位ID in 阵营数据:
		var 记录: 情报记录 = 阵营数据[单位ID]
		if 记录.状态 == 可见状态.当前可见:
			结果.append(单位ID)
	return 结果


## 清除阵营情报
func 清除阵营(阵营ID: int) -> void:
	_情报表.erase(阵营ID)


# ============================================================
# 内部
# ============================================================

func _取单位ID(单位: Node2D) -> int:
	var inst_id = 单位.get_instance_id()
	if _实例映射.has(inst_id):
		return _实例映射[inst_id]
	var new_id = _下一个ID
	_下一个ID += 1
	_实例映射[inst_id] = new_id
	return new_id


func _取阵营(单位: Node2D) -> int:
	if 单位.has_method("获取阵营"): return 单位.获取阵营()
	return 0


func _取生命(单位: Node2D) -> float:
	if 单位.has_method("获取当前生命值"): return 单位.获取当前生命值()
	var hc = 单位.get_node_or_null("HealthComponent")
	if hc: return hc.hp
	return 0


func _取最大生命(单位: Node2D) -> float:
	if 单位.has_method("获取最大生命值"): return 单位.获取最大生命值()
	var hc = 单位.get_node_or_null("HealthComponent")
	if hc: return hc.max_hp
	return 0
