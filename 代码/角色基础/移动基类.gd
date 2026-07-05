class_name 移动基类
extends CharacterBody2D

## 移动基类 — [已弃用] 请使用 UnitBase 替代
## 保留用于未迁移的旧单位。新单位应直接使用 UnitBase。
##
## 已移除：旧流场系统引用、旧 Separation 系统引用。
## 所有流场操作委托给 FFManager，分离由 SeparationSystem 处理。

signal 避开友军

# ========== 阵营系统 ==========
@export var 阵营: 阵营管理器.阵营 = 阵营管理器.阵营.玩家

# 移动参数
@export var 移动速度: float = 200.0
@export var 最大速度: float = 350.0
@export var 加速度: float = 800.0
@export var 停止阈值: float = 16.0
@export var 选择状态 = false

# ========== 战斗属性（所有单位通用） ==========
@export var 最大生命值: float = 100.0
var 当前生命值: float = 100.0
var _已死亡: bool = false

# ========== 排斥力参数（仅用于单位之间近距离分离） ==========
@export var 排斥距离: float = 32.0
@export var 排斥强度: float = 150.0

# ========== 导航代理（供子类直接调用，如追击） ==========
var 导航代理: NavigationAgent2D

# ========== 命令状态 ==========
var 目标位置: Vector2 = Vector2.ZERO
var 点击位置: Vector2 = Vector2.ZERO
var 移动方向: Vector2 = Vector2.ZERO
var 攻击目标: Node2D = null
var 巡逻路径: Array[Vector2] = []
var 当前巡逻索引: int = 0

enum 命令类型 { 无, 移动, 攻击, 驻守, 巡逻 }
var 当前命令: 命令类型 = 命令类型.无
var _是攻击移动: bool = false

# ========== 索敌与追击系统 ==========
@export var 索敌范围: float = 250.0
@export var 追击上限距离: float = 400.0
var _原始目标位置: Vector2 = Vector2.ZERO  # A-move 最终目标（杀敌后继续移动用）
var _追击起始位置: Vector2 = Vector2.ZERO  # 自动索敌时的起始点，超限后返回
var _是自动索敌攻击: bool = false

# ========== 驻守图标 ==========
var _驻守图标: Node2D = null


func _ready() -> void:
	当前生命值 = 最大生命值
	if collision_layer == 16:
		阵营 = 阵营管理器.阵营.敌人
	else:
		阵营 = 阵营管理器.阵营.玩家
	_初始化导航()
	add_to_group("移动单位")
	if 阵营 == 阵营管理器.阵营.玩家:
		add_to_group("可选单位")
	if not (collision_mask & 4):
		collision_mask += 4


func _初始化导航() -> void:
	if 导航代理:
		return
	导航代理 = NavigationAgent2D.new()
	导航代理.name = "导航代理"
	add_child(导航代理)


# ============================================================
# 阵营关系判断
# ============================================================

func 获取阵营() -> int:
	return 阵营

func 判断关系(目标) -> int:
	if not 目标 or not is_instance_valid(目标):
		return 阵营管理器.关系.中立
	if 目标.has_method("获取阵营"):
		return 阵营管理器.获取关系(阵营, 目标.获取阵营())
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

func _是敌人() -> bool:
	return 阵营 == 阵营管理器.阵营.敌人

func _是玩家() -> bool:
	return 阵营 == 阵营管理器.阵营.玩家


# ============================================================
# 通用命令接口
# ============================================================

func 命令移动(位置: Vector2, 攻击移动: bool = false) -> void:
	攻击目标 = null
	目标位置 = 位置
	当前命令 = 命令类型.移动
	_是攻击移动 = 攻击移动
	_是自动索敌攻击 = false
	_追击起始位置 = Vector2.ZERO
	if 攻击移动:
		_原始目标位置 = 位置   # A-move 记下最终目标，杀敌后继续移动
	else:
		_原始目标位置 = Vector2.ZERO
	_通知移动控制器()
	_切换动画("移动")
	_隐藏驻守图标()


func 命令停止() -> void:
	攻击目标 = null
	当前命令 = 命令类型.无
	_是攻击移动 = false
	_是自动索敌攻击 = false
	_追击起始位置 = Vector2.ZERO
	_原始目标位置 = Vector2.ZERO
	目标位置 = global_position
	导航代理.target_position = global_position
	velocity = Vector2.ZERO  # ★ LEGACY VELOCITY
	_切换动画("待机")
	_隐藏驻守图标()


func 命令驻守() -> void:
	攻击目标 = null
	当前命令 = 命令类型.驻守
	_是自动索敌攻击 = false
	_追击起始位置 = Vector2.ZERO
	_原始目标位置 = Vector2.ZERO
	目标位置 = global_position
	velocity = Vector2.ZERO  # ★ LEGACY VELOCITY
	_切换动画("待机")
	_显示驻守图标()

func 命令攻击(目标: Node2D) -> void:
	if not is_instance_valid(目标):
		return
	if not 是敌对(目标):
		return
	攻击目标 = 目标
	目标位置 = 目标.global_position
	当前命令 = 命令类型.攻击
	_是自动索敌攻击 = false
	_追击起始位置 = Vector2.ZERO
	_原始目标位置 = Vector2.ZERO  # 手动攻击清除 A-move 目标
	_通知移动控制器()
	_切换动画("移动")
	_隐藏驻守图标()


func _通知命令变更() -> void:
	pass

func 命令巡逻(位置: Vector2) -> void:
	攻击目标 = null
	巡逻路径 = [global_position, 位置]
	当前巡逻索引 = 1
	目标位置 = 位置
	当前命令 = 命令类型.巡逻
	_通知移动控制器()
	_切换动画("移动")


func _下一个巡逻点() -> void:
	当前巡逻索引 = (当前巡逻索引 + 1) % 巡逻路径.size()
	目标位置 = 巡逻路径[当前巡逻索引]
	当前命令 = 命令类型.移动
	_通知移动控制器()


# ============================================================
# 通知移动控制器（统一入口：流场 + FFManager）
# ============================================================

func _通知移动控制器() -> void:
	# 旧基类无 UnitController，由子类自行处理
	pass


# ============================================================
# 驻守图标
# ============================================================

const GARRISON_ICON = preload("res://combat/effects/garrison_icon.tscn")

## 创建驻守图标（场景）
func _创建驻守图标() -> void:
	_驻守图标 = GARRISON_ICON.instantiate()
	add_child(_驻守图标)


func _显示驻守图标() -> void:
	if not _驻守图标 or not is_instance_valid(_驻守图标):
		_创建驻守图标()
	if is_instance_valid(_驻守图标):
		_驻守图标.visible = true


func _隐藏驻守图标() -> void:
	if _驻守图标 and is_instance_valid(_驻守图标):
		_驻守图标.visible = false


# ============================================================
# 导航移动（旧接口，已禁用旧流场，直接使用 FFManager）
# ============================================================

func _导航移动到(目标位置: Vector2, delta: float) -> bool:
	var 剩余距离 = global_position.distance_to(目标位置)
	if 剩余距离 <= 停止阈值:
			velocity = velocity.move_toward(Vector2.ZERO, 加速度 * delta)  # ★ LEGACY VELOCITY
		if velocity.length() < 5.0:
			velocity = Vector2.ZERO  # ★ LEGACY VELOCITY
		return true

	# 获取方向（FFManager 流场，不可用时回退到指向目标方向）
	var 移动方向 = FFManager.get_direction(global_position, 目标位置)
	var 目标速度 = 移动方向 * 移动速度

	# 速度平滑过渡（仅平滑速度大小，不平滑方向向量）
		velocity = velocity.move_toward(目标速度.limit_length(最大速度), 加速度 * delta)  # ★ LEGACY VELOCITY

	return false


## 从选中单位获取攻击范围内最近的敌对目标
func _寻找最近的敌对目标(搜索范围: float) -> Node2D:
	var 最近: Node2D = null
	var 最近距离: float = 搜索范围

	for 单位 in FFManager.get_all_units():
		if 单位 == self or not is_instance_valid(单位):
			continue
		if not 是敌对(单位):
			continue
		if 单位.当前生命值 <= 0:
			continue
		var d = global_position.distance_squared_to(单位.global_position)
		var 范围平方 = 搜索范围 * 搜索范围
		if d <= 范围平方:
			if d < 最近距离 * 最近距离:
				最近距离 = sqrt(d)
				最近 = 单位

	for 建筑 in get_tree().get_nodes_in_group("建筑"):
		if not is_instance_valid(建筑):
			continue
		if not 是敌对(建筑):
			continue
		if 建筑.当前生命值 <= 0:
			continue
		var d = global_position.distance_squared_to(建筑.global_position)
		var 范围平方 = 搜索范围 * 搜索范围
		if d <= 范围平方:
			if d < 最近距离 * 最近距离:
				最近距离 = sqrt(d)
				最近 = 建筑

	return 最近


# ============================================================
# 子类需要重写的方法
# ============================================================

func 执行攻击() -> void:
	pass

func _切换动画(动画名: String) -> void:
	pass


# ============================================================
# 战斗系统
# ============================================================

func 受伤(伤害: float, 攻击来源 = null) -> void:
	当前生命值 -= 伤害
	_播放受击效果(攻击来源)
	var 伤害数字 = _创建伤害数字(int(伤害))
	if 伤害数字:
		add_child(伤害数字)
	if 当前生命值 <= 0:
		死亡()


func _播放受击效果(攻击来源 = null) -> void:
	_触发屏幕震动()

	var 原色调 = modulate
	var 原缩放 = scale
	modulate = Color(2, 0.2, 0.2, 1)
	scale = 原缩放 * 1.15
	position += Vector2(randf_range(-5, 5), randf_range(-5, 5))
	await get_tree().create_timer(0.06).timeout
	if is_instance_valid(self):
		modulate = Color(1.5, 0.4, 0.4, 1)
		scale = 原缩放 * 1.08
		await get_tree().create_timer(0.06).timeout
		if is_instance_valid(self):
			modulate = 原色调
			scale = 原缩放


func _触发屏幕震动() -> void:
	var 相机 = get_viewport().get_camera_2d()
	if 相机 and 相机.has_method("震屏"):
		var 震级 = 6.0 if (_是敌人() or 阵营 == 阵营管理器.阵营.敌人) else 4.0
		相机.震屏(震级, 0.2)


func _创建伤害数字(伤害: int) -> Label:
	var label: Label = Label.new()
	label.text = str(伤害)
	label.modulate = Color(1, 0.95, 0.3)
	label.position = Vector2(-20, -55)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 0.8)
	tween.tween_property(label, "position:x", label.position.x + randf_range(-10, 10), 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)
	return label


func 死亡() -> void:
	if _已死亡:
		return
	_已死亡 = true
	set_process(false)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	var 原缩放 = scale
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.08)
	tween.tween_property(self, "scale", 原缩放 * 1.3, 0.1)
	await tween.finished

	if not is_instance_valid(self):
		return

	var tween2: Tween = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(self, "modulate:a", 0.0, 0.35)
	tween2.tween_property(self, "scale", 原缩放 * 0.3, 0.35)
	tween2.tween_property(self, "rotation", randf_range(-0.3, 0.3), 0.35)
	await tween2.finished
	queue_free()


# ============================================================
# 虚拟函数 — 供子类重写（防 _physics_process 调用 super 报错）
# ============================================================

func _physics_process(_delta: float) -> void:
	pass


func 停止移动() -> void:
	pass


# ============================================================
# 排斥力系统 — 已迁移到 SeparationSystem
# 保留 _计算排斥力 方法供旧子类调用，内部使用 SeparationSystem
# ============================================================

## 兼容旧接口（供 人族步兵.gd 等子类调用）
func _计算总避障力(目标方向: Vector2) -> Vector2:
	return _计算排斥力()


func _计算排斥力() -> Vector2:
	var 总排斥: Vector2 = Vector2.ZERO
	var 本位置: Vector2 = global_position

	var tree: SceneTree = get_tree()
	if not tree:
		return Vector2.ZERO

	var 所有单位: Array = FFManager.get_all_units()
	return SeparationSystem.get_force(本位置, 所有单位, 排斥距离, 排斥强度 / 100.0)
