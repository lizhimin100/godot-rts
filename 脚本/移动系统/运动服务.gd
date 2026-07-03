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
	var 回退计时: float = 0.0
	var 回退中: bool = false

var _移动中单位: Dictionary = {}
const 最大卡死放弃: int = 3
var DEBUG_LOG: bool = true
const DIAG: bool = true
const DIAG_SPEED: bool = true

func _enter_tree() -> void: 实例 = self; process_priority = -100
func _exit_tree() -> void: if 实例 == self: 实例 = null
func _ready() -> void: set_physics_process(true)
func _physics_process(delta: float) -> void: _更新所有移动单位(delta)

func 请求移动(单位: Node2D, 请求: 移动请求) -> void:
	if not is_instance_valid(单位): return
	if 单位 in _移动中单位:
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

	for 单位 in _移动中单位.keys():
		if not is_instance_valid(单位): 待移除.append(单位); continue
		var 数据 = _移动中单位[单位]; var 请求 = 数据.请求; var 策略 = 数据.策略

		if 数据.已到达锁定:
			单位.velocity = Vector2.ZERO
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

func _获取周围单位(单位: Node2D) -> Array:
	return 单位管理器.获取所有单位() if is_instance_valid(单位管理器.实例) else []
