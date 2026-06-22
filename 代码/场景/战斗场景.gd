extends Node2D




func _on_拖放_单位放下(单位场景 , position) -> void:
	var 拖放单位 = 单位场景.instantiate()
	add_child(拖放单位)
	var 世界坐标 = get_viewport().get_camera_2d().get_screen_position() + position
	拖放单位.global_position = 世界坐标
	
