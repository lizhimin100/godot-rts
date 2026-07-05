class_name SeparationSystem
extends RefCounted

## 分离转向系统 — 防止单位重叠的 Steering Force
##
## 纯计算模块，不涉及物理碰撞层。
## 使用平方衰减排斥力：距离越近，排斥越强。
## 推荐参数：radius=24, strength=4.0
##
## 与 FlowField 方向叠加使用（不是替代）。
## 这是唯一负责"单位间推开"的系统，禁止 collision layer 互撞。

const DEFAULT_RADIUS: float = 24.0
const DEFAULT_STRENGTH: float = 4.0


## 计算指定位置所受的分离排斥力
##
## @param position    单位的世界坐标
## @param others      其他单位列表（Array[Node2D]）
## @param radius      排斥半径（px），推荐 20~30
## @param strength    排斥强度
## @return            累积排斥方向向量（* strength）
static func get_force(
	position: Vector2,
	others: Array,
	radius: float = DEFAULT_RADIUS,
	strength: float = DEFAULT_STRENGTH
) -> Vector2:
	var _t = Tracer.start()
	var force: Vector2 = Vector2.ZERO
	var radius_sq: float = radius * radius
	var _n_skip: int = 0
	var _n_applied: int = 0

	for other in others:
		if not is_instance_valid(other):
			continue

		var offset: Vector2 = position - other.global_position
		var dist_sq: float = offset.length_squared()

		# 超出范围或完全重叠
		if dist_sq >= radius_sq or dist_sq < 0.001:
			continue

		var dist: float = sqrt(dist_sq)
		# 平方衰减: (1 - d/r)^2
		var magnitude: float = (1.0 - dist / radius) * (1.0 - dist / radius)
		_n_applied += 1
		force += offset / dist * magnitude

	# Phase 7.3: neighbor count normalization for reciprocity
	# Prevent cumulative push from N neighbors being N× stronger than single
	if _n_applied > 1:
		force /= sqrt(float(_n_applied))
	return force * strength


## 批量计算所有单位的分离力
##
## @param units     单位列表（Array[Node2D]）
## @param radius    排斥半径
## @param strength  排斥强度
## @return          Dictionary: { unit_node: Vector2 force }
static func batch_forces(
	units: Array,
	radius: float = DEFAULT_RADIUS,
	strength: float = DEFAULT_STRENGTH
) -> Dictionary:
	var result: Dictionary = {}
	var count: int = units.size()
	if count <= 1:
		return result

	var radius_sq: float = radius * radius

	for i in range(count):
		var unit_a = units[i]
		if not is_instance_valid(unit_a):
			continue
		var pos_a: Vector2 = unit_a.global_position
		var total_force: Vector2 = Vector2.ZERO

		for j in range(count):
			if i == j:
				continue
			var unit_b = units[j]
			if not is_instance_valid(unit_b):
				continue

			var offset: Vector2 = pos_a - unit_b.global_position
			var dist_sq: float = offset.length_squared()

			if dist_sq >= radius_sq or dist_sq < 0.001:
				continue

			var dist: float = sqrt(dist_sq)
			var magnitude: float = (1.0 - dist / radius) * (1.0 - dist / radius)
			total_force += offset / dist * magnitude

		result[unit_a] = total_force * strength

	return result
