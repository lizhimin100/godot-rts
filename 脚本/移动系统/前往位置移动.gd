extends 移动策略
class_name 前往位置移动

## 前往位置策略 — 移动到点停止
##
## ⭐ 流场导航使用组目标（group_target），所有同队单位共享，
##    到达判定使用个体目标（slot_target = group_target + slot_offset）。
##    这样流场只需为组目标走一次缓存。
##
## 到达时减速刹车（停止距离内速度线性衰减到0），防止过冲
## 接近目标时转为直接指向（不走流场），防止流场绕圈到不了

var _停止距离平方: float = 0.0
var _刹车距离: float = 0.0

func _初始化(请求: 移动请求, 单位: Node2D) -> void:
	if _停止距离平方 == 0.0:
		var 停止距离 = 请求.停止距离
		# 优先使用单位的停止阈值
		if "停止阈值" in 单位:
			停止距离 = 单位.停止阈值
		_停止距离平方 = (停止距离 * 2.0) * (停止距离 * 2.0)
		_刹车距离 = 停止距离 * 4.0


## 队形展开半径：距 group_target 进入此范围后直指 slot_target
const FORMATION_SPREAD_RADIUS: float = 128.0


func 计算速度(单位: Node2D, 请求: 移动请求) -> Vector2:
	_初始化(请求, 单位)

	var 最终目标 = 获取最终目标(请求, 单位)   # slot_target（个体）
	var 流场目标 = 获取流场目标(请求, 单位)   # group_target（共享）
	var 距离 = 单位.global_position.distance_to(最终目标)

	# ════════════════════════════════════════════
	# 队形单位：展开半径用 group_target 判定
	# ════════════════════════════════════════════
	if 请求.队形槽位 >= 0:
		var dist_to_group = 单位.global_position.distance_to(流场目标)
		# 在展开半径内 → 直指 slot_target（各走各路）
		if dist_to_group < FORMATION_SPREAD_RADIUS:
			var 方向 = 最终目标 - 单位.global_position
			if 方向.length_squared() < 0.0001:
				return Vector2.ZERO
			方向 = 方向.normalized()
			var 速度倍率: float = 1.0
			if 距离 < _刹车距离:
				速度倍率 = maxf(0.0, (距离 - sqrt(_停止距离平方)) / (_刹车距离 - sqrt(_停止距离平方)))
				if 速度倍率 < 0.05:
					速度倍率 = 0.0
			return 方向 * 单位.移动速度 * 速度倍率

		# 远距：FF 指向 group_target（所有单位共享缓存）
		var 方向 = 流场管理器.获取方向(单位.global_position, 流场目标)
		if 方向 == Vector2.ZERO:
			方向 = (流场目标 - 单位.global_position).normalized()
		var 速度倍率: float = 1.0
		if 距离 < _刹车距离:
			速度倍率 = maxf(0.0, (距离 - sqrt(_停止距离平方)) / (_刹车距离 - sqrt(_停止距离平方)))
			if 速度倍率 < 0.05:
				速度倍率 = 0.0
		return 方向 * 单位.移动速度 * 速度倍率

	# ════════════════════════════════════════════
	# 非队形单位：原有逻辑（slot_target 刹车 + FF）
	# ════════════════════════════════════════════
	# 近距离直接指向目标，不走流场（防绕圈）
	if 距离 < _刹车距离 * 2.0:
		var 方向 = 最终目标 - 单位.global_position
		if 方向.length_squared() < 0.0001:
			return Vector2.ZERO
		方向 = 方向.normalized()
		var 速度倍率: float = 1.0
		if 距离 < _刹车距离:
			速度倍率 = maxf(0.0, (距离 - sqrt(_停止距离平方)) / (_刹车距离 - sqrt(_停止距离平方)))
			if 速度倍率 < 0.05:
				速度倍率 = 0.0
		return 方向 * 单位.移动速度 * 速度倍率

	# 远距离：流场指向目标
	var 方向 = 流场管理器.获取方向(单位.global_position, 流场目标)
	if 方向 == Vector2.ZERO:
		方向 = (流场目标 - 单位.global_position).normalized()

	var 速度倍率: float = 1.0
	if 距离 < _刹车距离:
		速度倍率 = maxf(0.0, (距离 - sqrt(_停止距离平方)) / (_刹车距离 - sqrt(_停止距离平方)))
		if 速度倍率 < 0.05:
			速度倍率 = 0.0

	return 方向 * 单位.移动速度 * 速度倍率


func 是否已到达(单位: Node2D, 请求: 移动请求) -> bool:
	_初始化(请求, 单位)
	var 最终目标 = 获取最终目标(请求, 单位)
	var 距离平方 = 单位.global_position.distance_squared_to(最终目标)

	# ⭐ 主到达判定：距离 slot_target / 目标位置 在停止距离内
	if 距离平方 <= _停止距离平方:
		return true

	# 刹车范围内且速度≈0 -> 防震荡
	if 距离平方 < _刹车距离 * _刹车距离:
		if 单位.velocity.length_squared() < 25.0:
			return true

	# ⭐ 非队形单位：目标被其他单位占据且足够近（防卡住）
	#   队形单位不启用此判定 —— 每个单位有独立的 slot_target，
	#   64px 范围内有其他单位"占据"槽位不说明本单位已到达
	if not (队形系统.实例 and 队形系统.实例.是否在队形中(单位)):
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
