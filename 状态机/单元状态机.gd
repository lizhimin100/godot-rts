class_name 单元状态机
extends Node


var current_state: int = -1 :
	set(v):
		if owner and owner.has_method("状态动画"):
			owner.状态动画(current_state, v)
		current_state = v
		


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_state = 0


func _physics_process(delta: float) -> void:
	# 改为单次状态检查避免无限循环
	var 下一状态 = owner.get_next_state(current_state) as int
	if current_state != 下一状态:
		current_state = 下一状态
	owner.tick_physics(current_state, delta)
