extends 移动基类


@onready var 非阵营标签: Label = $非阵营标签
@onready var 选中标签: Label = $选中标签


const 速度 = 200


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("可选单位")


func _process(_delta: float) -> void:

	非阵营标签.visible = false
	if  self.is_in_group("同阵营单位")  :
		选中标签.visible = 选择状态
	else : 非阵营标签.visible = 选择状态

 
