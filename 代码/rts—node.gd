extends Node2D

## rts-node — RTS 输入协调节点 v2
## 处理：左键框选/点选 + 右键统一发送命令 + A-move

static var _全局实例: Node2D = null

func _enter_tree() -> void:
	_全局实例 = self
	add_to_group("rts")

func _exit_tree() -> void:
	if _全局实例 == self:
		_全局实例 = null

## 供外部获取实例（兼容热更新）
static func 获取实例() -> Node2D:
	return _全局实例

var 开始选择 = Vector2.ZERO
var 鼠标按住中: bool = false

# 右键标记
var _右键标记位置: Vector2 = Vector2.ZERO
var _右键标记时长: float = 0.0
var _右键标记攻击: bool = false

# 鼠标光标
var _光标帧计数: int = 0
var _光标是攻击: bool = false

# A-move 模式
var _amove模式中: bool = false

# 当前选中单位列表
var _选中单位列表: Array[Node] = []

# ⭐ 框选优先级设置：true=单位优先于建筑，false=建筑优先于单位
@export var 框选优先单位: bool = true

@onready var 选择检查: Area2D = $选择检查
@onready var 框选碰撞: CollisionShape2D = $选择检查/框选碰撞


func 判断右键是否为攻击(点击位置: Vector2) -> bool:
	var 空间 = get_world_2d().direct_space_state
	var 查询 = PhysicsPointQueryParameters2D.new()
	查询.position = 点击位置
	查询.collision_mask = 16  # 敌人碰撞层
	var 结果 = 空间.intersect_point(查询)
	for 碰撞 in 结果:
		var 目标 = 碰撞.collider
		if 目标 and 目标.has_method("_是敌人") and 目标._是敌人() and 目标.当前生命值 > 0:
			return true

	# 也检测建筑
	查询.collision_mask = 16
	var 结果2 = 空间.intersect_point(查询)
	for 碰撞 in 结果2:
		var 目标 = 碰撞.collider
		if 目标 and 目标.has_method("_是敌人") and 目标._是敌人():
			return true

	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:

		if event.button_index == 1:
			if event.is_pressed() and not 鼠标按住中:
				# A-move 模式：左键发送攻击移动，跳过选择
				if _amove模式中:
					_amove模式中 = false
					_发送攻击移动命令(get_global_mouse_position())
					Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
					return

				鼠标按住中 = true
				开始选择 = get_global_mouse_position()

			elif event.is_released() and 鼠标按住中:
				鼠标按住中 = false
				选择单位()
				开始选择 = Vector2.ZERO
				queue_redraw()

		elif event.button_index == 2:
			# 右键 → 命令
			if event.is_pressed():
				var 点击位置 = get_global_mouse_position()
				var 是攻击指令: bool = 判断右键是否为攻击(点击位置)
				_显示右键标记(点击位置, 是攻击指令)
				_发送命令(点击位置, 是攻击指令)

	elif event is InputEventKey:
		if event.is_action_pressed("移动") and event.is_pressed():
			_amove模式中 = true
			print("⚔️ A-move 模式已激活，左键点击地面发送攻击移动命令")


func _process(_delta: float) -> void:
	if 开始选择 != Vector2.ZERO:
		queue_redraw()

	# 右键标记淡出
	if _右键标记时长 > 0:
		_右键标记时长 -= _delta
		queue_redraw()

	# 鼠标悬停检测：移到敌人上变攻击光标
	_更新鼠标光标()


## 鼠标悬停到敌人上方时切换光标
func _更新鼠标光标() -> void:
	_光标帧计数 += 1
	if _光标帧计数 % 5 != 0:
		return

	var 鼠标位置 = get_global_mouse_position()
	var 空间 = get_world_2d().direct_space_state
	var 查询 = PhysicsPointQueryParameters2D.new()
	查询.position = 鼠标位置
	查询.collision_mask = 16
	if 鼠标按住中:
		return
	var 结果 = 空间.intersect_point(查询)
	var 发现敌人: bool = false
	for 碰撞 in 结果:
		var 目标 = 碰撞.collider
		if 目标 and 目标.has_method("_是敌人") and 目标._是敌人():
			if 目标.当前生命值 > 0:
				发现敌人 = true
			break
	if 发现敌人 != _光标是攻击:
		_光标是攻击 = 发现敌人
		if 发现敌人:
			Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
		else:
			Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


## 发送命令到所有选中单位
func _发送命令(点击位置: Vector2, 是攻击: bool) -> void:
	var 目标: Node2D = _获取点击目标(点击位置)
	var 有选中单位 = false

	# 获取当前所有选中单位
	_选中单位列表 = []
	for 单位 in get_tree().get_nodes_in_group("可选单位"):
		if 单位.选择状态:
			_选中单位列表.append(单位)
			有选中单位 = true

	if not 有选中单位:
		return

	if 是攻击 and 目标:
		# 右键点到敌人 → 攻击
		for 单位 in _选中单位列表:
			if 单位.has_method("命令攻击"):
				单位.命令攻击(目标)
	else:
		# 右键点到空地 → 移动
		var total: int = _选中单位列表.size()
		for i in range(total):
			var 单位 = _选中单位列表[i]
			if 单位.has_method("命令移动"):
				单位.命令移动(点击位置)
				# 分配阵型 slot，锁住直到下次新命令
				var slot: Vector2 = UnitFormation.get_slot_offset(i, total)
				if "unit_controller" in 单位 and 单位.unit_controller: 单位.unit_controller.formation_offset = slot


## 发送攻击移动命令（A-move）
func _发送攻击移动命令(点击位置: Vector2) -> void:
	_选中单位列表 = []
	for 单位 in get_tree().get_nodes_in_group("可选单位"):
		if 单位.选择状态:
			_选中单位列表.append(单位)

	var total: int = _选中单位列表.size()
	for i in range(total):
		var 单位 = _选中单位列表[i]
		if 单位.has_method("命令移动"):
			单位.命令移动(点击位置, true)
			# 分配阵型 slot（A-move 也保持阵型）
			var slot: Vector2 = UnitFormation.get_slot_offset(i, total)
			if "unit_controller" in 单位 and 单位.unit_controller: 单位.unit_controller.formation_offset = slot


## 获取点击位置的目标节点
func _获取点击目标(点击位置: Vector2) -> Node2D:
	var 空间 = get_world_2d().direct_space_state

	# 先查敌人（collision_layer 16）
	var 查询 = PhysicsPointQueryParameters2D.new()
	查询.position = 点击位置
	查询.collision_mask = 16
	var 结果 = 空间.intersect_point(查询)
	for 碰撞 in 结果:
		var 目标 = 碰撞.collider
		if 目标 and is_instance_valid(目标) and 目标.当前生命值 > 0:
			if 目标.has_method("_是敌人") or 目标.has_method("获取阵营"):
				return 目标

	return null


## 在右键点击位置显示标记
func _显示右键标记(位置: Vector2, 是攻击: bool) -> void:
	_右键标记位置 = 位置
	_右键标记时长 = 1.2
	_右键标记攻击 = 是攻击
	queue_redraw()


func _draw() -> void:
	# 框选框
	if 开始选择 != Vector2.ZERO:
		var 鼠标位置 = get_global_mouse_position()
		var 起点X = 开始选择.x
		var 起点Y = 开始选择.y
		var 终点X = 鼠标位置.x
		var 终点Y = 鼠标位置.y
		var 线宽 = 3.0
		var 线条颜色 = Color.WHITE

		draw_line(Vector2(起点X, 起点Y), Vector2(终点X, 起点Y), 线条颜色, 线宽)
		draw_line(Vector2(起点X, 起点Y), Vector2(起点X, 终点Y), 线条颜色, 线宽)
		draw_line(Vector2(终点X, 起点Y), Vector2(终点X, 终点Y), 线条颜色, 线宽)
		draw_line(Vector2(起点X, 终点Y), Vector2(终点X, 终点Y), 线条颜色, 线宽)

	# 右键标记（增强版）
	if _右键标记时长 > 0:
		var 位置 = _右键标记位置
		var 进度: float = 1.0 - (_右键标记时长 / 1.2)  # 0→1
		var 透明度: float = min(_右键标记时长 / 1.2, 1.0)

		if _右键标记攻击:
			# 攻击标记：红色 X + 外圈
			var 颜色 = Color(1, 0.2, 0.2, 透明度)
			var 线宽 = 4.0 * 透明度
			# 外圈膨胀
			var 外圈半径 = 16.0 + 进度 * 20.0
			var 外圈透明度 = 透明度 * (1.0 - 进度 * 0.5)
			if 外圈透明度 > 0.05:
				draw_arc(位置, 外圈半径, 0, 2*PI, 24, Color(1, 0.3, 0.3, 外圈透明度), 2.0 * 外圈透明度)
			# X 标记
			var s = 12.0
			draw_line(位置 + Vector2(-s, -s), 位置 + Vector2(s, s), 颜色, 线宽)
			draw_line(位置 + Vector2(s, -s), 位置 + Vector2(-s, s), 颜色, 线宽)
		else:
			# 移动标记：白色圈 + 波纹扩散
			var 颜色 = Color(1, 1, 1, 透明度)
			# 主圈
			draw_arc(位置, 18.0, 0, 2*PI, 24, 颜色, 3.5 * 透明度)
			# 波纹圈（向外扩散）
			var 波纹半径 = 18.0 + 进度 * 30.0
			var 波纹透明度 = 透明度 * (1.0 - 进度) * 0.8
			if 波纹透明度 > 0.05:
				draw_arc(位置, 波纹半径, 0, 2*PI, 24, Color(1, 1, 1, 波纹透明度), 2.0 * 波纹透明度)
			# 中心点
			draw_circle(位置, 2.5 * 透明度, 颜色)


func 选择单位() -> void:
	var 鼠标位置 = get_global_mouse_position()
	var 大小 = abs(鼠标位置 - 开始选择)

	# ⭐ 极小拖动→当作点选，防误触
	if 大小.length() < 15.0 or (大小.x < 20 and 大小.y < 20):
		_点选单位(鼠标位置)
	else:
		await _框选单位(开始选择, 大小)


func _获取操作UI():
	# 1. 静态引用（兼容热更新）
	if 操作UI.获取实例() != null and is_instance_valid(操作UI.获取实例()):
		return 操作UI.获取实例()
	# 2. 组查找
	var ui = get_tree().get_first_node_in_group("操作UI")
	if ui:
		return ui
	# 3. 硬编码路径回退（平面测试场景）
	var fallback = get_node_or_null("/root/平面/UI层/操作UI")
	if fallback:
		return fallback
	# 4. 世界岛场景路径回退
	fallback = get_node_or_null("/root/世界岛场景/布局渲染/操作UI")
	return fallback

func _清除选择UI():
	var ui = _获取操作UI()
	if ui:
		ui._clear_selection()

func _点选单位(点击位置: Vector2) -> void:
	for 单位 in get_tree().get_nodes_in_group("可选单位"):
		单位.选择状态 = false

	var 空间 = get_world_2d().direct_space_state
	var 查询 = PhysicsPointQueryParameters2D.new()
	查询.position = 点击位置
	查询.collide_with_bodies = true
	查询.collision_mask = 12  # 8(操作单位) + 4(建筑)
	var 结果 = 空间.intersect_point(查询)

	# 点选：优先选移动单位，建筑次之（建筑靠点选，保持大碰撞体积）
	var 选中的单位 = null
	var 选中的建筑 = null

	for 碰撞结果 in 结果:
		var 目标 = 碰撞结果.collider
		if not 目标 or not 目标.is_in_group("可选单位"):
			continue
		if 目标.is_in_group("移动单位") and 选中的单位 == null:
			选中的单位 = 目标
		elif 目标.is_in_group("建筑") and 选中的建筑 == null:
			选中的建筑 = 目标

	var 最终选中 = 选中的单位 if 选中的单位 != null else 选中的建筑
	if 最终选中 != null:
		最终选中.选择状态 = true
		var ui = _获取操作UI()
		if ui:
			ui._on_selection_changed([最终选中])
		return

	_清除选择UI()

func _框选单位(起点: Vector2, 大小: Vector2) -> void:
	# ⭐ 立即清除所有选择，防止 await 期间旧选择被右键命令读取
	for 单位 in get_tree().get_nodes_in_group("可选单位"):
		单位.选择状态 = false

	var 框选区域位置 = 选择区域起始位置()
	选择检查.global_position = 框选区域位置
	框选碰撞.global_position = 框选区域位置 + 大小 / 2
	框选碰撞.shape.size = 大小

	await get_tree().create_timer(0.04).timeout

	var 所有可选 = get_tree().get_nodes_in_group("可选单位")
	var 框选单位列表: Array = []
	var 框选建筑列表: Array = []

	# 分离重叠体为"单位"和"建筑"
	for 目标 in 选择检查.get_overlapping_bodies():
		if not 目标 in 所有可选:
			continue
		if 目标.is_in_group("建筑"):
			框选建筑列表.append(目标)
		elif 目标.is_in_group("移动单位"):
			框选单位列表.append(目标)
		所有可选.erase(目标)

	# ⭐ 根据优先级决定最终选中
	var 最终选中: Array
	var 被排除的: Array  # 框选范围内但未选中的（需要强制取消选择）
	if 框选优先单位:
		# 单位优先：有单位时只选单位，无单位时才选建筑
		最终选中 = 框选单位列表 if not 框选单位列表.is_empty() else 框选建筑列表
		被排除的 = 框选建筑列表 if not 框选单位列表.is_empty() else []
	else:
		# 建筑优先
		最终选中 = 框选建筑列表 if not 框选建筑列表.is_empty() else 框选单位列表
		被排除的 = 框选单位列表 if not 框选建筑列表.is_empty() else []

	for 目标 in 所有可选:
		目标.选择状态 = false
	for 目标 in 被排除的:
		目标.选择状态 = false
	for 目标 in 最终选中:
		目标.选择状态 = true

	if 最终选中.is_empty():
		_清除选择UI()
	else:
		var ui = _获取操作UI()
		if ui:
			ui._on_selection_changed(最终选中)


func 选择区域起始位置() -> Vector2:
	var 新位置 = Vector2.ZERO
	var 鼠标位置 = get_global_mouse_position()
	if 开始选择.x < 鼠标位置.x:
		新位置.x = 开始选择.x
	else:
		新位置.x = 鼠标位置.x
	if 开始选择.y < 鼠标位置.y:
		新位置.y = 开始选择.y
	else:
		新位置.y = 鼠标位置.y
	return 新位置


## 获取最后右键标记位置（供操作UI调用）
func 获取最后标记位置() -> Vector2:
	return _右键标记位置
