extends 移动基类


@onready var 选中标签: Label = $选中标签
@onready var 动画: AnimatedSprite2D = $角色动画





const 速度 = 180

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("可选单位")
	add_to_group("同阵营单位")
	移动速度 = 速度


func _process(_delta: float) -> void:
	选中标签.visible = 选择状态

func _physics_process(_delta: float) -> void:
	super._physics_process(_delta)
	if 选择状态 :
		var 移动方向 = (目标位置 - global_position).normalized()
		动画.flip_h = 移动方向.x < 0 # 设置动画水平翻转（关键优化点）当x分量<0时向左移动，需要翻转精灵
