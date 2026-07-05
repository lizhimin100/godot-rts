class_name MovementForcePipeline
extends RefCounted

## MovementForcePipeline — 建议力生命周期流水线（Phase 5）
##
## 职责：
##   接收原始 Array<MovementForce>
##   → Filter（过期/无效/排序）
##   → Modify（全局修正/标志处理）
##   → Fusion（加权混合 + 限幅）
##   → FusionResult
##
## 设计原则：
##   Pipeline 是 Force 的唯一处理入口。
##   所有与 Force 生命周期相关的逻辑集中在 Pipeline，
##   不在 Solver、Fusion、或 Provider 中。
##
## 未来扩展：
##   技能 Force → 设置 lifetime + FLAG_TRANSIENT
##   Buff Force → 设置 weight 修正 + lifetime
##   Knockback → 设置 priority=10 + FLAG_UNSTOPPABLE + lifetime
##   冲锋 → 设置 priority=20 + FLAG_IGNORE_WEIGHT + lifetime=冲锋时长
##
## 内部阶段（本帧内顺序）：
##   1. remove_expired   — 跳过已过期的力
##   2. remove_invalid   — 跳过零力/无效力
##   3. sort_priority    — 按 priority 降序排列
##   4. apply_multiplier — 全局强度/权重修正（默认空）
##   5. apply_override   — 按 FLAG_* 调整力属性
##   6. solve            — 移交 Fusion 加权混合 + 限幅


# ============================================================
# Fusion 实例
# ============================================================

var _fusion: MovementForceFusion = null


# ============================================================
# 生命周期
# ============================================================

func _init():
	_fusion = MovementForceFusion.new()


# ============================================================
# 核心入口
# ============================================================

## 处理整条力流水线
##
## @param forces    原始建议力数组（会被修改——移除过期/无效项）
## @param delta     帧时间（秒）
## @param max_speed 最大速度限制（px/s）
## @return          FusionResult
func process(forces: Array[MovementForce], delta: float, max_speed: float) -> MovementForceFusion.FusionResult:
	if forces.is_empty():
		return _fusion.solve([], max_speed)

	# ── Filter 阶段 ──
	_remove_expired(forces, delta)
	_remove_invalid(forces)
	_sort_priority(forces)

	if forces.is_empty():
		return _fusion.solve([], max_speed)

	# ── Modify 阶段 ──
	_apply_multiplier(forces)
	_apply_override(forces)

	# ── Fusion 阶段 ──
	return _fusion.solve(forces, max_speed)


# ============================================================
# Filter 阶段（内部方法）
# ============================================================

## 移除过期力（lifetime >= 0 且已耗尽）
##   lifetime < 0 → 永久有效
##   lifetime = 0 → 本帧过期（立即移除）
##   lifetime > 0 → 每帧递减 delta，归零后移除
func _remove_expired(forces: Array[MovementForce], delta: float) -> void:
	var i = forces.size() - 1
	while i >= 0:
		var f: MovementForce = forces[i] as MovementForce
		if f == null:
			i -= 1
			continue

		if f.lifetime < 0.0:
			# 永久力，不移除
			i -= 1
			continue

		if f.lifetime <= 0.0:
			# 已过期或本帧过期
			forces.remove_at(i)
		else:
			# 递减 lifetime
			f.lifetime -= delta
			if f.lifetime <= 0.0:
				forces.remove_at(i)
		i -= 1


## 移除无效力（零力或无效数据）
func _remove_invalid(forces: Array[MovementForce]) -> void:
	var i = forces.size() - 1
	while i >= 0:
		var f: MovementForce = forces[i] as MovementForce
		if f == null or f.is_zero():
			forces.remove_at(i)
		i -= 1


## 按 priority 降序排列（高优先级在前）
## 确保 Modifier 阶段可按优先级顺序处理
func _sort_priority(forces: Array[MovementForce]) -> void:
	forces.sort_custom(_priority_desc)


static func _priority_desc(a: MovementForce, b: MovementForce) -> bool:
	return a.priority > b.priority


# ============================================================
# Modify 阶段（内部方法）
# ============================================================

## 应用全局乘数（暂时为空——未来框架用）
## 未来使用场景：全局减速 buff、slowed terrain、技能光环
func _apply_multiplier(forces: Array[MovementForce]) -> void:
	# 暂无全局乘数
	pass


## 按 FLAG_* 处理力属性
##   FLAG_IGNORE_WEIGHT → weight 视为 1.0（Fusion 在 _blend_weighted 中读取
##                            → 调用前暂时不分发，直接修改 weight）
##   FLAG_UNSTOPPABLE   → 记录元数据（当前被跳过，因卡死检测不在此层）
##   FLAG_TRANSIENT     → 本帧有效，融合后预期 Provider 不再生成（不做移除）
func _apply_override(forces: Array[MovementForce]) -> void:
	for f in forces:
		var force: MovementForce = f as MovementForce
		if force == null:
			continue
		if force.has_flag(MovementForce.FLAG_IGNORE_WEIGHT):
			# IGNORE_WEIGHT：weight 强制为 1.0
			force.weight = 1.0
		# UNSTOPPABLE / TRANSIENT 对融合无直接影响，
		# 但 Provider 和其他系统可通过标志位感知
