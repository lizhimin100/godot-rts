extends Control

@onready var 选中标签: Label = $选中标签

func _ready() -> void:
	选中标签.visible = false

func 是否选中(选择状态) -> void :
	选中标签.visible = 选择状态
