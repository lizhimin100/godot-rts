class_name 交互基础组件
extends Node2D
var 当前文字框 = null
var 交互对象 : Array[互动]
var 文字框实例列表 = []
var 附近可交互对象 : Array = []  # 存储进入交互区域的物体
@export var 文本框 = preload("res://对象资源/文本框节点.tscn")


func 加可交互对象(可交互目标: Node) -> void :
	if 可交互目标 in 交互对象 :
		return
	交互对象.append(可交互目标)
	print("玩家已添加可交互对象：", 可交互目标.name)
	弹出文字框(可交互目标 , null , null) #将可交互目标作为弹出文字框函数的参数传入

func 去可交互对象(可交互目标: Node) -> void:
	交互对象.erase(可交互目标)
	if 可交互目标 in 附近可交互对象:
		附近可交互对象.erase(可交互目标)
		print("玩家已移除可交互对象：",可交互目标.name)


func 弹出文字框 (触发目标 , _介绍内容 , _位置) ->void :
	var 文字框实例 = 文本框.instantiate()
	if is_instance_valid(文字框实例):
		get_tree().current_scene.add_child(文字框实例)
		
		# 处理旧文字框
		处理旧文字框()
		
		# 更新实例列表
		文字框实例列表.clear()
		文字框实例列表.append(文字框实例)
		
		# 显示文字框
		文字框实例.显示文字(str("发现目标：", 触发目标.name), global_position)

func 处理旧文字框() -> void :
	if 文字框实例列表.size() > 0:
		var 旧文字框 = 文字框实例列表[0]
		if is_instance_valid(旧文字框):
			旧文字框.立即淡出()
