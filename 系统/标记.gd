extends Node

## 标记系统 — 右键标记（白色圈=移动，红色叉=攻击）
##
## 在 CanvasLayer 上用 _draw 画标记，补间动画淡出

static var 实例: 标记 = null

var _画板: Control = null
var _标记列表: Array = []  # [{位置, 类型, 生命, 最大生命}]
var _标记容器: CanvasLayer = null


func _enter_tree() -> void:
	实例 = self


func _exit_tree() -> void:
	if 实例 == self:
		实例 = null


func _ready() -> void:
	_标记容器 = CanvasLayer.new()
	_标记容器.name = "右键标记层"
	_标记容器.layer = 50
	add_child(_标记容器)

	_画板 = Control.new()
	_画板.name = "画板"
	_画板.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_画板.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_画板.draw.connect(_绘制标记)
	_标记容器.add_child(_画板)


## 在屏幕位置显示移动标记（白色圈）
func 显示移动标记(屏幕位置: Vector2) -> void:
	_标记列表.append({
		"位置": 屏幕位置,
		"类型": "移动",
		"生命": 0.5,
		"最大生命": 0.5,
	})


## 在屏幕位置显示攻击标记（红色叉）
func 显示攻击标记(屏幕位置: Vector2) -> void:
	_标记列表.append({
		"位置": 屏幕位置,
		"类型": "攻击",
		"生命": 0.5,
		"最大生命": 0.5,
	})


func _process(delta: float) -> void:
	var 需要重绘: bool = false

	for i in range(_标记列表.size() - 1, -1, -1):
		_标记列表[i]["生命"] -= delta
		if _标记列表[i]["生命"] <= 0:
			_标记列表.remove_at(i)
			需要重绘 = true

	if 需要重绘 or not _标记列表.is_empty():
		_画板.queue_redraw()


func _绘制标记() -> void:
	var 相机 = _找相机()
	if not 相机:
		return

	for 标记数据 in _标记列表:
		var 屏幕位置: Vector2 = 标记数据["位置"]
		var 透明度: float = clamp(标记数据["生命"] / 标记数据["最大生命"], 0.0, 1.0)

		match 标记数据["类型"]:
			"移动":
				# 白色圈
				var 颜色 = Color(1, 1, 1, 透明度)
				_画板.draw_circle(屏幕位置, 12, Color(1, 1, 1, 透明度 * 0.2), false)
				_画板.draw_circle(屏幕位置, 10, Color(1, 1, 1, 透明度 * 0.4), false)
				_画板.draw_arc(屏幕位置, 8, 0, TAU, 16, 颜色, 2.0)

			"攻击":
				# 红色叉
				var 颜色 = Color(1, 0.2, 0.2, 透明度)
				var 大小: float = 8
				_画板.draw_line(屏幕位置 + Vector2(-大小, -大小), 屏幕位置 + Vector2(大小, 大小), 颜色, 2.0)
				_画板.draw_line(屏幕位置 + Vector2(大小, -大小), 屏幕位置 + Vector2(-大小, 大小), 颜色, 2.0)
				_画板.draw_circle(屏幕位置, 10, 颜色 * Color(1, 1, 1, 0.15), false)


func _找相机() -> Camera2D:
	var tree: SceneTree = get_tree()
	if not tree:
		return null
	return _递归找相机(tree.root)


func _递归找相机(node: Node) -> Camera2D:
	if node is Camera2D and node.is_current():
		return node
	for child in node.get_children():
		var 结果 = _递归找相机(child)
		if 结果:
			return 结果
	return null
