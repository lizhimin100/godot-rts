class_name 输入处理器
extends Node

## 输入处理器 — RTS 鼠标/键盘输入统一处理
##
## 选中规则：
##   - 己方单位：直接点选/框选
##   - 敌方单位：只在迷雾视野内才可选中（看信息但不可操控）
##   - 敌人不提供视野

signal 右键标记位置(pos: Vector2, is_attack: bool)

@export var 选择碰撞层: int = 12    # 8(操作单位) + 4(建筑)
@export var 敌人碰撞层: int = 16
@export var 框选阈值: float = 15.0
@export var 单位分组名: String = "可选单位"
@export var 玩家阵营ID: int = 0

var _框选起始: Vector2 = Vector2.ZERO
var _框选结束: Vector2 = Vector2.ZERO
var _是否框选中: bool = false
var _拖拽中: bool = false
var _鼠标按下位置: Vector2 = Vector2.ZERO
var _amode激活: bool = false
var _最后右键位置: Vector2 = Vector2.ZERO
var _相机: Camera2D = null
var _框选控件: Control = null
## 记录 _左键按下 是否选中了单位，用于 _左键释放 防止误取消
var _按下时选中了单位: bool = false


func _ready() -> void:
	_框选控件 = Control.new()
	_框选控件.name = "框选控件"
	_框选控件.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_框选控件.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_框选控件.draw.connect(_绘制框选)

	var 层 = CanvasLayer.new()
	层.name = "框选覆盖层"
	层.layer = 100
	层.add_child(_框选控件)
	add_child(层)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A:
			_amode激活 = not _amode激活
			return
		if event.keycode == KEY_F9:
			_记录阵型快照()
			return
	if event is InputEventMouseButton:
		_处理鼠标(event)
	elif event is InputEventMouseMotion and _拖拽中:
		_处理鼠标移动(event)


# ============================================================
# 鼠标
# ============================================================

func _处理鼠标(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed: _左键按下(event)
			else: _左键释放(event)
		MOUSE_BUTTON_RIGHT:
			if event.pressed: _右键按下(event)


func _左键按下(event: InputEventMouseButton) -> void:
	_鼠标按下位置 = event.position
	_拖拽中 = false
	_按下时选中了单位 = false

	# A-move
	if _amode激活:
		_amode激活 = false
		命令管理器.命令移动(选择管理器.获取选中(), _屏幕到世界(event.position))
		if 标记.实例: 标记.实例.显示攻击标记(event.position)
		return

	# 点选
	var 点中的 = _检测点击(event.position, [选择碰撞层, 敌人碰撞层])
	if 点中的:
		_按下时选中了单位 = true
		print("[PICK] mouse=(", event.position.x, ",", event.position.y, ") hit=", 点中的.name)
		var 是敌人 = 点中的.has_method("_是敌人") and 点中的._是敌人()
		if 是敌人:
			# 敌人只在视野可见时才可选（看信息不能操控）
			if 迷雾系统.实例 and 迷雾系统.实例.单位对阵营可见(点中的, 玩家阵营ID):
				if event.shift_pressed: 选择管理器.添加选中(点中的)
				else: 选择管理器.选中单位([点中的])
			return
		# 己方正常选中
		if event.shift_pressed: 选择管理器.添加选中(点中的)
		else: 选择管理器.选中单位([点中的])
		return

	# 空地 → 开始框选
	_拖拽中 = true
	_框选起始 = _屏幕到世界(event.position)
	_框选结束 = _框选起始
	_是否框选中 = false


func _左键释放(event: InputEventMouseButton) -> void:
	_拖拽中 = false
	var 有框选 = _是否框选中
	var 框选始 = _框选起始
	_框选起始 = Vector2.ZERO
	_框选结束 = Vector2.ZERO
	_是否框选中 = false
	_框选控件.queue_redraw()

	if 有框选:
		var 框选区: Rect2 = Rect2(框选始, Vector2.ZERO)
		框选区 = 框选区.expand(_屏幕到世界(event.position))
		if 框选区.size.length_squared() > 16:
			_执行框选(框选区)
			return

	# ⭐ 不在释放时重新检测点击 —— press 已选中单位，防止释放时的
	#   微小鼠标偏移导致二次检测失败而误取消选中。
	#   只有 press 时也未选中任何单位（点击空地），才在 release 取消选中。
	if not _按下时选中了单位:
		var 点中的 = _检测点击(event.position, [选择碰撞层, 敌人碰撞层])
		if not 点中的: 选择管理器.取消选中()


func _右键按下(event: InputEventMouseButton) -> void:
	var 世界位置 = _屏幕到世界(event.position)
	var 点中的敌人 = _检测点击(event.position, [敌人碰撞层])
	_最后右键位置 = 世界位置
	右键标记位置.emit(世界位置, 点中的敌人 != null)

	if 标记.实例:
		if 点中的敌人: 标记.实例.显示攻击标记(event.position)
		else: 标记.实例.显示移动标记(event.position)

	命令管理器.处理右键点击(世界位置, 点中的敌人)


func _处理鼠标移动(event: InputEventMouseMotion) -> void:
	if not _拖拽中: return
	var 世界位置 = _屏幕到世界(event.position)
	if event.position.distance_to(_鼠标按下位置) > 框选阈值:
		_是否框选中 = true
		_框选结束 = 世界位置
		_框选控件.queue_redraw()


# ============================================================
# _draw 框选
# ============================================================

func _绘制框选() -> void:
	if not _是否框选中 or _框选起始 == _框选结束: return
	var 屏始 = _世界到屏幕(_框选起始)
	var 屏末 = _世界到屏幕(_框选结束)
	var 矩形: Rect2 = Rect2(屏始, Vector2.ZERO).expand(屏末).abs()
	if 矩形.size.length_squared() < 4: return
	_框选控件.draw_rect(矩形, Color(0.2, 0.8, 0.3, 0.15), true)
	_框选控件.draw_rect(矩形, Color(0.0, 1.0, 0.2, 0.9), false, 1.5)


# ============================================================
# 框选（己方全部可选 + 敌方只在视野内可选）
# ============================================================

func _执行框选(矩形: Rect2) -> void:
	var 候选 = 单位管理器.获取半径内单位(矩形.get_center(), 矩形.size.length() / 2)
	var 选中: Array = []
	var 选中单位: Array = []
	var 选中建筑: Array = []

	for unit in 候选:
		if not is_instance_valid(unit): continue
		var 在框内 = 矩形.has_point(unit.global_position)
		if not 在框内: continue

		# 己方单位（在可选分组中）
		if unit.is_in_group(单位分组名):
			if unit is CharacterBody2D:
				选中单位.append(unit)
			else:
				选中建筑.append(unit)
			continue

		# 敌方单位（只在视野内可选）
		if unit.has_method("_是敌人") and unit._是敌人():
			if 迷雾系统.实例 and 迷雾系统.实例.单位对阵营可见(unit, 玩家阵营ID):
				选中.append(unit)

	if not 选中单位.is_empty():
		选中 = 选中单位
	elif not 选中建筑.is_empty():
		选中 = 选中建筑

	if not 选中.is_empty(): 选择管理器.选中单位(选中)


# ============================================================
# 辅助
# ============================================================

func _检测点击(屏幕位置: Vector2, 碰撞层列表: Array) -> Node2D:
	var 查询 := PhysicsPointQueryParameters2D.new()
	查询.position = _屏幕到世界(屏幕位置)
	查询.collision_mask = 0
	for 层 in 碰撞层列表: 查询.collision_mask += 层
	var 空间状态 = _获取空间状态()
	if not 空间状态: return null
	var 结果 = 空间状态.intersect_point(查询)
	if 结果.is_empty():
		return null

	# ⭐ 按距离排序，选最近的单位（而不是 z_index/ysort 序）
	#   intersect_point 不保证返回顺序，手动排序确保点击最近单位
	var 点击位置 = 查询.position
	结果.sort_custom(func(a, b): return _点选排序(a, b, 点击位置))

	for r in 结果:
		var c = r.collider
		if c and is_instance_valid(c) and c is Node2D:
			return c
	return null


## 按距离排序（防 null collider）
func _点选排序(a: Dictionary, b: Dictionary, 原点: Vector2) -> bool:
	var ca = a.collider if a.collider != null else null
	var cb = b.collider if b.collider != null else null
	if not is_instance_valid(ca): return false
	if not is_instance_valid(cb): return true
	return ca.global_position.distance_squared_to(原点) < cb.global_position.distance_squared_to(原点)


func _屏幕到世界(屏幕坐标: Vector2) -> Vector2:
	if not _相机: _相机 = _获取主相机()
	if _相机: return _相机.get_canvas_transform().affine_inverse() * 屏幕坐标
	return 屏幕坐标


func _世界到屏幕(世界坐标: Vector2) -> Vector2:
	if not _相机: _相机 = _获取主相机()
	if _相机: return _相机.get_canvas_transform() * 世界坐标
	return 世界坐标


func _获取主相机() -> Camera2D:
	var tree = get_tree()
	if not tree: return null
	return _递归找相机(tree.root)


func _递归找相机(node: Node) -> Camera2D:
	if node is Camera2D and node.is_current(): return node
	for child in node.get_children():
		var r = _递归找相机(child)
		if r: return r
	return null


func _获取空间状态() -> PhysicsDirectSpaceState2D:
	var tree = get_tree()
	if not tree: return null
	var root = tree.root
	if not root: return null
	var w2d: World2D = root.world_2d
	if not w2d: return null
	return w2d.direct_space_state

# ============================================================
# F9 — 记录当前选中单位的位置（阵型快照，供AI分析间距）
# ============================================================

func _记录阵型快照() -> void:
	var 选中的 = 选择管理器.获取选中()
	if 选中的.is_empty():
		print('[F9] ❌ 没有选中单位')
		return
	# 计算选中中心
	var 中心: Vector2 = Vector2.ZERO
	var 有效计数: int = 0
	for u in 选中的:
		if is_instance_valid(u):
			中心 += u.global_position
			有效计数 += 1
	if 有效计数 == 0:
		print('[F9] ❌ 没有有效单位')
		return
	中心 /= 有效计数
	# 写入日志
	var 日志 = UnitFormation.获取日志()
	日志.写日志('=== F9 手动阵型快照 ===')
	日志.写日志('中心点: (%.1f, %.1f) | 单位数: %d' % [中心.x, 中心.y, 有效计数])
	日志.写日志('')
	for i in range(选中的.size()):
		var u = 选中的[i]
		if not is_instance_valid(u): continue
		var 偏移 = u.global_position - 中心
		var 碰撞信息 = UnitFormation.获取碰撞信息(u)
		日志.写日志('[%d] %s | 碰撞=%s | 偏移=(%.1f, %.1f) | 全局位=(%.1f, %.1f)' % [
			i, u.name, 碰撞信息, 偏移.x, 偏移.y, u.global_position.x, u.global_position.y])
	日志.写日志('')
	print('[F9] ✅ 已记录 %d 个单位的位置到日志' % 有效计数)
	print('[F9]    中心=(%.1f, %.1f), 查看 _formation_log.txt' % [中心.x, 中心.y])
