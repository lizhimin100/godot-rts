class_name UnitController
extends Node

## 单位移动控制器 — 基于 FlowField 的稳定单位移动系统
##
## 职责：
##   1. 从 FlowField 采样获取全局移动方向
##   2. Separation Steering 分离转向（防止单位重叠）
##   3. Arrival Stop：进入 stop_radius 立即停止
##   4. Stuck Detection：velocity 过低超时 → 重新采样 + 扰动解卡
##   5. 阵型展开：接近阵型位时脱离流场直接指向槽位
##   6. 让路避让：前方有静止/低优先级友军时减速绕行
##   7. 禁止物理碰撞驱动行为（separation 纯 Steering，不靠 collision layer）
##
## 使用方式：
##   将此节点作为 CharacterBody2D 的子节点。
##   在父节点的 _physics_process 中调用 move_toward()，
##   然后调用 move_and_slide()。
##
##   ```gdscript
##   # 父节点 _physics_process
##   controller.move_toward(target_pos, delta, flow_field, all_units)
##   move_and_slide()
##   ```

signal arrived

# ============================================================
# 导出参数
# ============================================================

@export_group("移动参数")
## 最大移动速度（px/s）
@export var max_speed: float = 120.0
## 加速度（px/s²），越大响应越快
@export var acceleration: float = 600.0

@export_group("到达停止")
## 停止半径（px）：进入此范围后 velocity = ZERO，不再采样流场
## 推荐值：10~16 px
@export var stop_radius: float = 12.0

@export_group("分离转向")
## 分离排斥半径（px）：此范围内推开其他单位
## 推荐值：20~30 px
@export var separation_radius: float = 20.0
## 分离排斥强度
@export var separation_strength: float = 4.0

@export_group("阵型展开")
## 阵型接近半径（px）：接近此距离后直接指向阵型槽位，不再跟随全局流场
## 使多单位移动时自然分散到各自阵型位
@export var formation_approach_radius: float = 64.0

@export_group("让路避让")
## 让路检测半径（px）
@export var yield_radius: float = 48.0
## 前方静止友军减速因子（0=完全停下，1=不减速）
@export var yield_block_factor: float = 0.15
## 遇高优先级友军通行因子
@export var yield_pass_factor: float = 0.4
## 移动优先级（数值越高越优先通行）
@export var move_priority: int = 0

@export_group("卡死检测")
## 卡死速度阈值（px/s）：velocity 低于此值视为卡住
@export var stuck_threshold: float = 2.0
## 卡死判定时间（秒）：连续低于阈值超过此时间触发解卡
@export var stuck_timeout: float = 0.5
## 解卡扰动强度
@export var unstick_force: float = 25.0

# ============================================================
# 运行时状态
# ============================================================

## 目标位置（世界坐标）
var target_position: Vector2 = Vector2.ZERO
## 阵型偏移（由 rts—node 设置，实现编队展开）
var formation_offset: Vector2 = Vector2.ZERO
## 当前速度向量
var velocity: Vector2 = Vector2.ZERO
## 是否已到达
var is_arrived: bool = false
## 是否锁定移动（到达后锁定）
var is_locked: bool = false

# 到达 hysteresis
var _arrival_lock_timer: float = 0.0
const ARRIVAL_HYSTERESIS_PX: float = 32.0
const ARRIVAL_LOCK_DURATION: float = 0.3

## 父节点引用
var _unit: CharacterBody2D = null
## 卡死计时器
var _stuck_timer: float = 0.0
## 卡死连续采样计数（用于累加扰动方向）
var _stuck_sample_count: int = 0

# 让路节流缓存
var _yield_factor: float = 1.0
var _yield_throttle: int = 0
const YIELD_THROTTLE_INTERVAL: int = 8
const YIELD_VELOCITY_THRESHOLD_SQ: float = 1.0


func _ready() -> void:
	_unit = get_parent() as CharacterBody2D
	if not _unit:
		push_error("UnitController must be child of a CharacterBody2D, got: ", get_parent())
		set_physics_process(false)
		set_process(false)


# ============================================================
# 速度写入（唯一写入点）
# ============================================================

func _apply_velocity() -> void:
	_unit.velocity = velocity


# ============================================================
# 公共接口
# ============================================================

## 设置移动目标
func set_target(pos: Vector2) -> void:
	target_position = pos
	formation_offset = Vector2.ZERO
	is_arrived = false
	is_locked = false
	_arrival_lock_timer = 0.0
	_stuck_timer = 0.0
	_stuck_sample_count = 0


## 获取有效目标位置（目标 + 阵型偏移）
func effective_target() -> Vector2:
	return target_position + formation_offset


## 立即停止
func stop() -> void:
	target_position = _unit.global_position if _unit else Vector2.ZERO
	formation_offset = Vector2.ZERO
	is_arrived = true
	is_locked = true
	velocity = Vector2.ZERO
	_stuck_timer = 0.0
	_stuck_sample_count = 0
	_apply_velocity()


## 锁定移动（到达后调用）
func lock() -> void:
	is_locked = true
	is_arrived = true
	velocity = Vector2.ZERO
	_arrival_lock_timer = ARRIVAL_LOCK_DURATION
	_stuck_timer = 0.0
	_stuck_sample_count = 0
	_apply_velocity()
	arrived.emit()


## 主移动更新
##
## @param target      目标世界坐标
## @param delta       帧时间
## @param flow_field  当前流场（可为 null，将回退到直接指向目标）
## @param all_units   其他单位列表（用于分离计算）
## @return            是否已到达
func move_toward(
	target: Vector2,
	delta: float,
	flow_field: FFGrid,
	all_units: Array
) -> bool:
	if not _unit:
		return true
	target_position = target
	return _process_movement(delta, flow_field, all_units)


## 当前是否已到达
func has_arrived() -> bool:
	return is_arrived


## 是否锁定
func locked() -> bool:
	return is_locked


# ============================================================
# 核心处理
# ============================================================

func _process_movement(delta: float, ff: FFGrid, units: Array) -> bool:
	# 锁定后立即归零
	if is_locked:
		_apply_zero_velocity()
		return true

	var dist: float = _unit.global_position.distance_to(effective_target())

	# ---- 1. 到达检测：进入 stop_radius 立即停止 ----
	if dist <= stop_radius:
		lock()
		return true

	# hysteresis：锁定后至少保持 0.3s，且 > 32px 才解锁
	if is_arrived or _arrival_lock_timer > 0.0:
		_arrival_lock_timer -= delta
		if _arrival_lock_timer > 0.0:
			_apply_zero_velocity()
			return true
		if dist <= ARRIVAL_HYSTERESIS_PX:
			_apply_zero_velocity()
			return true
		is_locked = false

	is_arrived = false

	# ---- 2. 从 FlowField 获取移动方向 ----
	var flow_dir: Vector2 = _sample_flow_field(ff)

	# 流场不可用 → 回退到直接指向目标
	if flow_dir == Vector2.ZERO:
		var raw_dir: Vector2 = effective_target() - _unit.global_position
		if raw_dir.length_squared() < 0.0001:
			_apply_zero_velocity()
			return false
		flow_dir = raw_dir.normalized()

	# ---- 2b. 阵型接近时脱离流场，直接指向各自槽位 ----
	# 让多单位在最后一程自然展开到阵型位置
	if formation_offset.length_squared() > 0.01 and dist <= formation_approach_radius:
		var slot_dir: Vector2 = effective_target() - _unit.global_position
		if slot_dir.length_squared() > 0.0001:
			flow_dir = slot_dir.normalized()

	# ---- 3. Separation Steering 分离力 ----
	var sep_force: Vector2 = Vector2.ZERO
	if separation_strength > 0.0 and not units.is_empty():
		sep_force = SeparationSystem.get_force(
			_unit.global_position,
			units,
			separation_radius,
			separation_strength
		)

	# ---- 4. 方向融合 ----
	var desired_dir: Vector2 = flow_dir + sep_force
	if desired_dir.length_squared() < 0.0001:
		desired_dir = flow_dir
	if desired_dir.length_squared() < 0.0001:
		desired_dir = Vector2.RIGHT  # fallback safe direction
	desired_dir = desired_dir.normalized()

	# ---- 5. 目标速度 ----
	var desired_vel: Vector2 = desired_dir * max_speed

	# ---- 5b. 让路减速（节流：每 8 帧计算一次） ----
	desired_vel *= _compute_yield_factor()

	# ---- 6. 平滑加速 ----
	velocity = velocity.move_toward(desired_vel, acceleration * delta)

	# 速度上限
	if velocity.length_squared() > max_speed * max_speed:
		velocity = velocity.normalized() * max_speed

	# ---- 7. 卡死检测（已到达/锁定状态下禁用） ----
	if not is_arrived and not is_locked:
		_check_stuck(delta, ff, flow_dir)

	_apply_velocity()
	return false


# ============================================================
# 流场采样
# ============================================================

func _sample_flow_field(ff: FFGrid) -> Vector2:
	if not ff or not ff.is_valid():
		return Vector2.ZERO
	return ff.sample(_unit.global_position)


# ============================================================
# 让路避让系统
# ============================================================

## 计算让路因子（0~1）
## 检测移动方向前方是否有静止/低优先级友军，减速让路。
## 节流：每 YIELD_THROTTLE_INTERVAL 帧更新一次。
func _compute_yield_factor() -> float:
	_yield_throttle += 1
	if _yield_throttle % YIELD_THROTTLE_INTERVAL != 0:
		return _yield_factor

	if velocity.length_squared() < YIELD_VELOCITY_THRESHOLD_SQ:
		_yield_factor = 1.0
		return 1.0

	var my_dir: Vector2 = velocity.normalized()
	var factor: float = 1.0
	var all_units: Array = FFManager.get_all_units()

	for other in all_units:
		if other == _unit or not is_instance_valid(other):
			continue

		# 只对同阵营单位让路（不对敌人减速）
		if _is_different_camp(other):
			continue

		var offset: Vector2 = _unit.global_position - other.global_position
		var dist: float = offset.length()
		if dist > yield_radius or dist < 1.0:
			continue

		# 判断是否朝这个单位方向移动
		var to_other_dir: Vector2 = (-offset).normalized()
		var approach: float = my_dir.dot(to_other_dir)
		if approach <= 0.3:
			continue

		# 前方有友军 → 根据状态决定减速程度
		var strength: float = 1.0 - (dist / yield_radius)

		if _is_unit_stationary(other):
			# 静止友军 → 大幅减速，让分离力推开绕行
			factor = min(factor, lerp(1.0, yield_block_factor, strength))
		else:
			var other_vel: Vector2 = other.velocity if "velocity" in other else Vector2.ZERO
			if other_vel.length_squared() < YIELD_VELOCITY_THRESHOLD_SQ:
				# 对方也基本静止
				factor = min(factor, lerp(1.0, yield_pass_factor, strength))
			else:
				# 双方都在移动 → 高优先级者优先通行
				var from_other_dir: Vector2 = offset.normalized()
				var other_approach: float = other_vel.normalized().dot(from_other_dir)
				if other_approach > 0.3:
					var other_priority: int = other.get("move_priority") if "move_priority" in other else 0
					if other_priority > move_priority:
						factor = min(factor, lerp(1.0, yield_pass_factor, strength))

	_yield_factor = clampf(factor, 0.0, 1.0)
	return _yield_factor


## 判断目标是否为不同阵营（不对敌人让路）
func _is_different_camp(other: Node2D) -> bool:
	if not _unit.has_method("获取阵营") or not other.has_method("获取阵营"):
		return false
	return _unit.获取阵营() != other.获取阵营()


## 判断一个节点是否为静止单位
static func _is_unit_stationary(node: Node2D) -> bool:
	if "velocity" in node:
		return node.velocity.length_squared() < 4.0
	return true


# ============================================================
# 卡死检测与解卡
# ============================================================

func _check_stuck(delta: float, ff: FFGrid, original_flow_dir: Vector2) -> void:
	var speed: float = velocity.length()

	if speed < stuck_threshold:
		_stuck_timer += delta
		# 判断是否到达卡死超时
		if _stuck_timer >= stuck_timeout:
			_stuck_sample_count += 1

			# 重新采样 FlowField（单位可能已移动到隔壁格子）
			var fresh_dir: Vector2 = _sample_flow_field(ff)
			if fresh_dir == Vector2.ZERO:
				fresh_dir = original_flow_dir

			# 添加随机扰动打破平衡
			var perturbation: Vector2 = Vector2(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			)
			if perturbation.length_squared() > 0.0001:
				perturbation = perturbation.normalized() * unstick_force

			# 扰动 + 流场方向融合
			var recovery: Vector2 = fresh_dir * max_speed * 0.5 + perturbation
			if recovery.length_squared() > 0.0001:
				velocity = recovery

			_stuck_timer = 0.0
	else:
		# 正常移动 → 递减卡死计时（防瞬间重触发）
		_stuck_timer = maxf(_stuck_timer - delta * 2.0, 0.0)
		_stuck_sample_count = 0


# ============================================================
# 辅助
# ============================================================

func _apply_zero_velocity() -> void:
	velocity = Vector2.ZERO
	_unit.velocity = Vector2.ZERO


# ============================================================
# 重置
# ============================================================

## 完全重置控制器状态（用于单位重用时）
func reset() -> void:
	target_position = Vector2.ZERO
	velocity = Vector2.ZERO
	is_arrived = false
	is_locked = false
	_arrival_lock_timer = 0.0
	_stuck_timer = 0.0
	_stuck_sample_count = 0
	_yield_factor = 1.0
	_yield_throttle = 0
