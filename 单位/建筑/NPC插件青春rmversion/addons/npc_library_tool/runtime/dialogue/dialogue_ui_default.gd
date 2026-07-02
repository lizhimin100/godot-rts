@tool
extends CanvasLayer

signal dialogue_sequence_finished

const _InputSafe := preload("res://addons/npc_library_tool/runtime/npc_input_safe.gd")
const GROUP_NAME := "dialogue_ui"
const INNER_VOICE_COLOR := "#c9b8ff"
const BODY_FONT_SIZE := 32
const INNER_FONT_SIZE := 32
const DIALOG_TEXTURE_SIZE := Vector2(2500.0, 600.0)
const BODY_TEXT_ORIGIN_IN_TEXTURE := Vector2(290.0, 138.0)
const BODY_TEX_INSET_RIGHT := 300.0
const BODY_TEX_INSET_BOTTOM := 48.0

## 预制 UI 布局按此「设计画布」像素对齐（老项目 1920×1080）；其它分辨率下整面板等比缩放
const DEFAULT_DESIGN_VIEWPORT := Vector2(1920.0, 1080.0)

## 可在检查器中覆盖，便于不同项目统一改基准
@export var design_reference_size: Vector2 = DEFAULT_DESIGN_VIEWPORT
## 视口相对设计稿的缩放系数 clamp，避免极小/极大窗口变形过大
@export var dialogue_scale_min: float = 0.38
@export var dialogue_scale_max: float = 2.6
## 为 true 时保留场景里 BodyMargin 的边距，不再按底图纹理比例覆盖（便于在编辑器里手调布局）
@export var use_scene_body_margins: bool = false

@onready var _root: Control = $Root
@onready var _dialog_panel: Control = $Root/DialogPanel
@onready var _click_advance: Control = $Root/ClickAdvance
@onready var _portrait_frame: TextureRect = $Root/DialogPanel/PortraitFrame
@onready var _portrait: TextureRect = %Portrait
@onready var _name_plate: TextureRect = $Root/DialogPanel/NamePlate
@onready var _name_label: Label = %NameLabel
@onready var _body: RichTextLabel = %BodyText
@onready var _dialog_bg: TextureRect = $Root/DialogPanel/DialogBg
@onready var _body_margin: MarginContainer = $Root/DialogPanel/DialogBg/BodyVBox/BodyMargin

var _lines: Array[Dictionary] = []
var _index := 0
var _player_portrait: Texture2D
var _voice_player: AudioStreamPlayer
var _pending_dialogue_uniform_scale := 1.0
var _scale_apply_attempts := 0


func _enter_tree() -> void:
	# 尽早注册组，避免同一帧内多个 NPC 首次对话时重复实例化对话层（_ready 较晚）
	add_to_group(GROUP_NAME)


func _ready() -> void:
	layer = 100
	visible = false
	set_process_unhandled_input(false)
	if not Engine.is_editor_hint():
		var vp := get_viewport()
		if vp != null and not vp.size_changed.is_connected(_on_viewport_size_changed):
			vp.size_changed.connect(_on_viewport_size_changed)
	if ResourceLoader.exists("res://addons/npc_library_tool/runtime/dialogue/assets/占位图1.png"):
		_player_portrait = load("res://addons/npc_library_tool/runtime/dialogue/assets/占位图1.png") as Texture2D
	else:
		_player_portrait = null
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body.fit_content = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not _dialog_bg.resized.is_connected(_on_dialog_bg_resized):
		_dialog_bg.resized.connect(_on_dialog_bg_resized)
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoicePlayer"
	add_child(_voice_player)
	_sync_body_margins_to_dialog_texture()
	_click_advance.gui_input.connect(_on_click_advance_gui_input)
	_sync_click_layer_visible()
	call_deferred("_apply_dialogue_panel_scale_to_viewport")


func _on_viewport_size_changed() -> void:
	_apply_dialogue_panel_scale_to_viewport()


## 按当前游戏视口与设计稿短边比例做**统一**缩放，pivot 在面板底边中心，避免锚在底部时缩放跑偏
func _apply_dialogue_panel_scale_to_viewport() -> void:
	if Engine.is_editor_hint() or _dialog_panel == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vsize: Vector2 = vp.get_visible_rect().size
	if vsize.x < 2.0 or vsize.y < 2.0:
		return
	var ref := design_reference_size
	if ref.x < 1.0 or ref.y < 1.0:
		ref = DEFAULT_DESIGN_VIEWPORT
	var sx := vsize.x / ref.x
	var sy := vsize.y / ref.y
	_pending_dialogue_uniform_scale = clampf(minf(sx, sy), dialogue_scale_min, dialogue_scale_max)
	_scale_apply_attempts = 0
	call_deferred("_apply_dialogue_panel_scale_finalize")


func _apply_dialogue_panel_scale_finalize() -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_dialog_panel):
		return
	var psz: Vector2 = _dialog_panel.size
	if psz.x < 1.0 or psz.y < 1.0:
		_scale_apply_attempts += 1
		if _scale_apply_attempts < 10:
			call_deferred("_apply_dialogue_panel_scale_finalize")
		return
	_dialog_panel.pivot_offset = Vector2(psz.x * 0.5, psz.y)
	_dialog_panel.scale = Vector2(_pending_dialogue_uniform_scale, _pending_dialogue_uniform_scale)


func _on_dialog_bg_resized() -> void:
	_sync_body_margins_to_dialog_texture()


func _sync_body_margins_to_dialog_texture() -> void:
	if use_scene_body_margins:
		return
	if _dialog_bg == null or _body_margin == null:
		return
	var sz := _dialog_bg.size
	if sz.x < 1.0 or sz.y < 1.0:
		return
	var sx := sz.x / DIALOG_TEXTURE_SIZE.x
	var sy := sz.y / DIALOG_TEXTURE_SIZE.y
	_body_margin.add_theme_constant_override("margin_left", int(floor(BODY_TEXT_ORIGIN_IN_TEXTURE.x * sx)))
	_body_margin.add_theme_constant_override("margin_top", int(floor(BODY_TEXT_ORIGIN_IN_TEXTURE.y * sy)))
	_body_margin.add_theme_constant_override("margin_right", int(floor(BODY_TEX_INSET_RIGHT * sx)))
	_body_margin.add_theme_constant_override("margin_bottom", int(floor(BODY_TEX_INSET_BOTTOM * sy)))


func start_dialogue(lines: Array[Dictionary]) -> void:
	if lines.is_empty():
		dialogue_sequence_finished.emit()
		return
	_lines = lines
	_index = 0
	visible = true
	set_process_unhandled_input(true)
	_sync_click_layer_visible()
	call_deferred("_apply_dialogue_panel_scale_to_viewport")
	_show_line()


func _show_line() -> void:
	if _index >= _lines.size():
		_close()
		return
	var line: Dictionary = _lines[_index]
	var speaker := String(line.get("speaker", ""))
	var body := String(line.get("text", ""))
	var is_player := bool(line.get("is_player", false))
	var is_inner := bool(line.get("is_inner_voice", false))
	var hide_name := bool(line.get("hide_name", false))
	_name_label.text = speaker
	_name_plate.visible = not hide_name
	_name_label.visible = not hide_name
	if is_inner:
		_body.text = "[font_size=%d][i][color=%s]%s[/color][/i][/font_size]" % [INNER_FONT_SIZE, INNER_VOICE_COLOR, body]
	else:
		_body.text = "[font_size=%d]%s[/font_size]" % [BODY_FONT_SIZE, body]
	var tex := _portrait_texture_for_line(line, is_inner, is_player)
	if tex != null:
		_portrait_frame.visible = true
		_portrait.visible = true
		_portrait.texture = tex
	else:
		_portrait_frame.visible = false
		_portrait.visible = false
	_play_voice_for_line(line)


func _portrait_texture_for_line(line: Dictionary, is_inner: bool, is_player: bool) -> Texture2D:
	if is_inner or is_player:
		return _player_portrait
	var embedded: Variant = line.get("portrait", null)
	if embedded is Texture2D:
		return embedded as Texture2D
	var ppath := String(line.get("portrait_path", ""))
	if ppath == "":
		return null
	if not ResourceLoader.exists(ppath):
		return null
	var loaded := load(ppath)
	if loaded is Texture2D:
		return loaded as Texture2D
	return null


func _advance() -> void:
	_index += 1
	_show_line()


func _play_voice_for_line(line: Dictionary) -> void:
	if _voice_player == null:
		return
	_voice_player.stop()
	var embedded: Variant = line.get("voice_stream", null)
	if embedded is AudioStream:
		_voice_player.stream = embedded as AudioStream
		_voice_player.play()
		return
	var voice_path := String(line.get("voice_path", "")).strip_edges()
	if voice_path == "" or not ResourceLoader.exists(voice_path):
		_voice_player.stream = null
		return
	var loaded := load(voice_path)
	if loaded is AudioStream:
		_voice_player.stream = loaded as AudioStream
		_voice_player.play()
		return
	_voice_player.stream = null


func _close() -> void:
	visible = false
	set_process_unhandled_input(false)
	if _voice_player != null:
		_voice_player.stop()
	_lines.clear()
	_index = 0
	_sync_click_layer_visible()
	dialogue_sequence_finished.emit()


func _sync_click_layer_visible() -> void:
	_click_advance.visible = visible
	_click_advance.mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE


func _on_click_advance_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			_advance()
			_click_advance.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# 未在项目中添加 interact 等映射时，直接 is_action_pressed 会报错，必须先 has_action。
	if _InputSafe.event_any_action_pressed_safe(
			event,
			[&"interact", &"ui_accept", &"ui_select"]):
		_advance()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_E or key == KEY_F:
			_advance()
			get_viewport().set_input_as_handled()
