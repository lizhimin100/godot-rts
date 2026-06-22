extends Control
func 显示文字(内容: String) -> void:
	$"介绍文本".text = 内容
	size = $"介绍文本".size + Vector2(20, 10)
	$"介绍文本".position = (size - $"介绍文本".size)/2
func _process(_delta: float) -> void:
	var 视口大小 := get_viewport_rect().size
	global_position.x = clamp(global_position.x, 0, 视口大小.x - size.x)
	global_position.y = clamp(global_position.y, 0, 视口大小.y - size.y)
