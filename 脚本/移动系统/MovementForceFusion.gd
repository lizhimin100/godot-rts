class_name MovementForceFusion
extends RefCounted

## MovementForceFusion — 建议力融合层（Phase 4）
##
## 职责：
##   接收 Array<MovementForce>
##   按 weight × priority × strength 规则融合
##   输出最终 desired_direction 和 strength
##
## 不是 Provider — 不产出力。
## 不是 Solver — 不写 velocity。
## 职责唯一：融合。
##
## 融合规则（同 priority）：
##   result = Σ(direction × strength × weight)
##
## 优先级规则（不同 priority）：
##   高 priority 覆盖低 priority
##   （避免低优先级力在高优先级紧急力生效时产生干扰）
##
## 默认权重（由各 Provider 和内联构建方在 MovementForce.weight 中设定，
##             不在本层写死）：
##   路径力   = 1.0（全权重，主驱动力）
##   队形修正 = 0.6（辅助修正）
##   分离避障 = 0.4（弱推开）
##   槽位回归 = 1.0（精确归位）
##   卡死恢复 = 1.0（脱困优先）


## 融合结果数据结构
class FusionResult:
	## 融合方向（已归一化）
	var direction: Vector2 = Vector2.ZERO
	## 融合强度（已限幅到 max_speed）
	var strength: float = 0.0
	## 是否包含有效力
	var has_force: bool = false


## 融合建议力数组
##
## @param forces    建议力数组（来自 Provider + Solver 内联计算）
## @param max_speed 最大速度限制（px/s）
## @return          FusionResult
##
## 处理流程：
##   1. 跳过零力
##   2. 按 priority 分组
##   3. [Phase 7] 应用类型规则（force_type 驱动的分组调整）
##   4. 从高到低处理优先级组
##   5. 最高非零组决定最终方向
##   6. 结果限幅到 max_speed
func solve(forces: Array[MovementForce], max_speed: float = 350.0) -> FusionResult:
	var result = FusionResult.new()

	if forces.is_empty():
		return result

	# Step 1: 按优先级分组
	var groups: Dictionary = {}
	for f in forces:
		if f.is_zero():
			continue
		var p: int = f.priority
		if not groups.has(p):
			groups[p] = []
		groups[p].append(f)

	if groups.is_empty():
		return result

	# Step 2: 从高到低遍历优先级
	var priorities: Array[int] = []
	for p in groups:
		priorities.append(p)
	priorities.sort()
	priorities.reverse()

	# Step 3: [Phase 7] 按 force_type 规则调整分组 — 当前阶段不使用
	# _apply_force_type_rules 声明为 no-op，仅保留框架入口。
	# Phase 7（Separation Provider 迁移）不使用此规则系统。
	_apply_force_type_rules(groups, priorities)

	# ═══════════════════════════════════════════════════════════════
	# Step 4: 最高有非零力的优先级组决定最终方向
	# ═══════════════════════════════════════════════════════════════
	#
	# Phase 7.5 — Steering Correction Fusion（fix sticky behavior）
	# ──────────────────────────────────────────────────────────────
	# 当组内同时包含 GOAL + AVOIDANCE 时，改用方向修正模型替代
	# 线性叠加（Σ(dir × strength × weight)），避免分离力太弱
	# 无法突破路径力的主导方向。
	#
	# 融合策略：
	#   has_avoidance == true  → _blend_steering()  方向修正
	#   has_avoidance == false → _blend_weighted()  传统线性
	#
	# 三种力类型在同一 priority 组的处理规则：
	#   GOAL      → 主方向 + 速度基准
	#   AVOIDANCE → 方向修正项（非竞争向量）
	#   其他类型   → 正常权重叠加
	# ═══════════════════════════════════════════════════════════════
	for p in priorities:
		var group: Array = groups[p]

		var has_avoidance: bool = false
		for _f in group:
			if (_f as MovementForce).force_type == MovementForce.ForceType.AVOIDANCE:
				has_avoidance = true
				break

		var blended: Vector2
		if has_avoidance:
			blended = _blend_steering(group)
		else:
			blended = _blend_weighted(group)

		if blended.length_squared() > 0.0001:
			var len: float = blended.length()
			result.direction = blended / len
			result.strength = minf(len, max_speed)
			result.has_force = true
			break

	return result


## [Phase 7] 按 force_type 规则调整优先级分组
##
## 当前实现：no-op（保留所有组不变）。
##
## 这是未来规则系统的入口。规则可以通过以下方式介入：
##   - 修改 groups 字典（合并/拆分/提权/降权优先级组）
##   - 修改 priorities 数组（改变处理顺序）
##   - 注入新的优先级组
##
## 设计约束：
##   禁止在此方法内写 velocity。
##   禁止在此方法内调用 _blend_weighted（那是后续步骤）。
##   只应操作 groups/priorities 结构。
##
## @param groups      按 priority 分组的力字典（可修改）
## @param priorities  优先级列表（降序，可修改）
func _apply_force_type_rules(groups: Dictionary, priorities: Array[int]) -> void:
	# ── Phase 7: no-op ──
	# 后续规则可在此处根据 force_type 调整分组：
	#
	# 示例 1 — OVERRIDE 提权：
	#   var override_group: Array = []
	#   for p in priorities:
	#       var g: Array = groups[p]
	#       var kept: Array = []
	#       for f in g:
	#           if (f as MovementForce).force_type == MovementForce.ForceType.OVERRIDE:
	#               override_group.append(f)
	#           else:
	#               kept.append(f)
	#       groups[p] = kept
	#   if not override_group.is_empty():
	#       var max_p = priorities[0] + 1
	#       groups[max_p] = override_group
	#       priorities.insert(0, max_p)
	#
	# 示例 2 — EXTERNAL 降权：
	#   # 将所有 EXTERNAL 类型的力移到 priority = -10
	#   ...
	pass


## 加权混合同优先级力组
##
## 公式：result = Σ(direction × strength × weight)
##
## 每个 MovementForce 携带自己的 weight。
## weight=0 的力被排除（已在 solve 的 is_zero 检查中跳过零力，
## 但非零 × weight=0 仍贡献 0 — 语义正确）。
func _blend_weighted(forces: Array) -> Vector2:
	var result: Vector2 = Vector2.ZERO
	for f in forces:
		var force: MovementForce = f as MovementForce
		if force == null:
			continue
		result += force.direction * force.strength * force.weight
	return result


# ═══════════════════════════════════════════════════════════════
# Phase 7.5: Steering Correction Fusion
# ═══════════════════════════════════════════════════════════════
#
# 替代线性叠加（dir × strength × weight 求和），
# 将 AVOIDANCE 力作为方向修正项而非竞争项。
#
# 融合公式：
#   base_dir     = GOAL direction（主驱动力方向）
#   correction   = Σ(AVOIDANCE_dir × strength × weight)
#   final_dir    = normalize(base_dir + normalize(correction) × 0.3)
#   speed        = GOAL_strength × decay_factor
#   result       = final_dir × speed + Σ(other type forces)
#
# 任务 1：方向修正
#   AVOIDANCE 不竞争方向主导权，而是提供一个"提示方向"，
#   在 goal_dir 的基础上做小幅修正。
#   → base_dir += avoid_dir × 0.3
#
# 任务 2：速度衰减
#   当 AVOIDANCE 活跃（周围有单位）时，
#   轻微减速（×0.85~1.0），让单位更愿意让路。
#   → speed *= 1.0 - min(sep_strength / goal_speed, 1.0) × 0.15
#
# 任务 3：移除线性对抗
#   禁止 sep + path 的纯向量竞争模型。
#   AVOIDANCE 不乘以 strength 作为独立向量加入结果，
#   仅提供方向修正 + 速度衰减。
#
# 其他力类型（FORMATION 等）仍按权重叠加到最终结果。
# ═══════════════════════════════════════════════════════════════

const _STEER_CORRECTION_FACTOR: float = 0.3   # 方向修正系数（越大避让越敏感）
const _STEER_DECAY_MAX: float = 0.15            # 最大速度衰减比例（0.85 ~ 1.0）
const _STEER_VELOCITY_FACTOR: float = 0.5   # [Phase 7.6] AVOIDANCE 强度回归比例（0=不回归=旧行为）


## Phase 7.5: Steering correction blend
##
## @param forces  同优先级组内的所有力
## @return        融合后的速度向量
func _blend_steering(forces: Array) -> Vector2:
	var goal_dir: Vector2 = Vector2.ZERO
	var goal_speed: float = 0.0
	var goal_weight: float = 0.0  # tie-breaker: prefer non-zero-weight GOAL
	var correction: Vector2 = Vector2.ZERO
	var max_avoid_strength: float = 0.0

	# ── Step 1: 分类收集 —— GOAL / AVOIDANCE / OTHER ──
	for f in forces:
		var force: MovementForce = f as MovementForce
		if force == null:
			continue

		match force.force_type:
			MovementForce.ForceType.GOAL:
				# 取最强 GOAL 力作为基准；同强度时优先高权重
				# FlowFieldForceProvider 产出 weight=0.0 的冗余 GOAL 力，
				# 用 weight tie-break 避免被其覆盖正确的 Path 方向。
				if force.strength > goal_speed or \
				  (force.strength > 0 and force.strength >= goal_speed and force.weight > goal_weight):
					goal_dir = force.direction
					goal_speed = force.strength
					goal_weight = force.weight
			MovementForce.ForceType.AVOIDANCE:
				correction += force.direction * force.strength * force.weight
				max_avoid_strength = max(max_avoid_strength, force.strength)
			_:  # 后续再处理
				continue

	# ── Fallback: 无有效 GOAL → 退化为传统加权融合 ──
	if goal_speed <= 0.0 or goal_dir == Vector2.ZERO:
		return _blend_weighted(forces)

	# ──────────────────────────────────────────────────────
	# Task 1：方向修正
	#   base_dir = path_direction
	#   base_dir += separation_dir × 0.3
	#   final_dir = normalize(base_dir)
	# ──────────────────────────────────────────────────────
	var final_dir: Vector2 = goal_dir
	if correction.length_squared() > 0.0001:
		var avoid_dir: Vector2 = correction.normalized()
		final_dir = (goal_dir + avoid_dir * _STEER_CORRECTION_FACTOR).normalized()

	# ──────────────────────────────────────────────────────
	# Task 2：速度衰减
	#   当 separation > threshold → speed × 0.85 ~ 1.0
	# ──────────────────────────────────────────────────────
	var speed: float = goal_speed
	if max_avoid_strength > 0.0 and goal_speed > 0.0:
		# 求 avoidance 与 goal 的相对强度比
		var ratio: float = minf(max_avoid_strength / goal_speed, 1.0)
		speed *= (1.0 - ratio * _STEER_DECAY_MAX)  # → [0.85×, 1.0×]

	# ──────────────────────────────────────────────────────
	# Task 3：移除线性对抗
	#   AVOIDANCE 不是独立竞争向量
	#   其他非 GOAL/AVOIDANCE 力（FORMATION 等）正常叠加
	# ──────────────────────────────────────────────────────
	var result: Vector2 = final_dir * speed

	# ══════════════════════════════════════════════════════
	# [Phase 7.6] Restore AVOIDANCE velocity contribution
	# ══════════════════════════════════════════════════════
	# Steering correction (Task 1) changed direction but
	# discarded AVOIDANCE strength entirely.  Without some
	# velocity contribution, separation produces zero push.
	#
	# Fix: add correction × factor back into final velocity.
	# The factor dials how much separation push is visible.
	# 0.0 = pure Phase 7.5 (no push), 1.0 = full correction.
	# ══════════════════════════════════════════════════════
	if correction.length_squared() > 0.001:
		result += correction * _STEER_VELOCITY_FACTOR

	# 叠加其他力类型（FORMATION、SLOT_ANCHOR 等）
	# 权重 × 强度正常参与，但不再影响方向主导权
	for f in forces:
		var force: MovementForce = f as MovementForce
		if force == null:
			continue
		if force.force_type in [MovementForce.ForceType.GOAL, MovementForce.ForceType.AVOIDANCE]:
			continue  # 已处理
		result += force.direction * force.strength * force.weight

	return result
