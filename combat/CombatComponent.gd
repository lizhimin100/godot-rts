class_name CombatComponent
extends Node

## 战斗组件 — 管理完整攻击周期（前摇→打击→后摇→冷却）
##
## 单位只需：
##   1. 配置 windup_time / recovery_time / cooldown_timing
##   2. 连接 attack_strike 实现伤害/发射
##   3. 连接 attack_finished 做状态切换
##
## CombatComponent 自动完成：
##   - 冷却计时 + 全帧目标检测
##   - 前摇（windup）→ 打击（strike）→ 后摇（recovery）时序管理
##   - 冷却定位（AT_STRIKE 或 AT_WINDUP）
##
## 不再需要单位自己写 await / set_cooldown

enum CooldownTiming {
	AT_STRIKE,  # 冷却从打击时刻开始（旧版剑士/弓箭手行为）
	AT_WINDUP,  # 冷却从前摇开始（更快攻击循环）
}

## 生命周期信号
signal attack_started(target: Node2D)         # 前摇开始 — 单位可在此触发攻击动画
signal attack_strike(target: Node2D, packet: DamagePacket)  # 打击时刻 — 伤害/发射
signal attack_finished(target: Node2D)        # 后摇结束 — 单位在此做状态切换

## 基础攻击属性
@export var attack_damage: float = 10.0
@export var attack_range: float = 45.0
@export var attack_cooldown: float = 1.0
@export var damage_type: int = DamagePacket.DamageType.PHYSICAL

## 攻击周期参数
@export var windup_time: float = 0.0     # 前摇时长（秒）
@export var recovery_time: float = 0.0   # 后摇时长（秒）
@export var cooldown_timing: CooldownTiming = CooldownTiming.AT_STRIKE

enum AttackPhase { IDLE, WINDUP, RECOVERY }

# 相位状态机
var _phase: AttackPhase = AttackPhase.IDLE
var _cooldown_timer: float = 0.0
var _windup_timer: float = 0.0
var _recovery_timer: float = 0.0
var _current_target: Node2D = null
var _current_packet: DamagePacket = null

var targeting_component: TargetingComponent = null
var _owner_node: Node2D = null
var _found_targeting: bool = false


func _ready() -> void:
	_owner_node = owner as Node2D
	if not _owner_node:
		_owner_node = get_parent() as Node2D


func _process(delta: float) -> void:
	# 冷却始终递减
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	match _phase:
		AttackPhase.IDLE:
			if _cooldown_timer <= 0.0:
				_try_start_attack()
		AttackPhase.WINDUP:
			_windup_timer -= delta
			if _windup_timer <= 0.0:
				_deliver_strike()
		AttackPhase.RECOVERY:
			_recovery_timer -= delta
			if _recovery_timer <= 0.0:
				_finish_attack()


## 尝试开始新的攻击周期
func _try_start_attack() -> void:
	# 延迟查找 TargetingComponent（避免 _ready 顺序问题）
	if not _found_targeting:
		targeting_component = _find_targeting_component()
		_found_targeting = true

	if not targeting_component or not _owner_node:
		return

	var target: Node2D = targeting_component.get_target()
	if not target or not is_instance_valid(target):
		return

	var dist_sq: float = _owner_node.global_position.distance_squared_to(target.global_position)
	var range_sq: float = attack_range * attack_range
	if dist_sq > range_sq:
		return

	# 开始攻击周期
	_current_target = target
	_current_packet = _create_packet(target)

	_phase = AttackPhase.WINDUP
	_windup_timer = windup_time

	if cooldown_timing == CooldownTiming.AT_WINDUP:
		_cooldown_timer = attack_cooldown

	attack_started.emit(target)

	# 前摇为 0 → 立即打击
	if windup_time <= 0.0:
		_deliver_strike()


## 打击阶段 — 检查距离，发出 damage/发射信号
func _deliver_strike() -> void:
	var target = _current_target
	_phase = AttackPhase.RECOVERY
	_recovery_timer = recovery_time

	if cooldown_timing == CooldownTiming.AT_STRIKE:
		_cooldown_timer = attack_cooldown

	# 打击时检查目标是否仍在范围内（旧版行为）
	if target and is_instance_valid(target) and _owner_node:
		if _owner_node.global_position.distance_squared_to(target.global_position) <= attack_range * attack_range:
			attack_strike.emit(target, _current_packet)

	if recovery_time <= 0.0:
		_finish_attack()


## 攻击周期完全结束
func _finish_attack() -> void:
	var target = _current_target
	_phase = AttackPhase.IDLE
	_current_target = null
	_current_packet = null
	attack_finished.emit(target)


func _create_packet(target: Node2D) -> DamagePacket:
	var packet := DamagePacket.new()
	packet.damage = attack_damage
	packet.damage_type = damage_type
	packet.attacker = _owner_node
	packet.target = target
	if target:
		packet.position = target.global_position
	return packet


## 重置冷却（用于强制立即攻击）
func reset_cooldown() -> void:
	_cooldown_timer = 0.0


## 获取冷却进度 (0.0 ~ 1.0)，1.0 表示就绪
func get_cooldown_progress() -> float:
	if attack_cooldown <= 0.0:
		return 1.0
	return 1.0 - (_cooldown_timer / attack_cooldown)


## 中断当前攻击（单位死亡或被命令停止时调用）
func cancel_attack() -> void:
	_phase = AttackPhase.IDLE
	_current_target = null
	_current_packet = null


func _find_targeting_component() -> TargetingComponent:
	var parent: Node = get_parent()

	# 优先使用父节点的直接引用
	if parent and "targeting_component" in parent:
		return parent.targeting_component as TargetingComponent

	if not parent:
		return null
	for child in parent.get_children():
		if child is TargetingComponent:
			return child
	if parent.has_method("find_child"):
		return parent.find_child("TargetingComponent", true, false) as TargetingComponent
	return null
