extends 移动策略
class_name 前往位置移动

## 前往位置策略 — 最简单的移动到点停止
##
## 到达时减速刹车（停止距离内速度线性衰减到0），防止过冲
## ⭐ 接近目标时转为直接指向（不走流场），防止流场绕圈到不了

var _停止距离平方: float = 0.0
var _刹车距离: float = 0.0

func _初始化(请求: 移动请求, 单位: Node2D) -> void:
	if _停止距离平方 == 0.0:
		var 停止距离 = 请求.停止距离
		# 优先使用单位的停止阈值
		if "停止阈值" in 单位:
			停止距离 = 单位.停止阈值
		# ⭐ 到达判定用停止距离的 2 倍（4px → 8px 判定圈，比之前的12px更精确）
		_停止距离平方 = (停止距离 * 2.0) * (停止距离 * 2.0)
		_刹车距离 = 停止距离 * 4.0  # 4倍停止距离开始减速


func 计算速度(单位: Node2D, 请求: 移动请求) -> Vector2:
	_初始化(请求, 单位)
	var 最终目标 = 获取最终目标(请求)

	# ⭐ 距离很近时直接指向目标，不走流场（防止流场绕圈）
	var 距离 = 单位.global_position.distance_to(最终目标)
	if 距离 < _刹车距离 * 2.0:
		var 方向 = 最终目标 - 单位.global_position
		if 方向.length_squared() < 0.0001:
			return Vector2.ZERO
		方向 = 方向.normalized()
		# 减速刹车
		var 速度倍率: float = 1.0
		if 距离 < _刹车距离:
			速度倍率 = maxf(0.0, (距离 - sqrt(_停止距离平方)) / (_刹车距离 - sqrt(_停止距离平方)))
			if 速度倍率 < 0.05:
				速度倍率 = 0.0
		return 方向 * 单位.移动速度 * 速度倍率

	# 远距离：流场导向
	var 方向 = 流场管理器.获取方向(单位.global_position, 最终目标)
	if 方向 == Vector2.ZERO:
		方向 = (最终目标 - 单位.global_position).normalized()

	# 减速刹车
	var 速度倍率: float = 1.0
	if 距离 < _刹车距离:
		速度倍率 = maxf(0.0, (距离 - sqrt(_停止距离平方)) / (_刹车距离 - sqrt(_停止距离平方)))
		if 速度倍率 < 0.05:
			速度倍率 = 0.0

	return 方向 * 单位.移动速度 * 速度倍率


func 是否已到达(单位: Node2D, 请求: 移动请求) -> bool:
	_初始化(请求, 单位)
	var 最终目标 = 获取最终目标(请求)
	var 距离平方 = 单位.global_position.distance_squared_to(最终目标)

	# 到达目标附近（用扩大后的停止距离判断）
	if 距离平方 <= _停止距离平方:
		return true

	# ⭐ 在刹车范围内且速度接近零 → 视为已到达（防震荡）
	if 距离平方 < _刹车距离 * _刹车距离:
		if 单位.velocity.length_squared() < 25.0:  # 5px/s 以下
			return true

	# 目标位置被其他单位占据，且已经足够近（< 64px），视为到达
	if 距离平方 < 4096.0:
		if _目标位置被占据(单位, 最终目标):
			return true

	return false


## 检查目标位置是否有其他单位占据
func _目标位置被占据(单位: Node2D, 目标: Vector2) -> bool:
	var 所有单位 = 单位管理器.获取所有单位() if is_instance_valid(单位管理器.实例) else []
	for 其他 in 所有单位:
		if 其他 == 单位 or not is_instance_valid(其他):
			continue
		if 其他.global_position.distance_squared_to(目标) < 400.0:
			return true
	return false
