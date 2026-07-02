@tool
extends EditorPlugin

const DockScene := preload("res://addons/npc_library_tool/ui/npc_library_dock_v2.gd")

var _dock: Control
## 主工作区内部名（2D / 3D / Script 等）。拖放仅在 2D 时完成，避免误在脚本等界面松手仍生成。
var _editor_main_screen_name := "2D"
## 拖入 NPC 后由 Dock 置位，在下一帧 _process 里 save_scene（避免 progress_dialog / list.h 报错）。
var _pending_auto_save_edited_scene := false

func _enter_tree() -> void:
	set_process_input(true)
	set_process(true)
	_dock = DockScene.new()
	_dock.name = "AI资源库"
	if _dock.has_method("setup"):
		_dock.setup(get_editor_interface(), self)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	main_screen_changed.connect(_on_editor_main_screen_changed)


func _on_editor_main_screen_changed(screen_name: String) -> void:
	_editor_main_screen_name = screen_name


## 不依赖 _forward_canvas_gui_input（_handles 为 false 或场景无选中时引擎常常不转发）。
func _input(event: InputEvent) -> void:
	if _dock == null:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _editor_main_screen_name != "2D":
		return
	if _dock.has_method("complete_npc_drag_if_over_2d_viewport"):
		_dock.complete_npc_drag_if_over_2d_viewport()


func request_schedule_auto_save_edited_scene() -> void:
	_pending_auto_save_edited_scene = true


func _process(_delta: float) -> void:
	if not _pending_auto_save_edited_scene:
		return
	_pending_auto_save_edited_scene = false
	var ei := get_editor_interface()
	if ei == null:
		return
	var err: Error = ei.save_scene()
	if err != OK:
		push_warning("[AI资源库] 自动保存当前场景失败：%s" % error_string(err))
		if is_instance_valid(_dock) and _dock.has_method("_set_status"):
			_dock._set_status("实例已放入场景，但自动保存失败，请手动 Ctrl+S（%s）" % error_string(err))


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
