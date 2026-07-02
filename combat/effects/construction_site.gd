extends Node2D

## 施工场地 — 建造中的建筑
##
## 子节点：Sprite（半透明建筑图）+ StaticBody2D（碰撞阻挡）
## 进度条由单独的 build_countdown_ui.tscn 管理（农民.gd 负责实例化）
##
## v2 新增：可被敌人攻击，被摧毁时通知建造农民

signal construction_destroyed(site: Node2D)

@onready var sprite: Sprite2D = $Sprite
@onready var blocker: StaticBody2D = $Blocker

## 建造此施工场地的农民引用
var builder_peasant = null

## 建筑阵营（与建造者一致）
var building_faction: int = 阵营管理器.阵营.玩家
## 建筑类型（用于获取 HP 等属性）
var building_type: int = -1

var _health: HealthComponent = null


func _ready() -> void:
	# 添加 HealthComponent
	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	# 默认 HP 由 set_building_hp 设置
	_health.max_hp = 200.0
	add_child(_health)
	_health.died.connect(_on_destroyed)

	# 加入建筑组，使敌人可索敌
	add_to_group("建筑")


func set_building_texture(tex: Texture2D) -> void:
	if not sprite:
		sprite = $Sprite
	if not sprite:
		return
	sprite.texture = tex
	sprite.modulate = Color(1, 1, 1, 0.3)


func set_blocker_size(size: Vector2) -> void:
	if not blocker:
		blocker = $Blocker
	if not blocker:
		return
	var shape: RectangleShape2D = blocker.get_node("CollisionShape2D").shape as RectangleShape2D
	if shape:
		shape.size = size


## 设置施工场地的 HP（根据建筑类型）
func set_building_hp(hp: float) -> void:
	if _health:
		_health.max_hp = hp
		_health.set_hp(hp)


## 设置建造者和阵营
func set_builder(peasant, faction: int, btype: int) -> void:
	builder_peasant = peasant
	building_faction = faction
	building_type = btype


# ============================================================
# 阵营接口（供索敌系统使用）
# ============================================================

func 获取阵营() -> int:
	return building_faction


func _是敌人() -> bool:
	return building_faction == 阵营管理器.阵营.敌人


func _是玩家() -> bool:
	return building_faction == 阵营管理器.阵营.玩家


func 判断关系(目标) -> int:
	if not 目标 or not is_instance_valid(目标):
		return 阵营管理器.关系.中立
	if 目标.has_method("获取阵营"):
		return 阵营管理器.获取关系(building_faction, 目标.获取阵营())
	return 阵营管理器.关系.中立


func 是敌对(目标) -> bool:
	return 判断关系(目标) == 阵营管理器.关系.敌对


func 是友军(目标) -> bool:
	return 判断关系(目标) == 阵营管理器.关系.友军


# ============================================================
# 受伤/死亡接口
# ============================================================

func 受伤(伤害: float, 攻击来源 = null) -> void:
	if _health and not _health.is_dead():
		_health.take_damage(伤害, 攻击来源)


func _on_destroyed(_attacker) -> void:
	## 施工场地被摧毁 → 通知建造农民取消建造
	construction_destroyed.emit(self)

	# 通知农民取消建造（_取消建造 中会 queue_free 本节点）
	if builder_peasant and is_instance_valid(builder_peasant):
		if builder_peasant.has_method("_取消建造"):
			builder_peasant._取消建造()
	else:
		# 没有农民关联，自行消失
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
