extends Node2D
class_name 可复用文字框
signal 淡出完成
@onready var 文字容器: Label = $文本容器/对话框容器/边距/网格容器/文字容器
@onready var 文字淡出效果: AnimationPlayer = $文本容器/文字淡出效果

func 立即淡出():
	文字淡出效果.play("立刻淡出")


# 外部调用接口：设置文字并启动动画
func 显示文字 (内容: String , 位置 : Vector2) -> void :
	文字容器.text = 内容
	global_position = 位置
	文字淡出效果.play("淡入")
	await get_tree().create_timer(1.5).timeout
	文字淡出效果.play("淡出")
