extends Node

## MovementSolver — 唯一 velocity 写入者（Movement 2.0）
##
## 职责：
##   1. 读取已迁移单位的 MovementIntent
##   2. 通过 MovementForceProvider 收集建议力
##   3. 通过 MovementForcePipeline 过滤→修正→融合建议力 ★
##   4. 写入 unit.velocity（★ 唯一写入点）
##   5. 到达检测 + 信号发射
##   6. SLOT_LOCKED 锚点回归
##   7. 卡死检测与解卡
##
## ★ Phase 5 变更：
##   Pipeline 成为 Force 的唯一处理入口。
##   Solver 不直接操作 MovementForce 数组。
##   生命周期（过期/无效/标志）由 Pipeline 统一管理。
##
## Provider 架构（Phase 3+）：
##   路径力由 FlowFieldForceProvider 提供（已 Provider 化）
##   队形力由 FormationForceProvider 提供（Phase 6 已迁移）
##   分离力由 SeparationForceProvider 提供（Phase 7 已迁移）
##   当前唯一剩余内联力：路径力（策略方向 × 速度，待评估是否需 Provider 化）
##
## 与旧系统关系：
##   - 仅处理 _using_movement_solver == true 的单位
##   - 运动服务 的 gate 会跳过这些单位
##   - 空间哈希复用 运动服务 已重建的数据
##
## 处理顺序（本帧内）：
##   priority -100: 运动服务（跳过已迁移单位）
##   priority  -1: 单元状态机（写入 MovementIntent）
##   priority   0: MovementSolver（读取意图 → 写 velocity）【本系统】
##   priority   0: UnitBase（scene node, 在 autoload 之后 → move_and_slide()）

signal 移动完成(单位: Node2D, 结果: 移动结果)
signal 单位卡死(单位: Node2D)

static var 实例: Node = null


# ============================================================
# SLOT_LOCKED 状态（与 运动服务.MoveSlotState 保持一致）
# ============================================================

const SLOT_NONE: int = -1
const MOVING_TO_SLOT: int = 0
const SLOT_LOCKED: int = 1


# ============================================================
# Provider 脚本路径注册表
# ============================================================
# 内置 Provider 路径列表。Solver 在 _ready() 时按路径加载。
# 新增内置 Provider → 在数组中追加一行路径字符串。
# 外部 Provider 可通过 MovementSolver.注册Provider() 静态 API 注册，
# 无需修改本文件。
# ============================================================
const _PROVIDER_PATHS: Array[String] = [
	"res://脚本/移动系统/FlowFieldForceProvider.gd",
	"res://脚本/移动系统/FormationForceProvider.gd",
	"res://脚本/移动系统/SeparationForceProvider.gd",
]


# ============================================================
# 卡死参数（与 运动服务 一致）
# ============================================================

const 最大卡死放弃: int = 3
const 卡死速度阈值: float = 2.0
const 卡死超时: float = 0.5

# ============================================================
# Phase 7.5: Geometric Separation Constraint
# ============================================================
# Final-stage correction before velocity write.
# Resolves collider edge resting that steering cannot.
# ============================================================
const _GEOM_PUSH_STRENGTH: float = 35.0    # push impulse (px/s)
const _GEOM_MIN_DIST: float = 44.0         # trigger distance (matches SEP_RADIUS)
const _GEOM_COOLDOWN_FRAMES: int = 15      # per-pair cooldown frames (~0.25s @60fps)

# ============================================================
# Phase 7.6: Pair-based Stabilizer (replaces Phase 7.5)
# ============================================================
# Per-pair, symmetric, continuous velocity correction.
# Resolves overlap that steering cannot, without cooldown impulses.
# Applied as final velocity delta at write point.
# ============================================================
const _STABILIZER_STRENGTH: float = 4.0         # push per pixel of overlap
const _STABILIZER_PADDING: float = 6.0          # extra clearance beyond collision radius
const _STABILIZER_CLAMP: float = 120.0           # max correction per unit per frame (px/s)
const _STABILIZER_MAX_RATIO: float = 0.30       # [Step 2] max correction = move_speed * this ratio
const _HEAD_ON_DOT: float = -0.6                # dot(dir_a, dir_b) below this = head-on
const _HEAD_ON_BIAS: float = 3.0                # lateral bias strength per overlap
const _ARRIVAL_SUPPRESSION: float = 0.2          # correction multiplier near target
const _ARRIVAL_SPEED_THRESHOLD: float = 15.0    # below this speed, zero correction at target
const _ARRIVAL_DIST_FACTOR: float = 2.0         # stop_distance × factor = arrival range
const _DEFAULT_COLLISION_RADIUS: float = 24.0   # fallback when no 碰撞半径 found

# ============================================================
# 每个单位的状态数据
# ============================================================

class SolverUnitData:
	# 策略
	var 策略: 移动策略 = null
	var 上次意图类型: int = MovementIntent.IntentType.NONE

	# 位置追踪
	var 上次位置: Vector2 = Vector2.ZERO

	# ⭐ Slot 状态
	var slot_state: int = SLOT_NONE
	var anchor_position: Vector2 = Vector2.ZERO

	# ⭐ 到达标记
	var 已到达: bool = false

	# 卡死检测
	var 卡死计时: float = 0.0
	var 卡死计数: int = 0
	var 回退计时: float = 0.0
	var 回退中: bool = false

	# Phase 7.4: Direction continuity smoothing
	# Stores previous frame direction to prevent frame-to-frame flip
	var last_dir: Vector2 = Vector2.ZERO

	# Phase 7.5: Geometric separation constraint
	# Tracks per-neighbor distance for penetration-direction detection
	var last_neighbor_dist: Dictionary = {}  # int instance_id -> float distance

# ============================================================
# 运行时状态
# ============================================================

var _单位数据: Dictionary = {}  # Unit → SolverUnitData

# Phase 7.5: Geometric per-pair cooldown
# key = "smaller_id|larger_id", value = physics_frame + COOLDOWN_FRAMES
var _geom_pair_frame: Dictionary = {}  # "id|id" -> int (expire frame)

# Phase 7.6: Per-frame pair stabilizer state
# Cleared and rebuilt every physics frame in _compute_pair_stabilizer()
var _pair_corrections: Dictionary = {}  # int instance_id -> Vector2
var _id_to_unit: Dictionary = {}        # int instance_id -> Node2D (reverse lookup)

# Phase 7.6 Step 1: Ratio diagnostic accumulators (reset per frame)
var _dbg_goal_speed_sum: float = 0.0
var _dbg_corr_mag_sum: float = 0.0
var _dbg_max_ratio: float = 0.0
var _dbg_dominated: int = 0
var _dbg_reversed: int = 0
var _dbg_unit_count: int = 0

# ============================================================
# Force Provider 系统（Phase 3）
# ============================================================

## 注册的 Force Provider 列表
var _providers: Array[MovementForceProvider] = []

## 待注册的 Provider 静态队列（外部通过 注册Provider() 添加）
static var _待注册Provider: Array[MovementForceProvider] = []

## ⭐ Force Pipeline 实例（Phase 5 — 建议力生命周期流水线）
var _force_pipeline: MovementForcePipeline = null

## 当前帧收集的所有建议力（仅调试用）
var _当前帧力: Array[MovementForce] = []


# ============================================================
# 生命周期
# ============================================================

func _enter_tree() -> void:
	实例 = self
	process_priority = 0

func _exit_tree() -> void:
	if 实例 == self:
		实例 = null


func _ready() -> void:
	set_physics_process(true)

	# ⭐ 初始化 Force Pipeline（Phase 5 — 建议力生命周期流水线）
	_force_pipeline = MovementForcePipeline.new()

	# ⭐ 注册 Force Provider（从静态待注册队列迁移）
	_注册所有Provider()


func _注册所有Provider() -> void:
	# ① 按路径加载内置 Provider
	for path in _PROVIDER_PATHS:
		var script = load(path)
		if script == null or not script.can_instantiate():
			continue
		var instance = script.new()
		if instance is MovementForceProvider:
			_providers.append(instance)

	# ② 静态注册队列（外部通过 注册Provider() 添加）
	for p in _待注册Provider:
		if p != null:
			_providers.append(p)
	_待注册Provider.clear()


## 静态注册 Provider（外部调用，无需修改本文件）
## @param provider 已实例化的 MovementForceProvider 实例
static func 注册Provider(provider: MovementForceProvider) -> void:
	_待注册Provider.append(provider)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(单位管理器.实例):
		return

	# ⭐ Phase 7.6: Pre-compute pair stabilizer corrections for all active units
	_compute_pair_stabilizer()

	for unit in 单位管理器.获取所有单位():
		if not is_instance_valid(unit):
			continue
		# ⭐ 只处理已迁移单位
		if not ("_using_movement_solver" in unit) or not unit._using_movement_solver:
			continue
		if not ("移动意图" in unit) or unit.移动意图 == null or not unit.移动意图.is_valid():
			continue

		_解析单位(unit, delta)

	# ⭐ Phase 7.6: Apply pair corrections post-loop (includes SLOT_LOCKED units)
	_apply_pair_corrections()

	# ═══════════════════════════════════════════════════════════
	# Phase 7.6 Step 1: Ratio diagnostic (30-frame aggregate)
	# ═══════════════════════════════════════════════════════════
	if Engine.get_physics_frames() % 30 == 0 and _dbg_unit_count > 0:
		var avg_goal: float = _dbg_goal_speed_sum / _dbg_unit_count
		var avg_corr: float = _dbg_corr_mag_sum / _dbg_unit_count
		var avg_ratio: float = _dbg_corr_mag_sum / maxf(_dbg_goal_speed_sum, 0.001)
		print("[RATIO] frame=%d N=%d goal=%.1f corr=%.1f ratio=%.2f max_r=%.2f dominated=%d opp=%d" % [
			Engine.get_physics_frames(), _dbg_unit_count,
			avg_goal, avg_corr, avg_ratio,
			_dbg_max_ratio, _dbg_dominated, _dbg_reversed])

	# 清理无效单位
	_清理死单位()


# ============================================================
# 外部接口
# ============================================================

## 强制停止单位移动（供 UnitBase.立即停止 调用）
func 强制停止(单位: Node2D, 原因: int = 移动结果.结果类型.被中断) -> void:
	if not is_instance_valid(单位):
		_单位数据.erase(单位)
		return

	var data = _单位数据.get(单位)
	# SLOT_LOCKED：保留在追踪中，仅停止速度
	if data and data.slot_state == SLOT_LOCKED:
		单位.velocity = Vector2.ZERO
		_发送结果(单位, 原因)
		return

	_单位数据.erase(单位)
	单位.velocity = Vector2.ZERO
	_发送结果(单位, 原因)


## 检查单位是否在移动中
func 是否在移动(单位: Node2D) -> bool:
	return 单位 in _单位数据


## 检查单位是否处于 SLOT_LOCKED 状态
func 是否是槽锁定(单位: Node2D) -> bool:
	var data = _单位数据.get(单位)
	return data != null and data.slot_state == SLOT_LOCKED


# ============================================================
# 核心：解析单个单位的 MovementIntent
# ============================================================

func _解析单位(unit: Node2D, delta: float) -> void:
	var intent: MovementIntent = unit.移动意图
	if not intent or not intent.is_valid():
		return

	# --- 获取/创建单位状态数据 ---
	var data = _单位数据.get(unit)
	if not data:
		data = SolverUnitData.new()
		_单位数据[unit] = data
		data.上次意图类型 = intent.type
		data.策略 = _构建策略(intent)
		data.上次位置 = unit.global_position

	# --- 意图类型变更 → 重建策略 ---
	if intent.type != data.上次意图类型:
		data.策略 = _构建策略(intent)
		data.上次意图类型 = intent.type
		data.已到达 = false
		data.slot_state = SLOT_NONE
		data.卡死计时 = 0.0
		data.卡死计数 = 0
		data.回退中 = false
		data.已到达 = false

	# 转换为移动请求（供策略 API 使用）
	var 请求: 移动请求 = _意图转请求(unit, intent)
	if not 请求:
		return

	# ============================================================
	# ⭐ SLOT_LOCKED：仅 anchor return + 强制 idle 动画
	# ============================================================
	if data.slot_state == SLOT_LOCKED:
		var dist_to_anchor = unit.global_position.distance_to(data.anchor_position)
		if dist_to_anchor > 2.0:
			var return_dir = (data.anchor_position - unit.global_position).normalized()
			var 最大速度: float = unit.最大速度 if "最大速度" in unit else 350.0
			var return_speed = minf(dist_to_anchor * 0.5, 最大速度 * 0.25)
			unit.velocity = return_dir * return_speed
		else:
			unit.velocity = Vector2.ZERO

		# 强制 idle 动画
		if unit.has_method("_切换动画"):
			unit._切换动画("待机")
		return

	# ── 已到达 → 保持静止，从系统退出 ──
	if data.已到达:
		unit.velocity = Vector2.ZERO
		_单位数据.erase(unit)
		return

	# ── 到达检测 ──
	if data.策略.是否已到达(unit, 请求):
		if data.slot_state == MOVING_TO_SLOT:
			# 队形单位到达 → SLOT_LOCKED（不移除，继续跟踪）
			data.slot_state = SLOT_LOCKED
			var slot_target = 请求.目标位置 + 请求.队形偏移
			if 队形系统.实例 and 队形系统.实例.是否在队形中(unit):
				slot_target = 队形系统.实例.获取单位目标(unit)
			data.anchor_position = slot_target
			unit.velocity = Vector2.ZERO
			_发送结果(unit, 移动结果.结果类型.已到达)
			if unit.has_method("_切换动画"):
				unit._切换动画("待机")
			return
		else:
			# 非队形单位到达 → 正常移除
			data.已到达 = true
			unit.velocity = Vector2.ZERO
			_发送结果(unit, 移动结果.结果类型.已到达)
			if unit.has_method("_切换动画"):
				unit._切换动画("待机")
			return

	# ============================================================
	# ⭐ 收集所有建议力（Provider + 内联）
	# ============================================================

	var provider_forces = _收集Provider力(unit, data, intent, 请求)
	var inline_forces = _构建内联力(unit, data, intent, 请求)
	var all_forces = provider_forces + inline_forces
	_当前帧力 = all_forces

	# ============================================================
	# ⭐ 融合 — MovementForceFusion（Phase 4）
	# ============================================================
	# Solver 不再包含具体融合规则。
	# 所有 weight × priority × strength 规则集中在 Fusion 层。
	# 此处只做：收集 → 融合 → velocity（唯一写入点）
	# ============================================================

	var 最大速度: float = unit.最大速度 if "最大速度" in unit else 350.0
	var fusion_result = _force_pipeline.process(all_forces, delta, 最大速度)
	var 最终速度 = fusion_result.direction * fusion_result.strength


	if _检测卡死(unit, data, 最终速度, delta):
		# 回退阶段：反向移动 0.3 秒
		if not data.回退中:
			data.回退计时 = 0.0
		data.回退计时 += delta
		data.回退中 = true

		if data.回退计时 < 0.3:
			var 后退方向 = (data.上次位置 - unit.global_position).normalized()
			if 后退方向 == Vector2.ZERO:
				后退方向 = Vector2(0, 1)
			最终速度 = 后退方向 * (最大速度 * 0.5)
		else:
			data.回退中 = false
			data.卡死计数 += 1

			if data.卡死计数 >= 最大卡死放弃:
				_单位数据.erase(unit)
				unit.velocity = Vector2.ZERO
				_发送结果(unit, 移动结果.结果类型.卡死)
				if unit.has_method("_切换动画"):
					unit._切换动画("待机")
				return

			if is_instance_valid(流场管理器.实例):
				流场管理器.实例.标记障碍变更()
	else:
		if data.回退中:
			data.回退中 = false
		data.卡死计数 = 0
		data.卡死计时 = 0.0

		# Phase 7.5 disabled — replaced by Phase 7.6 pair stabilizer below
		# 最终速度 = _apply_geometric_constraint(unit, data, 最终速度)

		# ★ 写入 velocity（唯一写入点）
		unit.velocity = 最终速度


# ============================================================
# Phase 7.5: Geometric Separation Constraint
# ============================================================
#
# Lightweight spatial decoupling executed just before velocity write.
# Not a force/steering model - operates at the geometric overlap level.
#
# Triggers when:
#   1. Two units are within _GEOM_MIN_DIST
#   2. Distance is still decreasing (penetration deepening)
#   3. The pair is not on cooldown (prevents oscillation)
#
# Effect:
#   velocity += (pos - neighbor_pos).normalize() * _GEOM_PUSH_STRENGTH
#
# Cooldown:
#   Uses absolute physics frame number to avoid double-decrement
#   when both units in a pair check each other in the same frame.
# ============================================================

## Apply geometric separation constraint.
## Returns velocity with corrective impulse if units overlap.
func _apply_geometric_constraint(unit: Node2D, data: SolverUnitData, velocity: Vector2) -> Vector2:
	if not is_instance_valid(空间哈希网格.实例):
		return velocity

	var nearby: Array[Node2D] = 空间哈希网格.实例.查询9宫格(unit.global_position)
	var result: Vector2 = velocity

	for other in nearby:
		if other == unit or not is_instance_valid(other):
			continue
		if not ("_using_movement_solver" in other) or not other._using_movement_solver:
			continue

		var dist: float = unit.global_position.distance_to(other.global_position)
		if dist >= _GEOM_MIN_DIST or dist < 0.1:
			continue

		# Cooldown check - absolute frame, immune to double-decrement
		var pair_key: String = _geom_pair_key(unit, other)
		if Engine.get_physics_frames() < _geom_pair_frame.get(pair_key, 0):
			continue

		# Penetration direction: only push when still approaching
		var other_id: int = other.get_instance_id()
		var prev_dist: float = data.last_neighbor_dist.get(other_id, dist)
		data.last_neighbor_dist[other_id] = dist
		if prev_dist < dist and prev_dist > 0.0:
			continue  # moving apart, no push needed

		# Apply corrective impulse
		var push_dir: Vector2 = (unit.global_position - other.global_position).normalized()
		result += push_dir * _GEOM_PUSH_STRENGTH

		# Set per-pair cooldown
		_geom_pair_frame[pair_key] = Engine.get_physics_frames() + _GEOM_COOLDOWN_FRAMES

	return result


## Generate deterministic pair key (sorted instance IDs)
func _geom_pair_key(a: Node2D, b: Node2D) -> String:
	var id_a: int = a.get_instance_id()
	var id_b: int = b.get_instance_id()
	return str(mini(id_a, id_b)) + "|" + str(maxi(id_a, id_b))


# ============================================================
# Phase 7.6: Pair-based Stabilizer
# ============================================================
#
# Lightweight per-pair overlap resolution executed as a pre-pass
# before the main unit loop.  Computes symmetric velocity corrections
# for all overlapping pairs, then applies them at velocity write.
#
# Key properties:
#   - Each pair processed once per frame (sorted instance ID key)
#   - Correction is symmetric (50/50 split between units)
#   - No cooldown — continuous small corrections every frame
#   - No impulse — correction is a velocity delta, not a position delta
#   - Head-on lateral bias uses deterministic side (no jitter)
#   - Arrival suppression prevents slot jitter for parked units
# ============================================================


## Pre-compute pair stabilizer corrections for all active solver units.
## Runs once per physics frame before the main _解析单位 loop.
func _compute_pair_stabilizer() -> void:
	# Reset per-frame state
	_pair_corrections.clear()
	_id_to_unit.clear()

	# Collect all active solver units + their intent directions
	var units: Array[Node2D] = []
	var intent_dirs: Dictionary = {}  # int instance_id -> Vector2

	for unit in 单位管理器.获取所有单位():
		if not is_instance_valid(unit):
			continue
		if not ("_using_movement_solver" in unit) or not unit._using_movement_solver:
			continue
		if not ("移动意图" in unit) or unit.移动意图 == null or not unit.移动意图.is_valid():
			continue
		units.append(unit)
		var id: int = unit.get_instance_id()
		_id_to_unit[id] = unit
		intent_dirs[id] = _get_intent_direction(unit)

	if units.size() < 2:
		return

	# Process all unique pairs (i < j ensures each pair once)
	var processed: Dictionary = {}  # "id|id" -> true

	for i in range(units.size()):
		var a: Node2D = units[i]
		var id_a: int = a.get_instance_id()
		var radius_a: float = _get_collision_radius(a)
		var dir_a: Vector2 = intent_dirs.get(id_a, Vector2.ZERO)

		for j in range(i + 1, units.size()):
			var b: Node2D = units[j]
			var id_b: int = b.get_instance_id()

			var pair_key: String = _geom_pair_key(a, b)
			if processed.has(pair_key):
				continue
			processed[pair_key] = true

			var delta_vec: Vector2 = a.global_position - b.global_position
			var dist: float = delta_vec.length()
			var radius_b: float = _get_collision_radius(b)
			var desired_dist: float = radius_a + radius_b + _STABILIZER_PADDING

			if dist >= desired_dist:
				continue

			var overlap: float = desired_dist - dist
			var normal: Vector2 = delta_vec / maxf(dist, 0.001)
			var correction: Vector2 = normal * overlap * _STABILIZER_STRENGTH


			# ── Head-on lateral bias ──
			# Both units moving toward each other → add deterministic
			# sideways nudge so they can pass instead of deadlocking.
			var dir_b: Vector2 = intent_dirs.get(id_b, Vector2.ZERO)
			if dir_a.length_squared() > 0.01 and dir_b.length_squared() > 0.01:
				var ndir_a: Vector2 = dir_a.normalized()
				var ndir_b: Vector2 = dir_b.normalized()
				if ndir_a.dot(ndir_b) < _HEAD_ON_DOT:
					# Deterministic side derived from sorted pair IDs
					var side: Vector2 = Vector2(-normal.y, normal.x)
					if (id_a ^ id_b) & 1:
						side = -side
					correction += side * overlap * _HEAD_ON_BIAS

			# ── Split symmetrically ──
			var corr_a: Vector2 = correction * 0.5
			var corr_b: Vector2 = -correction * 0.5

			# ── Arrival suppression (per-unit) ──
			if _is_near_arrival(a):
				if a.velocity.length() < _ARRIVAL_SPEED_THRESHOLD:
					corr_a = Vector2.ZERO
				else:
					corr_a *= _ARRIVAL_SUPPRESSION

			if _is_near_arrival(b):
				if b.velocity.length() < _ARRIVAL_SPEED_THRESHOLD:
					corr_b = Vector2.ZERO
				else:
					corr_b *= _ARRIVAL_SUPPRESSION

			# ── Per-unit clamp ──
			if corr_a.length_squared() > _STABILIZER_CLAMP * _STABILIZER_CLAMP:
				corr_a = corr_a.normalized() * _STABILIZER_CLAMP
			if corr_b.length_squared() > _STABILIZER_CLAMP * _STABILIZER_CLAMP:
				corr_b = corr_b.normalized() * _STABILIZER_CLAMP

			# ── Accumulate ──
			if not _pair_corrections.has(id_a):
				_pair_corrections[id_a] = Vector2.ZERO
			if not _pair_corrections.has(id_b):
				_pair_corrections[id_b] = Vector2.ZERO

			_pair_corrections[id_a] += corr_a
			_pair_corrections[id_b] += corr_b

func _apply_pair_corrections() -> void:
	# Reset per-frame diagnostic accumulators
	_dbg_goal_speed_sum = 0.0
	_dbg_corr_mag_sum = 0.0
	_dbg_max_ratio = 0.0
	_dbg_dominated = 0
	_dbg_reversed = 0
	_dbg_unit_count = 0

	for id in _pair_corrections:
		var corr: Vector2 = _pair_corrections[id]
		if corr.length_squared() <= 0.001:
			continue
		var unit: Node2D = _id_to_unit.get(id) as Node2D
		if not is_instance_valid(unit) or not ("velocity" in unit):
			continue
		# Skip units that arrived and were removed from tracking
		if not _单位数据.has(unit):
			continue
		# Skip SLOT_LOCKED units (they hold position via anchor return)
		if 是否是槽锁定(unit):
			continue

		# Step 1: Capture pre-correction velocity and accumulate stats
		var pre_vel: Vector2 = unit.velocity
		var goal_spd: float = pre_vel.length()
		var corr_mag: float = corr.length()

		_dbg_unit_count += 1
		_dbg_goal_speed_sum += goal_spd
		_dbg_corr_mag_sum += corr_mag

		var ratio: float = corr_mag / maxf(goal_spd, 0.001)
		if ratio > _dbg_max_ratio:
			_dbg_max_ratio = ratio
		if corr_mag >= goal_spd and goal_spd > 0.001:
			_dbg_dominated += 1
		# Reversed: correction pushes opposite to goal direction
		if goal_spd > 0.001 and corr.dot(pre_vel / goal_spd) < -0.5 * corr_mag:
			_dbg_reversed += 1

		# Step 2: Speed-proportional clamp (max = move_speed * ratio)
		var move_spd: float = unit.移动速度 if "移动速度" in unit else unit.最大速度 if "最大速度" in unit else 200.0
		var max_corr: float = move_spd * _STABILIZER_MAX_RATIO
		if corr_mag > max_corr:
			corr = corr / corr_mag * max_corr
			corr_mag = max_corr
		unit.velocity += corr

	# [DIAG] Per-frame pair correction status (every 60 frames)
	if Engine.get_physics_frames() % 60 == 0:
		print("[PCDBG] pc_size=%d tracked=%d applied=%d" % [_pair_corrections.size(), _单位数据.size(), _dbg_unit_count])

func _get_intent_direction(unit: Node2D) -> Vector2:
	var intent: MovementIntent = unit.移动意图
	if not intent or not intent.is_valid():
		return Vector2.ZERO

	match intent.type:
		MovementIntent.IntentType.MOVE_TO, MovementIntent.IntentType.ATTACK_MOVE:
			return (intent.target_position - unit.global_position).normalized()
		MovementIntent.IntentType.PURSUE:
			if is_instance_valid(intent.target_unit):
				return (intent.target_unit.global_position - unit.global_position).normalized()
		MovementIntent.IntentType.SKILL_DRIVEN:
			return (intent.target_position - unit.global_position).normalized()
	return Vector2.ZERO


## Check if unit is near its arrival point.
## Used by arrival suppression to reduce pair correction strength.
func _is_near_arrival(unit: Node2D) -> bool:
	# SLOT_LOCKED or already arrived → fully suppressed
	var data = _单位数据.get(unit)
	if data:
		if data.slot_state == SLOT_LOCKED:
			return true
		if data.已到达:
			return true

	# Distance-based check against intent target
	var intent: MovementIntent = unit.移动意图
	if not intent or not intent.is_valid():
		return true
	var stop_dist: float = maxf(intent.stop_distance, 20.0)
	var dist_to_target: float = unit.global_position.distance_to(intent.target_position)
	return dist_to_target < stop_dist * _ARRIVAL_DIST_FACTOR


## Get collision radius for a unit, with sensible fallback.
func _get_collision_radius(unit: Node2D) -> float:
	if "碰撞半径" in unit:
		var r = unit.碰撞半径
		if typeof(r) == TYPE_FLOAT:
			return r
	# Read from CollisionShape2D child if accessible
	if unit.has_node("碰撞"):
		var shape_node = unit.get_node("碰撞")
		if shape_node and shape_node.shape and "radius" in shape_node.shape:
			return shape_node.shape.radius
	return _DEFAULT_COLLISION_RADIUS



# ============================================================
# 工具方法
# ============================================================

## 意图 → 移动请求 转换（复用现有策略 API）
func _意图转请求(unit: Node2D, intent: MovementIntent) -> 移动请求:
	var 请求 = 移动请求.new()

	match intent.type:
		MovementIntent.IntentType.MOVE_TO:
			请求.类型 = 移动请求.移动类型.前往位置
			请求.目标位置 = intent.target_position

		MovementIntent.IntentType.PURSUE:
			请求.类型 = 移动请求.移动类型.追击敌人
			请求.目标实体 = intent.target_unit
			请求.追击上限 = intent.pursue_max_range

		MovementIntent.IntentType.ATTACK_MOVE:
			请求.类型 = 移动请求.移动类型.移动攻击
			请求.目标位置 = intent.target_position

		MovementIntent.IntentType.SKILL_DRIVEN:
			请求.类型 = 移动请求.移动类型.技能驱动
			请求.目标位置 = intent.target_position
			请求.额外数据 = intent.extra_data

		_:
			return null

	请求.停止距离 = intent.stop_distance
	请求.队形偏移 = intent.formation_offset
	请求.队形槽位 = intent.formation_slot

	return 请求


## 构建移动策略（与 运动服务._构建策略 一致）
func _构建策略(intent: MovementIntent) -> 移动策略:
	match intent.type:
		MovementIntent.IntentType.MOVE_TO:
			return 前往位置移动.new()
		MovementIntent.IntentType.PURSUE:
			return 追击目标移动.new()
		MovementIntent.IntentType.ATTACK_MOVE:
			return 移动攻击移动.new()
		MovementIntent.IntentType.SKILL_DRIVEN:
			return 技能驱动移动.new()
		_:
			return 前往位置移动.new()


# ============================================================
# 内联建议力构建（Phase 7 — 分离力已迁移至 SeparationForceProvider）
# ============================================================
#
# 当前仍以内联形式计算的力：
#   ① 路径力（策略方向 × 速度）
#
# 已 Provider 化：
#   ② 队形力 → FormationForceProvider
#   ③ 分离力 → SeparationForceProvider
#
# 每个力被包装为 MovementForce，通过 Fusion.solve() 统一融合。
#
# ============================================================

## 构建内联建议力（尚未 Provider 化的力）
## @param unit    目标单位
## @param data    单位状态数据
## @param intent  当前 MovementIntent
## @param 请求    转换后的移动请求
## @return        建议力数组
func _构建内联力(unit: Node2D, data: SolverUnitData, intent: MovementIntent,
				 请求: 移动请求) -> Array[MovementForce]:
	var forces: Array[MovementForce] = []

	# ① 路径力 — 策略计算的速度（主驱动力）
	var 路径速度 = data.策略.计算速度(unit, 请求)
	var 路径方向 = 路径速度.normalized() if 路径速度.length_squared() > 0.01 else Vector2.ZERO

	if 路径方向 != Vector2.ZERO:
		var pf = MovementForce.new()
		pf.source_name = "Path"
		pf.force_type = MovementForce.ForceType.GOAL
		# Phase 7.4: Direction continuity smoothing
		# Blend with last frame direction to prevent frame-to-frame flip
		if data.last_dir != Vector2.ZERO and 路径方向 != Vector2.ZERO:
			路径方向 = 路径方向.lerp(data.last_dir, 0.3).normalized()
		data.last_dir = 路径方向

		pf.direction = 路径方向
		pf.strength = 路径速度.length()
		pf.weight = 1.0
		pf.priority = 0
		forces.append(pf)

	return forces


# ============================================================
# Force Provider 接口（Phase 3）
# ============================================================

## 收集所有 Provider 的建议力
## @param unit    目标单位
## @param data    单位状态数据
## @param intent  当前 MovementIntent
## @param 请求    转换后的移动请求
## @return        建议力数组（空表示无 Provider 激活）
func _收集Provider力(unit: Node2D, data: SolverUnitData, intent: MovementIntent,
					请求: 移动请求) -> Array[MovementForce]:
	var forces: Array[MovementForce] = []

	# 构建 Provider context
	var context: Dictionary = _构建Provider上下文(unit, data, intent, 请求)

	for provider in _providers:
		if not provider.is_active(unit, context):
			continue
		var force = provider.calculate_force(unit, context)
		if force and not force.is_zero():
			forces.append(force)

	return forces


## 构建 Provider 上下文字典
## 传入所有 Provider 可能需要的环境信息
func _构建Provider上下文(unit: Node2D, data: SolverUnitData,
						intent: MovementIntent, 请求: 移动请求) -> Dictionary:
	var ctx: Dictionary = {}
	ctx["unit"] = unit
	ctx["intent"] = intent
	ctx["request"] = 请求
	ctx["strategy"] = data.策略

	# 流场目标（供 FlowFieldForceProvider 使用）
	if data.策略:
		ctx["flow_field_target"] = data.策略.获取流场目标(请求, unit)

	# Slot 状态
	ctx["slot_state"] = data.slot_state
	ctx["anchor_position"] = data.anchor_position

	return ctx


## 发送移动完成结果（与 运动服务._发送结果 一致）
func _发送结果(单位: Node2D, 原因: int) -> void:
	if not is_instance_valid(单位):
		return

	var 最终原因 = 原因
	if 原因 == 移动结果.结果类型.被中断:
		# 追击目标丢失 → 用目标丢失类型
		var data = _单位数据.get(单位)
		if data and data.上次意图类型 == MovementIntent.IntentType.PURSUE:
			if not is_instance_valid(单位.攻击目标 if "攻击目标" in 单位 else null):
				最终原因 = 移动结果.结果类型.目标丢失

	var 结果 = 移动结果.new()
	结果.结果 = 最终原因
	移动完成.emit(单位, 结果)


## 卡死检测（与 运动服务._检测卡死 一致）
func _检测卡死(unit: Node2D, data: SolverUnitData, 期望速度: Vector2, delta: float) -> bool:
	var 期望 = 期望速度.length()
	var 实际 = unit.velocity.length()

	if 期望 < 卡死速度阈值:
		data.卡死计时 = 0.0
		return false

	if 实际 < 卡死速度阈值:
		data.卡死计时 += delta
		if data.卡死计时 >= 卡死超时:
			data.卡死计时 = 0.0
			return true
	else:
		data.卡死计时 = 0.0

	return false


## 清理无效/已释放的单位
func _清理死单位() -> void:
	var 待移除: Array = []
	for unit in _单位数据.keys():
		if not is_instance_valid(unit):
			待移除.append(unit)
	for unit in 待移除:
		_单位数据.erase(unit)
