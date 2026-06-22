extends Camera2D
var 向右 = false
var 向左 = false
var 向上 = false
var 向下 = false
var 允许移动 : bool = true  

func _process(delta: float) -> void:
	if  not 允许移动:
		return  # 对话期间锁定相机
	
	
	var 鼠标位置 = get_local_mouse_position()# 获取鼠标位置 基础边缘滚动逻辑
	var 视口尺寸 = get_viewport_rect().size  # 获取视口尺寸
	var 移动向量 = Vector2.ZERO
	
	if 鼠标位置.x > 540:
		向右 = true
		向左 = false
	if 鼠标位置.x < -540:
		向右 = false
		向左 = true
	if 鼠标位置.x < 540 and 鼠标位置.x > - 540:
		向右 = false
		向左 = false
	if 鼠标位置.y > 280:
		向上 = false
		向下 = true
	if 鼠标位置.y < -280:
		向上 = true
		向下 = false
	if 鼠标位置.y < 280 and 鼠标位置.y > -280:
		向上 = false
		向下 = false

	if 向右 == true and position.x <= 2040 :
		position += Vector2(1, 0) * 6
		$"../UI/小地图/地图屏幕/ColorRect".position += Vector2(1 , 0) * .2
	if 向左 == true and position.x >= -870 :
		position -= Vector2(1, 0) * 6
		$"../UI/小地图/地图屏幕/ColorRect".position -= Vector2(1 , 0) * .2
	if 向下 == true and position.y <= 1740 :
		position += Vector2(0, 1) * 6
		$"../UI/小地图/地图屏幕/ColorRect".position += Vector2(0 , 1) * .2
	if 向上 == true and position.y >= -1060 :
		position -= Vector2(0, 1) * 6
		$"../UI/小地图/地图屏幕/ColorRect".position -= Vector2(0 , 1) * .2
