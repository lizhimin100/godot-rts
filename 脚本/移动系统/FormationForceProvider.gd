class_name FormationForceProvider
extends MovementForceProvider

## FormationForceProvider — 队形建议力提供者（Phase 6）
##
## 从 队形系统 计算槽位修正方向，输出 FORMATION 类型建议力。
## 不涉及 velocity 计算。
##
## 迁移自 MovementSolver._构建内联力() 第二阶段（队形力）。
## 保持与旧逻辑完全一致的数学算法。
##
## Provider 上下文依赖：
##   context["unit"]        → Node2D （调用 计算队形力 必需）
##   context["slot_state"]  → int    （MOVING_TO_SLOT 时激活）
##   context["request"]     → 移动请求（队形偏移等数据）
##   context["intent"]      → MovementIntent
##
## 激活条件：
##   slot_state == MOVING_TO_SLOT
##   且 队形系统.实例 有效
##
## 权重：0.6（与旧 Solver 内联完全一致）
## 优先级：0（与路径力同级别混合）

const MOVING_TO_SLOT: int = 0  # 与 MovementSolver.MOVING_TO_SLOT 同步


func _init():
	provider_name = "Formation"
	process_priority = 15  # 在流场力（10）之后


## 计算队形建议力
## @param unit     目标单位
## @param context  必须包含 unit、slot_state 等数据
## @return         队形修正建议力（无队形时返回零力）
func calculate_force(unit: Node2D, context: Dictionary) -> MovementForce:
	var force = MovementForce.new()
	force.source_name = "Formation"
	force.force_type = MovementForce.ForceType.FORMATION

	# 计算队形力（与旧 _构建内联力 完全一致的算法）
	if not is_instance_valid(队形系统.实例):
		return force  # 零力

	var 队形力向量: Vector2 = 队形系统.实例.计算队形力(unit)

	# 零方向 → 零力（与旧逻辑一致：length_squared > 0.0001 才有效）
	if 队形力向量.length_squared() < 0.0001:
		return force  # 零力

	force.direction = 队形力向量.normalized()
	force.strength = 队形力向量.length()
	force.weight = 0.6        # 与旧 Solver 常量 队形力权重 完全一致
	force.priority = 0         # 与路径力同优先级（混合权重）
	force.lifetime = -1.0      # 永久有效（与旧行为一致）
	force.flags = MovementForce.FLAG_NONE

	return force


## 激活条件：仅当单位处于 MOVING_TO_SLOT 状态时计算队形力
## 与旧 Solver 条件完全一致：
##   if 队形系统.实例 and data.slot_state == MOVING_TO_SLOT
func is_active(unit: Node2D, context: Dictionary) -> bool:
	var slot_state: int = context.get("slot_state", -1)
	return slot_state == MOVING_TO_SLOT and is_instance_valid(队形系统.实例)
