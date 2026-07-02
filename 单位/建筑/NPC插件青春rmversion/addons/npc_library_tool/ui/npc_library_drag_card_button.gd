@tool
extends Button

## 由 NpcLibraryDock 赋值
var dock: Node = null
var source_index: int = -1


func _get_drag_data(_at_position: Vector2) -> Variant:
	if dock == null or not dock.has_method("npc_drag_build_payload"):
		return null
	return dock.npc_drag_build_payload(source_index, self)


func _notification(what: int) -> void:
	if dock == null:
		return
	match what:
		NOTIFICATION_DRAG_BEGIN:
			if dock.has_method("npc_drag_on_card_drag_begin"):
				dock.npc_drag_on_card_drag_begin(source_index)
		NOTIFICATION_DRAG_END:
			if dock.has_method("npc_drag_on_source_end_deferred"):
				dock.npc_drag_on_source_end_deferred()
