extends Control

signal 单位放下

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	
	
func _get_drag_data(at_position: Vector2):
	print("开始拖拽:", at_position)
	var 单位节点
	
	for node in get_tree().get_nodes_in_group("单位"):
		if node.拖放位置(at_position):
			单位节点 = node
			break  # 找到第一个匹配项即可
	if not 单位节点 : 
		print("未找到可拖拽单位")
		return null
	print("找到单位:", 单位节点.name)
	var 预览图像 = 单位节点.拖放预览()
	set_drag_preview(预览图像)
	return {
		"类型": "单位",
		"场景": 单位节点.单位场景,
		"来源": 单位节点
	}
	
func _can_drop_data(at_position , data) :
	print("可以放置:", at_position)
	return data != null && data.get("类型") == "单位"
func _drop_data(at_position , data):
	print("放置位置:", at_position)
	if data["类型"] == "单位":
		单位放下.emit(data.单位场景 , at_position)
