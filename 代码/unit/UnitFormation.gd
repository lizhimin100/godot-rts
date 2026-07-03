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
##   spacing=38 → 实测7单位阵型舒适间距；spacing=24 → WC3 紧凑

# 默认间距（38px = 碰撞体宽度~16px + 22px间隙）
const DEFAULT_SPACING: float = 38.0

# ========== 阵型日志 ==========
var 日志文件路径: String = "res://_formation_log.txt"
var _日志已写表头: bool = false

func _init():
	# 清空旧日志
	var f = FileAccess.open(日志文件路径, FileAccess.WRITE)
	if f:
		f.store_line("=== 阵型日志 v1.0 ===")
		f.store_line("格式: [帧数] 事件 | 数据")
		f.store_line("")
		f.close()

func 写日志(消息: String) -> void:
	var 帧 = Engine.get_frames_drawn()
	var f = FileAccess.open(日志文件路径, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line("[%d] %s" % [帧, 消息])
		f.close()

## 记录一次阵型分配
func 记录阵型分配(锚点: Vector2, 单位们: Array, 间距: float) -> void:
	写日志("=== 阵型分配 ===")
	写日志("锚点: (%.1f, %.1f)" % [锚点.x, 锚点.y])
	写日志("单位数: %d" % 单位们.size())
	写日志("间距: %.1f" % 间距)

	var cols = int(ceil(sqrt(单位们.size())))
	var rows = int(ceil(单位们.size() as float / cols))

	for i in range(单位们.size()):
		var u = 单位们[i]
		if not is_instance_valid(u):
			写日志("  单位[%d]: 无效" % i)
			continue

		var 偏移 = get_slot_offset(i, 单位们.size(), 间距)
		var 目标 = 锚点 + 偏移
		var 碰撞信息 = 获取碰撞信息(u)
		写日志("  单位[%d]: %s | 碰撞=%s | 偏移=(%.1f, %.1f) | 目标=(%.1f, %.1f) | 当前位=(%.1f, %.1f)" % [
			i, u.name, 碰撞信息, 偏移.x, 偏移.y, 目标.x, 目标.y, u.global_position.x, u.global_position.y])

	写日志("  网格: %d列 x %d行" % [cols, rows])
	写日志("")

## 记录单位到达最终位置
func 记录单位到达(单位: Node2D, 目标位置: Vector2) -> void:
	if not is_instance_valid(单位): return
	写日志("  到达: %s 实际=(%.1f, %.1f) 目标=(%.1f, %.1f) 偏差=(%.1f, %.1f)" % [
		单位.name,
		单位.global_position.x, 单位.global_position.y,
		目标位置.x, 目标位置.y,
		单位.global_position.x - 目标位置.x, 单位.global_position.y - 目标位置.y
	])

static func 获取碰撞信息(单位) -> String:
	if not is_instance_valid(单位): return "N/A"
	for child in 单位.get_children():
		var shape: CollisionShape2D = child as CollisionShape2D
		if shape and shape.shape:
			if shape.shape is RectangleShape2D:
				var s = shape.shape.size * 单位.scale
				return "Rect(%.1fx%.1f)" % [s.x, s.y]
			elif shape.shape is CircleShape2D:
				return "Circle(r=%.1f)" % shape.shape.radius
	return "None"

# ========== 单例引用，方便调用 ==========
static var _日志实例: UnitFormation = null
static func 获取日志() -> UnitFormation:
	if not _日志实例:
		_日志实例 = UnitFormation.new()
	return _日志实例

# ========== 原有计算逻辑 ==========

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
	var rows: int = int(ceil(total as float / cols))
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
