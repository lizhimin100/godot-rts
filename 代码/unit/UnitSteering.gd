class_name UnitSteering
extends RefCounted

## 局部避障系统 — 单位间平滑排斥力
##
## 使用平方衰减的排斥力，单位越近排斥越强。
## 只作用于 "移动单位" 组的单位之间，不参与全局寻路判断。
##
## 参数调优：
##   radius=80   → 更宽的排斥范围，提前推开防止贴图重叠
##   strength=3.0 → 更强力的推开，配合流场权重 0.7 达到平衡
##   stationary_multiplier=3.0 → 静止单位产生 3 倍排斥力（不可穿透）
##
## 返回值可直接与流场方向叠加（加权 1.5×）

# 排斥参数
const DEFAULT_RADIUS: float = 80.0
const DEFAULT_STRENGTH: float = 3.0
const DEFAULT_STATIONARY_MULTIPLIER: float = 3.0


## 计算指定单位受到的排斥力
## @param unit                   CharacterBody2D 单位
## @param radius                 排斥半径
## @param strength               排斥强度
## @param stationary_multiplier  静止单位额外排斥系数
## @return                      归一化后的排斥方向向量（乘以强度）
static func get_steering(unit: CharacterBody2D,
		radius: float = DEFAULT_RADIUS,
		strength: float = DEFAULT_STRENGTH,
		stationary_multiplier: float = DEFAULT_STATIONARY_MULTIPLIER) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	var pos: Vector2 = unit.global_position
	var radius_sq: float = radius * radius

	for other in unit.get_tree().get_nodes_in_group("移动单位"):
		if other == unit or not is_instance_valid(other):
			continue

		var offset: Vector2 = pos - other.global_position
		var dist_sq: float = offset.length_squared()

		# 超出范围或完全重叠 → 跳过
		if dist_sq > radius_sq or dist_sq < 0.001:
			continue

		var dist: float = sqrt(dist_sq)
		# 平方衰减：越近越强
		var force: float = pow(1.0 - dist / radius, 2)
		# 静止单位额外排斥力
		if "velocity" in other and other.velocity.length_squared() < 4.0:
			force *= stationary_multiplier
		push += offset / dist * force

	return push * strength
