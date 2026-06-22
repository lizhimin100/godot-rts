class_name 酒馆图像 extends Area2D

signal 进入酒馆
@onready var 轮廓高亮组件: 轮廓高亮组件 = $轮廓高亮组件



func _on_酒馆按钮_mouse_entered() -> void:
	轮廓高亮组件.highlight()


func _on_酒馆按钮_mouse_exited() -> void:
	轮廓高亮组件.clear_highlight()


func _on_酒馆按钮_pressed() -> void:
	进入酒馆.emit()
