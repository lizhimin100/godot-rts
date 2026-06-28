class_name UnitStuckDetector
extends RefCounted

## 卡死检测系统 — 检测单位"原地踏步"并触发扰动
##
## 工作原理：
##   每帧比较当前位置与上一帧位置，如果位移 < 阈值，
##   则累加 stuck_time。超过阈值后返回 stuck=true。
##   一旦检测到有效移动，重置计时器。
##
## 配合 UnitMovementController 使用：
##   if stuck_detector.update(self, delta):
##       velocity += randf_range(-20, 20)  # 微扰动解卡

# 卡死阈值（像素/帧，低于此值认为卡住）
var stuck_threshold: float = 0.5

# 卡死判定时间（秒）
var stuck_time_limit: float = 0.4

# 上一帧位置（世界坐标）
var _last_pos: Vector2 = Vector2.ZERO

# 已累积的卡死时间
var _stuck_time: float = 0.0

# 是否初始化了上一帧位置
var _has_last_pos: bool = false


## 每帧调用，返回是否卡住
func update(unit: Node2D, delta: float) -> bool:
	if not _has_last_pos:
		_last_pos = unit.global_position
		_has_last_pos = true
		return false

	var moved: float = unit.global_position.distance_to(_last_pos)
	_last_pos = unit.global_position

	if moved < stuck_threshold:
		_stuck_time += delta
	else:
		# 检测到有效移动 → 重置
		_stuck_time = 0.0

	return _stuck_time > stuck_time_limit


## 重置检测器（单位更换目标时调用）
func reset() -> void:
	_stuck_time = 0.0
	_has_last_pos = false


## 获取当前卡死时长（秒）
func get_stuck_time() -> float:
	return _stuck_time


## 设置卡死参数
func set_params(threshold: float, time_limit: float) -> void:
	stuck_threshold = threshold
	stuck_time_limit = time_limit
