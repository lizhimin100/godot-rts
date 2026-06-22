extends CardState #释放状态

func enter() -> void:
	card_ui.调试区域.color = Color.DARK_VIOLET
	card_ui.状态.text = "RELEASED"
