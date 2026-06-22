extends CardState# 基础状态

func enter() -> void:
	if not card_ui.is_node_ready():
		await card_ui.ready
	
	card_ui.reqarent_requested.emit(card_ui)
	card_ui.调试区域.color = Color.WEB_GREEN
	card_ui.状态.text = "BASE"
	card_ui.pivot_offset = Vector2.ZERO

func _on_gui_input(event : InputEvent) -> void:
	if event.is_action_pressed("拿起"):
		card_ui.pivot_offset = card_ui.get_global_mouse_position() - card_ui.global_position
		transition_requested.emit(self , CardState.State.CLICKED)





	
