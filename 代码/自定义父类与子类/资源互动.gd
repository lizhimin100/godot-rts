extends 互动


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	发生交互.connect(资源采集)

func 资源采集 () :
	var 蘑菇物品 = preload("res://物品系统/物品/蘑菇.tres")
	print("已采集蘑菇。")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
