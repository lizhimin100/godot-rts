class_name TargetingComponent
extends Node

## 目标选择组件 — 提供当前攻击目标
##
## 职责：
##   1. 维持当前攻击目标引用
##   2. 当前目标死亡/超距时自动更换
##   3. 使用策略模式支持多种索敌算法
##
## 策略:
##   - NearestStrategy（最近）
##   - LowestHPStrategy（最低血量）
##   - HighestThreatStrategy（最高威胁）

signal target_changed(new_target: Node2D)

## 索敌半径
@export var search_range: float = 250.0
## 追击上限距离（超过则放弃目标）
@export var chase_range: float = 400.0

var current_target: Node2D = null
var strategy: TargetingStrategy = null


func _ready() -> void:
	# 默认使用最近目标策略
	if not strategy:
		strategy = NearestStrategy.new()


## 获取当前目标（主接口）
func get_target() -> Node2D:
	# 当前目标有效 → 检查存活和距离
	if current_target and is_instance_valid(current_target):
		if _is_target_alive(current_target):
			var owner_node: Node2D = _get_owner_node()
			if owner_node:
				var dist: float = owner_node.global_position.distance_to(current_target.global_position)
				if dist <= chase_range:
					return current_target
		# 目标无效或超距
		current_target = null
		target_changed.emit(null)

	# 需要新目标
	current_target = _acquire_target()
	target_changed.emit(current_target)
	return current_target


## 手动设置目标（覆盖策略选择）
func set_target(target: Node2D) -> void:
	if target == current_target:
		return
	current_target = target
	target_changed.emit(target)


## 清除目标
func clear_target() -> void:
	if current_target == null:
		return
	current_target = null
	target_changed.emit(null)


## 切换索敌策略
func set_strategy(new_strategy: TargetingStrategy) -> void:
	strategy = new_strategy
	# 切换策略后清除旧目标
	clear_target()


func _acquire_target() -> Node2D:
	if not strategy:
		return null
	var owner_node: Node2D = _get_owner_node()
	if not owner_node:
		return null
	return strategy.find_target(owner_node, search_range)


func _get_owner_node() -> Node2D:
	var p: Node = get_parent()
	if p is Node2D:
		return p
	return owner as Node2D


## 检查目标是否存活
func _is_target_alive(target: Node2D) -> bool:
	if not is_instance_valid(target):
		return false

	# 通过 HealthComponent 检查
	var hc: HealthComponent = _find_health_component(target)
	if hc:
		return not hc.is_dead()

	# 向后兼容：检查旧属性
	if "当前生命值" in target:
		return target.当前生命值 > 0
	if "hp" in target:
		return target.hp > 0

	return true


static func _find_health_component(node: Node) -> HealthComponent:
	var hc: HealthComponent = node.get_node_or_null("HealthComponent") as HealthComponent
	if hc:
		return hc
	for child in node.get_children():
		if child is HealthComponent:
			return child
	return null
