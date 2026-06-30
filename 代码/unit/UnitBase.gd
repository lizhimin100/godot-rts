class_name UnitBase
extends CharacterBody2D

## 单位基类 — RTS 单位根基类（组合式架构）
##
## 继承自 CharacterBody2D，提供：
##   - 阵营系统 + 关系判断
##   - 命令系统（移动/攻击/驻守/巡逻/停止）
##   - 移动控制器（UnitController: 流场 + 分离转向 + 停止检测 + 卡死解卡）
##   - 战斗组件组合（创建 HealthComponent / CombatComponent / TargetingComponent 等子节点）
##   - 驻守图标
##   - 导航代理
##
## 战斗逻辑委托给组件，直接引用保存在：
##   health_component / combat_component / targeting_component

signal 避开友军

# ========== 阵营系统 ==========
@export var 阵营: 阵营管理器.阵营 = 阵营管理器.阵营.玩家

# ========== 移动参数 ==========
@export var 移动速度: float = 200.0
@export var 最大速度: float = 350.0
@export var 加速度: float = 800.0
@export var 停止阈值: float = 16.0
@export var 选择状态: bool = false:
	set(v):
		if 选择状态 != v:
			选择状态 = v
			_on_selection_changed()
## 让路优先级（越大越优先）
@export var move_priority: int = 0

# ========== 生命值（向后兼容 shim，委托给 HealthComponent） ==========
@export var 最大生命值: float = 100.0

# ========== 战斗组件直接引用 ==========
var health_component: HealthComponent
var combat_component: CombatComponent
var targeting_component: TargetingComponent
var _status_bar: UnitStatusBar  # 直接引用（避免 find_child 失效）

# ========== 战斗属性数据层（纯数据 Resource，可热调） ==========
@export var stats: UnitStats = null  # 子类在 _ready 中创建/赋值

# ========== 移动控制器（核心） ==========
var unit_controller: UnitController

# ========== 导航代理 ==========
var 导航代理: NavigationAgent2D

# ========== 命令状态 ==========
var 目标位置: Vector2 = Vector2.ZERO
var 点击位置: Vector2 = Vector2.ZERO
var 移动方向: Vector2 = Vector2.ZERO
var 攻击目标: Node2D:
	get: return targeting_component.current_target if targeting_component else null
	set(v):
		if targeting_component:
			targeting_component.set_target(v)
var 巡逻路径: Array[Vector2] = []
var 当前巡逻索引: int = 0

enum 命令类型 { 无, 移动, 攻击, 驻守, 巡逻 }
var 当前命令: 命令类型 = 命令类型.无
var _是攻击移动: bool = false

# ========== A-move 追击参数 ==========
var _原始目标位置: Vector2 = Vector2.ZERO
var _追击起始位置: Vector2 = Vector2.ZERO
var _是自动索敌攻击: bool = false

var 索敌范围: float = 250.0:
	get: return targeting_component.search_range if targeting_component else 250.0
	set(v):
		if targeting_component: targeting_component.search_range = v

var 追击上限距离: float = 400.0:
	get: return targeting_component.chase_range if targeting_component else 400.0
	set(v):
		if targeting_component: targeting_component.chase_range = v

# ========== 向后兼容 shim — 委托给 HealthComponent ==========
var 当前生命值: float:
	get: return health_component.hp if health_component else 最大生命值
	set(v):
		if health_component: health_component.set_hp(v)

var _已死亡: bool:
	get: return health_component.is_dead() if health_component else false

# ========== 驻守图标 ==========
var _驻守图标: Node2D = null

# ========== 视觉分离系统 ==========
var visual_offset: Vector2 = Vector2.ZERO
const VISUAL_RADIUS: float = 10.0
var _visual_sep_phase: int = 0
var _visual_sep_counter: int = 0
const VISUAL_SEP_INTERVAL: int = 10

# ========== 移动更新入口控制（减少 _execute_update 重复调用） ==========
var _movement_update_locked := false
var _move_update_timer := MOVE_UPDATE_INTERVAL  # 初始≥阈值，首帧立即触发
const MOVE_UPDATE_INTERVAL := 0.1  # 10 FPS 节流


func _ready() -> void:
	# 阵营判定（兼容旧碰撞层规则）
	if collision_layer == 16:
		阵营 = 阵营管理器.阵营.敌人
	else:
		阵营 = 阵营管理器.阵营.玩家

	# 初始化移动控制器
	_初始化移动控制器()

	# 视觉分离错峰
	_visual_sep_phase = hash(get_instance_id()) % VISUAL_SEP_INTERVAL
	_visual_sep_counter = _visual_sep_phase

	# 初始化导航代理
	_初始化导航()

	# 初始化战斗组件（先于分组注册）
	_init_combat_components()

	# 分组注册
	add_to_group("移动单位")
	if 阵营 == 阵营管理器.阵营.玩家:
		add_to_group("可选单位")

	# 碰撞掩码：确保包含建筑层（层4）
	if not (collision_mask & 4):
		collision_mask += 4


# ============================================================
# 战斗组件初始化（子类可重写以自定义配置）
# ============================================================

func _init_combat_components() -> void:
	# 属性数据层（子类可覆盖 stats 为具体配置）
	if not stats:
		stats = UnitStats.new()
		stats.hp = 最大生命值
	# HealthComponent
	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	health_component.max_hp = 最大生命值
	add_child(health_component)

	# TargetingComponent
	targeting_component = TargetingComponent.new()
	targeting_component.name = "TargetingComponent"
	add_child(targeting_component)

	# CombatComponent
	combat_component = CombatComponent.new()
	combat_component.name = "CombatComponent"
	combat_component.attack_range = 45.0
	combat_component.attack_damage = 10.0
	combat_component.attack_cooldown = 1.0
	combat_component.attack_strike.connect(_on_default_attack_strike)
	add_child(combat_component)

	# DeathHandler
	var death := DeathHandler.new()
	death.name = "DeathHandler"
	add_child(death)

	# UnitStatusBar（存直接引用，_on_selection_changed 不再依赖 find_child）
	var bar := UnitStatusBar.new()
	bar.name = "UnitStatusBar"
	_status_bar = bar
	add_child(bar)


# ============================================================
# 默认攻击响应 — 直接通过 DamageSystem 造成伤害
# ============================================================

func _on_default_attack_strike(_target: Node2D, packet: DamagePacket) -> void:
	DamageSystem.apply_damage(packet)


# ============================================================
# 初始化
# ============================================================

func _初始化移动控制器() -> void:
	unit_controller = UnitController.new()
	unit_controller.name = "UnitController"
	unit_controller.max_speed = 移动速度
	unit_controller.stop_radius = 停止阈值
	unit_controller.separation_radius = 24.0
	unit_controller.separation_strength = 4.0
	add_child(unit_controller)


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
	if 目标 is UnitBase:
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
	if targeting_component:
		targeting_component.clear_target()
	目标位置 = 位置
	当前命令 = 命令类型.移动
	_是攻击移动 = 攻击移动
	_是自动索敌攻击 = false
	_追击起始位置 = Vector2.ZERO
	if 攻击移动:
		_原始目标位置 = 位置
	else:
		_原始目标位置 = Vector2.ZERO
	_通知移动控制器()
	_切换动画("移动")
	_隐藏驻守图标()


func 命令停止() -> void:
	if combat_component:
		combat_component.cancel_attack()
	if targeting_component:
		targeting_component.clear_target()
	当前命令 = 命令类型.无
	_是攻击移动 = false
	_是自动索敌攻击 = false
	_追击起始位置 = Vector2.ZERO
	_原始目标位置 = Vector2.ZERO
	目标位置 = global_position
	if unit_controller:
		unit_controller.stop()
	if 导航代理:
		导航代理.target_position = global_position
	velocity = Vector2.ZERO
	visual_offset = Vector2.ZERO
	_切换动画("待机")
	_隐藏驻守图标()


func 命令驻守() -> void:
	if targeting_component:
		targeting_component.clear_target()
	当前命令 = 命令类型.驻守
	_是自动索敌攻击 = false
	_追击起始位置 = Vector2.ZERO
	_原始目标位置 = Vector2.ZERO
	目标位置 = global_position
	velocity = Vector2.ZERO
	if unit_controller:
		unit_controller.stop()
	_切换动画("待机")
	_显示驻守图标()


func 命令攻击(目标: Node2D) -> void:
	if not is_instance_valid(目标):
		return
	if not 是敌对(目标):
		return
	if targeting_component:
		targeting_component.set_target(目标)
	目标位置 = 目标.global_position
	当前命令 = 命令类型.攻击
	_是自动索敌攻击 = false
	_追击起始位置 = Vector2.ZERO
	_原始目标位置 = Vector2.ZERO
	_通知移动控制器()
	_切换动画("移动")
	_隐藏驻守图标()


func 命令巡逻(位置: Vector2) -> void:
	if targeting_component:
		targeting_component.clear_target()
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


func request_movement_update() -> void:
	## 统一移动更新入口 — 单帧防重入 + 控制 FFManager.request_update 调用
	if _movement_update_locked:
		return
	_movement_update_locked = true
	FFManager.request_update(目标位置)


func _通知移动控制器() -> void:
	if unit_controller and unit_controller.is_inside_tree():
		request_movement_update()
		unit_controller.set_target(目标位置)


# ============================================================
# 向后兼容 shim — 受伤/死亡接口
# ============================================================

func 受伤(伤害: float, 攻击来源 = null) -> void:
	if not health_component or health_component.is_dead():
		return
	health_component.take_damage(伤害, 攻击来源)


func 死亡() -> void:
	if health_component:
		health_component.take_damage(health_component.hp + 1, null)


## 索敌（向后兼容 shim）
func _寻找最近的敌对目标(搜索范围: float) -> Node2D:
	if targeting_component:
		var old_range = targeting_component.search_range
		targeting_component.search_range = 搜索范围
		var target = targeting_component.get_target()
		targeting_component.search_range = old_range
		return target
	return null


# ============================================================
# 子类可重写的方法
# ============================================================

func 执行攻击() -> void:
	pass


func _切换动画(动画名: String) -> void:
	pass


# ============================================================
# 选择状态 → 通知 UnitStatusBar
# ============================================================

func _on_selection_changed() -> void:
	# 优先使用直接引用（最可靠），回落 find_child
	var bar: UnitStatusBar = _status_bar
	if not bar or not is_instance_valid(bar):
		bar = find_child("UnitStatusBar") as UnitStatusBar
		if not bar:
			return
		_status_bar = bar
	bar.set_selected(选择状态)


# ============================================================
# 驻守图标
# ============================================================

const GARRISON_ICON = preload("res://combat/effects/garrison_icon.tscn")

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
# 视觉分离（纯视觉效果，不参与物理）
# ============================================================

func _update_visual_separation() -> void:
	# 帧节流：每 VISUAL_SEP_INTERVAL 帧更新一次，错峰
	_visual_sep_counter += 1
	if _visual_sep_counter % VISUAL_SEP_INTERVAL != _visual_sep_phase:
		return
	var push: Vector2 = Vector2.ZERO
	var count: int = 0
	var tree: SceneTree = get_tree()
	if not tree:
		return

	for other_node in FFManager.get_all_units():
		var other: Node2D = other_node
		if other == self or not is_instance_valid(other):
			continue
		var offset: Vector2 = global_position - other.global_position
		var dist: float = offset.length()
		if dist < 1 or dist > 60:
			continue
		var strength: float = 1.0 - (dist / 60.0)
		push += offset.normalized() * strength
		count += 1

	if count > 0:
		push /= count

	visual_offset = visual_offset.lerp(push * VISUAL_RADIUS, 0.15)


func _process(_delta: float) -> void:
	# 重置移动更新锁（允许新帧重新请求）
	_movement_update_locked = false
	_update_visual_separation()
	if has_node("角色图像"):
		$角色图像.position = visual_offset


# ============================================================
# 攻击后处理决策（默认行为，子类在 attack_finished 中调用）
# ============================================================

## 攻击结束后决策：继续攻击/追击/停止
## 返回："stay" 继续攻击/"chase" 追击/"stop" 停止
func _default_attack_finished_decision() -> String:
	var target = targeting_component.get_target()
	if target and is_instance_valid(target):
		var atk_range = combat_component.attack_range if combat_component else 45.0
		if global_position.distance_to(target.global_position) <= atk_range:
			return "stay"
		targeting_component.set_target(target)
		目标位置 = target.global_position
		当前命令 = 命令类型.攻击
		return "chase"
	if _原始目标位置 != Vector2.ZERO:
		目标位置 = _原始目标位置
		当前命令 = 命令类型.移动
		_是攻击移动 = true
		return "chase"
	return "stop"

# ============================================================
# 流场移动（单入口：FFManager + UnitController）
# ============================================================

func _使用流场移动(delta: float) -> bool:
	# ⭐ 节流：MOVE 状态下 10 FPS 触发流场更新
	_move_update_timer += delta
	if _move_update_timer >= MOVE_UPDATE_INTERVAL:
		_move_update_timer = 0.0
		request_movement_update()

	var 所有单位: Array = FFManager.get_all_units()
	return unit_controller.move_toward(目标位置, delta, FFManager.get_flow_field(), 所有单位)
