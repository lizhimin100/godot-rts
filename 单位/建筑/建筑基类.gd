class_name 建筑基类
extends StaticBody2D

## 建筑基类 — 所有 RTS 建筑的基类
##
## 不继承 UnitBase（建筑使用 StaticBody2D，不需要移动逻辑）
## 但通过组件组合复用相同的战斗系统：
##   HealthComponent     — HP 管理 + 死亡信号
##   CombatComponent     — 攻击冷却 + 触发（用于防御塔等可攻击建筑）
##   TargetingComponent  — 目标选择（用于防御塔等自动索敌建筑）
##   UnitStatusBar       — 选中时显示 HP 条（自动创建 ProgressBar）
##
## 保留建筑特有的：摧毁精灵切换、受击动画

signal 建筑被摧毁(建筑: 建筑基类)

# ========== 建筑属性 ==========
@export var 建筑名称: String = "建筑"
@export var 最大生命值: float = 500.0
@export var 阵营: 阵营管理器.阵营 = 阵营管理器.阵营.玩家

# 向后兼容 shim
var 当前生命值: float:
	get:
		var hc: HealthComponent = _get_health()
		return hc.hp if hc else 最大生命值
	set(v):
		var hc: HealthComponent = _get_health()
		if hc: hc.set_hp(v)

var 已摧毁 := false
var 选择状态 := false:
	set(v):
		if 选择状态 != v:
			选择状态 = v
			_on_selection_changed()

# 节点
@onready var 建筑图像: Sprite2D = $建筑图像
@onready var 已摧毁图像: Sprite2D = $已摧毁图像
@onready var 碰撞: CollisionShape2D = $碰撞
@onready var 动画: AnimationPlayer = $动画

# 缓存
var _cached_health: HealthComponent = null
var _cached_combat: CombatComponent = null
var _cached_targeting: TargetingComponent = null


func _ready() -> void:
	# 初始化战斗组件
	_init_combat_components()

	# 分组注册
	add_to_group("建筑")
	add_to_group("移动单位")

	if 已摧毁图像:
		已摧毁图像.visible = false

	# 阵营推断
	if collision_layer == 16:
		阵营 = 阵营管理器.阵营.敌人
	else:
		collision_layer = 4
		阵营 = 阵营管理器.阵营.玩家
	collision_mask = 0

	if 阵营 == 阵营管理器.阵营.玩家:
		add_to_group("可选单位")

	# 连接死亡信号
	var hc = _get_health()
	if hc:
		hc.died.connect(_on_died)


# ============================================================
# 战斗组件初始化（子类可重写）
# ============================================================

func _init_combat_components() -> void:
	# HealthComponent
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_hp = 最大生命值
	add_child(health)

	# CombatComponent（默认禁用，防御塔等子类会启用）
	var combat := CombatComponent.new()
	combat.name = "CombatComponent"
	combat.attack_damage = 0.0  # 默认不攻击
	combat.process_mode = PROCESS_MODE_DISABLED  # 默认不激活
	add_child(combat)

	# TargetingComponent（默认禁用，防御塔等子类会启用）
	var targeting := TargetingComponent.new()
	targeting.name = "TargetingComponent"
	targeting.process_mode = PROCESS_MODE_DISABLED
	add_child(targeting)

	# UnitStatusBar（自动创建血条/蓝条 ProgressBar）
	var bar := UnitStatusBar.new()
	bar.name = "UnitStatusBar"
	add_child(bar)


# ============================================================
# 组件访问
# ============================================================

func _get_health() -> HealthComponent:
	if not _cached_health or not is_instance_valid(_cached_health):
		_cached_health = find_child("HealthComponent") as HealthComponent
	return _cached_health

func _get_combat() -> CombatComponent:
	if not _cached_combat or not is_instance_valid(_cached_combat):
		_cached_combat = find_child("CombatComponent") as CombatComponent
	return _cached_combat

func _get_targeting() -> TargetingComponent:
	if not _cached_targeting or not is_instance_valid(_cached_targeting):
		_cached_targeting = find_child("TargetingComponent") as TargetingComponent
	return _cached_targeting


# ============================================================
# 选择状态 → 通知 UnitStatusBar
# ============================================================

func _on_selection_changed() -> void:
	var bar: UnitStatusBar = find_child("UnitStatusBar") as UnitStatusBar
	if bar:
		bar.set_selected(选择状态)


# ============================================================
# 阵营接口
# ============================================================

func _是敌人() -> bool:
	return 阵营 == 阵营管理器.阵营.敌人

func _是玩家() -> bool:
	return 阵营 == 阵营管理器.阵营.玩家

func 获取阵营() -> int:
	return 阵营


# ============================================================
# 向后兼容 — 受伤接口（转发到 HealthComponent）
# ============================================================

func 受伤(伤害: float, 攻击来源 = null) -> void:
	if 已摧毁:
		return
	var hc = _get_health()
	if hc:
		hc.take_damage(伤害, 攻击来源)


# ============================================================
# 死亡处理
# ============================================================

func _on_died(_attacker) -> void:
	if 已摧毁:
		return
	已摧毁 = true

	# 切换为摧毁精灵
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
