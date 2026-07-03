extends 移动策略
class_name 移动攻击移动

## 移动攻击策略（A-move）— 右键地面 + A 键
##
## 流程：
##   1. 向目标位置移动
##   2. 沿途检测攻击范围内是否有敌人
##   3. 有敌人 -> 停下列表攻击
##   4. 敌人死亡 -> 继续向原目标移动
##   5. 到达原目标 -> 结束
##
## ⭐ 流场用 group_target，到达判定用 slot_target

var _停止距离平方: float = 0.0
var _刹车距离: float = 0.0

func _初始化(请求: 移动请求) -> void:
	if _停止距离平方 == 0.0:
		var 停止距离 = 请求.停止距离
		_停止距离平方 = (停止距离 * 2.0) * (停止距离 * 2.0)
		_刹车距离 = 停止距离 * 4.0


func 计算速度(单位: Node2D, 请求: 移动请求) -> Vector2:
	_初始化(请求)

	# 检测周围是否有敌人
	var 敌人 = _索敌(单位)
	if 敌人 != null:
		return Vector2.ZERO

	# ⭐ 流场导航用 group_target（共享缓存），到达判定用 slot_target
	var 最终目标 = 获取最终目标(请求, 单位)
	var 流场目标 = 获取流场目标(请求, 单位)
	var 距离 = 单位.global_position.distance_to(最终目标)

	# 队形单位在展开半径内直指 slot_target
	var in_spread = false
	if 请求.队形槽位 >= 0 and 队形系统.实例 and 队形系统.实例.是否在队形中(单位):
		var dist_to_group = 单位.global_position.distance_to(流场目标)
		if dist_to_group < 128.0:
			in_spread = true

	# 近距离直接指向（不走流场绕圈）
	if 距离 < _刹车距离 * 2.0 or in_spread:
		var 方向 = 最终目标 - 单位.global_position
		if 方向.length_squared() < 0.0001:
			return Vector2.ZERO
		方向 = 方向.normalized()
		var 速度值 = 单位.移动速度 if "移动速度" in 单位 else 200.0
		var 速度倍率: float = 1.0
		if 距离 < _刹车距离:
			速度倍率 = maxf(0.0, (距离 - sqrt(_停止距离平方)) / (_刹车距离 - sqrt(_停止距离平方)))
			if 速度倍率 < 0.05: 速度倍率 = 0.0
		return 方向 * 速度值 * 速度倍率

	# ⭐ 远距离流场指向 group_target（所有单位共享，FFManager 可缓存）
	var 方向 = 流场管理器.获取方向(单位.global_position, 流场目标)
	if 方向 == Vector2.ZERO:
		方向 = (流场目标 - 单位.global_position).normalized()
	var 速度值 = 单位.移动速度 if "移动速度" in 单位 else 200.0
	var 速度倍率: float = 1.0
	if 距离 < _刹车距离:
		速度倍率 = maxf(0.0, (距离 - sqrt(_停止距离平方)) / (_刹车距离 - sqrt(_停止距离平方)))
		if 速度倍率 < 0.05: 速度倍率 = 0.0
	return 方向 * 速度值 * 速度倍率


func 是否已到达(单位: Node2D, 请求: 移动请求) -> bool:
	_初始化(请求)
	var 最终目标 = 获取最终目标(请求, 单位)
	var 距离平方 = 单位.global_position.distance_squared_to(最终目标)

	if 距离平方 <= _停止距离平方:
		return true

	if 距离平方 < _刹车距离 * _刹车距离:
		if 单位.velocity.length_squared() < 25.0:
			return true

	return false


## 查找攻击范围内的敌人
func _索敌(单位: Node2D) -> Node2D:
	if 单位.has_method("获取索敌组件"):
		var 索敌 = 单位.获取索敌组件()
		if 索敌 and 索敌.has_method("get_target"):
			return 索敌.get_target()

	if not 单位.has_method("是敌对"):
		return null

	var 攻击范围 = 单位.攻击范围 if "攻击范围" in 单位 else 45.0
	var 攻击范围平方 = 攻击范围 * 攻击范围

	var 所有单位 = 单位管理器.获取所有单位() if is_instance_valid(单位管理器.实例) else []
	for 其他 in 所有单位:
		if 其他 == 单位 or not is_instance_valid(其他):
			continue
		if not 单位.是敌对(其他):
			continue
		var 距离平方 = 单位.global_position.distance_squared_to(其他.global_position)
		if 距离平方 <= 攻击范围平方:
			return 其他

	return null
