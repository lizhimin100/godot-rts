extends 交互基础组件



# Called when the node enters the scene tree for the first time.
func 加可交互对象(_可交互目标: Node) -> void :
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func 去可交互对象(_可交互目标: Node) -> void:
	pass

func 弹出文字框 (触发目标  , 介绍内容: String , 位置: Vector2 ) ->void :
	var 文字框实例 = 文本框.instantiate()
	global_position = 位置 
	if is_instance_valid(文字框实例):
		get_tree().current_scene.add_child(文字框实例)
		
		# 处理旧文字框
		处理旧文字框()
		
		# 更新实例列表
		文字框实例列表.clear()
		文字框实例列表.append(文字框实例)
		
		# 显示文字框
		文字框实例.显示文字(str(触发目标.name , ":" , 介绍内容 ), global_position)
