class_name 建筑基类
extends StaticBody2D

## 建筑基类 — 所有 RTS 建筑的基类
##
## 不继承 单位基类（使用 StaticBody2D，不需要移动逻辑）
## 但通过组件组合复用相同的战斗系统：
##   HealthComponent     — HP 管理 + 死亡信号
##   CombatComponent     — 攻击冷却 + 触发（用于防御塔等可攻击建筑）
##   TargetingComponent  — 目标选择（用于防御塔等自动索敌建筑）
##   UnitStatusBar       — 选中时显示 HP 条
##
## 命令通过 CommandManager 下发
## 选择通过 SelectionManager 管理

signal 建筑被摧毁(建筑: 建筑基类)

# ========== 建筑属性 ==========
@export var 建筑名称: String = "建筑"
@export var 最大生命值: float = 500.0
@export var 视野半径: float = 200.0  # 建筑默认提供 200px 视野

var _阵营: int = 阵营管理器.阵营.玩家

@export var 阵营: int:
	get: return _阵营
	set(v):
		if _阵营 != v:
			_阵营 = v
			_更新阵营设置()

var 已摧毁 := false
var 选择状态 := false  # 简单状态，由外部设置

@onready var 建筑图像: Sprite2D = $建筑图像
@onready var 已摧毁图像: Sprite2D = $已摧毁图像
@onready var 碰撞: CollisionShape2D = $碰撞
@onready var 动画: AnimationPlayer = $动画

# 缓存
var _cached_health: HealthComponent = null
var _cached_combat: CombatComponent = null
var _cached_targeting: TargetingComponent = null
var _状态条: UnitStatusBar = null


func _ready() -> void:
	# 阵营判定（和 UnitBase 一致）
	if collision_layer == 16:
		_阵营 = 阵营管理器.阵营.敌人
	else:
		_阵营 = 阵营管理器.阵营.玩家

	_init_combat_components()

	# 分组注册
	add_to_group("建筑")
	add_to_group("移动单位")
	_更新阵营设置()

	# 注册到管理器
	if 单位管理器.实例:
		单位管理器.实例.注册单位(self)
	if 迷雾系统.实例 and 视野半径 > 0:
		迷雾系统.实例.注册视野来源(self)

	# 连接死亡信号
	var hc = _获取生命组件()
	if hc:
		hc.died.connect(_on_died)


func _exit_tree() -> void:
	if 单位管理器.实例:
		单位管理器.实例.注销单位(self)
	if 迷雾系统.实例:
		迷雾系统.实例.注销视野来源(self)


func _更新阵营设置() -> void:
	if _阵营 == 阵营管理器.阵营.玩家:
		add_to_group("可选单位")
		collision_layer = 4
	else:
		remove_from_group("可选单位")
		collision_layer = 16
	collision_mask = 8 + 16  # 被所有单位碰撞阻挡


# ============================================================
# 战斗组件初始化
# ============================================================

func _init_combat_components() -> void:
	# HealthComponent
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_hp = 最大生命值
	add_child(health)

	# CombatComponent（默认禁用，防御塔等会启用）
	var combat := CombatComponent.new()
	combat.name = "CombatComponent"
	combat.attack_damage = 0.0
	combat.process_mode = PROCESS_MODE_DISABLED
	add_child(combat)

	# TargetingComponent（默认禁用）
	var targeting := TargetingComponent.new()
	targeting.name = "TargetingComponent"
	targeting.process_mode = PROCESS_MODE_DISABLED
	add_child(targeting)

	# UnitStatusBar
	var bar := UnitStatusBar.new()
	bar.name = "UnitStatusBar"
	_状态条 = bar
	add_child(bar)


# ============================================================
# 组件访问
# ============================================================

func _获取生命组件() -> HealthComponent:
	if not _cached_health or not is_instance_valid(_cached_health):
		_cached_health = find_child("HealthComponent") as HealthComponent
	return _cached_health

func _获取战斗组件() -> CombatComponent:
	if not _cached_combat or not is_instance_valid(_cached_combat):
		_cached_combat = find_child("CombatComponent") as CombatComponent
	return _cached_combat

func _获取索敌组件() -> TargetingComponent:
	if not _cached_targeting or not is_instance_valid(_cached_targeting):
		_cached_targeting = find_child("TargetingComponent") as TargetingComponent
	return _cached_targeting


# ============================================================
# 阵营接口
# ============================================================

func _是敌人() -> bool:
	return _阵营 == 阵营管理器.阵营.敌人

func _是玩家() -> bool:
	return _阵营 == 阵营管理器.阵营.玩家

func 获取阵营() -> int:
	return _阵营


# ============================================================
# 向后兼容 — 受伤接口
# ============================================================

func 受伤(伤害: float, 攻击来源 = null) -> void:
	if 已摧毁:
		return
	var hc = _获取生命组件()
	if hc:
		hc.take_damage(伤害, 攻击来源)


func 获取当前生命值() -> float:
	var hc = _获取生命组件()
	return hc.hp if hc else 最大生命值


# ============================================================
# 死亡处理
# ============================================================

func _on_died(_attacker) -> void:
	if 已摧毁:
		return
	已摧毁 = true

	if 建筑图像 and 已摧毁图像:
		建筑图像.visible = false
		已摧毁图像.visible = true

	if 碰撞:
		碰撞.disabled = true

	建筑被摧毁.emit(self)

	# 隐藏状态条
	var bar: UnitStatusBar = find_child("UnitStatusBar") as UnitStatusBar
	if bar:
		bar.set_selected(false)

	# 淡出
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	if is_instance_valid(self):
		queue_free()
