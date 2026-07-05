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

# Phase 7.3: Soft disengage state for sticky units
# Tracks consecutive frames a unit is being pushed.
# After N frames, reduces separation influence to break C-sticky loop.
var _push_counters: Dictionary = {}  # unit_node -> frames count


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

	# 零方向 → 零力（与旧逻辑一致：length_squared > 0.0001 才有效）
	if 分离力向量.length_squared() < 0.0001:
		return force

	force.direction = 分离力向量.normalized()
	force.strength = 分离力向量.length()
	force.weight = 0.4         # 与旧 Solver 常量 分离力权重 完全一致
	force.priority = 0          # 与路径力同优先级（混合权重）
	force.lifetime = -1.0       # 永久有效（与旧行为一致）
	force.flags = MovementForce.FLAG_NONE

	# Phase 7.3: Soft disengage -- reduce separation if pushed >30 consecutive frames
	# Prevents C-sticky / infinite push between same unit pair
	var mag: float = force.strength
	if mag > 5.0:  # significant push threshold
		var entry: Dictionary = _push_counters.get(unit, {"frames": 0})
		entry["frames"] += 1
		_push_counters[unit] = entry

		if entry["frames"] >= 30:  # ~0.5 sec at 60fps
			# Enter soft disengage: halve separation influence
			force.strength *= 0.5
			force.weight *= 0.5
	else:
		# Not being pushed: decay counter
		if _push_counters.has(unit):
			var entry = _push_counters[unit]
			entry["frames"] = maxi(0, entry["frames"] - 2)
			if entry["frames"] == 0:
				_push_counters.erase(unit)

	return force


## 激活条件：避障系统可用时，始终尝试计算分离力
## 与旧 Solver 条件完全一致：
##   if 避障系统.实例:
##       var 周围单位 = ...
##       var 分离力向量 = ...
func is_active(unit: Node2D, context: Dictionary) -> bool:
	return is_instance_valid(避障系统.实例)


## 计算当前路径方向（与旧 Solver._构建内联力 第①段算法一致）
func _计算路径方向(unit: Node2D, context: Dictionary) -> Vector2:
	var strategy = context.get("strategy", null) as 移动策略
	var request = context.get("request", null) as 移动请求
	if strategy == null or request == null:
		return Vector2.ZERO
	var 路径速度: Vector2 = strategy.计算速度(unit, request)
	return 路径速度.normalized() if 路径速度.length_squared() > 0.01 else Vector2.ZERO
