@tool
extends TextureRect

## 由 NpcLibraryDock 赋值
var dock: Node = null


func _get_drag_data(_at_position: Vector2) -> Variant:
	if dock == null or not dock.has_method("npc_drag_data_for_preview"):
		return null
	return dock.npc_drag_data_for_preview(self)


func _notification(what: int) -> void:
	if dock == null:
		return
	match what:
		NOTIFICATION_DRAG_BEGIN:
			if dock.has_method("npc_drag_on_preview_drag_begin"):
				dock.npc_drag_on_preview_drag_begin()
		NOTIFICATION_DRAG_END:
			if dock.has_method("npc_drag_on_source_end_deferred"):
				dock.npc_drag_on_source_end_deferred()
