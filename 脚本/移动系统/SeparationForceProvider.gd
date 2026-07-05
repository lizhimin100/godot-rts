class_name SeparationForceProvider
extends MovementForceProvider

## SeparationForceProvider — 分离建议力提供者（Phase 7）
##
## 迁移自 MovementSolver._构建内联力() 第三阶段（分离力 / AVOIDANCE）。
## 保持与旧逻辑完全一致的数学算法：避障系统.计算让路修正 + 空间哈希邻近查询。
##
## 职责：
##   从 避障系统 读取同阵营推开修正方向，输出 AVOIDANCE 类型建议力。
##   不涉及 velocity 计算。
##
## Provider 上下文依赖：
##   context["unit"]     → Node2D          （查询空间哈希、避障计算必需）
##   context["strategy"] → 移动策略        （计算当前路径方向）
##   context["request"]  → 移动请求        （策略输入参数）
##
## 激活条件：
##   避障系统.实例 有效
##
## 权重：0.4（与旧 Solver 常量 分离力权重 完全一致）
## 优先级：0（与路径力同级别混合）

# ═══════════════════════════════════════════════════════════
# Phase 7.5: Spatial Stability — Contact Recovery + Symmetry
# ═══════════════════════════════════════════════════════════
#
# Per-unit contact state for symmetrical separation repair.
# Replaces the Phase 7.3 per-unit push counter (asymmetric
# per-pair iteration order) with:
#   ① Contact timer — counts consecutive frames stuck + neighbors
#   ② Escape pulse — one-shot push away from centroid
#   ③ Density pressure — gentle outward push from clusters
# ═══════════════════════════════════════════════════════════

class ContactState:
	var contact_frames: int = 0        # consecutive frames in contact + stuck
	var escape_cooldown: int = 0        # frames until next escape allowed
	var last_centroid: Vector2 = Vector2.ZERO
	var last_neighbor_count: int = 0
	var last_density: float = 0.0

const CONTACT_FRAME_THRESHOLD: int = 90   # ~1.5s at 60fps → trigger escape
const ESCAPE_COOLDOWN_FRAMES: int = 120   # ~2.0s between escape pulses
const ESCAPE_STRENGTH: float = 80.0       # px/s per escape
const DENSITY_WEIGHT: float = 0.12        # inverse-distance density → force gain
const SEP_RADIUS: float = 44.0            # matches 避障系统.分离半径

var _contact_states: Dictionary = {}      # Node2D unit → ContactState
var _cleanup_counter: int = 0            # cleanup gate counter


func _init():
	provider_name = "Separation"
	process_priority = 20  # 在队形力（15）之后


## 计算分离建议力
## @param unit     目标单位
## @param context  上下文（至少包含 unit / strategy / request）
## @return         分离/避障建议力（无周围单位时返回零力）
func calculate_force(unit: Node2D, context: Dictionary) -> MovementForce:
	var force = MovementForce.new()
	force.source_name = "Separation"
	force.force_type = MovementForce.ForceType.AVOIDANCE

	# Phase 7.5: Periodic stale state cleanup
	_cleanup_counter += 1
	if _cleanup_counter % 120 == 0:
		_cleanup_stale_states()

	if not is_instance_valid(避障系统.实例):
		return force

	# --- 计算路径方向（与旧 _构建内联力 完全一致的算法）---
	var 路径方向: Vector2 = _计算路径方向(unit, context)

	# --- 获取周围单位（复用空间哈希，与旧 Solver._获取周围单位 相同）---
	var 周围单位: Array[Node2D] = []
	if is_instance_valid(空间哈希网格.实例):
		周围单位 = 空间哈希网格.实例.查询9宫格(unit.global_position)

	# --- 计算避障修正（与旧内联逻辑完全一致）---
	var 分离力向量: Vector2 = 避障系统.实例.计算让路修正(unit, 周围单位, 路径方向)

	# ═══════════════════════════════════════════════════════
	# Phase 7.5: ① Contact state tracking
	# ═══════════════════════════════════════════════════════
	# NOTE: runs BEFORE zero-check so stuck-at-equilibrium
	# units are still tracked and can receive escape pulses.
	var state: ContactState = _get_or_create_contact_state(unit)

	var 周围_for_contact: Array[Node2D] = []
	if is_instance_valid(空间哈希网格.实例):
		周围_for_contact = 空间哈希网格.实例.查询9宫格(unit.global_position)

	var active_neighbors: int = 0
	var centroid: Vector2 = Vector2.ZERO
	var total_weight: float = 0.0
	for other in 周围_for_contact:
		if other == unit or not is_instance_valid(other):
			continue
		var d: float = unit.global_position.distance_to(other.global_position)
		if d < SEP_RADIUS and d > 1.0:
			active_neighbors += 1
			var w: float = 1.0 / maxf(d, 5.0)
			centroid += other.global_position * w
			total_weight += w

	state.last_neighbor_count = active_neighbors

	if active_neighbors > 0 and total_weight > 0.0:
		centroid /= total_weight
		state.last_centroid = centroid
		# Local density: Σ inverse-distance weights
		state.last_density = 0.0
		for other in 周围_for_contact:
			if other == unit or not is_instance_valid(other):
				continue
			var d: float = unit.global_position.distance_to(other.global_position)
			if d < SEP_RADIUS and d > 1.0:
				state.last_density += 1.0 / maxf(d, 5.0)
		# Only advance timer when unit is actually stuck (velocity ~0)
		var vel_sq: float = unit.velocity.length_squared() if "velocity" in unit else 0.0
		if vel_sq < 10.0:
			state.contact_frames += 1
		else:
			state.contact_frames = maxi(0, state.contact_frames - 2)
	else:
		state.contact_frames = maxi(0, state.contact_frames - 3)
		state.last_density = 0.0

	# ⭐ DEBUG: provider output before Phase 7.5
	var _d_avoid_len: float = 分离力向量.length()
	if active_neighbors > 0 and Engine.get_physics_frames() % 60 == 0:
		print("[SDEBUG] %s neighbors=%d raw_avoid=%.2f contact=%d" % [
			unit.name, active_neighbors, _d_avoid_len, state.contact_frames])

	# Phase 7.5 ②③: Escape + Density + Recap (shared by both zero and non-zero paths)
	return _apply_phase7_5(unit, force, state, 分离力向量, active_neighbors)


## 激活条件：避障系统可用时，始终尝试计算分离力
func is_active(unit: Node2D, context: Dictionary) -> bool:
	return is_instance_valid(避障系统.实例)


## 计算当前路径方向
func _计算路径方向(unit: Node2D, context: Dictionary) -> Vector2:
	var strategy = context.get("strategy", null) as 移动策略
	var request = context.get("request", null) as 移动请求
	if strategy == null or request == null:
		return Vector2.ZERO
	var 路径速度: Vector2 = strategy.计算速度(unit, request)
	return 路径速度.normalized() if 路径速度.length_squared() > 0.01 else Vector2.ZERO


# ============================================================
# Phase 7.5: Escape + Density + Recap Helper
# ============================================================

## Apply Phase 7.5 spatial stability adjustments to a separation force.
## Called from calculate_force for both zero and non-zero separation vectors.
##
## Combines: escape pulse + density pressure + re-cap
## Returns the modified MovementForce.
func _apply_phase7_5(unit: Node2D, force: MovementForce, state: ContactState,
					 seperation_vec: Vector2, active_neighbors: int) -> MovementForce:
	force.weight = 0.4
	force.priority = 0
	force.lifetime = -1.0
	force.flags = MovementForce.FLAG_NONE

	# --- ② Escape pulse for sustained contact ---
	var final_push: Vector2 = seperation_vec
	if state.contact_frames > CONTACT_FRAME_THRESHOLD and state.escape_cooldown <= 0:
		state.escape_cooldown = ESCAPE_COOLDOWN_FRAMES
		state.contact_frames = CONTACT_FRAME_THRESHOLD / 2
		if state.last_centroid != Vector2.ZERO:
			var escape_dir: Vector2 = (unit.global_position - state.last_centroid).normalized()
			if escape_dir.length_squared() > 0.5:
				final_push += escape_dir * ESCAPE_STRENGTH

	if state.escape_cooldown > 0:
		state.escape_cooldown -= 1

	# --- ③ Soft density pressure ---
	if state.last_density > 0.0 and state.last_centroid != Vector2.ZERO:
		var density_dir: Vector2 = (unit.global_position - state.last_centroid).normalized()
		if density_dir.length_squared() > 0.5:
			var density_mag: float = minf(state.last_density * DENSITY_WEIGHT, 15.0)
			final_push += density_dir * density_mag

	# --- Re-cap to avoid overpowering path force ---
	var 移动速度: float = unit.移动速度 if "移动速度" in unit else unit.最大速度 if "最大速度" in unit else 200.0
	var max_avoid: float = 移动速度 * 0.35
	if final_push.length_squared() > max_avoid * max_avoid and final_push.length_squared() > 0.0001:
		final_push = final_push.normalized() * max_avoid

	# --- Write back final separation force ---
	if final_push.length_squared() > 0.0001:
		force.direction = final_push.normalized()
		force.strength = final_push.length()
		if force.strength > 1.0 and 调试配置.DEBUG_AVOID:
			print("[SFOUT] %s final_push=%.1f dir=(%.2f,%.2f)" % [
				unit.name, force.strength, force.direction.x, force.direction.y])
	else:
		force.direction = Vector2.ZERO
		force.strength = 0.0

	return force


# ============================================================
# Phase 7.5: Contact State Management
# ============================================================

func _get_or_create_contact_state(unit: Node2D) -> ContactState:
	var state = _contact_states.get(unit) as ContactState
	if state == null:
		state = ContactState.new()
		_contact_states[unit] = state
	return state


func _cleanup_stale_states() -> void:
	var dead: Array = []
	for unit in _contact_states:
		if not is_instance_valid(unit):
			dead.append(unit)
	for unit in dead:
		_contact_states.erase(unit)
