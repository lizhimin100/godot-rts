class_name UnitController
extends Node

## 单位移动控制器 — 单驱动力原则
##
## 职责：
##   1. 唯一的 velocity 计算入口 compute_velocity()
##   2. FlowField 流场采样 + Steering 分离转向
##   3. 不可逆到达硬锁（ARRIVED_LOCKED）
##   4. Stuck Detection 卡死检测与解卡
##   5. 阵型展开（接近时直接指向槽位，一次性锁定）
##   6. 让路避让（前方静止/低优先级友军减速绕行）
##
## 到达锁定策略（v2）：
##   - 槽位到达阈值 = max(stop_radius * 2, 64.0)，大于最大推开距离
##   - 稳定计数器：连续 3 帧在窗口内才锁定
##   - 精确吸附：距离 < 16px 直接 snap 到槽位位置锁定
##
## 使用方式：
##   父节点 _physics_process 中：
##     velocity = controller.compute_velocity(delta, ff, all_units)
##     move_and_slide()

signal arrived

# ============================================================
# 状态枚举
# ============================================================

enum MoveState {
	IDLE,           # 待机 / 停稳
	FLOW_MOVE,      # 流场驱动移动中
	ARRIVED_LOCKED, # ⚠ 不可逆硬锁：到达后锁定，只有新命令可解锁
}

# ============================================================
# 导出参数
# ============================================================

@export_group("移动参数")
@export var max_speed: float = 120.0
@export var acceleration: float = 600.0

@export_group("到达停止")
## 停止半径（px）：进入此范围后 velocity = ZERO，锁定
@export var stop_radius: float = 12.0

@export_group("分离转向")
@export var separation_radius: float = 20.0
@export var separation_strength: float = 4.0

@export_group("阵型展开")
@export var formation_approach_radius: float = 64.0

@export_group("让路避让")
@export var yield_radius: float = 48.0
@export var yield_block_factor: float = 0.15
@export var yield_pass_factor: float = 0.4
@export var move_priority: int = 0

@export_group("卡死检测")
@export var stuck_threshold: float = 2.0
@export var stuck_timeout: float = 0.5
@export var unstick_force: float = 25.0

# ============================================================
# 到达参数（内部常量）
# ============================================================

## 槽位到达阈值：大于最大推开距离，确保被碰撞推开后仍能锁定
const SLOT_ARRIVAL_THRESHOLD: float = 64.0
## 精确吸附距离：小于此值直接设置 global_position
const SNAP_DISTANCE: float = 16.0
## 稳定计数器帧数：连续 N 帧在窗口内才锁定
const ARRIVE_STABLE_FRAMES: int = 3

# ============================================================
# 运行时状态
# ============================================================

var _move_state: MoveState = MoveState.IDLE

var target_position: Vector2 = Vector2.ZERO
var formation_offset: Vector2 = Vector2.ZERO
var formation_slot_id: int = -1

var velocity: Vector2 = Vector2.ZERO

var _approaching_slot: bool = false

var _unit: CharacterBody2D = null

# 卡死检测
var _stuck_timer: float = 0.0
var _stuck_sample_count: int = 0

# 让路节流缓存
var _yield_factor: float = 1.0
var _yield_throttle: int = 0
const YIELD_THROTTLE_INTERVAL: int = 8
const YIELD_VELOCITY_THRESHOLD_SQ: float = 1.0

# ⭐ 调试标志
var DEBUG_ARRIVE: bool = true

# ⭐ 稳定计数器：连续满足锁定条件的帧数
var _arrive_stable_counter: int = 0


func _ready() -> void:
	_unit = get_parent() as CharacterBody2D
	if not _unit:
		push_error("UnitController must be child of a CharacterBody2D, got: ", get_parent())
		set_physics_process(false)
		set_process(false)
		return
	velocity = _unit.velocity


# ============================================================
# 公共接口
# ============================================================

func set_target(pos: Vector2) -> void:
	target_position = pos
	formation_offset = Vector2.ZERO
	formation_slot_id = -1
	_move_state = MoveState.FLOW_MOVE
	_approaching_slot = false
	_stuck_timer = 0.0
	_stuck_sample_count = 0
	_arrive_stable_counter = 0


func get_final_target() -> Vector2:
	return target_position + formation_offset


func stop() -> void:
	_move_state = MoveState.IDLE
	formation_offset = Vector2.ZERO
	formation_slot_id = -1
	_approaching_slot = false
	_stuck_timer = 0.0
	_stuck_sample_count = 0
	_arrive_stable_counter = 0


func lock_arrival() -> void:
	_move_state = MoveState.ARRIVED_LOCKED
	velocity = Vector2.ZERO
	arrived.emit()


func has_arrived() -> bool:
	return _move_state == MoveState.ARRIVED_LOCKED


func is_moving() -> bool:
	return _move_state == MoveState.FLOW_MOVE


# ============================================================
# 唯一 velocity 计算入口
# ============================================================

func compute_velocity(delta: float, flow_field = null, all_units: Array = []) -> Vector2:
	if _unit:
		velocity = _unit.velocity

	match _move_state:
		MoveState.ARRIVED_LOCKED:
			return Vector2.ZERO

		MoveState.IDLE:
			if velocity.length_squared() > 0.1:
				return velocity.move_toward(Vector2.ZERO, acceleration * 2.0 * delta)
			return Vector2.ZERO

		MoveState.FLOW_MOVE:
			return _compute_flow_velocity(delta, flow_field, all_units)

	return Vector2.ZERO


# ============================================================
# FLOW_MOVE 核心计算
# ============================================================

func _compute_flow_velocity(delta: float, ff, units: Array) -> Vector2:
	# ---- 0. 稳定计数器维护（先判定槽位到达，再决定是否重置） ----
	var slot_arrival_qualified := false

	# ---- 1. 到达检测：进入 stop_radius 立即硬锁 ----
	var dist_target_sq: float = _unit.global_position.distance_squared_to(target_position)
	if dist_target_sq <= stop_radius * stop_radius:
		if DEBUG_ARRIVE: print("[ARRIVE] ", _unit.name, " 到达目标点 dist=", sqrt(dist_target_sq))
		lock_arrival()
		return Vector2.ZERO

	# ---- 2. 槽位到达检测（仅在有队形偏移时） ----
	if formation_offset.length_squared() > 0.01:
		var dist_slot: float = _unit.global_position.distance_to(get_final_target())

		# 2a. 精确吸附：距离 < SNAP_DISTANCE，直接 snap 到槽位
		if dist_slot < SNAP_DISTANCE:
			if DEBUG_ARRIVE: print("[ARRIVE] ", _unit.name, " SNAP dist=", dist_slot)
			_unit.global_position = get_final_target()
			lock_arrival()
			return Vector2.ZERO

		# 2b. 宽容锁定窗口：dist_slot < SLOT_ARRIVAL_THRESHOLD
		if dist_slot < SLOT_ARRIVAL_THRESHOLD:
			slot_arrival_qualified = true
			if DEBUG_ARRIVE: print("[ARRIVE] ", _unit.name, " 进入窗口 dist_slot=", dist_slot, " dist_target=", sqrt(dist_target_sq))

	# ---- 稳定计数器判定 ----
	if slot_arrival_qualified:
		_arrive_stable_counter += 1
		if DEBUG_ARRIVE: print("[ARRIVE] ", _unit.name, " counter=", _arrive_stable_counter, "/", ARRIVE_STABLE_FRAMES)
		if _arrive_stable_counter >= ARRIVE_STABLE_FRAMES:
			if DEBUG_ARRIVE: print("[ARRIVE] ", _unit.name, " LOCKED! counter=", _arrive_stable_counter)
			lock_arrival()
			return Vector2.ZERO
	else:
		if _arrive_stable_counter > 0:
			if DEBUG_ARRIVE: print("[ARRIVE] ", _unit.name, " counter RESET (was ", _arrive_stable_counter, ")")
		_arrive_stable_counter = 0

	# ---- 3. 从 FlowField 采样移动方向 ----
	var flow_dir: Vector2 = _sample_flow_field(ff)

	if flow_dir == Vector2.ZERO:
		var raw_dir: Vector2 = get_final_target() - _unit.global_position
		if raw_dir.length_squared() < 0.0001:
			return Vector2.ZERO
		flow_dir = raw_dir.normalized()

	# ---- 4. 阵型展开（接近槽位后直接指向，不再退回流场） ----
	if formation_offset.length_squared() > 0.01:
		var dist_to_slot: float = _unit.global_position.distance_to(get_final_target())
		if dist_to_slot <= formation_approach_radius or _approaching_slot:
			if not _approaching_slot:
				if DEBUG_ARRIVE: print("[ARRIVE] ", _unit.name, " 进入approach半径 dist_to_slot=", dist_to_final)
			_approaching_slot = true
			var slot_dir: Vector2 = get_final_target() - _unit.global_position
			if slot_dir.length_squared() > 0.0001:
				flow_dir = slot_dir.normalized()

	# ---- 5. Separation Steering 分离力（限幅 max 30%） ----
	var sep_force: Vector2 = Vector2.ZERO
	if separation_strength > 0.0 and not units.is_empty():
		sep_force = SeparationSystem.get_force(
			_unit.global_position,
			units,
			separation_radius,
			separation_strength
		)
		sep_force = sep_force.limit_length(max_speed * 0.3)

	# ---- 6. 方向融合 ----
	var desired_dir: Vector2 = flow_dir
	if sep_force != Vector2.ZERO:
		desired_dir = flow_dir + sep_force
		if desired_dir.length_squared() > 0.0001:
			desired_dir = desired_dir.normalized()
		else:
			desired_dir = flow_dir

	# ---- 7. 目标速度 ----
	var desired_vel: Vector2 = desired_dir * max_speed
	desired_vel *= _compute_yield_factor()

	# ---- 8. 平滑加速 ----
	var result: Vector2 = velocity.move_toward(desired_vel, acceleration * delta)
	result = result.limit_length(max_speed)

	# ---- 9. 卡死检测 ----
	if _move_state == MoveState.FLOW_MOVE:
		_check_stuck(delta, ff, flow_dir)

	return result


func _sample_flow_field(ff) -> Vector2:
	if not ff or (ff.has_method("is_valid") and not ff.is_valid()):
		return Vector2.ZERO
	if ff.has_method("sample"):
		return ff.sample(_unit.global_position)
	return Vector2.ZERO


# ============================================================
# 让路避让系统
# ============================================================

func _compute_yield_factor() -> float:
	_yield_throttle += 1
	if _yield_throttle % YIELD_THROTTLE_INTERVAL != 0:
		return _yield_factor

	if velocity.length_squared() < YIELD_VELOCITY_THRESHOLD_SQ:
		return _yield_factor

	var my_dir: Vector2 = velocity.normalized()
	var factor: float = 1.0
	var all_units: Array = FFManager.get_all_units() if is_instance_valid(FFManager) else []

	for other in all_units:
		if other == _unit or not is_instance_valid(other):
			continue
		if _is_different_camp(other):
			continue

		var offset: Vector2 = _unit.global_position - other.global_position
		var dist: float = offset.length()
		if dist > yield_radius or dist < 1.0:
			continue

		var to_other_dir: Vector2 = (-offset).normalized()
		var approach: float = my_dir.dot(to_other_dir)
		if approach <= 0.3:
			continue

		var strength: float = 1.0 - (dist / yield_radius)

		if _is_unit_stationary(other):
			factor = min(factor, lerp(1.0, yield_block_factor, strength))
		else:
			var other_vel: Vector2 = other.velocity if "velocity" in other else Vector2.ZERO
			if other_vel.length_squared() < YIELD_VELOCITY_THRESHOLD_SQ:
				factor = min(factor, lerp(1.0, yield_pass_factor, strength))
			else:
				var from_other_dir: Vector2 = offset.normalized()
				var other_approach: float = other_vel.normalized().dot(from_other_dir)
				if other_approach > 0.3:
					var other_priority: int = other.get("move_priority") if "move_priority" in other else 0
					if other_priority > move_priority:
						factor = min(factor, lerp(1.0, yield_pass_factor, strength))

	_yield_factor = clampf(factor, 0.0, 1.0)
	return _yield_factor


func _is_different_camp(other: Node2D) -> bool:
	if not _unit.has_method("获取阵营") or not other.has_method("获取阵营"):
		return false
	return _unit.获取阵营() != other.获取阵营()


static func _is_unit_stationary(node: Node2D) -> bool:
	if "velocity" in node:
		return node.velocity.length_squared() < 4.0
	return true


# ============================================================
# 卡死检测与解卡
# ============================================================

func _check_stuck(delta: float, ff, original_flow_dir: Vector2) -> void:
	var speed: float = velocity.length()

	if speed < stuck_threshold:
		_stuck_timer += delta
		if _stuck_timer >= stuck_timeout:
			_stuck_sample_count += 1

			var fresh_dir: Vector2 = _sample_flow_field(ff)
			if fresh_dir == Vector2.ZERO:
				fresh_dir = original_flow_dir

			var perturbation: Vector2 = Vector2(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			)
			if perturbation.length_squared() > 0.0001:
				perturbation = perturbation.normalized() * unstick_force

			var recovery: Vector2 = fresh_dir * max_speed * 0.5 + perturbation
			if recovery.length_squared() > 0.0001:
				velocity = recovery

			_stuck_timer = 0.0
	else:
		_stuck_timer = maxf(_stuck_timer - delta * 2.0, 0.0)
		_stuck_sample_count = 0


# ============================================================
# 重置
# ============================================================

func reset() -> void:
	target_position = Vector2.ZERO
	formation_offset = Vector2.ZERO
	formation_slot_id = -1
	velocity = Vector2.ZERO
	_move_state = MoveState.IDLE
	_approaching_slot = false
	_stuck_timer = 0.0
	_stuck_sample_count = 0
	_yield_factor = 1.0
	_yield_throttle = 0
	_arrive_stable_counter = 0
