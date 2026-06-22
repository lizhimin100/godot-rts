extends Control



func _on_返回按钮_pressed() -> void:
		#创建计时器，等待0.5秒后再跳转场景
	var 等待时间 :float = (0.25)
	var timer = get_tree().create_timer(等待时间)
	await timer.timeout
	queue_free()
