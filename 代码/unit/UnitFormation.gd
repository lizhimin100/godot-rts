class_name UnitFormation
extends RefCounted

## 队形偏移系统 — 多单位到达时分散站位
##
## 为选中单位按网格分配目标偏移，避免全部叠在同一个点上。
## 使用方形网格排列，以选中中心为锚点。
##
## 用法（在命令处理处）：
##   for i in units:
##       var offset = UnitFormation.get_slot_offset(i, units.size(), 24.0)
##       unit.unit_controller.formation_offset = offset
##
## 参数调优：
##   spacing=24 → WC3 风格紧凑；spacing=32 → RA 风格宽松

# 默认间距
const DEFAULT_SPACING: float = 24.0


## 计算槽位偏移
## @param index    单位在选中列表中的索引（从 0 开始）
## @param total    选中单位总数
## @param spacing  单位间距（像素）
## @return         以选中中心为原点的偏移向量
static func get_slot_offset(index: int, total: int,
		spacing: float = DEFAULT_SPACING) -> Vector2:
	if total <= 1:
		return Vector2.ZERO

	# 方形排列：列数 = ceil(sqrt(total))
	var cols: int = int(ceil(sqrt(total)))
	var row: int = index / cols
	var col: int = index % cols

	# 中心对齐
	var center_x: float = (cols - 1) * 0.5
	var rows: int = (total + cols - 1) / cols
	var center_y: float = (rows - 1) * 0.5

	return Vector2(
		(col - center_x) * spacing,
		(row - center_y) * spacing
	)


## 获取圆形排列偏移（更自然的散布）
static func get_circular_offset(index: int, total: int,
		spacing: float = DEFAULT_SPACING) -> Vector2:
	if total <= 1:
		return Vector2.ZERO

	var angle: float = (index as float) / total * TAU
	var radius: float = spacing * 0.5 * (1.0 + sqrt(total as float) * 0.3)
	return Vector2(cos(angle), sin(angle)) * radius


## 根据单位碰撞半径自动计算间距
static func get_spacing_for_unit(unit: CharacterBody2D,
		min_spacing: float = 16.0) -> float:
	# 如果有碰撞形状，取其半径
	if unit.collision_layer > 0:
		for child in unit.get_children():
			var shape: CollisionShape2D = child as CollisionShape2D
			if shape and shape.shape:
				if shape.shape is CircleShape2D:
					return max(min_spacing, shape.shape.radius * 2.5)
				elif shape.shape is RectangleShape2D:
					return max(min_spacing,
							max(shape.shape.size.x, shape.shape.size.y) * 1.2)
	return DEFAULT_SPACING
