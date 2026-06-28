class_name CombatComponent
extends Node

## 战斗组件 — 管理攻击冷却、触发伤害管线
##
## 职责：
##   1. 每帧递减冷却计时器
##   2. 冷却就绪时向 TargetingComponent 索取目标
##   3. 目标在攻击范围内时创建 DamagePacket 并发出 attack_initiated 信号
##
## 不负责：
##   - 选择目标（委托给 TargetingComponent）
##   - 伤害结算（委托给 DamageSystem）
##   - 动画播放（由连接 attack_initiated 的脚本处理）

signal attack_initiated(target: Node2D, packet: DamagePacket)

## 基础攻击属性
@export var attack_damage: float = 10.0
@export var attack_range: float = 45.0
@export var attack_cooldown: float = 1.0
@export var damage_type: int = DamagePacket.DamageType.PHYSICAL

## 目标选择组件引用（自动查找同级节点）
var targeting_component: TargetingComponent = null

var _cooldown_timer: float = 0.0
var _owner_node: Node2D = null
var _found_targeting: bool = false


func _ready() -> void:
	_owner_node = owner as Node2D
	if not _owner_node:
		_owner_node = get_parent() as Node2D


func _process(delta: float) -> void:
	# 冷却递减
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	# 冷却未就绪则跳过
	if _cooldown_timer > 0.0:
		return

	# 查找 TargetingComponent（延迟查找，避免 _ready 顺序问题）
	if not _found_targeting:
		targeting_component = _find_targeting_component()
		_found_targeting = true

	if not targeting_component:
		return

	# 获取目标
	var target: Node2D = targeting_component.get_target()
	if not target or not is_instance_valid(target):
		return

	# 检查距离
	if not _owner_node or not is_instance_valid(_owner_node):
		return

	var dist_sq: float = _owner_node.global_position.distance_squared_to(target.global_position)
	var range_sq: float = attack_range * attack_range
	if dist_sq > range_sq:
		return

	# 执行攻击
	_execute_attack(target)


func _execute_attack(target: Node2D) -> void:
	var packet := DamagePacket.new()
	packet.damage = attack_damage
	packet.damage_type = damage_type
	packet.attacker = _owner_node
	packet.target = target
	packet.position = target.global_position

	_cooldown_timer = attack_cooldown

	attack_initiated.emit(target, packet)


## 重置冷却（用于强制立即攻击）
func reset_cooldown() -> void:
	_cooldown_timer = 0.0


## 获取冷却进度 (0.0 ~ 1.0)，1.0 表示就绪
func get_cooldown_progress() -> float:
	if attack_cooldown <= 0.0:
		return 1.0
	return 1.0 - (_cooldown_timer / attack_cooldown)


func _find_targeting_component() -> TargetingComponent:
	var parent: Node = get_parent()

	# ⭐ 优先使用父节点的直接引用（UnitBase.targeting_component）
	if parent and "targeting_component" in parent:
		return parent.targeting_component as TargetingComponent

	if not parent:
		return null
	# 回退：遍历子节点查找
	for child in parent.get_children():
		if child is TargetingComponent:
			return child
	# 再回退：递归查找
	if parent.has_method("find_child"):
		return parent.find_child("TargetingComponent", true, false) as TargetingComponent
	return null
