extends Node
signal 移动完成(单位: Node2D, 结果: 移动结果)
signal 单位卡死(单位: Node2D)
static var 实例: Node = null

class 移动数据:
	var 请求: 移动请求
	var 策略: 移动策略
	var 上次位置: Vector2
	var 已到达锁定: bool = false
	var 卡死计数: int = 0
	var 让路前位置: Vector2 = Vector2.ZERO
	var 回退计时: float = 0.0
	var 回退中: bool = false
	var 让路CD: int = 0

var _移动中单位: Dictionary = {}
var _正在让路中: Dictionary = {}
var _已让路者: Dictionary = {}
const 让路防双向帧数: int = 120   # 被让路后冷却120帧（≈2s），覆盖返回全程+稳定期
const 最大卡死放弃: int = 3
var DEBUG_LOG: bool = true
const DIAG: bool = true
const DIAG_YIELD: bool = true
const DIAG_SPEED: bool = true

func _enter_tree() -> void: 实例 = self; process_priority = -100
func _exit_tree() -> void: if 实例 == self: 实例 = null
func _ready() -> void: set_physics_process(true)
func _physics_process(delta: float) -> void: _更新所有移动单位(delta)

func 请求移动(单位: Node2D, 请求: 移动请求, 是让路: bool = false) -> void:
	if not is_instance_valid(单位): return
	if 单位 in _移动中单位:
		var 旧数据 = _移动中单位[单位]
		if 旧数据.让路前位置 != Vector2.ZERO:
			旧数据.让路前位置 = Vector2.ZERO
		_发送结果(单位, 移动结果.结果类型.被中断)
	var 策略 := _构建策略(请求)
	if 策略 == null: return
	var 数据 := 移动数据.new()
	数据.请求 = 请求; 数据.策略 = 策略
	数据.上次位置 = 单位.global_position
	_移动中单位[单位] = 数据

func 强制停止(单位: Node2D, 原因: int = 移动结果.结果类型.被中断) -> void:
	if not is_instance_valid(单位): _移动中单位.erase(单位); return
	_移动中单位.erase(单位); 单位.velocity = Vector2.ZERO; _发送结果(单位, 原因)

func 获取当前请求(单位: Node2D) -> 移动请求:
	var 数据 = _移动中单位.get(单位); return 数据.请求 if 数据 else null
func 是否在移动(单位: Node2D) -> bool: return 单位 in _移动中单位

func _更新所有移动单位(delta: float) -> void:
	var 待移除: Array[Node2D] = []
	var 过期: Array = []
	for u in _已让路者:
		if Engine.get_frames_drawn() - _已让路者[u] > 让路防双向帧数:
			过期.append(u)
	for u in 过期: _已让路者.erase(u)

	for 单位 in _移动中单位.keys():
		if not is_instance_valid(单位): 待移除.append(单位); continue
		var 数据 = _移动中单位[单位]; var 请求 = 数据.请求; var 策略 = 数据.策略
		if 数据.让路CD > 0: 数据.让路CD -= 1

		if 数据.已到达锁定:
			单位.velocity = Vector2.ZERO
			if 数据.让路前位置 != Vector2.ZERO:
				if 单位.global_position.distance_squared_to(数据.让路前位置) < 256.0:
					数据.让路前位置 = Vector2.ZERO
				else:
					var return_pos = 数据.让路前位置
					数据.让路前位置 = Vector2.ZERO
					var rq = 移动请求.前往位置(return_pos)
					rq.停止距离 = 4.0
					请求移动(单位, rq)
					if 单位 in _移动中单位:
						_移动中单位[单位].让路前位置 = return_pos
					if 单位.has_method("_切换动画"): 单位._切换动画("移动")
			continue

		if 策略.是否已到达(单位, 请求):
			if DIAG: print("[ARRIVE] <", 单位.name, "> arrived")
			数据.已到达锁定 = true; 单位.velocity = Vector2.ZERO
			_发送结果(单位, 移动结果.结果类型.已到达)
			if 单位.has_method("_切换动画"): 单位._切换动画("待机")
			continue

		var 期望速度 = 策略.计算速度(单位, 请求)
		var 单位移动速度: float = 单位.移动速度 if "移动速度" in 单位 else 200.0
		var 最大速度: float = 单位.最大速度 if "最大速度" in 单位 else 350.0
		var 最终速度 = 期望速度

		if DIAG_SPEED and 最终速度.length_squared() > 4.0:
			print("[SPEED] <", 单位.name, "> expected=", 最终速度.length(), " speed=", 单位移动速度, " max=", 最大速度)

		if 最终速度.length_squared() > 单位移动速度 * 单位移动速度:
			最终速度 = 最终速度.normalized() * 单位移动速度
		if 最终速度.length_squared() > 最大速度 * 最大速度:
			最终速度 = 最终速度.normalized() * 最大速度

		_让路移动_一次性(单位, 请求)

		if is_instance_valid(避障系统.实例):
			var 卡死 = 避障系统.检测卡死(单位, 最终速度, delta)
			if 卡死:
				if not 数据.回退中: 数据.回退计时 = 0.0
				数据.回退计时 += delta; 数据.回退中 = true
				if 数据.回退计时 < 0.3:
					var 后退方向 = (数据.上次位置 - 单位.global_position).normalized()
					if 后退方向 == Vector2.ZERO: 后退方向 = Vector2(0, 1)
					最终速度 = 后退方向 * 单位移动速度 * 0.5
				else:
					数据.回退中 = false; 数据.卡死计数 += 1
					if 数据.卡死计数 >= 最大卡死放弃:
						待移除.append(单位); 单位.velocity = Vector2.ZERO
						_发送结果(单位, 移动结果.结果类型.卡死)
						if 单位.has_method("_切换动画"): 单位._切换动画("待机")
						continue
					if is_instance_valid(流场管理器.实例):
						流场管理器.实例.重置缓存()
						流场管理器.实例.标记障碍变更()
			else: 数据.回退中 = false; 数据.卡死计数 = maxi(数据.卡死计数 - 1, 0)

		单位.velocity = 最终速度; 数据.上次位置 = 单位.global_position

	_正在让路中.clear()
	for 单位 in 待移除: _移动中单位.erase(单位)

func _构建策略(请求: 移动请求) -> 移动策略:
	match 请求.类型:
		移动请求.移动类型.前往位置: return 前往位置移动.new()
		移动请求.移动类型.追击敌人: return 追击目标移动.new()
		移动请求.移动类型.移动攻击: return 移动攻击移动.new()
		移动请求.移动类型.技能驱动: return 技能驱动移动.new()
		_: return 前往位置移动.new()

func _发送结果(单位: Node2D, 原因: int) -> void:
	if not is_instance_valid(单位): return
	var 结果 = 移动结果.new(); 结果.结果 = 原因
	移动完成.emit(单位, 结果)

## 让路规则：只对已到达锁定的静止单位让路，不管是否同集群
func _让路移动_一次性(移动单位: Node2D, 请求: 移动请求) -> void:
	if 移动单位 in _已让路者: return

	var 最终目标 = 请求.目标位置 + 请求.队形偏移
	var 向目标 = 最终目标 - 移动单位.global_position
	if 向目标.length_squared() < 1.0: return
	var 方向 = 向目标.normalized()
	var 移动单位到目标距离 = 向目标.length()

	for 潜在让路单位 in _获取周围单位(移动单位):
		if 潜在让路单位 == 移动单位 or not is_instance_valid(潜在让路单位): continue
		if 潜在让路单位 in _正在让路中: continue
		if 潜在让路单位 is StaticBody2D: continue
		if 潜在让路单位 in _已让路者: continue

		# 只对已到达锁定的单位让路
		var 是已到达: bool = false
		if 潜在让路单位 in _移动中单位:
			var d = _移动中单位[潜在让路单位]
			if d.让路前位置 != Vector2.ZERO: continue
			if d.让路CD > 0: continue
			if d.已到达锁定: 是已到达 = true
		else:
			var vel = 潜在让路单位.velocity if "velocity" in 潜在让路单位 else Vector2.ZERO
			if vel.length_squared() > 4.0: continue
			是已到达 = true

		if not 是已到达: continue

		# 路径检测
		var 偏移 = 潜在让路单位.global_position - 移动单位.global_position
		var 距离 = 偏移.length()
		if 距离 > 120.0 or 距离 < 1.0: continue
		if 方向.dot(偏移.normalized()) < 0.3: continue

		var 投影距离 = 偏移.dot(方向)
		var 垂直距离 = abs(偏移.cross(方向))
		if 投影距离 < 0 or 投影距离 > 移动单位到目标距离 + 50.0: continue
		if 垂直距离 > 48.0: continue

		if DIAG_YIELD:
			print("[YIELD] <", 潜在让路单位.name, "> by <", 移动单位.name, "> dist=", 距离, " proj=", 投影距离, " perp=", 垂直距离)

		# 执行让路
		var 垂直 = Vector2(-方向.y, 方向.x)
		if 垂直.dot(偏移) < 0: 垂直 = -垂直
		var 让开位置 = 潜在让路单位.global_position + 垂直 * 80.0 + 方向 * (-20.0)

		var rq = 移动请求.前往位置(让开位置)
		rq.停止距离 = 10.0
		请求移动(潜在让路单位, rq, true)

		if 潜在让路单位 in _移动中单位:
			_移动中单位[潜在让路单位].让路前位置 = 潜在让路单位.global_position
			_移动中单位[潜在让路单位].让路CD = 让路防双向帧数
		if 潜在让路单位.has_method("_切换动画"): 潜在让路单位._切换动画("移动")

		_正在让路中[潜在让路单位] = true
		_已让路者[移动单位] = Engine.get_frames_drawn()

func _试探空位(单位: Node2D, 请求: 移动请求) -> Vector2:
	var 向目标 = 请求.目标位置 - 单位.global_position
	var 试探方向 = [Vector2(0, -40), Vector2(0, 40), Vector2(-40, 0), Vector2(40, 0)]
	if 向目标.length_squared() > 0.0001:
		var 目标方向 = 向目标.normalized()
		试探方向.sort_custom(func(a, b): return a.normalized().dot(目标方向) > b.normalized().dot(目标方向))
	for 试探 in 试探方向:
		var 候选 = 单位.global_position + 试探
		var 被占 = false
		for 其他 in _获取周围单位(单位):
			if 其他 == 单位 or not is_instance_valid(其他): continue
			if 其他.global_position.distance_squared_to(候选) < 2500.0: 被占 = true; break
		if not 被占: return 候选
	return Vector2.ZERO

func _获取周围单位(单位: Node2D) -> Array:
	return 单位管理器.获取所有单位() if is_instance_valid(单位管理器.实例) else []
