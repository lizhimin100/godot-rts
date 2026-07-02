extends Node

## 避障系统 — 两层避障：被动卡死修复 + 主动让路
##
## 被动避障：单位被卡住时报告运动服务，让其重新规划
## 主动避障：单位挡住己方单位时主动让出空间
##
## 使用方式（自动加载单例）：
##   避障系统.检测卡死(单位, 期望速度) → bool
##   避障系统.计算让路修正(单位, 周围单位) → Vector2

static var 实例: Node = null

## 卡死检测参数
const 卡死阈值: float = 2.0       # 每帧位移 < 2px 视为卡住
const 卡死超时: float = 0.5       # 连续卡住 0.5s 触发报告
const 让路半径: float = 32.0      # 此半径内检测周围单位
const 让路强度: float = 60.0     # 让路修正力度（大幅增强，用于推开静止单位）
const 让路最大比例: float = 0.4    # 让路修正最多占期望速度 80%（更强推开效果）

## 卡死计时缓存：单位 → 累计卡死时间
var _卡死计时: Dictionary = {}

func _enter_tree() -> void:
	实例 = self

func _exit_tree() -> void:
	if 实例 == self: 实例 = null


## 检测单位是否卡死
## @param 单位        移动中的单位
## @param 期望速度    策略计算的期望速度
## @param 帧间隔      delta
## @return            true=卡死超时，需要重新规划
func 检测卡死(单位: Node2D, 期望速度: Vector2, 帧间隔: float) -> bool:
	var 当前速度长度 = 单位.velocity.length()
	var 期望速度长度 = 期望速度.length()

	# 期望速度本身接近于零 → 不检测卡死
	if 期望速度长度 < 卡死阈值:
		_卡死计时.erase(单位)
		return false

	# 实际速度远低于期望 → 可能卡住
	if 当前速度长度 < 卡死阈值:
		var 计时 = _卡死计时.get(单位, 0.0)
		计时 += 帧间隔
		_卡死计时[单位] = 计时
		if 计时 >= 卡死超时:
			_卡死计时.erase(单位)
			return true
	else:
		_卡死计时.erase(单位)

	return false


## 计算主动让路修正向量
## @param 单位        移动中的单位
## @param 周围单位    周围的所有单位列表
## @param 期望方向    策略期望的移动方向（归一化）
## @return            修正速度向量（将被限幅后叠加到期望速度上）
func 计算让路修正(单位: Node2D, 周围单位: Array, 期望方向: Vector2) -> Vector2:
	var 修正 := Vector2.ZERO

	for 其他 in 周围单位:
		if 其他 == 单位 or not is_instance_valid(其他):
			continue

		# 只对同阵营让路（不对敌人让路）
		if _是否为敌对(单位, 其他):
			continue

		var 偏移: Vector2 = 单位.global_position - 其他.global_position
		var 距离: float = 偏移.length()
		if 距离 > 让路半径 or 距离 < 1.0:
			continue

		# 分离力：距离越近越强
		var 强度 = (1.0 - 距离 / 让路半径)
		修正 += 偏移.normalized() * 强度 * 让路强度

	# 限幅：修正最多占期望速度的 80%
	if 修正.length_squared() > 0:
		修正 = 修正.limit_length(单位.最大速度 * 让路最大比例)

	return 修正


## 计算静止单位让路修正（由运动服务在更新循环中调用）
## 当移动单位靠近静止单位时，给静止单位一个小推力



## 判断是否为敌对单位
func _是否为敌对(单位A: Node2D, 单位B: Node2D) -> bool:
	if 单位A.has_method("是敌对"):
		return 单位A.是敌对(单位B)
	return false
