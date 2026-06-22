extends Node2D
var 开始选择 = Vector2.ZERO
@onready var 选择检查: Area2D = $选择检查
@onready var 框选碰撞: CollisionShape2D = $选择检查/框选碰撞



func _input(event) -> void:
	 # 当选择起始点为原点且事件是鼠标左键按下时
	if ( 开始选择 == Vector2.ZERO && event is InputEventMouseButton  
		&& event.button_index == 1 && event.is_pressed() ) :
			开始选择 = get_global_mouse_position() # 记录框选起点坐标
	# 当已经存在选择起始点且鼠标左键释放时
	elif ( 开始选择 != Vector2.ZERO && event is InputEventMouseButton 
		&& event.button_index == 1 ):
			选择单位()
			开始选择 = Vector2.ZERO # 重置选择起始点

func _process(_delta: float) -> void:
	queue_redraw() # 请求重绘界面

func _draw() -> void:
	if 开始选择 == Vector2.ZERO : return # 无选择时不绘制
	# 获取当前鼠标全局坐标
	var 鼠标位置 = get_global_mouse_position()
	# 框选坐标参数
	var 起点X = 开始选择.x
	var 起点Y = 开始选择.y
	var 终点X = 鼠标位置.x
	var 终点Y = 鼠标位置.y

	#框选款式
	var 线宽 = 3.0
	var 线条颜色 = Color.WHITE

	draw_line(Vector2(起点X, 起点Y), Vector2(终点X, 起点Y), 线条颜色, 线宽)# 上边
	draw_line(Vector2(起点X, 起点Y), Vector2(起点X, 终点Y), 线条颜色, 线宽)# 左边
	draw_line(Vector2(终点X, 起点Y), Vector2(终点X, 终点Y), 线条颜色, 线宽)# 右边
	draw_line(Vector2(起点X, 终点Y), Vector2(终点X, 终点Y), 线条颜色, 线宽)# 下边

func 选择单位 () :
	var 大小 = abs(get_global_mouse_position() - 开始选择)
	var 框选区域位置 = 选择区域起始位置()   # 获取框选区域左上角坐标
	# 更新碰撞区域位置和尺寸
	选择检查.global_position = 框选区域位置
	框选碰撞.global_position =框选区域位置 + 大小 / 2
	框选碰撞.shape.size = 大小
	
	await get_tree().create_timer(0.04).timeout
	# 获取所有单位并检测重叠
	var 所有单位 = get_tree().get_nodes_in_group("可选单位")
	
	for 单位 in 选择检查.get_overlapping_bodies():
		if 单位 in get_tree().get_nodes_in_group("可选单位") :
			单位.选择状态 = true
			所有单位.erase(单位)
		 # 取消未选中单位状态
	for 单位 in 所有单位:
		单位.选择状态 = false



func 选择区域起始位置() :
	var 新位置 = Vector2.ZERO  # ⭐ 关键修正点
	var 鼠标位置 = get_global_mouse_position()
	# 计算X轴起点（取最小坐标）
	if 开始选择.x < 鼠标位置.x:
		新位置.x = 开始选择.x
	else : 新位置.x = 鼠标位置.x
	# 计算Y轴起点（取最小坐标）
	if 开始选择.y < 鼠标位置.y:
		新位置.y = 开始选择.y
	else: 新位置.y = 鼠标位置.y
	return 新位置
