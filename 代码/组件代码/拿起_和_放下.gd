class_name 拖放组件 extends Node
signal 开始拖动
signal 取消拖动(目标位置 : Vector2)
signal 放下目标(目标位置 : Vector2)
signal drap

@export var 启用 :bool = true
@export var 拖放组件目标 : Area2D

var 目标位置 : Vector2
var offset := Vector2.ZERO
var 是否拖动 := false
var 已放下 := false


func _ready() -> void:
	assert(拖放组件目标 , "不，拖放组件没有设置对应单位")
	拖放组件目标.input_event.connect(_on_target_input_event.unbind(1))
	self.drap.connect(_on_dragging)

func _physics_process(delta: float) -> void:
	if 是否拖动 and 拖放组件目标:
		拖放组件目标.global_position = 拖放组件目标.get_global_mouse_position() + offset

func _input(event: InputEvent) -> void:
	if 是否拖动 and event.is_action_pressed("取消拿起"):
		_cancel_dragging()
	elif 是否拖动 and event.is_action_released("拿起"):
		_drog()
		已放下 = true

func _end_dragging()-> void:
	是否拖动 = false
	拖放组件目标.remove_from_group("dragging")
	拖放组件目标.z_index = 0

func _cancel_dragging()-> void :
	_end_dragging()
	取消拖动.emit(目标位置)

func _stat_dragging() -> void:
	是否拖动 = true
	目标位置 = 拖放组件目标.global_position
	拖放组件目标.add_to_group("dragging")
	拖放组件目标.z_index = 99
	offset = 拖放组件目标.global_position - 拖放组件目标.get_global_mouse_position()
	开始拖动.emit()

func _drog() -> void:
	_end_dragging()
	放下目标.emit(目标位置)
	drap.emit()

func _on_dragging() -> void:
	await get_tree().create_timer(0.5).timeout
	已放下 = false

func _on_target_input_event(_viewport : Node , event : InputEvent ) -> void :
	if not 启用 :
		return
	
	var 拖放对象 := get_tree().get_first_node_in_group("dragging")
	
	if not 是否拖动 and 拖放对象 :#安全代码检查
		return
	if  not 是否拖动 and  not 已放下 and event.is_action_released("拿起") :
		_stat_dragging()
