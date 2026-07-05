class_name FlowFieldForceProvider
extends MovementForceProvider

## FlowFieldForceProvider — 流场建议力提供者
##
## 从 流场管理器 读取全局移动方向，输出 PATH / GOAL 类型建议力。
## 不涉及 velocity 计算。
##
## ⚠ Phase 7.3 — 禁止共享可变状态。
##   此 Provider 被 MovementSolver 用于所有已迁移单位。
##   任何实例变量都会被跨单位覆盖 → 路径污染。
##   必须保持无状态：所有输入通过 context 传入。


func _init():
	provider_name = "FlowField"
	process_priority = 10  # 在基础逻辑之后


## 计算流场建议力
## @param unit     目标单位
## @param context  必须包含 "flow_field_target"（Vector2目标位置）
##                 context["strategy"] → 策略.获取流场目标(请求, unit)
## @return 流场方向建议力
func calculate_force(unit: Node2D, context: Dictionary) -> MovementForce:
	var force = MovementForce.new()
	force.source_name = "FlowField"
	force.force_type = MovementForce.ForceType.GOAL

	# 获取流场目标
	var target: Vector2 = context.get("flow_field_target", Vector2.ZERO)
	if target == Vector2.ZERO:
		# 无目标 → 尝试从策略获取
		var strategy = context.get("strategy", null) as 移动策略
		var request = context.get("request", null) as 移动请求
		if strategy and request:
			target = strategy.获取流场目标(request, unit)
		if target == Vector2.ZERO:
			return force  # 零力

	# 移除: 共享实例变量会导致跨单位路径覆盖 (Phase 7.3)

	# 从流场管理器获取方向
	var dir: Vector2 = Vector2.ZERO
	if is_instance_valid(流场管理器.实例):
		dir = 流场管理器.获取方向(unit.global_position, target)

	# 流场不可用时回退到直接指向目标
	if dir == Vector2.ZERO:
		var raw = target - unit.global_position
		if raw.length_squared() < 0.0001:
			return force  # 零力
		dir = raw.normalized()

	# 计算强度（使用单位移动速度）
	var speed: float = unit.移动速度 if "移动速度" in unit else 200.0

	force.direction = dir
	force.strength = speed
	## Phase 7.2: weight=0.0 — 冗余力消除。
	## 策略类（前往位置移动 / 追击目标移动 / 移动攻击移动）已在内部
	## 直接调用 流场管理器.获取方向()。FlowFieldProvider 的 GOAL force
	## 与 inline Path GOAL force (weight=1.0) 形成双 GOAL 竞争，导致
	## 目标附近策略刹车逻辑被覆盖（策略减速但 FlowField 全速推进），
	## 产生左右抽搐。
	##
	## 保留 Provider 实例和 force_type=GOAL，待后续 Phase 重新评估
	## 是否应将路径力 Provider 化（届时 FlowField 可作为辅助信号）。
	force.weight = 0.0
	force.priority = 0

	return force


## 始终激活（只要 Solver 调用）
func is_active(unit: Node2D, context: Dictionary) -> bool:
	var intent = context.get("intent", null) as MovementIntent
	if intent and intent.is_valid():
		return intent.type in [
			MovementIntent.IntentType.MOVE_TO,
			MovementIntent.IntentType.PURSUE,
			MovementIntent.IntentType.ATTACK_MOVE,
		]
	return false
