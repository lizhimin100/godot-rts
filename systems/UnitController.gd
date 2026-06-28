class_name UnitController
extends Node

## 单位移动控制器 — 基于 FlowField 的稳定单位移动系统
##
## 职责：
##   1. 从 FlowField 采样获取全局移动方向
##   2. Separation Steering 分离转向（防止单位重叠）
##   3. Arrival Stop：进入 stop_radius 立即停止
##   4. Stuck Detection：velocity 过低超时 → 重新采样 + 扰动解卡
##   5. 禁止物理碰撞驱动行为（separation 纯 Steering，不靠 collision layer）
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
@export var separation_radius: float = 24.0
## 分离排斥强度
@export var separation_strength: float = 4.0

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

## 父节点引用
var _unit: CharacterBody2D = null
## 卡死计时器
var _stuck_timer: float = 0.0
## 卡死连续采样计数（用于累加扰动方向）
var _stuck_sample_count: int = 0


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

	# ---- 5. 目标速度 + 平滑加速 ----
	var desired_vel: Vector2 = desired_dir * max_speed
	velocity = velocity.move_toward(desired_vel, acceleration * delta)

	# 速度上限
	if velocity.length_squared() > max_speed * max_speed:
		velocity = velocity.normalized() * max_speed

	# ---- 6. 卡死检测 ----
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
	_stuck_timer = 0.0
	_stuck_sample_count = 0
