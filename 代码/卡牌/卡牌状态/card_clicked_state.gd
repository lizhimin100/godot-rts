extends CardState #点击状态

func enter() -> void:
	card_ui.调试区域.color = Color.ORANGE
	card_ui.状态.text = "CLICKED"
	card_ui.drop_point_detector.monitoring = true

func on_input(event : InputEvent) -> void:
	if event is InputEventMouse:
		transition_requested.emit(self , CardState.State.DRAGGING)
