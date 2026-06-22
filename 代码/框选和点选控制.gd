extends Node2D
# 参数区域
@export var 选框颜色 := Color(1, 1, 1, 0.2)  # 选框颜色（可自定义）
@export var 选框边框颜色 := Color(1, 1, 1)    # 边框颜色（可自定义）
# 自定义变量
var 是否正在选择 := false
var 选择起点 := Vector2.ZERO
var 已选单位数组 := []  # 当前选中单位数组

func _unhandled_input(event): # 将事件坐标转换为局部坐标系
	if event is InputEventMouseButton:
		event = event as InputEventMouseButton
		event.position = to_local(event.position)
	if event is InputEventMouseMotion:
		event = event as InputEventMouseMotion
		event.position = to_local(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:# 鼠标左键按下事件（点选/框选开始）
		print("接收到输入事件:", event.get_class())
		print("鼠标按键状态:", event.pressed)
		if event.pressed:
			开始选择(event.position)
		else:
			结束选择(event.position)


func 开始选择(局部位置: Vector2):# 自定义函数：开始选择
	选择起点 = 局部位置
	是否正在选择 = true
	if not Input.is_key_pressed(KEY_CTRL):# 清空当前选择（按住Ctrl时追加选择）
		取消所有选择()

func 结束选择(结束位置: Vector2):# 自定义函数：结束选择
	# 坐标转换确保在局部坐标系
	是否正在选择 = false
	var 局部结束位置 = to_local(结束位置)
	var 实际起点 = Vector2(
		min(选择起点.x, 局部结束位置.x),
		min(选择起点.y, 局部结束位置.y)
	 )
	var 实际终点 = Vector2(
		max(选择起点.x, 局部结束位置.x),
		max(选择起点.y, 局部结束位置.y)
	)
	var 有效尺寸 = 实际终点 - 实际起点
	print("实际起点：", 实际起点, " 实际终点：", 实际终点, " 有效尺寸：", 有效尺寸)

	var 形状变换 = Transform2D()
	形状变换.origin = 实际起点 + (有效尺寸 * 0.5)
	# 创建矩形查询形状
	var 矩形形状 = RectangleShape2D.new()
	矩形形状.size = 有效尺寸.abs()  # ⭐ 新增绝对值保证
	var 查询参数 = PhysicsShapeQueryParameters2D.new()
	查询参数.collision_mask = 2
	查询参数.collide_with_areas = true
	查询参数.transform = 形状变换
	查询参数.shape_rid = 矩形形状.get_rid()


	var 检测结果 = get_world_2d().direct_space_state.intersect_shape(查询参数)
	# 处理选中单位
	for 结果 in 检测结果:
		var 单位 = 结果.collider.get_parent()  # 假设Area2D是单位的子节点
		if 单位.is_in_group("可选单位"):
			选中单位(单位)
# 自定义函数：点选单位
func 点选单位(点击位置: Vector2):
	var 物理空间 = get_world_2d().direct_space_state
	var 查询参数 = PhysicsShapeQueryParameters2D.new()
	查询参数.collide_with_areas = true
	查询参数.collision_mask = 2  # 关键修改点
	查询参数.position = 点击位置
	var 检测结果 = 物理空间.intersect_point(查询参数, 1)
	if 检测结果:
		var 单位 = 检测结果[0].collider.get_parent()
		选中单位(单位)
# 自定义函数：选中单位
func 选中单位(单位):
	if not 单位 in 已选单位数组:
		已选单位数组.append(单位)
		单位.被选中()  # 调用单位自身的选中方法
# 自定义函数：取消所有选择
func 取消所有选择():
	for 单位 in 已选单位数组:
		单位.取消选中()
	已选单位数组.clear()
# 内置函数：绘制选框
func _draw():
	if 是否正在选择:
		var 当前鼠标位置 = get_global_mouse_position()
		var 矩形 = Rect2(
			Vector2(
				min(选择起点.x, 当前鼠标位置.x),  # 直接使用选择起点
				min(选择起点.y, 当前鼠标位置.y)
			),
			Vector2(
				abs(当前鼠标位置.x - 选择起点.x),
				abs(当前鼠标位置.y - 选择起点.y)
			)
		)
		draw_rect(矩形, 选框颜色, true)
		draw_rect(矩形, 选框边框颜色, false, 2.0)
