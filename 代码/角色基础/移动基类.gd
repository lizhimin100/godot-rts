class_name 移动基类
extends CharacterBody2D

## 移动基类 — 所有 RTS 可控制单位的基类
## 提供：导航寻路、阵营关系、通用命令、避障系统
## 所有物理单位加入"移动单位"组（避障使用）
## 只有玩家单位加入"可选单位"组（选择系统 + 迷雾视野使用）

signal 避开友军

# ========== 阵营系统 ==========
@export var 阵营: 阵营管理器.阵营 = 阵营管理器.阵营.玩家

# 移动参数
@export var 移动速度: float = 200.0
@export var 最大速度: float = 350.0
@export var 加速度: float = 50.0
@export var 停止阈值: float = 10.0
@export var 选择状态 = false

# ========== 战斗属性（所有单位通用） ==========
@export var 最大生命值: float = 100.0
var 当前生命值: float = 100.0
var _已死亡 := false  # 防重复死亡保护

# ========== 避障参数 ==========
@export var 避障探测距离: float = 50.0
@export var 避障强度: float = 4.0
@export var 排斥距离: float = 28.0
@export var 排斥强度: float = 80.0

# ========== 导航系统 ==========
var 导航代理: NavigationAgent2D
var 寻路计时器: Timer

# ========== 命令状态 ==========
var 目标位置: Vector2 = Vector2.ZERO
var 点击位置: Vector2 = Vector2.ZERO
var 移动方向: Vector2 = Vector2.ZERO
var 攻击目标: Node2D = null
var 巡逻路径: Array[Vector2] = []
var 当前巡逻索引: int = 0

enum 命令类型 { 无, 移动, 攻击, 驻守, 巡逻 }
var 当前命令: 命令类型 = 命令类型.无


func _ready() -> void:
	当前生命值 = 最大生命值
	# 从 collision_layer 检测阵营（必须在子类 _ready 之前完成）
	if collision_layer == 16:
		阵营 = 阵营管理器.阵营.敌人
	else:
		阵营 = 阵营管理器.阵营.玩家
	_初始化导航()
	add_to_group("移动单位")
	if 阵营 == 阵营管理器.阵营.玩家:
		add_to_group("可选单位")
	# 添加建筑层(4)到碰撞掩码，使单位能与建筑碰撞
	if not (collision_mask & 4):
		collision_mask += 4


## 动态创建导航代理（子类场景无需手动添加）
func _初始化导航() -> void:
	if 导航代理:
		return
	导航代理 = NavigationAgent2D.new()
	导航代理.name = "导航代理"
	add_child(导航代理)

	寻路计时器 = Timer.new()
	寻路计时器.name = "寻路计时器"
	寻路计时器.wait_time = 0.1
	寻路计时器.autostart = true
	add_child(寻路计时器)
	寻路计时器.timeout.connect(_on_寻路计时器_timeout)


# ============================================================
# 阵营关系判断
# ============================================================

## 获取自身阵营
func 获取阵营() -> int:
	return 阵营

## 判断与目标的关系（敌对/友军/中立）
func 判断关系(目标) -> int:
	if not 目标 or not is_instance_valid(目标):
		return 阵营管理器.关系.中立
	if 目标.has_method("获取阵营"):
		return 阵营管理器.获取关系(阵营, 目标.获取阵营())
	# 兼容旧的 collision_layer 判断
	if 目标 is 移动基类:
		if 目标.collision_layer == 16:
			return 阵营管理器.关系.敌对
		elif 目标.collision_layer == 8:
			return 阵营管理器.关系.友军
	return 阵营管理器.关系.中立

func 是敌对(目标) -> bool:
	return 判断关系(目标) == 阵营管理器.关系.敌对

func 是友军(目标) -> bool:
	return 判断关系(目标) == 阵营管理器.关系.友军

## 旧接口兼容
func _是敌人() -> bool:
	return 阵营 == 阵营管理器.阵营.敌人

func _是玩家() -> bool:
	return 阵营 == 阵营管理器.阵营.玩家


# ============================================================
# 通用命令接口
# ============================================================

## 移动到目标位置
func 命令移动(位置: Vector2) -> void:
	攻击目标 = null
	目标位置 = 位置
	当前命令 = 命令类型.移动
	导航代理.target_position = 位置
	_切换动画("移动")


## 停止所有行为
func 命令停止() -> void:
	攻击目标 = null
	当前命令 = 命令类型.无
	目标位置 = global_position
	导航代理.target_position = global_position
	velocity = Vector2.ZERO
	_切换动画("待机")


## 驻守：保持原地，自动攻击范围内敌人
func 命令驻守() -> void:
	攻击目标 = null
	当前命令 = 命令类型.驻守
	目标位置 = global_position
	velocity = Vector2.ZERO
	_切换动画("待机")


## 攻击指定目标
func 命令攻击(目标: Node2D) -> void:
	if not is_instance_valid(目标):
		return
	if not 是敌对(目标):
		return
	攻击目标 = 目标
	目标位置 = 目标.global_position
	当前命令 = 命令类型.攻击
	导航代理.target_position = 目标位置
	_切换动画("移动")


## 巡逻：在两个点之间来回移动
func 命令巡逻(位置: Vector2) -> void:
	攻击目标 = null
	巡逻路径 = [global_position, 位置]
	当前巡逻索引 = 1
	目标位置 = 位置
	当前命令 = 命令类型.巡逻
	导航代理.target_position = 位置
	_切换动画("移动")


## 寻路到下一个巡逻点
func _下一个巡逻点() -> void:
	当前巡逻索引 = (当前巡逻索引 + 1) % 巡逻路径.size()
	目标位置 = 巡逻路径[当前巡逻索引]
	导航代理.target_position = 目标位置


# ============================================================
# 导航计时器（每0.1秒更新导航目标）
# ============================================================

func _on_寻路计时器_timeout() -> void:
	match 当前命令:
		命令类型.移动, 命令类型.巡逻:
			导航代理.target_position = 目标位置
		命令类型.攻击:
			if 攻击目标 and is_instance_valid(攻击目标):
				导航代理.target_position = 攻击目标.global_position
				# 同步更新目标位置（追击移动目标）
				目标位置 = 攻击目标.global_position


# ============================================================
# 导航移动帮助方法（给子类调用）
# ============================================================

## 执行导航移动，返回是否到达目标
func _导航移动到(目标位置: Vector2, delta: float) -> bool:
	var 剩余距离 = global_position.distance_to(目标位置)
	if 剩余距离 <= 停止阈值:
		velocity = velocity.move_toward(Vector2.ZERO, 加速度 * 10 * delta)
		return true

	if 导航代理.is_navigation_finished():
		velocity = velocity.move_toward(Vector2.ZERO, 加速度 * 10 * delta)
		return true

	var 下一个路径点 = 导航代理.get_next_path_position()
	var 目标方向 = (下一个路径点 - global_position).normalized()
	var 目标速度 = 目标方向 * 移动速度
	var 总避障力 := _计算总避障力(目标方向)
	if 总避障力 != Vector2.ZERO:
		目标速度 += 总避障力
	velocity = 目标速度.limit_length(最大速度)
	return false


## 从选中单位获取攻击范围内最近的敌对目标
func _寻找最近的敌对目标(搜索范围: float) -> Node2D:
	var 最近: Node2D = null
	var 最近距离 := 搜索范围

	for 单位 in get_tree().get_nodes_in_group("移动单位"):
		if 单位 == self or not is_instance_valid(单位):
			continue
		if not 是敌对(单位):
			continue
		if 单位.当前生命值 <= 0:
			continue
		var d = global_position.distance_to(单位.global_position)
		if d <= 最近距离:
			最近距离 = d
			最近 = 单位

	# 也检测建筑
	for 建筑 in get_tree().get_nodes_in_group("建筑"):
		if not is_instance_valid(建筑):
			continue
		if not 是敌对(建筑):
			continue
		if 建筑.当前生命值 <= 0:
			continue
		var d = global_position.distance_to(建筑.global_position)
		if d <= 最近距离:
			最近距离 = d
			最近 = 建筑

	return 最近


# ============================================================
# 子类需要重写的方法
# ============================================================

## 子类重写以处理攻击逻辑
func 执行攻击() -> void:
	pass

## 子类重写以切换动画（"待机"/"移动"/"攻击"）
func _切换动画(动画名: String) -> void:
	pass


# ============================================================
# 战斗系统
# ============================================================

## 受伤 — 被攻击时调用
func 受伤(伤害: float, 攻击来源 = null) -> void:
	当前生命值 -= 伤害
	_播放受击效果(攻击来源)
	var 伤害数字 = _创建伤害数字(int(伤害))
	if 伤害数字:
		add_child(伤害数字)
	if 当前生命值 <= 0:
		死亡()


## 受击视觉反馈：闪红 + 屏幕震动 + 击中火花
func _播放受击效果(攻击来源 = null) -> void:
	# 屏幕震动（找活动相机）
	_触发屏幕震动()

	# 闪红 + 缩放脉冲
	var 原色调 = modulate
	var 原缩放 = scale
	modulate = Color(2, 0.2, 0.2, 1)
	scale = 原缩放 * 1.15  # 受击膨胀
	position += Vector2(randf_range(-5, 5), randf_range(-5, 5))
	await get_tree().create_timer(0.06).timeout
	if is_instance_valid(self):
		modulate = Color(1.5, 0.4, 0.4, 1)
		scale = 原缩放 * 1.08
		await get_tree().create_timer(0.06).timeout
		if is_instance_valid(self):
			modulate = 原色调
			scale = 原缩放


## 触发全局屏幕震动
func _触发屏幕震动() -> void:
	var 相机 = get_viewport().get_camera_2d()
	if 相机 and 相机.has_method("震屏"):
		var 震级 = 6.0 if (_是敌人() or 阵营 == 阵营管理器.阵营.敌人) else 4.0
		相机.震屏(震级, 0.2)


## 生成浮动伤害数字（自动上飘 + 淡出 + 删除）
func _创建伤害数字(伤害: int) -> Label:
	var label := Label.new()
	label.text = str(伤害)
	label.modulate = Color(1, 0.95, 0.3)
	label.position = Vector2(-20, -55)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 0.8)
	tween.tween_property(label, "position:x", label.position.x + randf_range(-10, 10), 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)
	return label


## 死亡 — 膨胀 + 闪白 + 淡出
func 死亡() -> void:
	if _已死亡:
		return
	_已死亡 = true
	set_process(false)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	# 死亡瞬间膨胀闪白
	var 原缩放 = scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.08)
	tween.tween_property(self, "scale", 原缩放 * 1.3, 0.1)
	await tween.finished

	if not is_instance_valid(self):
		return

	# 淡出缩小
	var tween2 := create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(self, "modulate:a", 0.0, 0.35)
	tween2.tween_property(self, "scale", 原缩放 * 0.3, 0.35)
	tween2.tween_property(self, "rotation", randf_range(-0.3, 0.3), 0.35)
	await tween2.finished
	queue_free()


# ============================================================
# 避障系统（所有可移动单位之间都避障）
# ============================================================

## 计算避障力 + 排斥力的统一入口
func _计算总避障力(目标方向: Vector2) -> Vector2:
	var 总力 := Vector2.ZERO
	总力 += _计算避障力(目标方向)
	总力 += _计算排斥力()
	return 总力


## 检测前方所有单位并计算绕行方向（垂直于移动方向）
func _计算避障力(移动方向: Vector2) -> Vector2:
	var 总避障力 := Vector2.ZERO
	var 垂直 = Vector2(-移动方向.y, 移动方向.x)

	for 单位 in get_tree().get_nodes_in_group("移动单位"):
		if 单位 == self or not is_instance_valid(单位):
			continue

		var 偏移 = 单位.global_position - global_position
		var 距离 = 偏移.length()
		if 距离 > 避障探测距离 or 距离 == 0:
			continue

		# 判断是否在移动方向的前方（点积 > 0.2）
		var 前方分量 = 偏移.normalized().dot(移动方向)
		if 前方分量 < 0.2:
			continue

		# 计算应该往哪一侧绕行
		var 侧向符号 = sign(偏移.dot(垂直))
		var 力度 = 1.0 - (距离 / 避障探测距离)
		力度 *= 力度

		总避障力 += 垂直 * 侧向符号 * 移动速度 * 力度 * 避障强度 * 0.3

	return 总避障力


## 近距离排斥力：单位靠太近时直接径向推开
func _计算排斥力() -> Vector2:
	var 总排斥 := Vector2.ZERO

	for 单位 in get_tree().get_nodes_in_group("移动单位"):
		if 单位 == self or not is_instance_valid(单位):
			continue

		var 偏移 = global_position - 单位.global_position
		var 距离 = 偏移.length()
		if 距离 > 排斥距离 or 距离 == 0:
			continue

		var 力度 = 1.0 - (距离 / 排斥距离)
		力度 *= 力度
		总排斥 += 偏移.normalized() * 力度 * 排斥强度

	return 总排斥
