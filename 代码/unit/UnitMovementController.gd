class_name UnitMovementController
extends Node

## 单位移动控制器 — 唯一 velocity 控制中心
##
## 设计规则：
##   - ❗只有 _apply_velocity() 可以写入 velocity
##   - ❗FlowField / Steering 仅返回方向，不写入 velocity
##   - ❗子类不得直接写入 velocity
##
## 负责：
##   1. MOVE: 方向融合（流场×0.7 + 避障×1.5）+ 速度平滑
##   2. IDLE: 排斥力或归零
##   3. ATTACK: 减速归零
##   4. HARD ARRIVAL LOCK: 到达即停，后续不再执行
##   5. Soft Stop: 48px 内减速
##   6. Static Blocking + Yield + Crowd

signal arrived

# -------- 导出参数 --------

@export_group("移动参数")
@export var max_speed: float = 120.0
@export var accel: float = 8.0
@export var stopping_distance: float = 16.0

@export_group("流场参数")
@export var flow_weight: float = 0.7
@export var steer_weight: float = 1.5

@export_group("软停止 Soft Stop")
@export var slow_radius: float = 48.0

@export_group("让路系统 Right of Way")
@export var yield_range: float = 64.0
@export var yield_strength: float = 0.5
@export var move_priority: int = 0

@export var block_stop_factor: float = 0.0
@export var yield_pass_factor: float = 0.4

@export_group("人群密度 Crowd Pressure")
@export var crowd_radius: float = 64.0
@export var crowd_slowdown: float = 0.5
@export var stationary_density_multiplier: float = 3.0

@export_group("卡死检测")
@export var stuck_threshold: float = 0.5
@export var stuck_time_limit: float = 0.4
@export var unstick_strength: float = 25.0

# -------- 运行时状态 --------

var velocity: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var formation_offset: Vector2 = Vector2.ZERO

var _unit: CharacterBody2D = null
var _stuck_detector: UnitStuckDetector = null

var _has_arrived: bool = false
var _last_frame_dir: Vector2 = Vector2.ZERO
var _movement_locked: bool = false

# 到达 hysteresis
var _arrival_lock_timer: float = 0.0
const ARRIVAL_HYSTERESIS_PX: float = 32.0
const ARRIVAL_LOCK_DURATION: float = 0.3

# 帧节流：错峰偏移（基于 instance_id）
var _throttle_phase: int = 0
var _throttle_counter: int = 0
var _last_crowd_factor: float = 1.0
var _last_yield_factor: float = 1.0
const THROTTLE_INTERVAL: int = 8

const STUCK_CHECK_MULTIPLIER: float = 3.0
const STATIONARY_VELOCITY_THRESHOLD: float = 2.0


func _ready() -> void:
	_unit = get_parent() as CharacterBody2D
	if not _unit:
		push_error("UnitMovementController must be child of CharacterBody2D, got: ", get_parent())
		return
	_stuck_detector = UnitStuckDetector.new()
	_stuck_detector.set_params(stuck_threshold, stuck_time_limit)
	# 基于 instance_id 错峰
	_throttle_phase = hash(get_instance_id()) % THROTTLE_INTERVAL
	_throttle_counter = _throttle_phase


static func is_stationary(node: Node2D) -> bool:
	if "velocity" in node:
		return node.velocity.length_squared() < STATIONARY_VELOCITY_THRESHOLD * STATIONARY_VELOCITY_THRESHOLD
	return true


static func is_moving(node: Node2D) -> bool:
	return not is_stationary(node)


# ============================================================
# 唯一 velocity 写入点
# ============================================================

func _apply_velocity(vel: Vector2) -> void:
	velocity = vel
	_unit.velocity = vel


# ============================================================
# PUBLIC API
# ============================================================

func move_toward(target: Vector2, delta: float,
		formation: Vector2 = formation_offset) -> bool:
	if not _unit:
		return true
	target_position = target
	formation_offset = formation
	_process_movement(delta)
	return _has_arrived


## IDLE 状态：应用排斥力或归零
func process_idle(delta: float, repel_force: Vector2 = Vector2.ZERO) -> void:
	if _movement_locked:
		_apply_velocity(Vector2.ZERO)
		return
	if repel_force.length_squared() > 0.01:
		velocity = velocity.move_toward(repel_force, max_speed * 10.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, max_speed * 10.0 * delta)
	_apply_velocity(velocity)


## ATTACK 状态：减速归零
func process_attack(delta: float) -> void:
	if _movement_locked:
		_apply_velocity(Vector2.ZERO)
		return
	velocity = velocity.move_toward(Vector2.ZERO, max_speed * 12.0 * delta)
	_apply_velocity(velocity)


## 到达硬锁定
func lock() -> void:
	_movement_locked = true
	_has_arrived = true
	_last_frame_dir = Vector2.ZERO
	_arrival_lock_timer = ARRIVAL_LOCK_DURATION  # 至少保持 0.3s
	_apply_velocity(Vector2.ZERO)
	if _stuck_detector:
		_stuck_detector.reset()
	arrived.emit()


func has_arrived() -> bool:
	return _has_arrived


func is_locked() -> bool:
	return _movement_locked


func stop() -> void:
	target_position = _unit.global_position if _unit else Vector2.ZERO
	formation_offset = Vector2.ZERO
	_movement_locked = false
	_has_arrived = true
	_last_frame_dir = Vector2.ZERO
	_apply_velocity(Vector2.ZERO)
	if _stuck_detector:
		_stuck_detector.reset()


func set_target(target: Vector2) -> void:
	target_position = target
	formation_offset = Vector2.ZERO
	_has_arrived = false
	_movement_locked = false
	_arrival_lock_timer = 0.0
	if _unit:
		var dir_to: Vector2 = target - _unit.global_position
		if dir_to.length_squared() > 1.0:
			velocity = dir_to.normalized() * min(velocity.length(), max_speed * 0.3)
		else:
			velocity = Vector2.ZERO
	_last_frame_dir = Vector2.ZERO
	if _stuck_detector:
		_stuck_detector.reset()


# ============================================================
# 方向融合 — 只返回 direction，不写 velocity
# ============================================================

func _calculate_desired_direction() -> Vector2:
	if _movement_locked:
		return Vector2.ZERO

	var world_target: Vector2 = target_position + formation_offset

	var flow_dir: Vector2 = FFManager.get_direction(
		_unit.global_position, world_target)

	var steer_dir: Vector2 = SeparationSystem.get_force(_unit.global_position, FFManager.get_all_units(), 24.0, 4.0)

	var dir: Vector2 = flow_dir * flow_weight + steer_dir * steer_weight

	if dir.length_squared() < 0.0001:
		dir = (world_target - _unit.global_position).normalized()
	else:
		dir = dir.normalized()

	if _last_frame_dir.dot(dir) < -0.95 and _last_frame_dir.length_squared() > 0.1:
		dir = _last_frame_dir
	_last_frame_dir = dir

	return dir


# ============================================================
# 因子 — 只返回 scalar，不写 velocity
# ============================================================

func get_slow_factor(dist_to_target: float) -> float:
	if dist_to_target >= slow_radius:
		return 1.0
	return clamp(dist_to_target / slow_radius, 0.0, 1.0)


func get_crowd_factor() -> float:
	# 帧节流：每 8 帧更新一次，错峰
	_throttle_counter += 1
	if _throttle_counter % THROTTLE_INTERVAL != _throttle_phase:
		return _last_crowd_factor
	var density: float = 0.0
	var tree: SceneTree = _unit.get_tree()
	if not tree:
		return 1.0
	for other_node in FFManager.get_all_units():
		if other_node == _unit or not is_instance_valid(other_node):
			continue
		var d: float = _unit.global_position.distance_to(other_node.global_position)
		if d < crowd_radius:
			var contribution: float = 1.0 - d / crowd_radius
			if is_stationary(other_node):
				contribution *= stationary_density_multiplier
			density += contribution
	_last_crowd_factor = 1.0 - clamp(density, 0.0, 1.0) * crowd_slowdown
	return _last_crowd_factor


func get_yield_factor() -> float:
	# 帧节流：每 8 帧更新一次，错峰
	if _throttle_counter % THROTTLE_INTERVAL != (_throttle_phase + 3) % THROTTLE_INTERVAL:
		return _last_yield_factor
	var tree: SceneTree = _unit.get_tree()
	if not tree:
		return 1.0
	var my_vel: Vector2 = velocity
	if my_vel.length_squared() < 1.0:
		return 1.0
	var my_dir: Vector2 = my_vel.normalized()
	var factor: float = 1.0
	for other_node in FFManager.get_all_units():
		if other_node == _unit or not is_instance_valid(other_node):
			continue
		var offset: Vector2 = _unit.global_position - other_node.global_position
		var dist: float = offset.length()
		if dist > yield_range or dist < 1.0:
			continue
		var to_other_dir: Vector2 = (-offset).normalized()
		var my_approach: float = my_dir.dot(to_other_dir)
		if my_approach <= 0.3:
			continue
		# 静止 → 归零绕行
		if is_stationary(other_node):
			var strength: float = 1.0 - (dist / yield_range)
			factor = min(factor, lerp(1.0, block_stop_factor, strength))
			continue
		var other_vel: Vector2 = other_node.velocity if "velocity" in other_node else Vector2.ZERO
		if other_vel.length_squared() < 1.0:
			var strength: float = 1.0 - (dist / yield_range)
			factor = min(factor, lerp(1.0, yield_pass_factor, strength))
			continue
		var from_other_dir: Vector2 = offset.normalized()
		var other_approach: float = other_vel.normalized().dot(from_other_dir)
		if other_approach > 0.3:
			var other_priority: int = other_node.get("move_priority") if "move_priority" in other_node else 0
			if other_priority > move_priority:
				var strength: float = 1.0 - (dist / yield_range)
				factor = min(factor, lerp(1.0, yield_pass_factor, strength))
	_last_yield_factor = clamp(factor, 0.0, 1.0)
	return _last_yield_factor


# ============================================================
# 核心移动处理
# ============================================================

func _process_movement(delta: float) -> void:
	# 锁定后立即归零，跳过一切计算
	if _movement_locked:
		_apply_velocity(Vector2.ZERO)
		return

	var world_target: Vector2 = target_position + formation_offset
	var dist: float = _unit.global_position.distance_to(world_target)

	# HARD ARRIVAL LOCK：到达即停
	if dist <= stopping_distance:
		lock()
		return

	# 到达 hysteresis：锁定后至少保持 0.3s，且 > 32px 才解锁
	if _has_arrived or _arrival_lock_timer > 0.0:
		_arrival_lock_timer -= delta
		if _arrival_lock_timer > 0.0:
			_apply_velocity(Vector2.ZERO)
			return
		if dist <= ARRIVAL_HYSTERESIS_PX:
			_apply_velocity(Vector2.ZERO)
			return
		_movement_locked = false

	_has_arrived = false

	var desired_dir: Vector2 = _calculate_desired_direction()

	# 方向太弱 → 归零
	if desired_dir.length_squared() < 0.001:
		velocity = velocity.move_toward(Vector2.ZERO, max_speed * 6.0 * delta)
		if velocity.length() < 1.0:
			_apply_velocity(Vector2.ZERO)
		else:
			_apply_velocity(velocity)
		return

	var slow_factor: float = get_slow_factor(dist)
	var crowd_factor: float = get_crowd_factor()
	var yield_factor: float = get_yield_factor()

	var desired_velocity: Vector2 = desired_dir * max_speed * slow_factor * crowd_factor * yield_factor

	# 减速因子导致归零（遇到静态阻挡）
	if desired_velocity.length_squared() < 0.1:
		velocity = velocity.move_toward(Vector2.ZERO, max_speed * 6.0 * delta)
		if velocity.length() < 1.0:
			_apply_velocity(Vector2.ZERO)
		else:
			_apply_velocity(velocity)
		return

	velocity = velocity.lerp(desired_velocity, accel * delta)

	# 卡死检测（已到达/锁定状态下禁用）
	if not _has_arrived and not _movement_locked:
		if dist > stopping_distance * STUCK_CHECK_MULTIPLIER:
			if _stuck_detector and _stuck_detector.update(_unit, delta):
				var unstick: Vector2 = Vector2(
					randf_range(-1.0, 1.0),
					randf_range(-1.0, 1.0)
				).normalized() * unstick_strength
				velocity += unstick
				if velocity.dot(desired_velocity) < 0 and desired_velocity.length() > 0:
					velocity = desired_velocity * 0.2 + unstick

	if velocity.length_squared() > max_speed * max_speed:
		velocity = velocity.normalized() * max_speed

	_apply_velocity(velocity)
