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

	# Step 4: 最高有非零力的优先级组决定最终方向
	for p in priorities:
		var group: Array = groups[p]
		var blended: Vector2 = _blend_weighted(group)
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
