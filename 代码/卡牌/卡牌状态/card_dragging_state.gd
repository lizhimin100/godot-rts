extends CardState #拖拽状态

func enter() -> void:
	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
	if ui_layer:
		card_ui.reparent(ui_layer)
	
	card_ui.调试区域.color = Color.NAVY_BLUE
	card_ui.状态.text = "DRAGGING"

func on_input(event : InputEvent) -> void:
	var mouse_motion := event is InputEventMouseMotion#鼠标移动的布尔值
	var cancel := event.is_action_pressed("取消拿起")
	var confirm := event.is_action_released("拿起") or event.is_action_pressed("拿起")
	
	if mouse_motion:
		card_ui.global_position = card_ui.get_global_mouse_position() - card_ui.pivot_offset
		
	if cancel:
		transition_requested.emit(self , CardState.State.BASE)
	elif confirm:
		get_viewport().set_input_as_handled()#标记已处理
		transition_requested.emit(self , CardState.State.RELEASED)
	
