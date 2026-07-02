@tool
extends ScrollContainer

const RepoScript := preload("res://addons/npc_library_tool/core/npc_repository.gd")
const DragCardButtonScript := preload("res://addons/npc_library_tool/ui/npc_library_drag_card_button.gd")
const DragPreviewRectScript := preload("res://addons/npc_library_tool/ui/npc_library_drag_preview_rect.gd")
## 拖到 2D 视图时 gui_get_drag_data 字典中的标记键（与插件转发配合）
const NPC_DRAG_DICT_KEY := "npc_library_tool"
const DIALOG_ASSET_BASE := "res://addons/npc_library_tool/runtime/dialogue/assets/"
const DIALOG_ASSET_DIALOG_BG := DIALOG_ASSET_BASE + "对话框底图.png"
const DIALOG_ASSET_PORTRAIT_FRAME := DIALOG_ASSET_BASE + "特效小块.png"
const DIALOG_ASSET_NAME_PLATE := DIALOG_ASSET_BASE + "玩家与NPC名字条.png"
const CONTACT_TEXT := "联系方式：QQ 719937402\n收费版插件 / AI 像素技术培训 / 游戏资源解包培训 / 挂机脚本培训 / Godot 快速入门\n1、像素素材生成培训：角色到地形流程，含常规视频没有的技巧，2 小时远程桌面加语音。\n2、UE5 / Unity 像素游戏资源提取培训：经验之谈，外界无参考教程，1~2 小时。\n3、安卓模拟器游戏挂机脚本培训：熟悉工作室脚本流程，帮助快速上手自动化脚本。\n4、Godot 快速入门培训：AI 结合 Godot 开发技巧。\n5、满血版插件：带新模板，支持 HD2D 版本。"
const AD_DIALOGUE_LINES: Array[String] = [
	"广告：联系 QQ 719937402，可咨询收费版插件、AI 像素技术培训、游戏资源解包培训。",
	"像素素材生成培训：从像素角色生成流程到地形生成流程，除基础教学外会给常规视频里没有的技巧；2 小时，远程桌面加语音，效果是能独立定制自己的像素风格（有限）。",
	"像素资源提取培训：对 UE5 和 Unity 像素游戏提取做简单培训，完全经验之谈，外界无参考教程；1~2 小时，远程桌面加语音。",
	"游戏挂机脚本培训：安卓模拟器自动化写脚本，本人熟悉工作室脚本流程，帮助学员快速上手安卓游戏自动化脚本编写，常规游戏可自己写挂机脚本。",
	"Godot 快速入门培训：AI 结合 Godot 开发技巧；另有满血版插件，带新模板并支持 HD2D 版本。"
]
## 运行时与「UI框编辑」当前使用的对话界面场景（可被预设覆盖）
const DIALOGUE_UI_SCENE_PATH := "res://addons/npc_library_tool/runtime/dialogue/dialogue_ui_default.tscn"
## 插件内置「恢复默认」用的只读副本（首次与 dialogue_ui_default 一致；更新插件时可替换此文件）
const DIALOGUE_UI_BUILTIN_PATH := "res://addons/npc_library_tool/runtime/dialogue/dialogue_ui_default_builtin.tscn"
const DIALOGUE_LAYOUT_PRESETS_DIR := "res://addons/npc_library_tool/editor_data/dialogue_layout_presets/"
const DIALOGUE_LAYOUT_PRESETS_INDEX := "res://addons/npc_library_tool/editor_data/dialogue_layout_presets_index.json"
const DialogueLayoutPresetIo := preload("res://addons/npc_library_tool/ui/dialogue_layout_preset_io.gd")

## 与 AI 像素商 K 一致的一图全动作切帧（固定区域表，非均匀网格）；随插件内置。
const BUNDLED_OCAD_GENERATOR := "res://addons/npc_library_tool/core/ocad_spritesheet_generator.gd"
## RPG Maker 四向奔跑（144×192，48×48 格）；与根目录 rpgmaker.tscn 一致。
const BUNDLED_RPGMAKER_GENERATOR := "res://addons/npc_library_tool/core/rpgmaker_spritesheet_generator.gd"
## 拖入场景时实例化此子场景：主场景里只占一行「实例」节点，子结构收在子场景内。
const NPC_CHARACTER_BASE_SCENE := "res://addons/npc_library_tool/runtime/npc_character_base.tscn"
const FootShadowFactory := preload("res://addons/npc_library_tool/runtime/npc_foot_shadow_factory.gd")
const GENERATED_SPAWN_SCENE_DIR := "res://generated/npc_library_tool/npcs"
const RPGMAKER_PROTAGONIST_DRIVER_SCRIPT := "res://addons/npc_library_tool/runtime/rpgmaker_protagonist_driver.gd"
## 本项目主角比例适配：NPC 拖入场景时默认放大到与主角一致。
const NPC_SPAWN_SCALE := 3.0
## NPC 对话触发范围按世界距离控制；根节点放大后，本地碰撞圆需反向缩小。
const NPC_INTERACT_RADIUS_WORLD := 5.0

## 上次成功解析到的 AI 资源库根路径（按资源类型分子键记忆）
const EDITOR_PREF_LAST_NPC_ROOT := "npc_library_tool/last_resolved_npc_library_root"
## 顶部「类型选择」当前项（metadata 中的 id，如 yituquan）
const EDITOR_PREF_RESOURCE_TYPE_ID := "npc_library_tool/last_resource_type_id"
## AI 资源库根；子目录由「类型选择」决定。
## 扩展：在 res://AI资源库/ 下新建子文件夹后，在此数组追加一行：
## {"id": "唯一英文 id", "label": "下拉显示名", "folder": "磁盘上的子文件夹名"}。
const AI_LIBRARY_BASE := "res://AI资源库"
const RESOURCE_TYPE_ENTRIES: Array = [
	{"id": "yituquan", "label": "一图全动作", "folder": "一图全动作"},
	{"id": "rpgmaker", "label": "RPG Maker", "folder": "RPGMAKER"},
	{"id": "yitu2", "label": "一图2", "folder": "一图2"},
	{"id": "hunter", "label": "全职猎人", "folder": "全职猎人"},
	{"id": "naruto", "label": "火影忍者", "folder": "火影忍者"},
	{"id": "demonslayer", "label": "鬼灭之刃", "folder": "鬼灭之刃"},
	{"id": "fx", "label": "特效库", "folder": "特效库"},
]
## 「新增 NPC」画风下拉中「自定义」项的 metadata，用于显示自定义行
const CREATE_STYLE_CUSTOM_META := "__npc_lib_custom_style__"
## 「新增 NPC」主类型选「自定义」时的 metadata
const CREATE_PRIMARY_CUSTOM_META := "__npc_lib_primary_custom__"

## Dock 卡片区：一行 6 张、默认可视 1 行。卡高 = 内边距 8 + 预览区 + 间距 2 + 名字条 13。
const DOCK_CARD_PREVIEW_H := 124
const DOCK_CARD_W := 78
const DOCK_CARD_H := 8 + DOCK_CARD_PREVIEW_H + 2 + 13
const CARD_PREVIEW_FRAME_SIDE_CROP := 2
const DOCK_GRID_COLS := 6
const DOCK_GRID_SEP_H := 6
const DOCK_GRID_SEP_V := 6
## 卡片区 Scroll 默认可视高度（1 行 × 6 列/行）
const DOCK_GRID_VISIBLE_ROWS := 1
const MAX_DISPLAYED_NPC_CARDS := 6
## 整行卡片宽度（6 列 + 间距），供布局参考
const DOCK_GRID_INNER_W := DOCK_GRID_COLS * DOCK_CARD_W + (DOCK_GRID_COLS - 1) * DOCK_GRID_SEP_H
## 可视区高度：N 行卡片 + (N-1) 行间距
const DOCK_CARDS_SCROLL_MIN_H := DOCK_GRID_VISIBLE_ROWS * DOCK_CARD_H + (DOCK_GRID_VISIBLE_ROWS - 1) * DOCK_GRID_SEP_V
## 卡片区左右总留白（含与滚动条视觉空隙）
const DOCK_CARDS_PAD_X := 20.0
## 卡片内名称最多显示字数（窄卡）
const CARD_NAME_MAX_CHARS := 3
const VOICE_FILE_EXTENSIONS := [".mp3", ".ogg", ".wav"]

var _editor_interface: EditorInterface
var _editor_plugin: EditorPlugin
var _repo: RefCounted
var _main_column: VBoxContainer
var _search_edit: LineEdit
var _resource_type_option: OptionButton
var _suppress_resource_type_change := false
var _scan_btn: Button
var _create_npc_btn: Button
var _ui_skin_btn: Button
var _status_label: Label

var _cards_scroll: ScrollContainer
var _cards_grid: GridContainer

var _detail_panel: VBoxContainer
var _id_value: Label
## 只读展示 meta.displayName（外观同输入框，不可改；改名请编辑 npc.json）
var _name_display_edit: LineEdit
var _spawn_type_option: OptionButton
var _npc_portrait_edit_btn: Button
var _enable_dialogue_check: CheckBox
var _dialogue_edit_btn: Button
var _voice_locale_row: HBoxContainer
var _voice_locale_option: OptionButton
var _suppress_voice_locale_change := false
var _preview_rect: TextureRect
var _preview_anim_option: OptionButton
var _preview_fps_spin: SpinBox
var _preview_play_check: CheckBox
var _suppress_preview_transport := false
var _spawn_scale_spin: SpinBox
var _interact_radius_spin: SpinBox
var _spawn_scale_by_id: Dictionary = {}
var _interact_radius_by_id: Dictionary = {}
var _rpgmaker_protagonist_check: CheckBox
var _ai_logic_section: VBoxContainer
var _merchant_shop_section: VBoxContainer
var _merchant_auto_shop_check: CheckBox
var _merchant_items_container: VBoxContainer
var _merchant_item_rows: Array = []
var _merchant_save_btn: Button

var _items: Array[Dictionary] = []
var _selected_source_index := -1
var _selected_style := ""  # ""=全部，或扫描到的任意 meta.style
var _selected_category := ""  # ""=全部，或扫描到的任意 meta.category
var _style_filter_option: OptionButton
var _category_filter_option: OptionButton
var _empty_state_label: Label
## 选中角色时展示 npc.json 校验问题（贴图缺失等），避免新手只看控制台
var _detail_issues_label: Label
var _resolved_npc_root: String = ""

var _npc_drag_track_idx := -1

var _card_previews: Array[Dictionary] = []
var _card_fps := 8.0

var _preview_frames: Array[AtlasTexture] = []
var _preview_frame_idx := 0
var _preview_time_acc := 0.0
var _preview_fps := 8.0
var _preview_playing := false
var _preview_sprite_frames: SpriteFrames
var _ui_skin_dialog: AcceptDialog
var _ui_skin_file_dialog: EditorFileDialog
var _ui_skin_path_inputs: Dictionary = {}
var _ui_skin_preview_rects: Dictionary = {}
var _ui_skin_advanced_btn: Button
var _ui_skin_advanced_panel: VBoxContainer
var _ui_skin_layout_scroll: ScrollContainer
var _ui_skin_layout_rows: VBoxContainer
var _ui_skin_layout_name_edit: LineEdit
var _npc_portrait_dialog: AcceptDialog
var _npc_portrait_file_dialog: EditorFileDialog
var _npc_portrait_path_edit: LineEdit
var _npc_portrait_preview_rect: TextureRect
var _npc_portrait_override_by_id: Dictionary = {}
var _preferred_voice_locale_by_id: Dictionary = {}
var _dialogue_editor_dialog: AcceptDialog
var _dialogue_editor_scroll: ScrollContainer
var _dialogue_editor_list: VBoxContainer
var _dialogue_editor_tip_label: Label
## 会话内覆盖：与 npc.json 合并；拖入场景时用 _get_dialogue_lines_for_item
var _dialogue_lines_by_id: Dictionary = {}
var _ai_logic_by_id: Dictionary = {}
var _ai_mode_option: OptionButton
var _ai_move_style_option: OptionButton
var _ai_speed_spin: SpinBox
var _ai_step_spin: SpinBox
var _ai_rest_spin: SpinBox
var _ai_range_spin: SpinBox
var _ai_run_axis_option: OptionButton
var _ai_arcade_mode_check: CheckBox
var _ai_action_option: OptionButton
var _path_section: VBoxContainer
var _ai_axis_default_range := 260.0
var _path_points_container: VBoxContainer
var _path_add_btn: Button
var _path_pingpong_check: CheckBox
var _path_vanish_check: CheckBox
var _suppress_ai_logic_save := false
var _create_npc_dialog: AcceptDialog
var _create_npc_file_dialog: EditorFileDialog
var _create_style_option: OptionButton
var _create_style_custom_edit: LineEdit
var _create_primary_type_option: OptionButton
var _create_primary_category_hint_label: Label
var _create_primary_category_custom_edit: LineEdit
var _create_name_edit: LineEdit
var _create_id_edit: LineEdit
var _create_desc_edit: TextEdit
var _create_sprite_path_edit: LineEdit
var _create_thumb_path_edit: LineEdit
var _create_time_logic_check: CheckBox
var _create_time_logic_edit: TextEdit
var _create_faction_logic_check: CheckBox
var _create_faction_logic_edit: TextEdit
var _create_merchant_section: VBoxContainer
var _create_merchant_items_container: VBoxContainer
var _create_merchant_item_rows: Array = []
var _create_merchant_preset_shop_check: CheckBox
var _create_quest_section: VBoxContainer
var _create_quest_items_container: VBoxContainer
var _create_quest_rows: Array = []
var _create_combat_section: VBoxContainer
var _create_combat_level_spin: SpinBox
var _create_combat_hp_spin: SpinBox
var _create_combat_attack_spin: SpinBox
var _create_combat_defense_spin: SpinBox
var _create_combat_speed_spin: SpinBox


func setup(editor_interface: EditorInterface, editor_plugin: EditorPlugin = null) -> void:
	_editor_interface = editor_interface
	_editor_plugin = editor_plugin
	_repo = RepoScript.new()
	_build_ui()
	_load_resource_type_from_editor_settings()
	set_process(true)
	call_deferred("_apply_dock_content_width")
	_refresh_list()


## 弹窗必须挂在编辑器根控件下；若作为 ScrollContainer/Dock 子节点，首次 layout 会把 Window 撑到异常巨大。
func _dialog_parent() -> Node:
	if _editor_interface != null:
		var bc := _editor_interface.get_base_control()
		if is_instance_valid(bc):
			return bc
	return self


func _exit_tree() -> void:
	for w in [
		_create_npc_dialog,
		_create_npc_file_dialog,
		_ui_skin_dialog,
		_ui_skin_file_dialog,
		_npc_portrait_dialog,
		_npc_portrait_file_dialog,
		_dialogue_editor_dialog,
	]:
		if is_instance_valid(w):
			w.queue_free()


func _build_ui() -> void:
	# 横向铺满 Dock，不强制大于槽位的最小宽度，避免出现底部横向滚动条
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	var main := VBoxContainer.new()
	# 横向铺满最小内容宽度，便于各行 HBox 等分对齐
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main.add_theme_constant_override("separation", 4)
	add_child(main)
	_main_column = main

	var ad_panel := PanelContainer.new()
	ad_panel.custom_minimum_size = Vector2(0, 320)
	ad_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ad_style := StyleBoxFlat.new()
	ad_style.bg_color = Color(0.92, 0.28, 0.08, 0.96)
	ad_style.border_color = Color(1.0, 0.84, 0.28, 1.0)
	ad_style.set_border_width_all(2)
	ad_style.set_corner_radius_all(6)
	ad_style.content_margin_left = 8
	ad_style.content_margin_right = 8
	ad_style.content_margin_top = 8
	ad_style.content_margin_bottom = 8
	ad_panel.add_theme_stylebox_override("panel", ad_style)
	main.add_child(ad_panel)

	var contact_label := Label.new()
	contact_label.text = CONTACT_TEXT
	contact_label.tooltip_text = CONTACT_TEXT
	contact_label.custom_minimum_size = Vector2(0, 304)
	contact_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	contact_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	contact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contact_label.add_theme_font_size_override("font_size", 13)
	contact_label.add_theme_color_override("font_color", Color(1, 1, 1))
	ad_panel.add_child(contact_label)

	var top_bar := HBoxContainer.new()
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_theme_constant_override("separation", 6)
	main.add_child(top_bar)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索（ID/名称）"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.size_flags_stretch_ratio = 1.0
	_search_edit.text_changed.connect(func(_t: String) -> void:
		_rebuild_cards()
	)
	top_bar.add_child(_search_edit)

	_resource_type_option = OptionButton.new()
	for e in RESOURCE_TYPE_ENTRIES:
		var d: Dictionary = e
		var ix := _resource_type_option.item_count
		_resource_type_option.add_item(String(d.get("label", "")))
		_resource_type_option.set_item_metadata(ix, String(d.get("id", "")))
	_resource_type_option.custom_minimum_size.x = 120
	_resource_type_option.tooltip_text = "选择 AI资源库 下的资源子目录；后续可在此增加怪物等类型。"
	_resource_type_option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_resource_type_option.item_selected.connect(_on_resource_type_selected)
	top_bar.add_child(_resource_type_option)

	_scan_btn = Button.new()
	_scan_btn.text = "扫描资源库"
	_scan_btn.tooltip_text = "按左侧下拉所选资源类型扫描对应子目录（默认 res://AI资源库/一图全动作）；若无角色则全局搜索该子目录名并记住路径。「一图全动作」用内置 ocad 切帧；「RPG Maker」用 144×192（3×4×48×48）切帧，与 rpgmaker.tscn 一致。\n新手：每个角色一个文件夹，里面要有 npc.json（或 RPGMAKER 下可用 NPC.json），且 assets.spritePath 指向的贴图真实存在（拷齐并等 Godot 导入）。"
	_scan_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_scan_btn.pressed.connect(_refresh_list)
	top_bar.add_child(_scan_btn)

	_create_npc_btn = Button.new()
	_create_npc_btn.text = "新增NPC"
	_create_npc_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_create_npc_btn.pressed.connect(_open_create_npc_dialog)
	top_bar.add_child(_create_npc_btn)

	_ui_skin_btn = Button.new()
	_ui_skin_btn.text = "UI框编辑"
	_ui_skin_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_ui_skin_btn.pressed.connect(_open_ui_skin_editor)
	top_bar.add_child(_ui_skin_btn)

	# 单行：「资源过滤」+ 下拉靠左；右侧状态文案（扫描结果等）右对齐
	var nav_filter_row := HBoxContainer.new()
	nav_filter_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_filter_row.add_theme_constant_override("separation", 4)
	main.add_child(nav_filter_row)

	var filter_lbl := Label.new()
	filter_lbl.text = "资源过滤"
	filter_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	filter_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav_filter_row.add_child(filter_lbl)
	_style_filter_option = OptionButton.new()
	_style_filter_option.tooltip_text = "按画风（meta.style）筛选；选项在扫描资源库后按实际出现过的 style 动态生成"
	_style_filter_option.add_item("全部风格")
	_style_filter_option.set_item_metadata(0, "")
	_style_filter_option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_style_filter_option.custom_minimum_size.x = 120
	_style_filter_option.item_selected.connect(func(_idx: int) -> void:
		_selected_style = String(_style_filter_option.get_selected_metadata())
		_rebuild_cards()
	)
	nav_filter_row.add_child(_style_filter_option)

	_category_filter_option = OptionButton.new()
	_category_filter_option.tooltip_text = "按类型（meta.category）筛选；选项在扫描后按实际出现过的 category 动态生成（如 merchant 显示为商店类）"
	_category_filter_option.add_item("全部类型")
	_category_filter_option.set_item_metadata(0, "")
	_category_filter_option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_category_filter_option.custom_minimum_size.x = 120
	_category_filter_option.item_selected.connect(func(_idx: int) -> void:
		_selected_category = String(_category_filter_option.get_selected_metadata())
		_rebuild_cards()
	)
	nav_filter_row.add_child(_category_filter_option)

	_status_label = Label.new()
	_status_label.text = "就绪"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.size_flags_stretch_ratio = 1.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.clip_text = true
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	nav_filter_row.add_child(_status_label)

	_empty_state_label = Label.new()
	_update_empty_state_hint()
	_empty_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_state_label.visible = false
	main.add_child(_empty_state_label)

	_cards_scroll = ScrollContainer.new()
	_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# 只约束高度；横向最小宽度交给网格，避免比 Dock 更宽触发根级横向滚动
	_cards_scroll.custom_minimum_size = Vector2(0, float(DOCK_CARDS_SCROLL_MIN_H))
	main.add_child(_cards_scroll)

	var cards_center := CenterContainer.new()
	cards_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_cards_scroll.add_child(cards_center)

	_cards_grid = GridContainer.new()
	_cards_grid.columns = DOCK_GRID_COLS
	_cards_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_cards_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_cards_grid.add_theme_constant_override("h_separation", DOCK_GRID_SEP_H)
	_cards_grid.add_theme_constant_override("v_separation", DOCK_GRID_SEP_V)
	cards_center.add_child(_cards_grid)

	_detail_panel = VBoxContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(_detail_panel)

	var detail_id_name_row := HBoxContainer.new()
	detail_id_name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_id_name_row.add_theme_constant_override("separation", 6)
	_detail_panel.add_child(detail_id_name_row)

	_id_value = Label.new()
	_id_value.text = "ID: -"
	_id_value.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_id_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_id_name_row.add_child(_id_value)

	_name_display_edit = LineEdit.new()
	_name_display_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_display_edit.size_flags_stretch_ratio = 1.0
	_name_display_edit.editable = false
	_name_display_edit.focus_mode = Control.FOCUS_NONE
	_name_display_edit.selecting_enabled = false
	_name_display_edit.tooltip_text = "角色名称只读；请在资源目录的 npc.json 中修改 meta.displayName"
	detail_id_name_row.add_child(_name_display_edit)

	_enable_dialogue_check = CheckBox.new()
	_enable_dialogue_check.text = "创建对话系统"
	_enable_dialogue_check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_enable_dialogue_check.button_pressed = true
	_enable_dialogue_check.toggled.connect(func(pressed: bool) -> void:
		if _npc_portrait_edit_btn != null:
			_npc_portrait_edit_btn.disabled = not pressed
		if _dialogue_edit_btn != null:
			_dialogue_edit_btn.disabled = not pressed
	)
	detail_id_name_row.add_child(_enable_dialogue_check)

	_detail_issues_label = Label.new()
	_detail_issues_label.visible = false
	_detail_issues_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_issues_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.38))
	_detail_issues_label.text = ""
	_detail_panel.add_child(_detail_issues_label)

	_spawn_type_option = OptionButton.new()
	_spawn_type_option.tooltip_text = "决定拖到 2D 场景时生成的节点/脚本类型（如 MerchantNpc），与上方「资源过滤」里的 meta.category 不是同一套菜单。任务/功能/战斗等拖入类型待开发完成后再加回。"
	_spawn_type_option.add_item("路人NPC")
	_spawn_type_option.set_item_metadata(0, "normal")
	_spawn_type_option.add_item("商人NPC")
	_spawn_type_option.set_item_metadata(1, "merchant")
	_spawn_type_option.select(0)
	_spawn_type_option.item_selected.connect(_on_spawn_type_option_selected)

	var spawn_portrait_dialogue_row := HBoxContainer.new()
	spawn_portrait_dialogue_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_portrait_dialogue_row.add_theme_constant_override("separation", 6)
	_detail_panel.add_child(spawn_portrait_dialogue_row)

	_spawn_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spawn_type_option.size_flags_stretch_ratio = 1.0
	spawn_portrait_dialogue_row.add_child(_spawn_type_option)

	_npc_portrait_edit_btn = Button.new()
	_npc_portrait_edit_btn.text = "NPC立绘编辑"
	_npc_portrait_edit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_npc_portrait_edit_btn.size_flags_stretch_ratio = 1.0
	_npc_portrait_edit_btn.pressed.connect(_open_npc_portrait_editor)
	spawn_portrait_dialogue_row.add_child(_npc_portrait_edit_btn)

	_dialogue_edit_btn = Button.new()
	_dialogue_edit_btn.text = "对话内容编辑"
	_dialogue_edit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_edit_btn.size_flags_stretch_ratio = 1.0
	_dialogue_edit_btn.pressed.connect(_open_dialogue_editor)
	spawn_portrait_dialogue_row.add_child(_dialogue_edit_btn)

	_voice_locale_row = HBoxContainer.new()
	_voice_locale_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_voice_locale_row.add_theme_constant_override("separation", 6)
	_voice_locale_row.visible = false
	_detail_panel.add_child(_voice_locale_row)

	var voice_label := Label.new()
	voice_label.text = "配音语言"
	voice_label.custom_minimum_size = Vector2(66, 0)
	voice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_voice_locale_row.add_child(voice_label)

	_voice_locale_option = OptionButton.new()
	_voice_locale_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_voice_locale_option.add_item("中文")
	_voice_locale_option.set_item_metadata(0, "chinese")
	_voice_locale_option.add_item("英文")
	_voice_locale_option.set_item_metadata(1, "english")
	_voice_locale_option.add_item("日语")
	_voice_locale_option.set_item_metadata(2, "japanese")
	_voice_locale_option.item_selected.connect(_on_voice_locale_option_selected)
	_voice_locale_row.add_child(_voice_locale_option)

	var preview_split := HBoxContainer.new()
	preview_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_split.add_theme_constant_override("separation", 8)
	preview_split.alignment = BoxContainer.ALIGNMENT_BEGIN
	_detail_panel.add_child(preview_split)

	var preview_left := VBoxContainer.new()
	preview_left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	preview_left.add_theme_constant_override("separation", 4)
	preview_split.add_child(preview_left)

	var preview_title := Label.new()
	preview_title.text = "动作预览"
	preview_left.add_child(preview_title)

	_preview_rect = DragPreviewRectScript.new()
	_preview_rect.dock = self
	_preview_rect.custom_minimum_size = Vector2(180, 180)
	_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 特效类常见超小帧（如 11x8），需放大到预览框可见
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_rect.tooltip_text = "可拖入 2D 编辑器视图，在当前选中角色位置放置"
	preview_left.add_child(_preview_rect)

	var preview_right := VBoxContainer.new()
	preview_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_right.add_theme_constant_override("separation", 4)
	preview_split.add_child(preview_right)

	var preview_bar := HBoxContainer.new()
	preview_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_bar.add_theme_constant_override("separation", 6)
	preview_right.add_child(preview_bar)

	_preview_play_check = CheckBox.new()
	_preview_play_check.text = "播放"
	_preview_play_check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_preview_play_check.focus_mode = Control.FOCUS_NONE
	_preview_play_check.toggled.connect(_on_preview_play_check_toggled)
	preview_bar.add_child(_preview_play_check)

	_preview_anim_option = OptionButton.new()
	_preview_anim_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_anim_option.size_flags_stretch_ratio = 1.0
	_preview_anim_option.item_selected.connect(func(_idx: int) -> void:
		_build_preview_frames_for_selected_anim()
	)
	preview_bar.add_child(_preview_anim_option)

	_preview_fps_spin = SpinBox.new()
	_preview_fps_spin.min_value = 1
	_preview_fps_spin.max_value = 30
	_preview_fps_spin.step = 1
	_preview_fps_spin.value = 8
	_preview_fps_spin.value_changed.connect(func(v: float) -> void:
		_preview_fps = maxf(1.0, v)
	)
	preview_bar.add_child(_preview_fps_spin)

	_ai_logic_section = VBoxContainer.new()
	_ai_logic_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ai_logic_section.add_theme_constant_override("separation", 4)
	preview_right.add_child(_ai_logic_section)
	_build_ai_logic_inline_panel(_ai_logic_section)

	var spawn_tune_box := VBoxContainer.new()
	spawn_tune_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_tune_box.add_theme_constant_override("separation", 4)
	preview_right.add_child(spawn_tune_box)

	var scale_row := HBoxContainer.new()
	scale_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_theme_constant_override("separation", 6)
	spawn_tune_box.add_child(scale_row)
	var scale_label := Label.new()
	scale_label.text = "角色大小"
	scale_label.custom_minimum_size = Vector2(86, 0)
	scale_row.add_child(scale_label)
	_spawn_scale_spin = SpinBox.new()
	_spawn_scale_spin.min_value = 0.1
	_spawn_scale_spin.max_value = 10.0
	_spawn_scale_spin.step = 0.1
	_spawn_scale_spin.value = NPC_SPAWN_SCALE
	_spawn_scale_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spawn_scale_spin.tooltip_text = "生成或拖入场景时的角色缩放，默认 3"
	_spawn_scale_spin.value_changed.connect(_on_spawn_scale_value_changed)
	scale_row.add_child(_spawn_scale_spin)

	var range_row := HBoxContainer.new()
	range_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_row.add_theme_constant_override("separation", 6)
	spawn_tune_box.add_child(range_row)
	var range_label := Label.new()
	range_label.text = "对话触发范围"
	range_label.custom_minimum_size = Vector2(86, 0)
	range_row.add_child(range_label)
	_interact_radius_spin = SpinBox.new()
	_interact_radius_spin.min_value = 1.0
	_interact_radius_spin.max_value = 120.0
	_interact_radius_spin.step = 1.0
	_interact_radius_spin.value = NPC_INTERACT_RADIUS_WORLD
	_interact_radius_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interact_radius_spin.tooltip_text = "离 NPC 多近才显示对话提示，默认 5"
	_interact_radius_spin.value_changed.connect(_on_interact_radius_value_changed)
	range_row.add_child(_interact_radius_spin)

	var action_bar := HBoxContainer.new()
	action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_right.add_child(action_bar)

	var spawn_btn := Button.new()
	spawn_btn.text = "生成到场景原点"
	spawn_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_btn.size_flags_stretch_ratio = 1.0
	spawn_btn.pressed.connect(_spawn_to_scene_origin)
	action_bar.add_child(spawn_btn)
	_rpgmaker_protagonist_check = CheckBox.new()
	_rpgmaker_protagonist_check.text = "成为主角"
	_rpgmaker_protagonist_check.visible = false
	_rpgmaker_protagonist_check.focus_mode = Control.FOCUS_NONE
	_rpgmaker_protagonist_check.tooltip_text = "勾选后，运行场景时可用 W A S D 控制该角色（四向奔跑）；关闭 AI 与对话互动提示。"
	action_bar.add_child(_rpgmaker_protagonist_check)

	_merchant_shop_section = VBoxContainer.new()
	_merchant_shop_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_merchant_shop_section.add_theme_constant_override("separation", 6)
	_merchant_shop_section.visible = false
	preview_right.add_child(_merchant_shop_section)
	var merchant_title := Label.new()
	merchant_title.text = "商人功能"
	_merchant_shop_section.add_child(merchant_title)
	_merchant_auto_shop_check = CheckBox.new()
	_merchant_auto_shop_check.text = "启用商店系统"
	_merchant_auto_shop_check.button_pressed = false
	_merchant_shop_section.add_child(_merchant_auto_shop_check)
	_merchant_items_container = VBoxContainer.new()
	_merchant_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_merchant_items_container.add_theme_constant_override("separation", 6)
	_merchant_shop_section.add_child(_merchant_items_container)
	var merchant_action_row := HBoxContainer.new()
	merchant_action_row.add_theme_constant_override("separation", 8)
	_merchant_shop_section.add_child(merchant_action_row)
	var add_merchant_item_btn := Button.new()
	add_merchant_item_btn.text = "+ 添加商品"
	add_merchant_item_btn.pressed.connect(func() -> void:
		_add_merchant_editor_item_row()
	)
	merchant_action_row.add_child(add_merchant_item_btn)
	_merchant_save_btn = Button.new()
	_merchant_save_btn.text = "保存商人商品配置"
	_merchant_save_btn.pressed.connect(_save_current_merchant_settings_to_json)
	merchant_action_row.add_child(_merchant_save_btn)

	if _npc_portrait_edit_btn != null:
		_npc_portrait_edit_btn.disabled = not _enable_dialogue_check.button_pressed
	if _dialogue_edit_btn != null:
		_dialogue_edit_btn.disabled = not _enable_dialogue_check.button_pressed


func _format_card_display_name(raw: String) -> String:
	if raw.length() <= CARD_NAME_MAX_CHARS:
		return raw
	return raw.substr(0, CARD_NAME_MAX_CHARS) + "..."


func _sync_preview_play_check() -> void:
	if _preview_play_check == null:
		return
	_suppress_preview_transport = true
	_preview_play_check.set_pressed_no_signal(_preview_playing)
	_suppress_preview_transport = false


func _on_preview_play_check_toggled(pressed: bool) -> void:
	if _suppress_preview_transport:
		return
	if pressed and _preview_frames.is_empty():
		_suppress_preview_transport = true
		_preview_play_check.set_pressed_no_signal(false)
		_suppress_preview_transport = false
		return
	_preview_playing = pressed


func _apply_dock_content_width() -> void:
	# 不再设置横向 custom_minimum_size：固定值若大于编辑器 Dock 实际宽度，根 ScrollContainer 会出现横向滚动条。
	custom_minimum_size.x = 0.0
	if is_instance_valid(_main_column):
		_main_column.custom_minimum_size.x = 0.0


func _last_resolved_root_key_for_type_id(type_id: String) -> String:
	return "npc_library_tool/last_resolved_npc_library_root__%s" % type_id


func _current_resource_type_id() -> String:
	if _resource_type_option == null or _resource_type_option.item_count == 0:
		return "yituquan"
	return String(_resource_type_option.get_selected_metadata())


func _resource_type_folder_for_id(type_id: String) -> String:
	for e in RESOURCE_TYPE_ENTRIES:
		var d: Dictionary = e
		if String(d.get("id", "")) == type_id:
			return String(d.get("folder", "一图全动作"))
	return "一图全动作"


func _default_resource_type_root() -> String:
	return AI_LIBRARY_BASE.path_join(_resource_type_folder_for_id(_current_resource_type_id()))


func _update_empty_state_hint() -> void:
	if _empty_state_label == null:
		return
	var subdir := _resource_type_folder_for_id(_current_resource_type_id())
	_empty_state_label.text = "暂无角色资产。\n请把「AI资源库/%s/<角色文件夹>」放进项目（含 npc.json 与贴图），再点「扫描资源库」。" % subdir


func _load_resource_type_from_editor_settings() -> void:
	if _resource_type_option == null:
		return
	var saved := ""
	if _editor_interface:
		var es := _editor_interface.get_editor_settings()
		if es and es.has_setting(EDITOR_PREF_RESOURCE_TYPE_ID):
			saved = String(es.get_setting(EDITOR_PREF_RESOURCE_TYPE_ID))
	_suppress_resource_type_change = true
	if saved != "":
		for i in range(_resource_type_option.item_count):
			if String(_resource_type_option.get_item_metadata(i)) == saved:
				_resource_type_option.select(i)
				_suppress_resource_type_change = false
				return
	_resource_type_option.select(0)
	_suppress_resource_type_change = false


func _on_resource_type_selected(_idx: int) -> void:
	if _suppress_resource_type_change:
		return
	if _editor_interface:
		var es := _editor_interface.get_editor_settings()
		if es:
			es.set_setting(EDITOR_PREF_RESOURCE_TYPE_ID, _current_resource_type_id())
	_refresh_list()


func _save_last_resolved_root(path: String) -> void:
	if path == "" or _editor_interface == null:
		return
	_resolved_npc_root = path
	var es := _editor_interface.get_editor_settings()
	if es:
		es.set_setting(EDITOR_PREF_LAST_NPC_ROOT, path)
		es.set_setting(_last_resolved_root_key_for_type_id(_current_resource_type_id()), path)


func _resolve_npc_library_root() -> String:
	var def := _default_resource_type_root()
	if _repo.scan_npc_files(def).size() > 0:
		_save_last_resolved_root(def)
		return def
	var tid := _current_resource_type_id()
	if _editor_interface:
		var es := _editor_interface.get_editor_settings()
		if es:
			var keyed := _last_resolved_root_key_for_type_id(tid)
			if es.has_setting(keyed):
				var last := String(es.get_setting(keyed))
				if last != "" and DirAccess.dir_exists_absolute(last) and _repo.scan_npc_files(last).size() > 0:
					_resolved_npc_root = last
					return last
			if tid == "yituquan" and es.has_setting(EDITOR_PREF_LAST_NPC_ROOT):
				var last_legacy := String(es.get_setting(EDITOR_PREF_LAST_NPC_ROOT))
				if last_legacy != "" and DirAccess.dir_exists_absolute(last_legacy) and _repo.scan_npc_files(last_legacy).size() > 0:
					_resolved_npc_root = last_legacy
					return last_legacy
	var folder_name := _resource_type_folder_for_id(tid)
	var found := _search_project_for_named_folder(folder_name)
	if found != "" and _repo.scan_npc_files(found).size() > 0:
		_save_last_resolved_root(found)
		return found
	if DirAccess.dir_exists_absolute(def):
		_save_last_resolved_root(def)
		return def
	return def


func _search_project_for_named_folder(folder_name: String) -> String:
	return _find_dir_named_recursive("res://", folder_name, 0, 16)


func _find_dir_named_recursive(path: String, target_name: String, depth: int, max_depth: int) -> String:
	if depth > max_depth:
		return ""
	var da := DirAccess.open(path)
	if da == null:
		return ""
	da.list_dir_begin()
	while true:
		var n := da.get_next()
		if n == "":
			break
		if n.begins_with("."):
			continue
		var full := path.path_join(n)
		if da.current_is_dir():
			if n == target_name:
				da.list_dir_end()
				return full
			var sub := _find_dir_named_recursive(full, target_name, depth + 1, max_depth)
			if sub != "":
				da.list_dir_end()
				return sub
	da.list_dir_end()
	return ""


func _refresh_list() -> void:
	var root := _resolve_npc_library_root()
	_items = _repo.scan_npc_files(root)
	_selected_source_index = -1
	_rebuild_filter_dropdowns_from_scan()
	_rebuild_cards()
	if _items.is_empty():
		_update_empty_state_hint()
		_empty_state_label.visible = true
		_detail_panel.visible = false
		if _rpgmaker_protagonist_check != null:
			_rpgmaker_protagonist_check.visible = false
		var folder_disp := _resource_type_folder_for_id(_current_resource_type_id())
		_set_status("未扫描到角色：请将资源放在 %s/<角色名>/npc.json，或点击扫描全局搜索「%s」目录。" % [_default_resource_type_root(), folder_disp])
	else:
		_empty_state_label.visible = false
		_detail_panel.visible = true
		_set_status("扫描完成：%d 个角色，精简展示前 %d 个" % [_items.size(), mini(_items.size(), MAX_DISPLAYED_NPC_CARDS)])
		var fi := _first_filtered_item_index()
		if fi >= 0:
			_enter_detail(fi)


## 未在下方 match 表登记的风格/类型 id：把 snake_case 格式化成可读短名，避免下拉里整串英文下划线；无需为每个甲方 id 手写中文映射
func _prettify_unmapped_id_for_filter_display(raw: String) -> String:
	var t := raw.strip_edges()
	if t == "":
		return ""
	if t.find("_") < 0:
		return t.capitalize()
	var parts := t.split("_", false)
	var out := ""
	for p in parts:
		var seg := p.strip_edges()
		if seg == "":
			continue
		if out != "":
			out += " "
		out += seg.capitalize()
	return out


func _humanize_style_for_filter(style: String) -> String:
	var s := style.strip_edges()
	match s:
		"gufeng":
			return "古风"
		"modern":
			return "现代风"
		"medieval":
			return "中世纪风"
		"wasteland_scifi":
			return "废土科幻"
		"high_fantasy_celestial":
			return "高魔天国"
		_:
			if s == "":
				return "?"
			return "%s（未登记画风）" % _prettify_unmapped_id_for_filter_display(s)


func _humanize_category_for_filter(cat: String) -> String:
	var c := cat.strip_edges()
	match c:
		"merchant", "shop":
			return "商店类"
		"function":
			return "功能类"
		"quest":
			return "任务类"
		"combat":
			return "战斗类"
		"normal":
			return "路人"
		_:
			if c == "":
				return "?"
			return "%s（未登记类型）" % _prettify_unmapped_id_for_filter_display(c)


func _find_option_index_by_metadata(ob: OptionButton, meta: String) -> int:
	if meta == "":
		return 0
	for i in range(ob.item_count):
		if String(ob.get_item_metadata(i)) == meta:
			return i
	return 0


## 扫描后根据当前资源库实际出现过的 meta.style / meta.category 填充下拉框（旧版写死 gufeng/shop 与现网 wasteland_scifi/merchant 不一致会导致筛选无效）
func _rebuild_filter_dropdowns_from_scan() -> void:
	if _style_filter_option == null or _category_filter_option == null:
		return
	var prev_style := _selected_style
	var prev_cat := _selected_category
	_style_filter_option.set_block_signals(true)
	_category_filter_option.set_block_signals(true)
	_style_filter_option.clear()
	_category_filter_option.clear()
	_style_filter_option.add_item("全部风格")
	_style_filter_option.set_item_metadata(0, "")
	_category_filter_option.add_item("全部类型")
	_category_filter_option.set_item_metadata(0, "")
	var style_seen: Dictionary = {}
	var cat_seen: Dictionary = {}
	for it in _items:
		var st := String(it.get("style", "")).strip_edges()
		if st != "":
			style_seen[st] = true
		var ct := String(it.get("category", "")).strip_edges()
		if ct != "":
			cat_seen[ct] = true
	var style_keys: Array = style_seen.keys()
	style_keys.sort()
	for sk in style_keys:
		_style_filter_option.add_item(_humanize_style_for_filter(String(sk)))
		_style_filter_option.set_item_metadata(_style_filter_option.item_count - 1, String(sk))
	var cat_keys: Array = cat_seen.keys()
	cat_keys.sort()
	for ck in cat_keys:
		_category_filter_option.add_item(_humanize_category_for_filter(String(ck)))
		_category_filter_option.set_item_metadata(_category_filter_option.item_count - 1, String(ck))
	var isel := _find_option_index_by_metadata(_style_filter_option, prev_style)
	_style_filter_option.select(isel)
	_selected_style = String(_style_filter_option.get_selected_metadata())
	var icat := _find_option_index_by_metadata(_category_filter_option, prev_cat)
	_category_filter_option.select(icat)
	_selected_category = String(_category_filter_option.get_selected_metadata())
	_style_filter_option.set_block_signals(false)
	_category_filter_option.set_block_signals(false)


## 与下拉 metadata 或 json 取值对齐：商店类允许 shop / merchant；并识别 meta.tags 中的同义标签
func _category_matches_filter_item(it: Dictionary, filter_selected: String) -> bool:
	if filter_selected == "":
		return true
	var ic := String(it.get("category", "")).strip_edges().to_lower()
	var fs := filter_selected.strip_edges().to_lower()
	var tag_strs: Array[String] = []
	var tv: Variant = it.get("tags", PackedStringArray())
	if tv is PackedStringArray:
		for x in tv as PackedStringArray:
			tag_strs.append(String(x).strip_edges().to_lower())
	elif tv is Array:
		for x in tv as Array:
			tag_strs.append(String(x).strip_edges().to_lower())
	if fs == "shop" or fs == "merchant":
		if ic == "shop" or ic == "merchant":
			return true
		for ts in tag_strs:
			if ts == "shop" or ts == "merchant":
				return true
		return false
	if ic == fs:
		return true
	for ts in tag_strs:
		if ts == fs:
			return true
	return false


func _item_passes_style_search_filters(it: Dictionary) -> bool:
	if _selected_style != "" and String(it.get("style", "")) != _selected_style:
		return false
	if not _category_matches_filter_item(it, _selected_category):
		return false
	var q := _search_edit.text.strip_edges().to_lower()
	if q != "":
		var tag_join := ""
		var tv2: Variant = it.get("tags", PackedStringArray())
		if tv2 is PackedStringArray:
			var psa := tv2 as PackedStringArray
			for ti in range(psa.size()):
				if ti > 0:
					tag_join += " "
				tag_join += String(psa[ti])
		elif tv2 is Array:
			var parts: Array[String] = []
			for x in tv2 as Array:
				parts.append(String(x))
			tag_join = " ".join(parts)
		var search_text := ("%s %s %s %s" % [
			String(it.get("id", "")),
			String(it.get("displayName", "")),
			String(it.get("category", "")),
			tag_join
		]).to_lower()
		if search_text.find(q) < 0:
			return false
	return true


func _first_filtered_item_index() -> int:
	for i in range(_items.size()):
		if _item_passes_style_search_filters(_items[i]):
			return i
	return -1


func _rebuild_cards() -> void:
	_clear_cards()
	var displayed := 0
	for i in range(_items.size()):
		var it := _items[i]
		if not _item_passes_style_search_filters(it):
			continue
		if displayed >= MAX_DISPLAYED_NPC_CARDS:
			break
		_add_card_for_item(it, i)
		displayed += 1
	_refresh_cards_min_size()
	_ensure_detail_matches_filter()


func _ensure_detail_matches_filter() -> void:
	if _items.is_empty():
		return
	if _selected_source_index < 0 or _selected_source_index >= _items.size():
		var fi := _first_filtered_item_index()
		if fi >= 0:
			_enter_detail(fi)
		return
	if not _item_passes_style_search_filters(_items[_selected_source_index]):
		var fi := _first_filtered_item_index()
		if fi >= 0:
			_enter_detail(fi)


func _add_card_for_item(item: Dictionary, source_index: int) -> void:
	var card_btn := DragCardButtonScript.new()
	card_btn.dock = self
	card_btn.source_index = source_index
	card_btn.flat = true
	card_btn.custom_minimum_size = Vector2(DOCK_CARD_W, DOCK_CARD_H)
	card_btn.clip_contents = true
	card_btn.focus_mode = Control.FOCUS_NONE
	var card_border := StyleBoxFlat.new()
	card_border.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	card_border.set_border_width_all(1)
	card_border.border_color = Color(0.35, 0.38, 0.45, 0.9)
	card_border.set_corner_radius_all(3)
	card_btn.add_theme_stylebox_override("normal", card_border)
	var card_hover := card_border.duplicate() as StyleBoxFlat
	card_hover.border_color = Color(0.45, 0.55, 0.72, 1.0)
	card_btn.add_theme_stylebox_override("hover", card_hover)
	var card_pressed := card_border.duplicate() as StyleBoxFlat
	card_pressed.bg_color = Color(0.16, 0.17, 0.2, 1.0)
	card_btn.add_theme_stylebox_override("pressed", card_pressed)
	var errs_variant: Variant = item.get("errors", [])
	var has_issue := errs_variant is PackedStringArray and (errs_variant as PackedStringArray).size() > 0
	if has_issue:
		var warn := Color(0.88, 0.42, 0.18, 1.0)
		card_border.border_color = warn
		card_hover.border_color = Color(0.95, 0.55, 0.32, 1.0)
		card_pressed.border_color = warn
		card_pressed.bg_color = Color(0.20, 0.14, 0.12, 1.0)
	card_btn.pressed.connect(func() -> void:
		_enter_detail(source_index)
	)
	_cards_grid.add_child(card_btn)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	card_btn.add_child(v)
	var pad := 4
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, pad)

	var clip_wrap := Control.new()
	clip_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_wrap.clip_contents = true
	# 与 DOCK_CARD_PREVIEW_H、底栏名字条高度协调；整图等比居中，避免裁头脚
	clip_wrap.custom_minimum_size = Vector2(0, float(DOCK_CARD_PREVIEW_H))
	clip_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(clip_wrap)

	var rect := TextureRect.new()
	# Godot 4.5：勿用 Control.LAYOUT_MODE_*（GDScript 中未绑定）；用 preset 即可铺满裁剪区
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 特效类可能是超小帧；用 KEEP_ASPECT 让贴图可按卡片区域放大显示
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_wrap.add_child(rect)

	var raw_name := String(item.get("displayName", "未命名NPC"))
	var tip_lines: Array[String] = []
	tip_lines.append("%s" % raw_name)
	tip_lines.append("（可拖入 2D 编辑器视图）")
	if has_issue:
		tip_lines.append("")
		tip_lines.append("注意：该条目存在问题，拖到场景可能异常：")
		for e in errs_variant as PackedStringArray:
			tip_lines.append("· %s" % String(e))
	card_btn.tooltip_text = "\n".join(tip_lines)
	var title := Label.new()
	title.text = _format_card_display_name(raw_name)
	title.custom_minimum_size = Vector2(0, 13)
	title.add_theme_font_size_override("font_size", 11)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)

	var tex := _load_sprite_texture(item)
	var preview_names := _card_preview_candidates(item)
	var merged := _build_frames_for_named_anim(item, tex, preview_names)
	if not merged.is_empty():
		rect.texture = merged[0]

	_card_previews.append({
		"source_index": source_index,
		"button": card_btn,
		"rect": rect,
		"frames": merged,
		"frame_idx": 0,
		"time_acc": 0.0
	})


func _enter_detail(source_index: int) -> void:
	if source_index < 0 or source_index >= _items.size():
		return
	_selected_source_index = source_index
	_detail_panel.visible = _items.size() > 0
	var item := _items[source_index]
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	_id_value.text = "ID: %s" % String(meta.get("id", ""))
	_name_display_edit.text = String(meta.get("displayName", ""))
	if _npc_portrait_edit_btn != null:
		_npc_portrait_edit_btn.disabled = not _enable_dialogue_check.button_pressed
	if _dialogue_edit_btn != null:
		_dialogue_edit_btn.disabled = not _enable_dialogue_check.button_pressed
	_sync_spawn_type_by_item(item)
	_refresh_detail_issues_banner(item)
	_refresh_voice_locale_for_item(item)
	_refresh_merchant_editor_for_item(item)
	_refresh_preview_from_item(item)
	_refresh_ai_logic_dialog()
	_refresh_spawn_tuning_controls(item)
	_sync_rpgmaker_protagonist_check_visibility(item)


func _sync_rpgmaker_protagonist_check_visibility(item: Dictionary) -> void:
	if _rpgmaker_protagonist_check == null:
		return
	_rpgmaker_protagonist_check.visible = not item.is_empty() and _item_prefers_rpgmaker_slices(item)


func _wants_rpgmaker_protagonist_spawn(item: Dictionary) -> bool:
	if _rpgmaker_protagonist_check == null or not _rpgmaker_protagonist_check.visible:
		return false
	return _rpgmaker_protagonist_check.button_pressed and _item_prefers_rpgmaker_slices(item)


func _attach_rpgmaker_protagonist_driver(npc_root: Node2D, edited_scene_root: Node) -> void:
	if npc_root == null or edited_scene_root == null:
		return
	if npc_root.get_node_or_null("RpgmakerProtagonistDriver") != null:
		return
	if npc_root.get_script() != null:
		npc_root.set("enable_ai_logic", false)
		npc_root.set("enable_dialogue_system", false)
	var ia := npc_root.get_node_or_null("InteractArea") as Area2D
	if ia != null:
		ia.monitoring = false
		ia.monitorable = false
	var prompt := npc_root.get_node_or_null("InteractPrompt")
	if prompt is CanvasItem:
		(prompt as CanvasItem).visible = false
	if not ResourceLoader.exists(RPGMAKER_PROTAGONIST_DRIVER_SCRIPT):
		push_warning("[AI资源库] 缺少主角控制脚本：%s" % RPGMAKER_PROTAGONIST_DRIVER_SCRIPT)
		return
	var scr := load(RPGMAKER_PROTAGONIST_DRIVER_SCRIPT) as GDScript
	if scr == null:
		return
	var driver := Node.new()
	driver.name = "RpgmakerProtagonistDriver"
	driver.set_script(scr)
	npc_root.add_child(driver)
	driver.owner = edited_scene_root


func _refresh_detail_issues_banner(item: Dictionary) -> void:
	if _detail_issues_label == null:
		return
	var errs: Variant = item.get("errors", [])
	if not errs is PackedStringArray:
		_detail_issues_label.visible = false
		_detail_issues_label.text = ""
		return
	var lines: PackedStringArray = errs as PackedStringArray
	if lines.is_empty():
		_detail_issues_label.visible = false
		_detail_issues_label.text = ""
		return
	var parts: Array[String] = []
	for i in range(lines.size()):
		parts.append("· %s" % String(lines[i]))
	_detail_issues_label.visible = true
	_detail_issues_label.text = "注意：该角色配置存在问题（拖到场景或预览可能异常）：\n" + "\n".join(parts)


func _on_spawn_type_option_selected(_idx: int) -> void:
	_update_merchant_shop_section_visibility()


func _current_selected_npc_id() -> String:
	if _selected_source_index < 0 or _selected_source_index >= _items.size():
		return ""
	var item: Dictionary = _items[_selected_source_index]
	var meta: Dictionary = item.get("data", {}).get("meta", {})
	return String(meta.get("id", "")).strip_edges()


func _refresh_spawn_tuning_controls(item: Dictionary) -> void:
	var meta: Dictionary = item.get("data", {}).get("meta", {})
	var npc_id := String(meta.get("id", "")).strip_edges()
	if _spawn_scale_spin != null:
		_spawn_scale_spin.set_value_no_signal(_spawn_scale_for_id(npc_id))
	if _interact_radius_spin != null:
		_interact_radius_spin.set_value_no_signal(_interact_radius_for_id(npc_id))


func _spawn_scale_for_id(npc_id: String) -> float:
	if npc_id != "" and _spawn_scale_by_id.has(npc_id):
		return maxf(0.1, float(_spawn_scale_by_id[npc_id]))
	return NPC_SPAWN_SCALE


func _interact_radius_for_id(npc_id: String) -> float:
	if npc_id != "" and _interact_radius_by_id.has(npc_id):
		return maxf(1.0, float(_interact_radius_by_id[npc_id]))
	return NPC_INTERACT_RADIUS_WORLD


func _current_spawn_scale() -> float:
	if _spawn_scale_spin != null:
		return maxf(0.1, float(_spawn_scale_spin.value))
	return NPC_SPAWN_SCALE


func _current_interact_radius_world() -> float:
	if _interact_radius_spin != null:
		return maxf(1.0, float(_interact_radius_spin.value))
	return NPC_INTERACT_RADIUS_WORLD


func _on_spawn_scale_value_changed(value: float) -> void:
	var npc_id := _current_selected_npc_id()
	if npc_id != "":
		_spawn_scale_by_id[npc_id] = maxf(0.1, value)


func _on_interact_radius_value_changed(value: float) -> void:
	var npc_id := _current_selected_npc_id()
	if npc_id != "":
		_interact_radius_by_id[npc_id] = maxf(1.0, value)


func _supports_merchant_for_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var gameplay: Dictionary = data.get("gameplay", {})
	var category := String(meta.get("category", "")).to_lower()
	if category == "shop" or category == "merchant":
		return true
	var types_variant: Variant = meta.get("types", [])
	if types_variant is Array:
		for t in types_variant as Array:
			var key := String(t).to_lower()
			if key == "shop" or key == "merchant":
				return true
	var interaction: Dictionary = gameplay.get("interaction", {})
	if bool(interaction.get("canTrade", false)):
		return true
	var merchant_cfg: Dictionary = gameplay.get("merchant", {})
	if bool(merchant_cfg.get("enabled", false)):
		return true
	return false


func _sync_spawn_type_by_item(item: Dictionary) -> void:
	if _spawn_type_option == null:
		return
	var target_key := "merchant" if _supports_merchant_for_item(item) else "normal"
	for i in range(_spawn_type_option.item_count):
		if String(_spawn_type_option.get_item_metadata(i)) == target_key:
			_spawn_type_option.select(i)
			break
	_update_merchant_shop_section_visibility()


func _current_spawn_type_key() -> String:
	if _spawn_type_option == null:
		return "normal"
	return String(_spawn_type_option.get_selected_metadata())


func _update_merchant_shop_section_visibility() -> void:
	if _merchant_shop_section == null:
		return
	_merchant_shop_section.visible = _current_spawn_type_key() == "merchant"


func _normalize_merchant_shop_item(raw_item: Dictionary) -> Dictionary:
	return {
		"itemId": String(raw_item.get("itemId", "")),
		"itemName": String(raw_item.get("itemName", "")),
		"itemType": String(raw_item.get("itemType", "")),
		"price": int(raw_item.get("price", 0)),
		"count": int(raw_item.get("count", 1)),
		"stock": int(raw_item.get("stock", -1)),
		"spritePath": String(raw_item.get("spritePath", ""))
	}


func _extract_merchant_shop_items(data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gameplay: Dictionary = data.get("gameplay", {})
	var merchant_cfg: Dictionary = gameplay.get("merchant", {})
	var items_var: Variant = merchant_cfg.get("shopItems", [])
	if items_var is Array:
		for it in items_var as Array:
			if it is Dictionary:
				out.append(_normalize_merchant_shop_item(it as Dictionary))
	return out


func _is_merchant_shop_enabled(data: Dictionary) -> bool:
	var gameplay: Dictionary = data.get("gameplay", {})
	var merchant_cfg: Dictionary = gameplay.get("merchant", {})
	if merchant_cfg.has("enabled"):
		return bool(merchant_cfg.get("enabled", false))
	var ext: Dictionary = data.get("ext", {})
	var shop_sys: Dictionary = ext.get("shopSystem", {})
	return bool(shop_sys.get("enabled", false))


func _clear_merchant_editor_rows() -> void:
	for r in _merchant_item_rows:
		var row := r.get("row", null) as Control
		if row != null:
			row.queue_free()
	_merchant_item_rows.clear()


func _add_merchant_editor_item_row(initial: Dictionary = {}) -> void:
	if _merchant_items_container == null:
		return
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	_merchant_items_container.add_child(row)
	var line_a := HBoxContainer.new()
	line_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_a.add_theme_constant_override("separation", 6)
	row.add_child(line_a)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "商品名"
	name_edit.text = String(initial.get("itemName", ""))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_a.add_child(name_edit)
	var type_edit := LineEdit.new()
	type_edit.placeholder_text = "类型"
	type_edit.text = String(initial.get("itemType", ""))
	type_edit.custom_minimum_size = Vector2(90, 0)
	line_a.add_child(type_edit)
	var line_b := HBoxContainer.new()
	line_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_b.add_theme_constant_override("separation", 6)
	row.add_child(line_b)
	var icon_edit := LineEdit.new()
	icon_edit.placeholder_text = "精灵图（可选，res:// 或 ./）"
	icon_edit.text = String(initial.get("spritePath", ""))
	icon_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_b.add_child(icon_edit)
	var line_c := HBoxContainer.new()
	line_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_c.add_theme_constant_override("separation", 6)
	row.add_child(line_c)
	var price_spin := SpinBox.new()
	price_spin.min_value = 0
	price_spin.max_value = 999999
	price_spin.step = 1
	price_spin.value = float(initial.get("price", 0))
	price_spin.custom_minimum_size = Vector2(72, 0)
	price_spin.prefix = "价格 "
	line_c.add_child(price_spin)
	var count_spin := SpinBox.new()
	count_spin.min_value = 1
	count_spin.max_value = 9999
	count_spin.step = 1
	count_spin.value = float(initial.get("count", 1))
	count_spin.custom_minimum_size = Vector2(72, 0)
	count_spin.prefix = "数量 "
	line_c.add_child(count_spin)
	var stock_spin := SpinBox.new()
	stock_spin.min_value = -1
	stock_spin.max_value = 9999
	stock_spin.step = 1
	stock_spin.value = float(initial.get("stock", -1))
	stock_spin.custom_minimum_size = Vector2(72, 0)
	stock_spin.prefix = "库存 "
	line_c.add_child(stock_spin)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_c.add_child(fill)
	var remove_btn := Button.new()
	remove_btn.text = "删除"
	remove_btn.pressed.connect(func() -> void:
		for i in range(_merchant_item_rows.size()):
			if _merchant_item_rows[i].get("row", null) == row:
				_merchant_item_rows.remove_at(i)
				break
		row.queue_free()
	)
	line_c.add_child(remove_btn)
	_merchant_item_rows.append({
		"row": row,
		"name": name_edit,
		"type": type_edit,
		"icon": icon_edit,
		"price": price_spin,
		"count": count_spin,
		"stock": stock_spin
	})


func _refresh_merchant_editor_for_item(item: Dictionary) -> void:
	_update_merchant_shop_section_visibility()
	_clear_merchant_editor_rows()
	var data: Dictionary = item.get("data", {})
	if _merchant_auto_shop_check != null:
		# 默认值为关闭，但若该角色已保存启用状态，则必须如实回显。
		_merchant_auto_shop_check.button_pressed = _is_merchant_shop_enabled(data)
	var items := _extract_merchant_shop_items(data)
	if items.is_empty():
		_add_merchant_editor_item_row()
	else:
		for it in items:
			_add_merchant_editor_item_row(it)


func _collect_merchant_editor_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in _merchant_item_rows:
		var name_edit := r.get("name", null) as LineEdit
		var type_edit := r.get("type", null) as LineEdit
		var icon_edit := r.get("icon", null) as LineEdit
		var price_spin := r.get("price", null) as SpinBox
		var count_spin := r.get("count", null) as SpinBox
		var stock_spin := r.get("stock", null) as SpinBox
		var item_name := String(name_edit.text if name_edit != null else "").strip_edges()
		if item_name == "":
			continue
		out.append({
			"itemId": "item_custom_%03d" % (out.size() + 1),
			"itemName": item_name,
			"itemType": String(type_edit.text if type_edit != null else "").strip_edges(),
			"spritePath": String(icon_edit.text if icon_edit != null else "").strip_edges(),
			"price": int(price_spin.value if price_spin != null else 0),
			"count": int(count_spin.value if count_spin != null else 1),
			"stock": int(stock_spin.value if stock_spin != null else -1)
		})
	return out


func _save_current_merchant_settings_to_json() -> void:
	var item := _current_item()
	if item.is_empty():
		_set_status("请先选择一个NPC")
		return
	var json_path := String(item.get("path", ""))
	if json_path == "":
		_set_status("保存失败：当前NPC缺少 JSON 路径")
		return
	var data: Dictionary = item.get("data", {})
	var gameplay: Dictionary = data.get("gameplay", {})
	var interaction: Dictionary = gameplay.get("interaction", {})
	var merchant_cfg: Dictionary = gameplay.get("merchant", {})
	var ext: Dictionary = data.get("ext", {})
	var shop_system: Dictionary = ext.get("shopSystem", {})
	var items := _collect_merchant_editor_items()
	var enabled := _merchant_auto_shop_check != null and _merchant_auto_shop_check.button_pressed
	interaction["canTrade"] = enabled
	gameplay["interaction"] = interaction
	merchant_cfg["enabled"] = enabled
	merchant_cfg["shopItems"] = items
	gameplay["merchant"] = merchant_cfg
	data["gameplay"] = gameplay
	shop_system["enabled"] = enabled
	shop_system["presetId"] = "npc_library_tool_default_shop_v1"
	ext["shopSystem"] = shop_system
	data["ext"] = ext
	var meta: Dictionary = data.get("meta", {})
	if String(meta.get("category", "")).to_lower() == "normal":
		meta["category"] = "shop"
		data["meta"] = meta
	if not _repo.save_npc_json(json_path, data):
		_set_status("保存失败：写入 npc.json 失败")
		return
	var idx := _selected_source_index
	if idx >= 0 and idx < _items.size():
		_items[idx]["data"] = data
	_set_status("已保存商店配置：%d 个商品" % items.size())


func _apply_to_selected_node() -> void:
	var item := _current_item()
	if item.is_empty():
		return
	if _editor_interface == null:
		_set_status("编辑器接口不可用")
		return
	var nodes: Array[Node] = _editor_interface.get_selection().get_selected_nodes()
	if nodes.is_empty():
		_set_status("请先在场景中选中一个节点")
		return
	var node := nodes[0]
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var gameplay: Dictionary = data.get("gameplay", {})
	node.set_meta("npc_id", String(meta.get("id", "")))
	node.set_meta("npc_json_path", String(item.get("path", "")))
	node.set_meta("npc_style", String(meta.get("style", "")))
	node.set_meta("npc_category", String(meta.get("category", "")))
	node.set_meta("npc_data", data)
	if String(meta.get("displayName", "")) != "":
		node.name = String(meta.get("displayName", ""))
	_try_set_property(node, "role", gameplay.get("role", ""))
	_try_set_property(node, "level", gameplay.get("level", 1))
	var stats: Dictionary = gameplay.get("stats", {})
	_try_set_property(node, "max_hp", stats.get("hp", null))
	_try_set_property(node, "attack", stats.get("attack", null))
	_try_set_property(node, "defense", stats.get("defense", null))
	_try_set_property(node, "move_speed", stats.get("moveSpeed", null))
	_try_set_property(node, "spritesheet", _load_sprite_texture(item))
	_set_status("已应用到节点：%s" % node.name)


func _spawn_to_scene_origin() -> void:
	if _current_item().is_empty():
		_set_status("请先选择一个NPC卡片")
		return
	var item := _current_item()
	var want_hero := _wants_rpgmaker_protagonist_spawn(item)
	spawn_npc_item_at(item, Vector2.ZERO)
	var meta: Dictionary = item.get("data", {}).get("meta", {})
	var base_status := "已在场景原点生成：%s" % String(meta.get("displayName", "NPC"))
	if want_hero:
		_set_status("%s（已挂 W A S D 主角控制，请运行场景试玩）" % base_status)
	else:
		_set_status(base_status)


func spawn_npc_item_at(item: Dictionary, world_pos: Vector2) -> void:
	if item.is_empty():
		return
	if _editor_interface == null:
		_set_status("生成失败：编辑器接口不可用")
		return
	var scene_root := _editor_interface.get_edited_scene_root()
	if scene_root == null:
		_set_status("生成失败：当前没有打开场景")
		return
	var spawn_type := String(_spawn_type_option.get_selected_metadata())
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var is_fx_item := _is_fx_library_item(item)
	var node := _create_spawn_node(item)
	if node == null:
		_set_status("生成失败：无法创建节点")
		return
	if node == scene_root:
		_set_status("生成失败：目标节点非法")
		return
	var old_parent := node.get_parent()
	if old_parent != null:
		(old_parent as Node).remove_child(node)
	if is_fx_item:
		var base_display_fx := _sanitize_editable_node_name(String(meta.get("displayName", "FX")))
		node.name = _unique_child_node_name(scene_root, base_display_fx)
		scene_root.add_child(node)
		_set_spawned_scene_instance_ownership(node, scene_root)
		if node is Node2D:
			(node as Node2D).position = world_pos
		if world_pos != Vector2.ZERO:
			_set_status("已拖入特效：%s" % node.name)
		_schedule_save_edited_scene_after_spawn()
		return
	if spawn_type == "normal" or spawn_type == "merchant":
		# 已由子场景打包：名称、meta、路径预览/活动范围等均在生成的 .tscn 内
		# owner 规则须与编辑器里手动拖入子场景一致：
		# - 实例根 owner = 主场景根
		# - 实例内部所有节点 owner = 实例根（不能留空，也不能全部设成主场景根）
		# 否则保存时会被当成主场景内联节点 → 展开整树 + OcadNpc/Shadow 重名「加载错误」。
		# 多次拖入同一角色时，子场景根名相同；须在加入父节点前分配兄弟内唯一名，避免引擎落成 @Node2D@…
		var base_display := _sanitize_editable_node_name(String(meta.get("displayName", "NPC")))
		node.name = _unique_child_node_name(scene_root, base_display)
		scene_root.add_child(node)
		_set_spawned_scene_instance_ownership(node, scene_root)
		if node is Node2D:
			(node as Node2D).position = world_pos
			_apply_default_spawn_scale(node as Node2D)
			_apply_default_interact_radius(node as Node2D)
			_apply_spawn_runtime_exports(node)
			if _wants_rpgmaker_protagonist_spawn(item):
				_attach_rpgmaker_protagonist_driver(node as Node2D, scene_root)
		if world_pos != Vector2.ZERO:
			_set_status("已拖入场景：%s" % node.name)
		_schedule_save_edited_scene_after_spawn()
		return
	node.name = _unique_child_node_name(scene_root, _sanitize_editable_node_name(String(meta.get("displayName", "NPC"))))
	node.set_meta("npc_id", String(meta.get("id", "")))
	node.set_meta("npc_json_path", String(item.get("path", "")))
	node.set_meta("npc_style", String(meta.get("style", "")))
	node.set_meta("npc_category", String(meta.get("category", "")))
	node.set_meta("npc_data", data)
	if node is Node2D:
		(node as Node2D).position = world_pos
		_apply_default_spawn_scale(node as Node2D)
		_apply_default_interact_radius(node as Node2D)
		_apply_spawn_runtime_exports(node)
		_apply_ai_behavior_helper_nodes(node as Node2D, item)
	scene_root.add_child(node)
	_set_owner_recursive(node, scene_root)
	if node is Node2D and _wants_rpgmaker_protagonist_spawn(item):
		_attach_rpgmaker_protagonist_driver(node as Node2D, scene_root)
	if world_pos != Vector2.ZERO:
		_set_status("已拖入场景：%s" % node.name)
	_schedule_save_edited_scene_after_spawn()


## 自动保存当前编辑场景：必须在 EditorPlugin._process 等主循环里调用 save_scene()，
## 不可用 call_deferred / SceneTreeTimer 回调，否则会触发 progress_dialog 或 list.h 断言。
func _schedule_save_edited_scene_after_spawn() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("request_schedule_auto_save_edited_scene"):
		_editor_plugin.request_schedule_auto_save_edited_scene()
		return
	push_warning("[AI资源库] 无法调度自动保存（缺少 EditorPlugin 引用），请手动 Ctrl+S")


func spawn_npc_by_source_index_at(source_index: int, canvas_pos: Vector2) -> void:
	if source_index < 0 or source_index >= _items.size():
		return
	spawn_npc_item_at(_items[source_index], canvas_pos)


func npc_drag_build_payload(source_index: int, drag_control: Control) -> Variant:
	if drag_control == null:
		return null
	if source_index < 0 or source_index >= _items.size():
		return null
	var item: Dictionary = _items[source_index]
	var tex := _load_sprite_texture(item)
	var preview := TextureRect.new()
	preview.texture = tex
	preview.custom_minimum_size = Vector2(72, 72)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	drag_control.set_drag_preview(preview)
	return {NPC_DRAG_DICT_KEY: true, "source_index": source_index}


func npc_drag_data_for_preview(drag_control: Control) -> Variant:
	if _selected_source_index < 0 or _selected_source_index >= _items.size():
		return null
	return npc_drag_build_payload(_selected_source_index, drag_control)


func npc_drag_on_card_drag_begin(source_index: int) -> void:
	_npc_drag_track_idx = source_index


func npc_drag_on_preview_drag_begin() -> void:
	if _selected_source_index >= 0:
		_npc_drag_track_idx = _selected_source_index


func npc_drag_on_source_end_deferred() -> void:
	call_deferred("_npc_drag_clear_track_idx")


func _npc_drag_clear_track_idx() -> void:
	_npc_drag_track_idx = -1


func _canvas_point_to_parent_local(scene_root: Node, canvas_pt: Vector2) -> Vector2:
	if scene_root is Node2D:
		return (scene_root as Node2D).to_local(canvas_pt)
	if scene_root is Control:
		return (scene_root as Control).to_local(canvas_pt)
	return canvas_pt


## 保守策略：优先旧算法；若在缩放/平移视野下误差较大，再自动回退到组合变换。
## 通过“回投影误差”选择更贴近鼠标落点的结果，尽量避免再次引入偏移回归。
func _viewport_mouse_to_parent_local(scene_root: Node, vp: SubViewport, local_mouse: Vector2) -> Vector2:
	var tf_a: Transform2D = vp.canvas_transform
	var canvas_a: Vector2 = tf_a.affine_inverse() * local_mouse
	var local_a: Vector2 = _canvas_point_to_parent_local(scene_root, canvas_a)
	if not (scene_root is Node2D):
		return local_a
	var root2d := scene_root as Node2D
	var reproj_a: Vector2 = tf_a * root2d.to_global(local_a)
	var err_a := reproj_a.distance_to(local_mouse)
	if err_a <= 2.0:
		return local_a

	var tf_b: Transform2D = vp.global_canvas_transform * vp.canvas_transform
	var canvas_b: Vector2 = tf_b.affine_inverse() * local_mouse
	var local_b: Vector2 = _canvas_point_to_parent_local(scene_root, canvas_b)
	var reproj_b: Vector2 = tf_b * root2d.to_global(local_b)
	var err_b := reproj_b.distance_to(local_mouse)
	return local_b if err_b < err_a else local_a


func complete_npc_drag_if_over_2d_viewport() -> void:
	if _editor_interface == null:
		return
	var scene_root_chk := _editor_interface.get_edited_scene_root()
	if scene_root_chk == null:
		return
	var vp := _editor_interface.get_editor_viewport_2d()
	if vp == null:
		return
	var vp_size := vp.size
	if vp_size.x < 2.0 or vp_size.y < 2.0:
		return
	var local_mouse := vp.get_mouse_position()
	if not Rect2(Vector2.ZERO, vp_size).has_point(local_mouse):
		return
	var idx := _npc_drag_track_idx
	var d_btn: Variant = vp.gui_get_drag_data()
	if d_btn is Dictionary and bool((d_btn as Dictionary).get(NPC_DRAG_DICT_KEY, false)):
		idx = int((d_btn as Dictionary).get("source_index", -1))
	if idx < 0:
		return
	_npc_drag_track_idx = -1
	var local_pos := _viewport_mouse_to_parent_local(scene_root_chk, vp, local_mouse)
	spawn_npc_by_source_index_at(idx, local_pos)


## 甲方方案：先把完整 NPC 树打包成独立 .tscn，再实例化进主场景 → 场景树里只占一行「实例」，子结构折叠在子场景内。
## 健壮性：不假设用户项目结构；纯中文 id 等用哈希文件名，避免多人共用同一 .tscn 互相覆盖；不写 scene_file_path（部分引擎版本只读）。
func _instantiate_generated_spawn_scene(item: Dictionary, spawn_type: String) -> Node:
	var scene_path := _ensure_generated_spawn_scene(item, spawn_type)
	if scene_path == "":
		return null
	var scene_res := ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if scene_res is PackedScene:
		return (scene_res as PackedScene).instantiate()
	_set_status("生成失败：无法加载角色子场景（请确认路径在 res:// 下且可导入）")
	return null


func _ensure_generated_spawn_scene(item: Dictionary, spawn_type: String) -> String:
	if not ResourceLoader.exists(NPC_CHARACTER_BASE_SCENE):
		_set_status("生成失败：缺少插件内置子场景 %s（请检查插件是否完整）" % NPC_CHARACTER_BASE_SCENE)
		return ""
	var node: Node = null
	match spawn_type:
		"normal":
			node = _create_merchant_node(item)
		"merchant":
			node = _create_merchant_node(item)
		_:
			_set_status("生成失败：未知的 NPC 类型")
			return ""
	if node == null:
		return ""
	var scene_path := _generated_spawn_scene_path(item, spawn_type)
	if scene_path == "" or not scene_path.begins_with("res://"):
		node.free()
		_set_status("生成失败：无法确定角色子场景路径（需为 res://）")
		return ""
	var base_dir := scene_path.get_base_dir()
	var make_dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
	if make_dir_err != OK:
		node.free()
		_set_status("生成失败：无法在项目中创建目录：%s" % base_dir)
		return ""
	_prepare_spawn_scene_root(node, item)
	if node is Node2D:
		_apply_ai_behavior_helper_nodes(node as Node2D, item)
	node.owner = null
	node.scene_file_path = ""
	_set_owner_for_packing(node, node)
	var packed := PackedScene.new()
	var pack_err := packed.pack(node)
	if pack_err != OK:
		node.free()
		_set_status("生成失败：打包角色子场景失败（错误码 %s）" % str(int(pack_err)))
		return ""
	var save_err := ResourceSaver.save(packed, scene_path)
	node.free()
	if save_err != OK:
		_set_status("生成失败：保存子场景失败（错误码 %s），请检查磁盘与项目写权限" % str(int(save_err)))
		return ""
	ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	call_deferred("_deferred_scan_filesystem_after_npc_scene_saved")
	return scene_path


func _deferred_scan_filesystem_after_npc_scene_saved() -> void:
	if _editor_interface == null:
		return
	var fs: EditorFileSystem = _editor_interface.get_resource_filesystem()
	if fs != null:
		fs.scan()


## 生成路径：json 在 res:// 下则与 npc.json 同目录；否则写入插件 generated/（空项目、仅插件时仍可用）。
func _generated_spawn_scene_path(item: Dictionary, spawn_type: String) -> String:
	var fname := _generated_spawn_scene_filename(item, spawn_type)
	return "%s/%s" % [GENERATED_SPAWN_SCENE_DIR, fname]


## 文件名：ASCII id 优先；sanitize 后只剩下划线或为空时用 json 路径哈希，避免所有中文 id 共用一个文件。
func _generated_spawn_scene_filename(item: Dictionary, spawn_type: String) -> String:
	var meta: Dictionary = item.get("data", {}).get("meta", {})
	var raw_id := String(meta.get("id", "")).strip_edges()
	var stem := _sanitize_scene_file_stem(raw_id)
	if stem.replace("_", "").is_empty():
		stem = ""
	if stem != "":
		return "%s.%s.tscn" % [stem, spawn_type]
	var jp := String(item.get("path", "")).strip_edges()
	if jp != "":
		return "npc_%s.%s.tscn" % [str(abs(String(jp).hash())), spawn_type]
	return "npc_%s.%s.tscn" % [str(Time.get_ticks_msec()), spawn_type]


func _prepare_spawn_scene_root(node: Node, item: Dictionary) -> void:
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var display_name := String(meta.get("displayName", meta.get("id", "NPC"))).strip_edges()
	if display_name != "":
		node.name = _sanitize_editable_node_name(display_name)
	if node is Node2D:
		_apply_default_spawn_scale(node as Node2D)
		_apply_default_interact_radius(node as Node2D)
	_apply_spawn_metadata(node, item)
	_force_canvas_items_visible(node)


func _apply_default_spawn_scale(node: Node2D) -> void:
	if node == null:
		return
	var s := _current_spawn_scale()
	node.scale = Vector2(s, s)


func _apply_default_interact_radius(node: Node2D) -> void:
	if node == null:
		return
	var shape_node := node.get_node_or_null("InteractArea/CollisionShape2D") as CollisionShape2D
	if shape_node == null or not shape_node.shape is CircleShape2D:
		return
	var scale_factor := maxf(0.001, absf(node.scale.x))
	(shape_node.shape as CircleShape2D).radius = maxf(1.0, _current_interact_radius_world() / scale_factor)


func _apply_spawn_runtime_exports(node: Node) -> void:
	if node == null or node.get_script() == null:
		return
	node.set("interact_radius", _current_interact_radius_world())


func _force_canvas_items_visible(root: Node) -> void:
	if root is CanvasItem:
		(root as CanvasItem).visible = true
	for c in root.get_children():
		if c is Node:
			_force_canvas_items_visible(c as Node)


func _apply_spawn_start_animation(asp: AnimatedSprite2D, sf: SpriteFrames, preferred: String) -> void:
	if asp == null or sf == null:
		return
	var candidates := PackedStringArray()
	if preferred != "":
		candidates.append(preferred)
	for n in ["idledown", "idle_down", "idleleft", "idle_left", "idleup", "idle_up", "walkdown", "walk_down"]:
		if not candidates.has(n):
			candidates.append(n)
	for n in candidates:
		if sf.has_animation(n):
			asp.animation = StringName(n)
			asp.frame = 0
			asp.play()
			return
	if sf.get_animation_names().size() > 0:
		var fallback := String(sf.get_animation_names()[0])
		asp.animation = StringName(fallback)
		asp.frame = 0
		asp.play()


func _sanitize_editable_node_name(text: String) -> String:
	var t := text.strip_edges()
	if t.is_empty():
		return "NPC"
	for bad in ["/", "\\", ":", ".", "@", "%", "\""]:
		t = t.replace(bad, "_")
	if t.is_empty():
		return "NPC"
	return t


## 与编辑器「实例重名自动加后缀」一致：在 parent 已有子节点中分配不重复的节点名（首实例保持原名，其后为 base2、base3…）。
func _unique_child_node_name(parent: Node, base: String) -> String:
	var b := base.strip_edges()
	if b.is_empty():
		b = "NPC"
	var used: Dictionary = {}
	if parent != null:
		for ch in parent.get_children():
			used[String(ch.name)] = true
	if not used.has(b):
		return b
	var n := 2
	while n < 1000000:
		var cand: String = "%s%d" % [b, n]
		if not used.has(cand):
			return cand
		n += 1
	return "%s%d" % [b, n]


func _apply_spawn_metadata(node: Node, item: Dictionary) -> void:
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	node.set_meta("npc_id", String(meta.get("id", "")))
	node.set_meta("npc_json_path", String(item.get("path", "")))
	node.set_meta("npc_style", String(meta.get("style", "")))
	node.set_meta("npc_category", String(meta.get("category", "")))
	node.set_meta("npc_data", data)


func _sanitize_scene_file_stem(text: String) -> String:
	var out := ""
	for i in range(text.length()):
		var code := text.unicode_at(i)
		var is_num := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		if is_num or is_upper or is_lower or code == 45 or code == 95:
			out += text.substr(i, 1)
		else:
			out += "_"
	return out.strip_edges()


func _create_spawn_node(item: Dictionary) -> Node:
	if _is_fx_library_item(item):
		return _create_fx_spawn_node(item)
	var spawn_type := String(_spawn_type_option.get_selected_metadata())
	if spawn_type == "normal" or spawn_type == "merchant":
		return _instantiate_generated_spawn_scene(item, spawn_type)

	# 下拉仅含路人/商人；若出现异常 metadata，仍尝试旧兜底（一般不应走到）
	var packed: PackedScene = null
	for p in [
		"res://ocad_npc.tscn",
		"res://游戏场景/共用场景/ocad_npc.tscn",
		"res://scenes/common/ocad_npc.tscn"
	]:
		if not ResourceLoader.exists(p):
			continue
		var res := load(p)
		if res is PackedScene:
			packed = res
			break
	var node: Node = null
	if packed != null:
		node = packed.instantiate()
	else:
		var fallback := Node2D.new()
		var sp := Sprite2D.new()
		sp.name = "Sprite2D"
		fallback.add_child(sp)
		node = fallback
	var tex := _load_sprite_texture(item)
	_try_set_property(node, "spritesheet", tex)
	var asp := node.find_child("AnimatedSprite2D", true, false)
	if asp is AnimatedSprite2D and asp.sprite_frames != null:
		if asp.sprite_frames.has_animation("idledown"):
			asp.animation = "idledown"
			asp.play()
	var sp2 := node.find_child("Sprite2D", true, false)
	if sp2 is Sprite2D and tex != null:
		(sp2 as Sprite2D).texture = tex
	return node


func _is_fx_library_item(item: Dictionary) -> bool:
	if _current_resource_type_id() == "fx":
		return true
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var style := String(meta.get("style", "")).strip_edges().to_lower()
	return style == "fx"


func _create_fx_spawn_node(item: Dictionary) -> Node:
	# 特效库：仅生成一个 Node2D 并挂载花瓣发射器脚本；不走 NPC 场景/交互/阴影分支。
	var root := Node2D.new()
	var emitter_script_path := ""
	var data: Dictionary = item.get("data", {})
	var ext: Dictionary = data.get("ext", {})
	var payload: Dictionary = ext.get("otherPayload", {})
	emitter_script_path = String(payload.get("emitterScriptPath", "")).strip_edges()
	if emitter_script_path == "":
		emitter_script_path = "res://AI资源库/特效库/花瓣飘落/flower_petal_emitter.gd"
	if ResourceLoader.exists(emitter_script_path):
		var script_res := load(emitter_script_path)
		if script_res is GDScript:
			root.set_script(script_res)
		else:
			push_warning("[AI资源库] 特效脚本不是 GDScript：%s" % emitter_script_path)
	else:
		push_warning("[AI资源库] 未找到特效脚本：%s" % emitter_script_path)
	_apply_spawn_metadata(root, item)
	return root


func _ensure_ocad_foot_shadow(ocad_root: Node2D) -> void:
	FootShadowFactory.ensure_under_ocad(ocad_root)


func _add_merchant_visual_branch(node: Node2D, item: Dictionary) -> void:
	var tex := _load_sprite_texture(item)
	var sf := _build_sprite_frames_for_spawn(item, tex)
	var ocad_root := node.get_node_or_null("OcadNpc") as Node2D
	var asp := node.get_node_or_null("OcadNpc/AnimatedSprite2D") as AnimatedSprite2D
	# 健壮性优先：不依赖用户项目是否存在 ocad_npc.tscn，优先使用可直接播放的 SpriteFrames。
	if sf != null and asp != null:
		asp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		asp.sprite_frames = sf
		asp.visible = true
		if ocad_root != null:
			ocad_root.visible = true
			# 写入 OcadNpc.spritesheet，保存进子场景后，运行时 OcadNpc 脚本能与父节点赋值顺序对齐。
			if tex != null:
				_try_set_property(ocad_root, "spritesheet", tex)
		var start_anim_existing := _pick_spawn_start_animation(item, sf)
		_apply_spawn_start_animation(asp, sf, String(start_anim_existing))
		if ocad_root != null:
			_ensure_ocad_foot_shadow(ocad_root)
		return
	if sf != null:
		ocad_root = Node2D.new()
		ocad_root.name = "OcadNpc"
		node.add_child(ocad_root)
		asp = AnimatedSprite2D.new()
		asp.name = "AnimatedSprite2D"
		asp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ocad_root.add_child(asp)
		asp.sprite_frames = sf
		asp.visible = true
		var start_anim := _pick_spawn_start_animation(item, sf)
		_apply_spawn_start_animation(asp, sf, String(start_anim))
		_ensure_ocad_foot_shadow(ocad_root)
		return
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tex != null:
		sprite.texture = tex
	node.add_child(sprite)


func _apply_merchant_spawn_exports(node: Node, item: Dictionary) -> void:
	if node.get_script() == null:
		return
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var assets: Dictionary = data.get("assets", {})
	var npc_id := String(meta.get("id", ""))
	node.set("npc_display_name", String(meta.get("displayName", "商人")))
	var lines := _get_dialogue_lines_for_item(item)
	node.set("dialogue_lines", lines)
	node.set("preferred_voice_locale", _effective_voice_locale_for_item(item))
	node.set("enable_dialogue_system", _enable_dialogue_check.button_pressed)
	node.set("interact_radius", _current_interact_radius_world())
	var ai_cfg := _get_ai_logic_for_item(item)
	node.set("enable_ai_logic", bool(ai_cfg.get("enabled", false)))
	node.set("ai_mode", String(ai_cfg.get("mode", "idle")))
	node.set("ai_speed", float(ai_cfg.get("speed", 30.0)))
	node.set("ai_step_distance", float(ai_cfg.get("step_distance", 26.0)))
	node.set("ai_rest_seconds", float(ai_cfg.get("rest_seconds", 2.0)))
	node.set("ai_range", float(ai_cfg.get("range", 120.0)))
	node.set("ai_wander_move", String(ai_cfg.get("wander_move", "walk")))
	node.set("ai_path_pingpong", bool(ai_cfg.get("path_pingpong", true)))
	node.set("ai_path_vanish", bool(ai_cfg.get("path_vanish", false)))
	node.set("ai_arcade_mode", bool(ai_cfg.get("arcade_mode", false)))
	node.set("ai_run_axis", String(ai_cfg.get("run_axis", "horizontal")))
	node.set("ai_action", String(ai_cfg.get("action", "idledown")))
	var ppt: Variant = ai_cfg.get("path_points", [])
	if ppt is Array:
		node.set_meta("ai_path_points", ppt)
	else:
		node.set_meta("ai_path_points", [])
	if npc_id != "" and _npc_portrait_override_by_id.has(npc_id):
		node.set("npc_portrait_path", String(_npc_portrait_override_by_id[npc_id]))
	else:
		var portrait_rel := String(assets.get("thumbPath", ""))
		if portrait_rel != "":
			var json_path := String(item.get("path", ""))
			var portrait_abs := json_path.get_base_dir().path_join(portrait_rel.trim_prefix("./"))
			node.set("npc_portrait_path", portrait_abs)
	var shop_enabled := false
	var shop_list: Array[Dictionary] = []
	var current_json := String(_current_item().get("path", ""))
	var this_json := String(item.get("path", ""))
	if _current_spawn_type_key() == "merchant":
		shop_enabled = _is_merchant_shop_enabled(data)
		shop_list = _extract_merchant_shop_items(data)
		if current_json != "" and current_json == this_json:
			if _merchant_auto_shop_check != null:
				shop_enabled = _merchant_auto_shop_check.button_pressed
			var edited_items := _collect_merchant_editor_items()
			if not edited_items.is_empty():
				shop_list = edited_items
	node.set("enable_shop_system", shop_enabled)
	node.set("shop_items", shop_list)


func _voice_locale_presence_for_item(item: Dictionary) -> Dictionary:
	var out := {
		"any": false,
		"chinese": false,
		"english": false,
		"japanese": false,
	}
	var json_path := String(item.get("path", "")).strip_edges()
	if json_path == "":
		return out
	var base_dir := json_path.get_base_dir()
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue
		var lower := name.to_lower()
		if not _is_voice_file_name(lower):
			continue
		out["any"] = true
		if lower.begins_with("chinese"):
			out["chinese"] = true
		elif lower.begins_with("english") or lower.begins_with("engligh"):
			out["english"] = true
		elif lower.begins_with("japanese"):
			out["japanese"] = true
	dir.list_dir_end()
	return out


func _is_voice_file_name(file_name_lower: String) -> bool:
	for ext in VOICE_FILE_EXTENSIONS:
		if file_name_lower.ends_with(String(ext)):
			return true
	return false


func _effective_voice_locale_for_item(item: Dictionary) -> String:
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var npc_id := String(meta.get("id", ""))
	if npc_id != "" and _preferred_voice_locale_by_id.has(npc_id):
		return String(_preferred_voice_locale_by_id[npc_id])
	var ext: Dictionary = data.get("ext", {})
	var loc: Dictionary = ext.get("localization", {})
	var saved := String(loc.get("preferredVoiceLocale", "")).to_lower().strip_edges()
	if saved == "chinese" or saved == "english" or saved == "japanese":
		return saved
	return "chinese"


func _refresh_voice_locale_for_item(item: Dictionary) -> void:
	if _voice_locale_row == null or _voice_locale_option == null:
		return
	var presence := _voice_locale_presence_for_item(item)
	var has_voice := bool(presence.get("any", false))
	_voice_locale_row.visible = has_voice
	if not has_voice:
		return
	var locale := _effective_voice_locale_for_item(item)
	_suppress_voice_locale_change = true
	_select_option_by_metadata(_voice_locale_option, locale)
	_suppress_voice_locale_change = false
	var tip := "当前角色有配音文件；可切换对话语音优先语言（中文/英文/日语）"
	_voice_locale_option.tooltip_text = tip


func _on_voice_locale_option_selected(_idx: int) -> void:
	if _suppress_voice_locale_change:
		return
	var item := _current_item()
	if item.is_empty():
		return
	var locale := String(_voice_locale_option.get_selected_metadata())
	if locale == "":
		locale = "chinese"
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var npc_id := String(meta.get("id", ""))
	if npc_id != "":
		_preferred_voice_locale_by_id[npc_id] = locale
	var ext: Dictionary = data.get("ext", {})
	var localization: Dictionary = ext.get("localization", {})
	localization["preferredVoiceLocale"] = locale
	ext["localization"] = localization
	data["ext"] = ext
	var json_path := String(item.get("path", "")).strip_edges()
	if json_path.begins_with("res://"):
		if _repo.save_npc_json(json_path, data):
			if _selected_source_index >= 0 and _selected_source_index < _items.size():
				_items[_selected_source_index]["data"] = data
			_set_status("已保存配音语言偏好：%s" % _voice_locale_option.get_item_text(_voice_locale_option.selected))
		else:
			_set_status("保存失败：无法写入配音语言偏好")
	elif _selected_source_index >= 0 and _selected_source_index < _items.size():
		_items[_selected_source_index]["data"] = data


func _create_merchant_node_legacy(item: Dictionary) -> Node:
	var node := Node2D.new()
	node.name = "MerchantNpc"
	node.y_sort_enabled = true
	_add_merchant_visual_branch(node, item)
	var area := Area2D.new()
	area.name = "InteractArea"
	node.add_child(area)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = NPC_INTERACT_RADIUS_WORLD
	cs.shape = circle
	area.add_child(cs)
	var prompt := Label.new()
	prompt.name = "InteractPrompt"
	prompt.position = Vector2(-60, -45)
	prompt.size = Vector2(120, 28)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 8)
	prompt.text = "press E to active"
	node.add_child(prompt)
	var script_res: Resource = null
	if ResourceLoader.exists("res://addons/npc_library_tool/runtime/merchant_npc.gd"):
		script_res = load("res://addons/npc_library_tool/runtime/merchant_npc.gd")
	if script_res is Script:
		node.set_script(script_res)
	_apply_merchant_spawn_exports(node, item)
	return node


func _create_merchant_node(item: Dictionary) -> Node:
	if ResourceLoader.exists(NPC_CHARACTER_BASE_SCENE):
		var pscn := load(NPC_CHARACTER_BASE_SCENE) as PackedScene
		if pscn != null:
			var inst := pscn.instantiate()
			if inst is Node2D:
				var node := inst as Node2D
				_add_merchant_visual_branch(node, item)
				_apply_merchant_spawn_exports(node, item)
				return node
	return _create_merchant_node_legacy(item)


func _apply_ai_behavior_helper_nodes(root: Node2D, item: Dictionary) -> void:
	if root == null:
		return
	var cfg := _get_ai_logic_for_item(item)
	if not bool(cfg.get("enabled", false)):
		return
	var mode := String(cfg.get("mode", "idle"))
	match mode:
		"wander":
			_add_activity_range_helper_node(root)
		"path":
			_add_path_waypoint_preview_line(root, item)
		_:
			pass


func _add_activity_range_helper_node(root: Node2D) -> void:
	if root.get_node_or_null("ActivityRange") != null:
		return
	var area := Area2D.new()
	area.name = "ActivityRange"
	area.monitoring = false
	area.monitorable = false
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	var rng := 120.0
	var v: Variant = root.get("ai_range")
	if v != null:
		rng = float(v)
	circle.radius = maxf(16.0, rng)
	cs.shape = circle
	area.add_child(cs)
	root.add_child(area)


func _ai_dir_to_vec(dir_key: String) -> Vector2:
	match String(dir_key):
		"up":
			return Vector2(0, -1)
		"down":
			return Vector2(0, 1)
		"left":
			return Vector2(-1, 0)
		"right":
			return Vector2(1, 0)
		_:
			return Vector2(1, 0)


func _add_path_waypoint_preview_line(root: Node2D, item: Dictionary) -> void:
	var npc_id := String(root.get_meta("npc_id", "")).strip_edges()
	var pname := "PathPreview"
	if npc_id != "":
		pname = "PathPreview_%s" % npc_id.replace("/", "_").replace(":", "_")
	var old := root.get_node_or_null(pname)
	if old != null and is_instance_valid(old):
		root.remove_child(old)
		old.free()
	var cfg := _get_ai_logic_for_item(item)
	var pts: Variant = cfg.get("path_points", [])
	if not pts is Array:
		return
	var arr: Array = pts as Array
	if arr.is_empty():
		return
	var line := Line2D.new()
	line.name = pname
	var preview_scale := maxf(0.001, absf(root.scale.x))
	line.width = 2.0 / preview_scale
	line.default_color = Color(0.45, 0.82, 1.0, 0.92)
	var acc := Vector2.ZERO
	line.add_point(acc / preview_scale)
	for p in arr:
		if p is Dictionary:
			var d := String((p as Dictionary).get("dir", "right"))
			var dist := float((p as Dictionary).get("dist", 0))
			acc += _ai_dir_to_vec(d) * maxf(1.0, dist)
			line.add_point(acc / preview_scale)
	root.add_child(line)


func _process(delta: float) -> void:
	_update_card_previews(delta)
	if _preview_playing and not _preview_frames.is_empty():
		_preview_time_acc += delta
		var frame_dt := 1.0 / maxf(1.0, _preview_fps)
		if _preview_time_acc >= frame_dt:
			_preview_time_acc = 0.0
			_preview_frame_idx = (_preview_frame_idx + 1) % _preview_frames.size()
			_show_preview_frame()


func _update_card_previews(delta: float) -> void:
	if _card_previews.is_empty():
		return
	var frame_dt := 1.0 / maxf(1.0, _card_fps)
	for i in range(_card_previews.size()):
		var cp: Dictionary = _card_previews[i]
		var frames: Array = cp.get("frames", [])
		if frames.is_empty():
			continue
		var time_acc := float(cp.get("time_acc", 0.0)) + delta
		var idx := int(cp.get("frame_idx", 0))
		while time_acc >= frame_dt:
			time_acc -= frame_dt
			idx = (idx + 1) % frames.size()
		cp["time_acc"] = time_acc
		cp["frame_idx"] = idx
		var rect: TextureRect = cp.get("rect")
		rect.texture = frames[idx]
		_card_previews[i] = cp


## RPG Maker：144×192，插件内置生成 SpriteFrames（见 rpgmaker.tscn）；也可在 npc.json 设 spritesheet.layoutVersion 为 rpgmaker_v1。
func _item_prefers_rpgmaker_slices(item: Dictionary) -> bool:
	if _current_resource_type_id() == "fx":
		return false
	var data_rm: Dictionary = item.get("data", {})
	var ext_rm: Dictionary = data_rm.get("ext", {})
	if String(ext_rm.get("spritesheetSlice", "")) == "json_grid":
		return false
	if _current_resource_type_id() == "rpgmaker":
		return true
	var sheet_rm: Dictionary = data_rm.get("spritesheet", {})
	return String(sheet_rm.get("layoutVersion", "")) == "rpgmaker_v1"


## yituquan_v1 一图全动作：正确切法为 ocad 固定区域表（与 AI 像素商 K 一致），非 row/from/to 均匀网格。
## 若需旧版「仅 JSON 网格」预览，在 npc.json 的 ext 中设 "spritesheetSlice": "json_grid"。
func _item_prefers_ocad_slices(item: Dictionary) -> bool:
	if _item_prefers_rpgmaker_slices(item):
		return false
	if _current_resource_type_id() == "fx":
		return false
	var data: Dictionary = item.get("data", {})
	var ext: Dictionary = data.get("ext", {})
	if String(ext.get("spritesheetSlice", "")) == "json_grid":
		return false
	var sheet: Dictionary = data.get("spritesheet", {})
	var lv := String(sheet.get("layoutVersion", "yituquan_v1"))
	if lv == "json_grid":
		return false
	return lv == "yituquan_v1" or lv == ""


func _get_ocad_sprite_frames(tex: Texture2D) -> SpriteFrames:
	if tex == null:
		return null
	var candidates: Array = [BUNDLED_OCAD_GENERATOR]
	for p in candidates:
		if not ResourceLoader.exists(p):
			continue
		var script_res := load(p)
		if script_res is GDScript:
			var obj := (script_res as GDScript).new()
			if obj != null and obj.has_method("build_sprite_frames"):
				var sf: Variant = obj.call("build_sprite_frames", tex)
				if sf is SpriteFrames:
					return sf as SpriteFrames
	return null


func _get_rpgmaker_sprite_frames(tex: Texture2D) -> SpriteFrames:
	if tex == null:
		return null
	if not ResourceLoader.exists(BUNDLED_RPGMAKER_GENERATOR):
		return null
	var script_res := load(BUNDLED_RPGMAKER_GENERATOR)
	if script_res is GDScript:
		var obj := (script_res as GDScript).new()
		if obj != null and obj.has_method("build_sprite_frames"):
			var sf: Variant = obj.call("build_sprite_frames", tex)
			if sf is SpriteFrames:
				return sf as SpriteFrames
	return null


func _validate_spritesheet_against_texture(tex: Texture2D, spritesheet: Dictionary) -> String:
	if tex == null:
		return "贴图未加载"
	var fw := int(spritesheet.get("frameWidth", 0))
	var fh := int(spritesheet.get("frameHeight", 0))
	if fw <= 0 or fh <= 0:
		return "frameWidth/frameHeight 无效"
	var tw := tex.get_width()
	var th := tex.get_height()
	var animations: Dictionary = spritesheet.get("animations", {})
	if animations.is_empty():
		return "animations 为空"
	var spacing := int(spritesheet.get("spacing", 0))
	var margin := int(spritesheet.get("margin", 0))
	for anim_key in animations.keys():
		var anim_data: Dictionary = animations[anim_key]
		var row := int(anim_data.get("row", 0))
		var from_idx := int(anim_data.get("from", 0))
		var to_idx := int(anim_data.get("to", 0))
		if to_idx < from_idx:
			return "动画 %s：from/to 无效" % String(anim_key)
		for col in range(from_idx, to_idx + 1):
			var x := margin + col * (fw + spacing)
			var y := margin + row * (fh + spacing)
			if x < 0 or y < 0:
				return "动画 %s：坐标为负" % String(anim_key)
			if x + fw > tw or y + fh > th:
				return "动画 %s：帧越界 (%d,%d) 格 %dx%d 贴图 %dx%d" % [String(anim_key), x, y, fw, fh, tw, th]
	return ""


func _refresh_preview_from_item(item: Dictionary) -> void:
	_preview_playing = false
	_sync_preview_play_check()
	_preview_frame_idx = 0
	_preview_time_acc = 0.0
	_preview_frames.clear()
	_preview_sprite_frames = null
	_preview_anim_option.clear()
	var tex := _load_sprite_texture(item)
	if _current_resource_type_id() == "fx":
		var data_fx: Dictionary = item.get("data", {})
		var spritesheet_fx: Dictionary = data_fx.get("spritesheet", {})
		_preview_anim_option.add_item("fx")
		_preview_fps = maxf(1.0, float(spritesheet_fx.get("defaultFps", 8)))
		_preview_fps_spin.value = _preview_fps
		_preview_anim_option.select(0)
		_build_preview_frames_for_selected_anim()
		if not _preview_frames.is_empty():
			_preview_playing = true
			_sync_preview_play_check()
		else:
			_preview_rect.texture = null
		return
	if tex != null and _item_prefers_rpgmaker_slices(item):
		_preview_sprite_frames = _get_rpgmaker_sprite_frames(tex)
	elif tex != null and _item_prefers_ocad_slices(item):
		_preview_sprite_frames = _get_ocad_sprite_frames(tex)
	if _preview_sprite_frames != null:
		var sf_names := _sorted_anim_names_from_sprite_frames(_preview_sprite_frames)
		for k in sf_names:
			_preview_anim_option.add_item(k)
		if _item_prefers_rpgmaker_slices(item):
			_preview_fps = 5.0
		else:
			_preview_fps = 8.0
	else:
		var data: Dictionary = item.get("data", {})
		var spritesheet: Dictionary = data.get("spritesheet", {})
		var animations: Dictionary = spritesheet.get("animations", {})
		if _item_prefers_rpgmaker_slices(item) and tex != null:
			_set_status("RPG Maker 切帧失败：请确认 sprite 为 144×192（3×4×48×48，与 rpgmaker.tscn 一致）。")
		elif _item_prefers_ocad_slices(item) and tex != null:
			_set_status("ocad 切帧失败：请确认 sprite 为 252×252 一图全动作（与 AI 像素商 K 同布局）。")
		else:
			var keys := _preview_anim_candidates(animations)
			for k in keys:
				_preview_anim_option.add_item(k)
			_preview_fps = maxf(1.0, float(spritesheet.get("defaultFps", 8)))
	_preview_fps_spin.value = _preview_fps
	if _preview_anim_option.item_count > 0:
		var picked := false
		for prefer_name in ["runL", "run_left", "runleft", "rundown", "run_down", "runup", "run_up", "runright", "run_right"]:
			for i in range(_preview_anim_option.item_count):
				if _preview_anim_option.get_item_text(i) == prefer_name:
					_preview_anim_option.select(i)
					picked = true
					break
			if picked:
				break
		if not picked:
			_preview_anim_option.select(0)
		_build_preview_frames_for_selected_anim()
		if not _preview_frames.is_empty():
			_preview_playing = true
			_sync_preview_play_check()
	else:
		_preview_rect.texture = null


func _preview_anim_candidates(animations: Dictionary) -> PackedStringArray:
	if _current_resource_type_id() == "fx":
		var fx_out := PackedStringArray()
		if animations.has("idle_down"):
			fx_out.append("idle_down")
		elif animations.has("idledown"):
			fx_out.append("idledown")
		if fx_out.is_empty():
			var fx_keys := animations.keys()
			fx_keys.sort()
			for k in fx_keys:
				fx_out.append(String(k))
		return fx_out
	# 详情预览先稳定优先：只展示待机/行走，避免 run_* 在部分图集下语义错位。
	var preferred := PackedStringArray([
		"idle_down", "idledown",
		"walk_down", "walkdown",
		"idle_left", "idleL",
		"walk_left", "walkL",
		"idle_up", "idleup",
		"walk_up", "walkup"
	])
	var out := PackedStringArray()
	for k in preferred:
		if animations.has(k):
			out.append(k)
	# 如果上述都没有，再回退显示全部，避免空列表。
	if out.is_empty():
		var keys := animations.keys()
		keys.sort()
		for k in keys:
			out.append(String(k))
	return out


func _build_preview_frames_for_selected_anim() -> void:
	# 切换动作时保留「播放」状态；仅在下方失败路径或 _refresh_preview_from_item 中关闭。
	_preview_frames.clear()
	_preview_frame_idx = 0
	_preview_time_acc = 0.0
	var item := _current_item()
	if item.is_empty():
		_preview_playing = false
		_sync_preview_play_check()
		return
	var tex := _load_sprite_texture(item)
	if tex == null:
		_set_status("预览失败：spritePath 指向的贴图不存在或不可加载。")
		_preview_playing = false
		_sync_preview_play_check()
		return
	var anim_name := _preview_anim_option.get_item_text(_preview_anim_option.selected)
	if _preview_sprite_frames != null:
		_preview_frames = _build_frames_from_sprite_frames(_preview_sprite_frames, anim_name)
	else:
		var data: Dictionary = item.get("data", {})
		var spritesheet: Dictionary = data.get("spritesheet", {})
		if _current_resource_type_id() == "fx":
			_preview_frames = _build_fx_strip_frames(tex, spritesheet)
			if _preview_frames.is_empty():
				_set_status("特效预览失败：请检查 fx.json 的 columns（应为 7）与贴图路径。")
				_preview_playing = false
				_sync_preview_play_check()
				return
			_show_preview_frame()
			return
		var animations: Dictionary = spritesheet.get("animations", {})
		var anim_data: Dictionary = animations.get(anim_name, {})
		if anim_data.is_empty():
			_set_status("预览失败：未找到动画 %s" % anim_name)
			_preview_playing = false
			_sync_preview_play_check()
			return
		_preview_frames = _build_frames_from_anim_data(tex, spritesheet, anim_data)
	if _preview_frames.is_empty():
		_set_status("预览失败：切帧越界或参数错误。")
		_preview_playing = false
		_sync_preview_play_check()
		return
	_show_preview_frame()


func _build_frames_for_named_anim(item: Dictionary, tex: Texture2D, names: PackedStringArray) -> Array[AtlasTexture]:
	var out: Array[AtlasTexture] = []
	if tex == null:
		return out
	if _current_resource_type_id() == "fx":
		var data_fx: Dictionary = item.get("data", {})
		var spritesheet_fx: Dictionary = data_fx.get("spritesheet", {})
		return _build_fx_strip_frames(tex, spritesheet_fx)
	if _item_prefers_rpgmaker_slices(item):
		var sf_rpg := _get_rpgmaker_sprite_frames(tex)
		if sf_rpg != null:
			for nm in names:
				for v in _anim_name_variants(nm):
					if sf_rpg.has_animation(v):
						return _crop_frames_for_card_preview(_build_frames_from_sprite_frames(sf_rpg, v))
		return out
	if _item_prefers_ocad_slices(item):
		var sf := _get_ocad_sprite_frames(tex)
		if sf != null:
			for nm in names:
				for v in _anim_name_variants(nm):
					if sf.has_animation(v):
						return _crop_frames_for_card_preview(_build_frames_from_sprite_frames(sf, v))
		return out
	var data: Dictionary = item.get("data", {})
	var spritesheet: Dictionary = data.get("spritesheet", {})
	var animations: Dictionary = spritesheet.get("animations", {})
	for nm in names:
		if animations.has(nm):
			return _crop_frames_for_card_preview(_build_frames_from_anim_data(tex, spritesheet, animations.get(nm, {})))
	return out


func _crop_frames_for_card_preview(frames: Array[AtlasTexture]) -> Array[AtlasTexture]:
	var out: Array[AtlasTexture] = []
	for frame in frames:
		if frame == null:
			continue
		var src_region: Rect2i = frame.region
		var max_crop := maxi(0, int((src_region.size.x - 1) / 2))
		var crop_x := min(CARD_PREVIEW_FRAME_SIDE_CROP, max_crop)
		if crop_x <= 0:
			out.append(frame)
			continue
		var cropped := AtlasTexture.new()
		cropped.atlas = frame.atlas
		cropped.region = Rect2i(
			src_region.position.x + crop_x,
			src_region.position.y,
			src_region.size.x - crop_x * 2,
			src_region.size.y
		)
		out.append(cropped)
	return out


func _card_preview_candidates(item: Dictionary) -> PackedStringArray:
	if _current_resource_type_id() == "fx":
		return PackedStringArray([
			"idle_down", "idledown",
		])
	if _item_prefers_rpgmaker_slices(item):
		return PackedStringArray([
			"rundown", "run_down",
			"runleft", "run_left", "runL",
			"runright", "run_right",
			"runup", "run_up",
		])
	# 默认展示往下跑（ocad：rundown），邻近采样防糊。
	return PackedStringArray([
		"rundown", "run_down",
		"runL", "run_left",
		"runup", "run_up",
		"walkL", "walk_left",
		"walkdown", "walk_down",
		"walkup", "walk_up",
		"idleL", "idle_left",
		"idledown", "idle_down",
		"idleup", "idle_up"
	])


func _build_frames_from_anim_data(tex: Texture2D, spritesheet: Dictionary, anim_data: Dictionary) -> Array[AtlasTexture]:
	var out: Array[AtlasTexture] = []
	var frame_w := int(spritesheet.get("frameWidth", 0))
	var frame_h := int(spritesheet.get("frameHeight", 0))
	var row := int(anim_data.get("row", 0))
	var from_idx := int(anim_data.get("from", 0))
	var to_idx := int(anim_data.get("to", 0))
	var spacing := int(spritesheet.get("spacing", 0))
	var margin := int(spritesheet.get("margin", 0))
	if frame_w <= 0 or frame_h <= 0:
		return out
	for col in range(from_idx, to_idx + 1):
		var x := margin + col * (frame_w + spacing)
		var y := margin + row * (frame_h + spacing)
		if x + frame_w > tex.get_width() or y + frame_h > tex.get_height():
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2i(x, y, frame_w, frame_h)
		out.append(atlas)
	return out


func _build_fx_strip_frames(tex: Texture2D, spritesheet: Dictionary) -> Array[AtlasTexture]:
	var out: Array[AtlasTexture] = []
	if tex == null:
		return out
	var columns := maxi(1, int(spritesheet.get("columns", 7)))
	var spacing := int(spritesheet.get("spacing", 0))
	var margin := int(spritesheet.get("margin", 0))
	var frame_w := int(spritesheet.get("frameWidth", 0))
	var frame_h := int(spritesheet.get("frameHeight", 0))
	if frame_w <= 0:
		frame_w = int(floor(float(tex.get_width() - margin * 2 - spacing * (columns - 1)) / float(columns)))
	if frame_h <= 0:
		frame_h = tex.get_height() - margin * 2
	if frame_w <= 0 or frame_h <= 0:
		return out
	for col in range(columns):
		var x := margin + col * (frame_w + spacing)
		var y := margin
		if x + frame_w > tex.get_width() or y + frame_h > tex.get_height():
			break
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2i(x, y, frame_w, frame_h)
		out.append(atlas)
	return out


func _build_frames_from_sprite_frames(sf: SpriteFrames, anim_name: String) -> Array[AtlasTexture]:
	var out: Array[AtlasTexture] = []
	if sf == null or not sf.has_animation(anim_name):
		return out
	var count := sf.get_frame_count(anim_name)
	for i in range(count):
		var t := sf.get_frame_texture(anim_name, i)
		if t is AtlasTexture:
			out.append(t as AtlasTexture)
	return out


func _sorted_anim_names_from_sprite_frames(sf: SpriteFrames) -> PackedStringArray:
	var preferred := PackedStringArray([
		"idledown", "idleL", "idleup",
		"walkdown", "walkL", "walkup",
		"rundown", "runL", "runup",
		"attractL", "item", "jump", "defence", "sitdown", "climb", "die"
	])
	var out := PackedStringArray()
	if sf == null:
		return out
	var names := sf.get_animation_names()
	for k in preferred:
		if names.has(StringName(k)):
			out.append(k)
	for n in names:
		var s := String(n)
		if out.has(s):
			continue
		out.append(s)
	return out


func _anim_name_variants(name: String) -> PackedStringArray:
	match name:
		"idle_down":
			return PackedStringArray(["idle_down", "idledown"])
		"idle_left":
			return PackedStringArray(["idle_left", "idleL"])
		"idle_up":
			return PackedStringArray(["idle_up", "idleup"])
		"walk_down":
			return PackedStringArray(["walk_down", "walkdown"])
		"walk_left":
			return PackedStringArray(["walk_left", "walkL"])
		"walk_up":
			return PackedStringArray(["walk_up", "walkup"])
		"run_down":
			return PackedStringArray(["rundown", "run_down"])
		"rundown":
			return PackedStringArray(["rundown", "run_down"])
		"run_left":
			return PackedStringArray(["run_left", "runL", "runleft"])
		"runleft":
			return PackedStringArray(["runleft", "run_left", "runL"])
		"run_right":
			return PackedStringArray(["runright", "run_right"])
		"runright":
			return PackedStringArray(["runright", "run_right"])
		"run_up":
			return PackedStringArray(["run_up", "runup"])
		_:
			return PackedStringArray([name])


## 从 npc.json 的均匀网格描述生成 SpriteFrames（与详情预览一致，用于无 ocad_npc.tscn 时拖入场景）。
func _build_sprite_frames_from_json_grid(tex: Texture2D, spritesheet: Dictionary) -> SpriteFrames:
	var animations: Dictionary = spritesheet.get("animations", {})
	if animations.is_empty():
		return null
	var sf := SpriteFrames.new()
	var default_fps := maxf(1.0, float(spritesheet.get("defaultFps", 8)))
	for anim_key in animations.keys():
		var anim_name := String(anim_key)
		var anim_data: Dictionary = animations[anim_key]
		var frames := _build_frames_from_anim_data(tex, spritesheet, anim_data)
		if frames.is_empty():
			continue
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, bool(anim_data.get("loop", true)))
		sf.set_animation_speed(anim_name, default_fps)
		for atlas in frames:
			sf.add_frame(anim_name, atlas, 1.0)
	if sf.get_animation_names().is_empty():
		return null
	return sf


## 拖入场景用：RPG Maker / ocad 内置切帧优先，失败则回落 JSON 网格。
func _build_sprite_frames_for_spawn(item: Dictionary, tex: Texture2D) -> SpriteFrames:
	if tex == null:
		return null
	if _item_prefers_rpgmaker_slices(item):
		var rpg_sf := _get_rpgmaker_sprite_frames(tex)
		if rpg_sf != null:
			return rpg_sf
	if _item_prefers_ocad_slices(item):
		var ocad_sf := _get_ocad_sprite_frames(tex)
		if ocad_sf != null:
			return ocad_sf
	var data: Dictionary = item.get("data", {})
	var spritesheet: Dictionary = data.get("spritesheet", {})
	return _build_sprite_frames_from_json_grid(tex, spritesheet)


## 按 ext 提示、分类与 role 选默认待机；名称同时兼容 ocad（idledown）与 JSON（idle_down）。
func _pick_spawn_start_animation(item: Dictionary, sf: SpriteFrames) -> StringName:
	if sf == null:
		return StringName("")
	var data: Dictionary = item.get("data", {})
	var ext: Dictionary = data.get("ext", {})
	var hinted := String(ext.get("spawnIdleAnim", ext.get("cardPreviewAnim", ""))).strip_edges()
	if hinted != "":
		for v in _anim_name_variants(hinted):
			if sf.has_animation(v):
				return StringName(v)
	var meta: Dictionary = data.get("meta", {})
	var gameplay: Dictionary = data.get("gameplay", {})
	var category := String(meta.get("category", ""))
	var role := String(gameplay.get("role", "")).to_lower()
	var prefer: PackedStringArray
	match category:
		"combat":
			prefer = PackedStringArray(["idledown", "idle_down", "defence", "idleL", "idle_left", "idleup", "idle_up"])
		"shop", "function", "quest":
			prefer = PackedStringArray(["idledown", "idle_down", "idleL", "idle_left", "idleup", "idle_up"])
		_:
			prefer = PackedStringArray(["idledown", "idle_down", "idleL", "idle_left", "idleup", "idle_up"])
	if role.find("guard") >= 0 or role.find("patrol") >= 0:
		var merged := PackedStringArray(["walkdown", "walk_down", "idledown", "idle_down", "idleL", "idle_left"])
		for p in prefer:
			if not merged.has(p):
				merged.append(p)
		prefer = merged
	for anim in prefer:
		if sf.has_animation(anim):
			return StringName(anim)
	var run_fallback := PackedStringArray([
		"rundown", "run_down", "runleft", "run_left", "runL",
		"runright", "run_right", "runup", "run_up"
	])
	for anim in run_fallback:
		for v in _anim_name_variants(anim):
			if sf.has_animation(v):
				return StringName(v)
	for n in sf.get_animation_names():
		return n
	return StringName("")


func _show_preview_frame() -> void:
	if _preview_frames.is_empty():
		_preview_rect.texture = null
		return
	_preview_frame_idx = clampi(_preview_frame_idx, 0, _preview_frames.size() - 1)
	_preview_rect.texture = _preview_frames[_preview_frame_idx]


func _resolve_sprite_res_path(item: Dictionary) -> String:
	var data: Dictionary = item.get("data", {})
	var assets: Dictionary = data.get("assets", {})
	var sprite_path := String(assets.get("spritePath", "")).strip_edges()
	if sprite_path == "":
		return ""
	# 支持绝对资源路径（res:// / user://），不要再与 json 目录拼接
	if sprite_path.begins_with("res://") or sprite_path.begins_with("user://"):
		return sprite_path
	var json_path := String(item.get("path", ""))
	if json_path == "":
		return ""
	var base_dir := json_path.get_base_dir()
	return base_dir.path_join(sprite_path.trim_prefix("./"))


## 精灵图候选路径：优先 JSON 中的 spritePath；若文件不存在（甲方常写成 elune_xxx 但实际放了 sprite.png），再尝试同目录约定俗成文件名。
func _sprite_texture_candidate_paths(item: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var seen := {}
	var primary := _resolve_sprite_res_path(item)
	if primary != "":
		out.append(primary)
		seen[primary] = true
	var json_path := String(item.get("path", "")).strip_edges()
	if json_path == "":
		return out
	var base_dir := json_path.get_base_dir()
	for name in ["sprite.png", "spritesheet.png", "character.png"]:
		var p := base_dir.path_join(name)
		if seen.get(p, false):
			continue
		out.append(p)
		seen[p] = true
	return out


func _load_sprite_texture(item: Dictionary) -> Texture2D:
	for target_path in _sprite_texture_candidate_paths(item):
		if target_path == "" or not ResourceLoader.exists(target_path):
			continue
		var tex := load(target_path)
		if tex is Texture2D:
			return tex
	return null


func _current_item() -> Dictionary:
	if _selected_source_index < 0 or _selected_source_index >= _items.size():
		return {}
	return _items[_selected_source_index]


func _clear_cards() -> void:
	_card_previews.clear()
	for c in _cards_grid.get_children():
		c.queue_free()
	_cards_grid.custom_minimum_size = Vector2.ZERO


func _refresh_cards_min_size() -> void:
	var count := _cards_grid.get_child_count()
	if count <= 0:
		_cards_grid.custom_minimum_size = Vector2.ZERO
		return
	var cols := max(1, _cards_grid.columns)
	var rows := int(ceil(float(count) / float(cols)))
	var card_h := float(DOCK_CARD_H)
	var gap := float(DOCK_GRID_SEP_V)
	_cards_grid.custom_minimum_size = Vector2(0, rows * card_h + max(0, rows - 1) * gap)


func _build_ai_logic_inline_panel(parent: VBoxContainer) -> void:
	var mode_row := HBoxContainer.new()
	mode_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_theme_constant_override("separation", 8)
	parent.add_child(mode_row)
	var mode_label := Label.new()
	mode_label.text = "行为类型"
	mode_label.custom_minimum_size = Vector2(72, 0)
	mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_row.add_child(mode_label)
	_ai_mode_option = OptionButton.new()
	_ai_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ai_mode_option.size_flags_stretch_ratio = 1.0
	_ai_mode_option.add_item("待机")
	_ai_mode_option.set_item_metadata(0, "idle")
	_ai_mode_option.add_item("不规则移动")
	_ai_mode_option.set_item_metadata(1, "wander")
	_ai_mode_option.add_item("路径移动")
	_ai_mode_option.set_item_metadata(2, "path")
	_ai_mode_option.add_item("自定义动作")
	_ai_mode_option.set_item_metadata(3, "action")
	_ai_mode_option.item_selected.connect(func(_idx: int) -> void:
		_apply_ai_mode_defaults()
		_refresh_ai_logic_mode_visibility()
		_save_ai_logic_from_dialog()
	)
	_ai_mode_option.add_item("左右移动")
	_ai_mode_option.set_item_metadata(4, "horizontal_move")
	_ai_mode_option.add_item("上下移动")
	_ai_mode_option.set_item_metadata(5, "vertical_move")
	mode_row.add_child(_ai_mode_option)
	_ai_arcade_mode_check = CheckBox.new()
	_ai_arcade_mode_check.text = "街机模式"
	_ai_arcade_mode_check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_ai_arcade_mode_check.toggled.connect(func(_on: bool) -> void:
		_save_ai_logic_from_dialog()
	)
	mode_row.add_child(_ai_arcade_mode_check)

	var move_style_row := HBoxContainer.new()
	move_style_row.name = "MoveStyleRow"
	move_style_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_style_row.add_theme_constant_override("separation", 8)
	parent.add_child(move_style_row)
	var ms_label := Label.new()
	ms_label.text = "移动方式"
	ms_label.custom_minimum_size = Vector2(72, 0)
	ms_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	move_style_row.add_child(ms_label)
	_ai_move_style_option = OptionButton.new()
	_ai_move_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ai_move_style_option.add_item("走")
	_ai_move_style_option.set_item_metadata(0, "walk")
	_ai_move_style_option.add_item("跑")
	_ai_move_style_option.set_item_metadata(1, "run")
	_ai_move_style_option.item_selected.connect(func(_idx: int) -> void:
		_save_ai_logic_from_dialog()
	)
	move_style_row.add_child(_ai_move_style_option)

	_ai_speed_spin = _create_ai_spin_row(parent, "速度", 1, 300, 30)
	_ai_rest_spin = _create_ai_spin_row(parent, "间隔", 1, 10, 2)
	_ai_step_spin = _create_ai_spin_row(parent, "单次移动距离", 4, 400, 26)
	_ai_range_spin = _create_ai_spin_row(parent, "活动范围", 8, 800, 120)
	_ai_speed_spin.value_changed.connect(func(_v: float) -> void: _save_ai_logic_from_dialog())
	_ai_rest_spin.value_changed.connect(func(_v: float) -> void: _save_ai_logic_from_dialog())
	_ai_step_spin.value_changed.connect(func(_v: float) -> void: _save_ai_logic_from_dialog())
	_ai_range_spin.value_changed.connect(func(_v: float) -> void: _save_ai_logic_from_dialog())
	if _ai_range_spin != null and _ai_range_spin.get_parent() is HBoxContainer:
		var range_row := _ai_range_spin.get_parent() as HBoxContainer
		if range_row.get_child_count() > 0 and range_row.get_child(0) is Label:
			(range_row.get_child(0) as Label).text = "移动范围"

	var axis_row := HBoxContainer.new()
	axis_row.name = "RunAxisRow"
	axis_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	axis_row.add_theme_constant_override("separation", 8)
	parent.add_child(axis_row)
	var axis_label := Label.new()
	axis_label.text = "奔跑方向"
	axis_label.custom_minimum_size = Vector2(72, 0)
	axis_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	axis_row.add_child(axis_label)
	_ai_run_axis_option = OptionButton.new()
	_ai_run_axis_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ai_run_axis_option.add_item("左右来回")
	_ai_run_axis_option.set_item_metadata(0, "horizontal")
	_ai_run_axis_option.add_item("上下来回")
	_ai_run_axis_option.set_item_metadata(1, "vertical")
	_ai_run_axis_option.item_selected.connect(func(_idx: int) -> void:
		_save_ai_logic_from_dialog()
	)
	axis_row.add_child(_ai_run_axis_option)
	axis_row.visible = false

	_path_section = VBoxContainer.new()
	_path_section.name = "PathSection"
	_path_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_section.add_theme_constant_override("separation", 4)
	parent.add_child(_path_section)
	var path_title := Label.new()
	path_title.text = "移动路径（相对角色初始位置）"
	path_title.add_theme_font_size_override("font_size", 11)
	_path_section.add_child(path_title)
	_path_points_container = VBoxContainer.new()
	_path_points_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_section.add_child(_path_points_container)
	_path_add_btn = Button.new()
	_path_add_btn.text = "添加移动点"
	_path_add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_add_btn.pressed.connect(_on_ai_path_add_point_pressed)
	_path_section.add_child(_path_add_btn)
	var ping_row := HBoxContainer.new()
	ping_row.add_theme_constant_override("separation", 8)
	_path_section.add_child(ping_row)
	_path_pingpong_check = CheckBox.new()
	_path_pingpong_check.text = "折返（到终点后沿路返回并循环）"
	_path_pingpong_check.toggled.connect(_on_ai_path_pingpong_toggled)
	ping_row.add_child(_path_pingpong_check)
	var van_row := HBoxContainer.new()
	van_row.add_theme_constant_override("separation", 8)
	_path_section.add_child(van_row)
	_path_vanish_check = CheckBox.new()
	_path_vanish_check.text = "到达终点后消失（仅在不折返时生效）"
	_path_vanish_check.toggled.connect(func(_on: bool) -> void: _save_ai_logic_from_dialog())
	van_row.add_child(_path_vanish_check)

	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 8)
	parent.add_child(action_row)
	var action_label := Label.new()
	action_label.text = "动作"
	action_label.custom_minimum_size = Vector2(72, 0)
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_row.add_child(action_label)
	_ai_action_option = OptionButton.new()
	_ai_action_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ai_action_option.size_flags_stretch_ratio = 1.0
	_ai_action_option.item_selected.connect(func(_idx: int) -> void:
		_save_ai_logic_from_dialog()
	)
	action_row.add_child(_ai_action_option)


func _create_ai_spin_row(parent: VBoxContainer, label_text: String, minv: float, maxv: float, defaultv: float) -> SpinBox:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(72, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minv
	spin.max_value = maxv
	spin.step = 1
	spin.value = defaultv
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return spin


func _dir_to_label(dir_key: String) -> String:
	match String(dir_key):
		"up":
			return "上"
		"down":
			return "下"
		"left":
			return "左"
		"right":
			return "右"
		_:
			return dir_key


func _on_ai_path_pingpong_toggled(pressed: bool) -> void:
	if _path_vanish_check != null:
		_path_vanish_check.disabled = pressed
		if pressed:
			_path_vanish_check.button_pressed = false
	_save_ai_logic_from_dialog()


func _on_ai_path_add_point_pressed() -> void:
	_add_path_point_row({"dir": "right", "dist": 48.0})
	_save_ai_logic_from_dialog()


func _clear_path_point_rows() -> void:
	if _path_points_container == null:
		return
	for c in _path_points_container.get_children():
		_path_points_container.remove_child(c)
		c.free()


func _add_path_point_row(pt: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(56, 0)
	var dirs := ["up", "down", "left", "right"]
	for d in dirs:
		opt.add_item(_dir_to_label(d))
		opt.set_item_metadata(opt.item_count - 1, d)
	var want := String(pt.get("dir", "right"))
	for i in range(opt.item_count):
		if String(opt.get_item_metadata(i)) == want:
			opt.select(i)
			break
	opt.item_selected.connect(func(_i: int) -> void: _save_ai_logic_from_dialog())
	row.add_child(opt)
	var spin := SpinBox.new()
	spin.min_value = 1.0
	spin.max_value = 4000.0
	spin.step = 1.0
	spin.value = float(pt.get("dist", 48.0))
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(_v: float) -> void: _save_ai_logic_from_dialog())
	row.add_child(spin)
	var del_btn := Button.new()
	del_btn.text = "删"
	del_btn.custom_minimum_size = Vector2(36, 0)
	del_btn.pressed.connect(func() -> void:
		row.queue_free()
		_save_ai_logic_from_dialog()
	)
	row.add_child(del_btn)
	_path_points_container.add_child(row)


func _rebuild_path_point_rows_from_cfg(cfg: Dictionary) -> void:
	_clear_path_point_rows()
	var pts: Variant = cfg.get("path_points", [])
	var arr: Array = []
	if pts is Array:
		arr = pts as Array
	if arr.is_empty():
		arr = [{"dir": "right", "dist": 48.0}]
	for pt in arr:
		if pt is Dictionary:
			_add_path_point_row(pt)
		else:
			_add_path_point_row({"dir": "right", "dist": 48.0})


func _collect_path_points_from_ui() -> Array:
	var out: Array = []
	if _path_points_container == null:
		return out
	for row in _path_points_container.get_children():
		if not row is HBoxContainer:
			continue
		var h := row as HBoxContainer
		if h.get_child_count() < 2:
			continue
		var opt := h.get_child(0) as OptionButton
		var sp := h.get_child(1) as SpinBox
		if opt == null or sp == null:
			continue
		out.append({
			"dir": String(opt.get_selected_metadata()),
			"dist": float(sp.value)
		})
	return out


func _normalize_saved_ai_logic(cfg: Dictionary) -> Dictionary:
	var c := cfg.duplicate(true)
	var m := String(c.get("mode", "idle"))
	if m == "walk":
		c["mode"] = "wander"
		if not c.has("wander_move"):
			c["wander_move"] = "walk"
	elif m == "run":
		c["mode"] = "wander"
		if not c.has("wander_move"):
			c["wander_move"] = "run"
	if not c.has("wander_move"):
		c["wander_move"] = "walk"
	if not c.has("range"):
		c["range"] = _default_ai_range_for_mode(m)
	var ppa: Variant = c.get("path_points")
	if ppa == null or (ppa is Array and (ppa as Array).is_empty()):
		c["path_points"] = [{"dir": "right", "dist": 48.0}]
	if not c.has("path_pingpong"):
		c["path_pingpong"] = true
	if not c.has("path_vanish"):
		c["path_vanish"] = false
	if not c.has("arcade_mode"):
		c["arcade_mode"] = false
	return c


func _default_ai_range_for_mode(mode: String) -> float:
	if mode == "horizontal_move" or mode == "vertical_move":
		return _ai_axis_default_range
	return 120.0


func _apply_ai_mode_defaults() -> void:
	if _ai_mode_option == null or _ai_range_spin == null:
		return
	var mode := String(_ai_mode_option.get_selected_metadata())
	if mode != "horizontal_move" and mode != "vertical_move":
		return
	var default_range := _default_ai_range_for_mode(mode)
	if is_zero_approx(_ai_range_spin.value - 120.0) or _ai_range_spin.value < 120.0:
		_ai_range_spin.value = default_range


func _refresh_ai_logic_dialog() -> void:
	if _ai_mode_option == null:
		return
	var cfg: Dictionary = _normalize_saved_ai_logic(_get_ai_logic_for_current_item())
	var mode := String(cfg.get("mode", "idle"))
	for i in range(_ai_mode_option.item_count):
		if String(_ai_mode_option.get_item_metadata(i)) == mode:
			_ai_mode_option.select(i)
			break
	var wmove := String(cfg.get("wander_move", "walk"))
	if _ai_move_style_option != null:
		for i in range(_ai_move_style_option.item_count):
			if String(_ai_move_style_option.get_item_metadata(i)) == wmove:
				_ai_move_style_option.select(i)
				break
	_ai_speed_spin.value = float(cfg.get("speed", 30.0))
	_ai_step_spin.value = float(cfg.get("step_distance", 26.0))
	_ai_rest_spin.value = float(cfg.get("rest_seconds", 2.0))
	_ai_range_spin.value = float(cfg.get("range", _default_ai_range_for_mode(mode)))
	var axis := String(cfg.get("run_axis", "horizontal"))
	for i in range(_ai_run_axis_option.item_count):
		if String(_ai_run_axis_option.get_item_metadata(i)) == axis:
			_ai_run_axis_option.select(i)
			break
	_suppress_ai_logic_save = true
	if _ai_arcade_mode_check != null:
		_ai_arcade_mode_check.button_pressed = bool(cfg.get("arcade_mode", false))
	_rebuild_path_point_rows_from_cfg(cfg)
	_suppress_ai_logic_save = false
	if _path_pingpong_check != null:
		_path_pingpong_check.button_pressed = bool(cfg.get("path_pingpong", true))
	if _path_vanish_check != null:
		_path_vanish_check.button_pressed = bool(cfg.get("path_vanish", false))
		_path_vanish_check.disabled = bool(cfg.get("path_pingpong", true))
	_ai_action_option.clear()
	var item := _current_item()
	if not item.is_empty():
		var names := _get_available_anim_names_for_item(item)
		for n in names:
			_ai_action_option.add_item(n)
	var selected_action := String(cfg.get("action", "idledown"))
	for i in range(_ai_action_option.item_count):
		if _ai_action_option.get_item_text(i) == selected_action:
			_ai_action_option.select(i)
			break
	if _ai_action_option.item_count <= 0:
		_ai_action_option.add_item("idledown")
		_ai_action_option.select(0)
	_refresh_ai_logic_mode_visibility()


func _refresh_ai_logic_mode_visibility() -> void:
	if _ai_mode_option == null:
		return
	var mode := String(_ai_mode_option.get_selected_metadata())
	var is_wander := mode == "wander"
	var is_axis_patrol := mode == "horizontal_move" or mode == "vertical_move" or mode == "run"
	var is_path := mode == "path"
	var ms_row := _ai_move_style_option.get_parent() if _ai_move_style_option != null else null
	if ms_row is Control:
		(ms_row as Control).visible = is_wander or is_axis_patrol or is_path
	if _ai_speed_spin and _ai_speed_spin.get_parent():
		_ai_speed_spin.get_parent().visible = is_wander or is_axis_patrol or is_path
	if _ai_step_spin and _ai_step_spin.get_parent():
		_ai_step_spin.get_parent().visible = is_wander
	if _ai_rest_spin and _ai_rest_spin.get_parent():
		_ai_rest_spin.get_parent().visible = is_wander or is_axis_patrol
	if _ai_range_spin and _ai_range_spin.get_parent():
		_ai_range_spin.get_parent().visible = is_wander or is_axis_patrol
	if _ai_run_axis_option and _ai_run_axis_option.get_parent():
		_ai_run_axis_option.get_parent().visible = mode == "run"
	if _path_section != null:
		_path_section.visible = is_path
	var action_row := _ai_action_option.get_parent() if _ai_action_option != null else null
	if action_row is Control:
		(action_row as Control).visible = mode == "action"


func _save_ai_logic_from_dialog() -> void:
	if _suppress_ai_logic_save:
		return
	var item := _current_item()
	if item.is_empty() or _ai_mode_option == null:
		return
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var npc_id := String(meta.get("id", ""))
	if npc_id == "":
		return
	var mode := String(_ai_mode_option.get_selected_metadata())
	var action := "idledown"
	if _ai_action_option != null and _ai_action_option.item_count > 0:
		action = _ai_action_option.get_item_text(_ai_action_option.selected)
	var run_axis := "horizontal"
	if _ai_run_axis_option != null:
		run_axis = String(_ai_run_axis_option.get_selected_metadata())
	var wander_move := "walk"
	if _ai_move_style_option != null:
		wander_move = String(_ai_move_style_option.get_selected_metadata())
	var path_pts := _collect_path_points_from_ui()
	if mode == "path" and path_pts.is_empty():
		path_pts = [{"dir": "right", "dist": 48.0}]
	var pingpong := true
	var vanish := false
	if _path_pingpong_check != null:
		pingpong = _path_pingpong_check.button_pressed
	if _path_vanish_check != null:
		vanish = _path_vanish_check.button_pressed and not pingpong
	_ai_logic_by_id[npc_id] = {
		"enabled": mode != "idle",
		"mode": mode,
		"speed": float(_ai_speed_spin.value) if _ai_speed_spin != null else 30.0,
		"step_distance": float(_ai_step_spin.value) if _ai_step_spin != null else 26.0,
		"rest_seconds": float(_ai_rest_spin.value) if _ai_rest_spin != null else 2.0,
		"range": float(_ai_range_spin.value) if _ai_range_spin != null else 120.0,
		"wander_move": wander_move,
		"run_axis": run_axis,
		"action": action,
		"path_points": path_pts,
		"path_pingpong": pingpong,
		"path_vanish": vanish,
		"arcade_mode": _ai_arcade_mode_check.button_pressed if _ai_arcade_mode_check != null else false
	}
	_set_status("已保存行为逻辑：%s" % mode)


func _get_ai_logic_for_item(item: Dictionary) -> Dictionary:
	var base := {
		"enabled": true,
		"mode": "wander",
		"speed": 30.0,
		"step_distance": 26.0,
		"rest_seconds": 2.0,
		"wander_move": "walk",
		"run_axis": "horizontal",
		"action": "idledown",
		"path_points": [{"dir": "right", "dist": 48.0}],
		"path_pingpong": true,
		"path_vanish": false,
		"arcade_mode": false
	}
	if item.is_empty():
		return _normalize_saved_ai_logic(base)
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var npc_id := String(meta.get("id", ""))
	if npc_id != "" and _ai_logic_by_id.has(npc_id):
		return _normalize_saved_ai_logic(_ai_logic_by_id[npc_id])
	return _normalize_saved_ai_logic(base)


func _get_ai_logic_for_current_item() -> Dictionary:
	return _get_ai_logic_for_item(_current_item())


func _get_available_anim_names_for_item(item: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var tex := _load_sprite_texture(item)
	if tex != null and _item_prefers_rpgmaker_slices(item):
		var sf_rpg := _get_rpgmaker_sprite_frames(tex)
		if sf_rpg != null:
			return _sorted_anim_names_from_sprite_frames(sf_rpg)
	if tex != null and _item_prefers_ocad_slices(item):
		var sf := _get_ocad_sprite_frames(tex)
		if sf != null:
			return _sorted_anim_names_from_sprite_frames(sf)
	var data: Dictionary = item.get("data", {})
	var spritesheet: Dictionary = data.get("spritesheet", {})
	var animations: Dictionary = spritesheet.get("animations", {})
	var keys := animations.keys()
	keys.sort()
	for k in keys:
		out.append(String(k))
	if out.is_empty():
		out.append("idledown")
	return out


func _open_create_npc_dialog() -> void:
	if _create_npc_dialog == null:
		_build_create_npc_dialog()
	_refresh_create_npc_defaults()
	_popup_dialog_fit_screen(_create_npc_dialog, Vector2i(700, 760), 0.9)


func _build_create_npc_dialog() -> void:
	_create_npc_dialog = AcceptDialog.new()
	_create_npc_dialog.title = "新增NPC"
	_create_npc_dialog.dialog_hide_on_ok = false
	_create_npc_dialog.get_ok_button().text = "生成"
	_create_npc_dialog.confirmed.connect(_confirm_create_npc)
	_dialog_parent().add_child(_create_npc_dialog)

	_create_npc_file_dialog = EditorFileDialog.new()
	_create_npc_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_create_npc_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_create_npc_file_dialog.filters = PackedStringArray(["*.png ; PNG图片", "*.jpg ; JPG图片", "*.jpeg ; JPEG图片", "*.webp ; WEBP图片"])
	_create_npc_file_dialog.exclusive = false
	_create_npc_file_dialog.file_selected.connect(_on_create_npc_file_selected)
	_dialog_parent().add_child(_create_npc_file_dialog)

	var form_scroll := ScrollContainer.new()
	form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	form_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	form_scroll.custom_minimum_size = Vector2(700, 760)
	_create_npc_dialog.add_child(form_scroll)

	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(680, 980)
	wrap.add_theme_constant_override("separation", 8)
	form_scroll.add_child(wrap)

	var tip := Label.new()
	tip.text = "最少填写「角色名称+精灵图」即可创建。"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wrap.add_child(tip)

	var row_style := HBoxContainer.new()
	row_style.add_theme_constant_override("separation", 8)
	wrap.add_child(row_style)
	_create_style_option = OptionButton.new()
	_create_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_style_option.tooltip_text = "与资源过滤画风一致；选「自定义」时在下一行填写 snake_case id（如 cyber_neon）"
	_create_style_option.add_item("古风")
	_create_style_option.set_item_metadata(0, "gufeng")
	_create_style_option.add_item("现代风")
	_create_style_option.set_item_metadata(1, "modern")
	_create_style_option.add_item("中世纪风")
	_create_style_option.set_item_metadata(2, "medieval")
	_create_style_option.add_item("废土科幻")
	_create_style_option.set_item_metadata(3, "wasteland_scifi")
	_create_style_option.add_item("高魔天国")
	_create_style_option.set_item_metadata(4, "high_fantasy_celestial")
	_create_style_option.add_item("自定义…")
	_create_style_option.set_item_metadata(5, CREATE_STYLE_CUSTOM_META)
	_create_style_option.item_selected.connect(func(_idx: int) -> void:
		_update_create_style_custom_visibility()
	)
	row_style.add_child(_create_style_option)
	_create_primary_type_option = OptionButton.new()
	_create_primary_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_primary_type_option.tooltip_text = "决定 meta.category；选「自定义」时在下一行填写主分类（过滤器会按扫描结果出现）。"
	_create_primary_type_option.add_item("路人")
	_create_primary_type_option.set_item_metadata(0, "normal")
	_create_primary_type_option.add_item("商人")
	_create_primary_type_option.set_item_metadata(1, "primary_shop")
	_create_primary_type_option.add_item("任务")
	_create_primary_type_option.set_item_metadata(2, "primary_quest")
	_create_primary_type_option.add_item("战斗")
	_create_primary_type_option.set_item_metadata(3, "primary_combat")
	_create_primary_type_option.add_item("自定义…")
	_create_primary_type_option.set_item_metadata(4, CREATE_PRIMARY_CUSTOM_META)
	_create_primary_type_option.item_selected.connect(func(_idx: int) -> void:
		_update_create_primary_category_custom_visibility()
	)
	if _create_style_option != null:
		var sb_n := _create_style_option.get_theme_stylebox("normal", "OptionButton")
		var sb_h := _create_style_option.get_theme_stylebox("hover", "OptionButton")
		var sb_p := _create_style_option.get_theme_stylebox("pressed", "OptionButton")
		var sb_f := _create_style_option.get_theme_stylebox("focus", "OptionButton")
		if sb_n != null:
			_create_primary_type_option.add_theme_stylebox_override("normal", sb_n)
		if sb_h != null:
			_create_primary_type_option.add_theme_stylebox_override("hover", sb_h)
		if sb_p != null:
			_create_primary_type_option.add_theme_stylebox_override("pressed", sb_p)
		if sb_f != null:
			_create_primary_type_option.add_theme_stylebox_override("focus", sb_f)
	row_style.add_child(_create_primary_type_option)

	_create_style_custom_edit = LineEdit.new()
	_create_style_custom_edit.visible = false
	_create_style_custom_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_style_custom_edit.placeholder_text = "自定义 meta.style（小写英文+下划线，如 cyber_neon、east_island）"
	_create_style_custom_edit.tooltip_text = "须与全项目约定一致；保存后会在「资源过滤」中随扫描出现。"
	wrap.add_child(_create_style_custom_edit)

	_create_primary_category_hint_label = Label.new()
	_create_primary_category_hint_label.text = "主分类 meta.category（仅当选「自定义」主类型时填写）"
	_create_primary_category_hint_label.visible = false
	wrap.add_child(_create_primary_category_hint_label)
	_create_primary_category_custom_edit = LineEdit.new()
	_create_primary_category_custom_edit.visible = false
	_create_primary_category_custom_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_primary_category_custom_edit.placeholder_text = "小写英文+下划线，如 my_series_alpha（勿填中文）"
	_create_primary_category_custom_edit.tooltip_text = "写入 meta.category；过滤器会按扫描结果动态出现。若下方填写了商人/任务等内容，会同时写入 meta.tags 便于按类型筛选。"
	wrap.add_child(_create_primary_category_custom_edit)

	_create_name_edit = LineEdit.new()
	_create_name_edit.placeholder_text = "NPC名称（displayName）"
	wrap.add_child(_create_name_edit)

	_create_id_edit = LineEdit.new()
	_create_id_edit.placeholder_text = "NPC ID（留空自动生成）"
	wrap.add_child(_create_id_edit)

	_create_desc_edit = TextEdit.new()
	_create_desc_edit.custom_minimum_size = Vector2(0, 84)
	_create_desc_edit.placeholder_text = "角色描述（可写长文本：外观、性格、设定等）"
	wrap.add_child(_create_desc_edit)

	var row_sprite := HBoxContainer.new()
	row_sprite.add_theme_constant_override("separation", 8)
	wrap.add_child(row_sprite)
	_create_sprite_path_edit = LineEdit.new()
	_create_sprite_path_edit.placeholder_text = "精灵图路径（res://...）"
	_create_sprite_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_sprite.add_child(_create_sprite_path_edit)
	var sprite_pick := Button.new()
	sprite_pick.text = "选择精灵图"
	sprite_pick.pressed.connect(func() -> void:
		_create_npc_file_dialog.set_meta("target", "sprite")
		_create_npc_file_dialog.popup_centered_ratio(0.72)
	)
	row_sprite.add_child(sprite_pick)

	var row_thumb := HBoxContainer.new()
	row_thumb.add_theme_constant_override("separation", 8)
	wrap.add_child(row_thumb)
	_create_thumb_path_edit = LineEdit.new()
	_create_thumb_path_edit.placeholder_text = "立绘/缩略图（可选，留空则只生成精灵图）"
	_create_thumb_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_thumb.add_child(_create_thumb_path_edit)
	var thumb_pick := Button.new()
	thumb_pick.text = "选择立绘图"
	thumb_pick.pressed.connect(func() -> void:
		_create_npc_file_dialog.set_meta("target", "thumb")
		_create_npc_file_dialog.popup_centered_ratio(0.72)
	)
	row_thumb.add_child(thumb_pick)

	_create_time_logic_check = CheckBox.new()
	_create_time_logic_check.text = "这个角色有时间行动逻辑"
	_create_time_logic_check.toggled.connect(func(_v: bool) -> void:
		_update_create_type_sections_visibility()
	)
	wrap.add_child(_create_time_logic_check)
	_create_time_logic_edit = TextEdit.new()
	_create_time_logic_edit.custom_minimum_size = Vector2(0, 72)
	_create_time_logic_edit.placeholder_text = "填写时间行为文本（例如：20:00出现，05:00消失）"
	wrap.add_child(_create_time_logic_edit)

	_create_faction_logic_check = CheckBox.new()
	_create_faction_logic_check.text = "这个角色有工会/阵营逻辑"
	_create_faction_logic_check.toggled.connect(func(_v: bool) -> void:
		_update_create_type_sections_visibility()
	)
	wrap.add_child(_create_faction_logic_check)
	_create_faction_logic_edit = TextEdit.new()
	_create_faction_logic_edit.custom_minimum_size = Vector2(0, 72)
	_create_faction_logic_edit.placeholder_text = "填写工会/阵营文本（例如：所属阵营、关系、规则）"
	wrap.add_child(_create_faction_logic_edit)

	_create_merchant_section = VBoxContainer.new()
	_create_merchant_section.add_theme_constant_override("separation", 6)
	wrap.add_child(_create_merchant_section)
	var merchant_title := Label.new()
	merchant_title.text = "商人设置（可选）"
	_create_merchant_section.add_child(merchant_title)
	_create_merchant_preset_shop_check = CheckBox.new()
	_create_merchant_preset_shop_check.text = "生成时启用预制商店系统"
	_create_merchant_preset_shop_check.button_pressed = true
	_create_merchant_section.add_child(_create_merchant_preset_shop_check)
	_create_merchant_items_container = VBoxContainer.new()
	_create_merchant_items_container.add_theme_constant_override("separation", 6)
	_create_merchant_section.add_child(_create_merchant_items_container)
	var add_shop_btn := Button.new()
	add_shop_btn.text = "+ 添加商品"
	add_shop_btn.pressed.connect(func() -> void:
		_create_add_shop_item_row()
	)
	_create_merchant_section.add_child(add_shop_btn)

	_create_quest_section = VBoxContainer.new()
	_create_quest_section.add_theme_constant_override("separation", 6)
	wrap.add_child(_create_quest_section)
	var quest_title := Label.new()
	quest_title.text = "任务设置（可选）"
	_create_quest_section.add_child(quest_title)
	_create_quest_items_container = VBoxContainer.new()
	_create_quest_items_container.add_theme_constant_override("separation", 6)
	_create_quest_section.add_child(_create_quest_items_container)
	var add_quest_btn := Button.new()
	add_quest_btn.text = "+ 添加任务"
	add_quest_btn.pressed.connect(func() -> void:
		_create_add_quest_row()
	)
	_create_quest_section.add_child(add_quest_btn)

	_create_combat_section = VBoxContainer.new()
	_create_combat_section.add_theme_constant_override("separation", 6)
	wrap.add_child(_create_combat_section)
	var combat_title := Label.new()
	combat_title.text = "战斗数值（可选）"
	_create_combat_section.add_child(combat_title)
	var combat_row_a := HBoxContainer.new()
	combat_row_a.add_theme_constant_override("separation", 8)
	_create_combat_section.add_child(combat_row_a)
	_create_combat_level_spin = SpinBox.new()
	_create_combat_level_spin.min_value = 1
	_create_combat_level_spin.max_value = 999
	_create_combat_level_spin.step = 1
	_create_combat_level_spin.value = 1
	_create_combat_level_spin.prefix = "等级 "
	_create_combat_level_spin.custom_minimum_size = Vector2(130, 0)
	combat_row_a.add_child(_create_combat_level_spin)
	_create_combat_hp_spin = SpinBox.new()
	_create_combat_hp_spin.min_value = 1
	_create_combat_hp_spin.max_value = 999999
	_create_combat_hp_spin.step = 1
	_create_combat_hp_spin.value = 100
	_create_combat_hp_spin.prefix = "血量 "
	_create_combat_hp_spin.custom_minimum_size = Vector2(150, 0)
	combat_row_a.add_child(_create_combat_hp_spin)
	_create_combat_attack_spin = SpinBox.new()
	_create_combat_attack_spin.min_value = 0
	_create_combat_attack_spin.max_value = 99999
	_create_combat_attack_spin.step = 1
	_create_combat_attack_spin.value = 5
	_create_combat_attack_spin.prefix = "攻击 "
	_create_combat_attack_spin.custom_minimum_size = Vector2(150, 0)
	combat_row_a.add_child(_create_combat_attack_spin)
	var combat_row_b := HBoxContainer.new()
	combat_row_b.add_theme_constant_override("separation", 8)
	_create_combat_section.add_child(combat_row_b)
	_create_combat_defense_spin = SpinBox.new()
	_create_combat_defense_spin.min_value = 0
	_create_combat_defense_spin.max_value = 99999
	_create_combat_defense_spin.step = 1
	_create_combat_defense_spin.value = 3
	_create_combat_defense_spin.prefix = "防御 "
	_create_combat_defense_spin.custom_minimum_size = Vector2(150, 0)
	combat_row_b.add_child(_create_combat_defense_spin)
	_create_combat_speed_spin = SpinBox.new()
	_create_combat_speed_spin.min_value = 0.1
	_create_combat_speed_spin.max_value = 999.0
	_create_combat_speed_spin.step = 0.1
	_create_combat_speed_spin.value = 2.5
	_create_combat_speed_spin.prefix = "移速 "
	_create_combat_speed_spin.custom_minimum_size = Vector2(150, 0)
	combat_row_b.add_child(_create_combat_speed_spin)

	_update_create_type_sections_visibility()
	_update_create_style_custom_visibility()
	_update_create_primary_category_custom_visibility()


func _update_create_style_custom_visibility() -> void:
	if _create_style_custom_edit == null or _create_style_option == null:
		return
	var m := String(_create_style_option.get_selected_metadata())
	_create_style_custom_edit.visible = (m == CREATE_STYLE_CUSTOM_META)


func _create_dialog_resolve_style() -> String:
	if _create_style_option == null:
		return "gufeng"
	var m := String(_create_style_option.get_selected_metadata())
	if m == CREATE_STYLE_CUSTOM_META:
		return _create_style_custom_edit.text.strip_edges() if _create_style_custom_edit != null else ""
	return m


func _create_dialog_primary_meta() -> String:
	if _create_primary_type_option == null:
		return "normal"
	return String(_create_primary_type_option.get_selected_metadata())


func _create_dialog_resolve_category_from_primary() -> String:
	var pm := _create_dialog_primary_meta()
	match pm:
		"normal":
			return "normal"
		"primary_shop":
			return "shop"
		"primary_quest":
			return "quest"
		"primary_combat":
			return "combat"
		CREATE_PRIMARY_CUSTOM_META:
			return _create_primary_category_custom_edit.text.strip_edges().to_lower() if _create_primary_category_custom_edit != null else ""
		_:
			return "normal"


func _create_add_shop_item_row(initial: Dictionary = {}) -> void:
	if _create_merchant_items_container == null:
		return
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	_create_merchant_items_container.add_child(row)
	var line_a := HBoxContainer.new()
	line_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_a.add_theme_constant_override("separation", 6)
	row.add_child(line_a)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "商品名"
	name_edit.text = String(initial.get("itemName", ""))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_a.add_child(name_edit)
	var type_edit := LineEdit.new()
	type_edit.placeholder_text = "类型"
	type_edit.text = String(initial.get("itemType", ""))
	type_edit.custom_minimum_size = Vector2(90, 0)
	line_a.add_child(type_edit)
	var line_b := HBoxContainer.new()
	line_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_b.add_theme_constant_override("separation", 6)
	row.add_child(line_b)
	var icon_edit := LineEdit.new()
	icon_edit.placeholder_text = "商品精灵图（可选，res:// 或 ./）"
	icon_edit.text = String(initial.get("spritePath", ""))
	icon_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_b.add_child(icon_edit)
	var line_c := HBoxContainer.new()
	line_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_c.add_theme_constant_override("separation", 6)
	row.add_child(line_c)
	var price_spin := SpinBox.new()
	price_spin.min_value = 0
	price_spin.max_value = 999999
	price_spin.step = 1
	price_spin.value = float(initial.get("price", 50))
	price_spin.custom_minimum_size = Vector2(72, 0)
	price_spin.prefix = "价格 "
	price_spin.tooltip_text = "商品价格"
	line_c.add_child(price_spin)
	var count_spin := SpinBox.new()
	count_spin.min_value = 1
	count_spin.max_value = 9999
	count_spin.step = 1
	count_spin.value = float(initial.get("count", 1))
	count_spin.custom_minimum_size = Vector2(72, 0)
	count_spin.prefix = "数量 "
	count_spin.tooltip_text = "每次购买数量"
	line_c.add_child(count_spin)
	var stock_spin := SpinBox.new()
	stock_spin.min_value = -1
	stock_spin.max_value = 9999
	stock_spin.step = 1
	stock_spin.value = float(initial.get("stock", -1))
	stock_spin.custom_minimum_size = Vector2(72, 0)
	stock_spin.prefix = "库存 "
	stock_spin.tooltip_text = "商品库存（-1 表示无限）"
	line_c.add_child(stock_spin)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_c.add_child(fill)
	var remove_btn := Button.new()
	remove_btn.text = "删除"
	remove_btn.pressed.connect(func() -> void:
		for i in range(_create_merchant_item_rows.size()):
			if _create_merchant_item_rows[i].get("row", null) == row:
				_create_merchant_item_rows.remove_at(i)
				break
		row.queue_free()
	)
	line_c.add_child(remove_btn)
	_create_merchant_item_rows.append({
		"row": row,
		"name": name_edit,
		"type": type_edit,
		"icon": icon_edit,
		"price": price_spin,
		"count": count_spin,
		"stock": stock_spin
	})


func _create_add_quest_row() -> void:
	if _create_quest_items_container == null:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_create_quest_items_container.add_child(box)
	var title_edit := LineEdit.new()
	title_edit.placeholder_text = "任务标题"
	box.add_child(title_edit)
	var desc_edit := TextEdit.new()
	desc_edit.custom_minimum_size = Vector2(0, 64)
	desc_edit.placeholder_text = "任务描述"
	box.add_child(desc_edit)
	var objective_edit := LineEdit.new()
	objective_edit.placeholder_text = "任务目标"
	box.add_child(objective_edit)
	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 6)
	box.add_child(reward_row)
	var gold_spin := SpinBox.new()
	gold_spin.min_value = 0
	gold_spin.max_value = 9999999
	gold_spin.step = 10
	gold_spin.value = 100
	gold_spin.custom_minimum_size = Vector2(120, 0)
	gold_spin.prefix = "金币 "
	gold_spin.tooltip_text = "任务奖励金币"
	reward_row.add_child(gold_spin)
	var exp_spin := SpinBox.new()
	exp_spin.min_value = 0
	exp_spin.max_value = 9999999
	exp_spin.step = 10
	exp_spin.value = 50
	exp_spin.custom_minimum_size = Vector2(120, 0)
	exp_spin.prefix = "经验 "
	exp_spin.tooltip_text = "任务奖励经验"
	reward_row.add_child(exp_spin)
	var remove_btn := Button.new()
	remove_btn.text = "删除任务"
	remove_btn.pressed.connect(func() -> void:
		for i in range(_create_quest_rows.size()):
			if _create_quest_rows[i].get("row", null) == box:
				_create_quest_rows.remove_at(i)
				break
		box.queue_free()
	)
	reward_row.add_child(remove_btn)
	_create_quest_rows.append({"row": box, "title": title_edit, "desc": desc_edit, "objective": objective_edit, "gold": gold_spin, "exp": exp_spin})


func _update_create_type_sections_visibility() -> void:
	if _create_merchant_section != null:
		_create_merchant_section.visible = true
	if _create_quest_section != null:
		_create_quest_section.visible = true
	if _create_combat_section != null:
		_create_combat_section.visible = true
	if _create_time_logic_edit != null and _create_time_logic_check != null:
		_create_time_logic_edit.visible = _create_time_logic_check.button_pressed
	if _create_faction_logic_edit != null and _create_faction_logic_check != null:
		_create_faction_logic_edit.visible = _create_faction_logic_check.button_pressed


func _update_create_primary_category_custom_visibility() -> void:
	if _create_primary_type_option == null:
		return
	var show_custom := String(_create_primary_type_option.get_selected_metadata()) == CREATE_PRIMARY_CUSTOM_META
	if _create_primary_category_custom_edit != null:
		_create_primary_category_custom_edit.visible = show_custom
	if _create_primary_category_hint_label != null:
		_create_primary_category_hint_label.visible = show_custom


func _refresh_create_npc_defaults() -> void:
	if _create_style_option == null:
		return
	_create_style_option.select(0)
	if _create_style_custom_edit != null:
		_create_style_custom_edit.text = ""
	if _create_primary_type_option != null:
		_create_primary_type_option.select(0)
	if _create_primary_category_custom_edit != null:
		_create_primary_category_custom_edit.text = ""
	_update_create_style_custom_visibility()
	_update_create_primary_category_custom_visibility()
	if _create_name_edit != null:
		_create_name_edit.text = ""
	if _create_id_edit != null:
		_create_id_edit.text = ""
	if _create_desc_edit != null:
		_create_desc_edit.text = ""
	if _create_sprite_path_edit != null:
		_create_sprite_path_edit.text = ""
	if _create_thumb_path_edit != null:
		_create_thumb_path_edit.text = ""
	if _create_time_logic_check != null:
		_create_time_logic_check.button_pressed = false
	if _create_time_logic_edit != null:
		_create_time_logic_edit.text = ""
	if _create_faction_logic_check != null:
		_create_faction_logic_check.button_pressed = false
	if _create_faction_logic_edit != null:
		_create_faction_logic_edit.text = ""
	if _create_merchant_preset_shop_check != null:
		_create_merchant_preset_shop_check.button_pressed = true
	for r in _create_merchant_item_rows:
		var row := r.get("row", null) as Control
		if row != null:
			row.queue_free()
	_create_merchant_item_rows.clear()
	for r in _create_quest_rows:
		var row: VBoxContainer = r.get("row", null)
		if row != null:
			row.queue_free()
	_create_quest_rows.clear()
	if _create_combat_level_spin != null:
		_create_combat_level_spin.value = 1
	if _create_combat_hp_spin != null:
		_create_combat_hp_spin.value = 100
	if _create_combat_attack_spin != null:
		_create_combat_attack_spin.value = 5
	if _create_combat_defense_spin != null:
		_create_combat_defense_spin.value = 3
	if _create_combat_speed_spin != null:
		_create_combat_speed_spin.value = 2.5
	_create_add_shop_item_row()
	_create_add_quest_row()
	_update_create_type_sections_visibility()


func _on_create_npc_file_selected(res_path: String) -> void:
	var target := String(_create_npc_file_dialog.get_meta("target", ""))
	if target == "sprite" and _create_sprite_path_edit != null:
		_create_sprite_path_edit.text = res_path
	elif target == "thumb" and _create_thumb_path_edit != null:
		_create_thumb_path_edit.text = res_path


func _sanitize_folder_name(display_name: String) -> String:
	var s := display_name.strip_edges()
	for bad in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		s = s.replace(bad, "_")
	if s == "":
		s = "未命名角色"
	return s


## 精灵图复制到角色目录后的文件名：与角色名一致 + 源文件扩展名（如 小明.png）
func _export_sprite_filename_for_npc(display_name: String, sprite_src: String) -> String:
	var base := _sanitize_folder_name(display_name)
	var ext := sprite_src.get_extension()
	if ext == "":
		ext = "png"
	return "%s.%s" % [base, ext.to_lower()]


func _confirm_create_npc() -> void:
	var root := _resolved_npc_root
	if root == "":
		root = _resolve_npc_library_root()
	if root == "":
		root = _default_resource_type_root()
	var merchant_preset_enabled := _create_merchant_preset_shop_check != null and _create_merchant_preset_shop_check.button_pressed
	var style := _create_dialog_resolve_style()
	if _create_style_option != null and String(_create_style_option.get_selected_metadata()) == CREATE_STYLE_CUSTOM_META:
		if style == "":
			_set_status("创建失败：选择「自定义」画风时请填写 meta.style（小写英文+下划线）")
			return
	var pmeta := _create_dialog_primary_meta()
	var category := _create_dialog_resolve_category_from_primary()
	if pmeta == CREATE_PRIMARY_CUSTOM_META:
		if category == "":
			_set_status("创建失败：选择「自定义」主类型时请填写 meta.category（小写英文+下划线）")
			return
	var is_primary_shop := pmeta == "primary_shop"
	var is_primary_quest := pmeta == "primary_quest"
	var is_primary_combat := pmeta == "primary_combat"
	var display_name := _create_name_edit.text.strip_edges()
	var sprite_src := _create_sprite_path_edit.text.strip_edges()
	var thumb_src := _create_thumb_path_edit.text.strip_edges()
	if display_name == "":
		_set_status("创建失败：请填写角色名称")
		return
	if sprite_src == "":
		_set_status("创建失败：请选择精灵图")
		return
	if not sprite_src.begins_with("res://"):
		_set_status("创建失败：精灵图路径必须是 res://")
		return
	if not FileAccess.file_exists(sprite_src):
		_set_status("创建失败：精灵图文件不存在")
		return
	if thumb_src != "":
		if not thumb_src.begins_with("res://"):
			_set_status("创建失败：立绘路径必须是 res://")
			return
		if not FileAccess.file_exists(thumb_src):
			_set_status("创建失败：立绘文件不存在")
			return
	var merchant_items: Array[Dictionary] = []
	for r in _create_merchant_item_rows:
		var nm := String((r.get("name", null) as LineEdit).text if r.get("name", null) != null else "").strip_edges()
		if nm == "":
			continue
		merchant_items.append({
			"itemId": "item_custom_%03d" % (merchant_items.size() + 1),
			"itemName": nm,
			"itemType": String((r.get("type", null) as LineEdit).text if r.get("type", null) != null else "").strip_edges(),
			"price": int((r.get("price", null) as SpinBox).value if r.get("price", null) != null else 0),
			"count": int((r.get("count", null) as SpinBox).value if r.get("count", null) != null else 1),
			"spritePath": String((r.get("icon", null) as LineEdit).text if r.get("icon", null) != null else "").strip_edges(),
			"stock": int((r.get("stock", null) as SpinBox).value if r.get("stock", null) != null else -1)
		})

	var quest_items: Array[Dictionary] = []
	for r in _create_quest_rows:
		var q_title := String((r.get("title", null) as LineEdit).text if r.get("title", null) != null else "").strip_edges()
		var q_obj := String((r.get("objective", null) as LineEdit).text if r.get("objective", null) != null else "").strip_edges()
		if q_title == "" or q_obj == "":
			continue
		quest_items.append({
			"enabled": true,
			"title": q_title,
			"description": String((r.get("desc", null) as TextEdit).text if r.get("desc", null) != null else "").strip_edges(),
			"objective": q_obj,
			"rewards": {
				"gold": int((r.get("gold", null) as SpinBox).value if r.get("gold", null) != null else 0),
				"exp": int((r.get("exp", null) as SpinBox).value if r.get("exp", null) != null else 0),
				"items": []
			}
		})

	var has_merchant_content := not merchant_items.is_empty()
	var has_quest_content := not quest_items.is_empty()
	var tag_map: Dictionary = {}
	if has_merchant_content or is_primary_shop:
		tag_map["shop"] = true
	if has_quest_content or is_primary_quest:
		tag_map["quest"] = true
	if is_primary_combat:
		tag_map["combat"] = true
	var meta_tags: Array = []
	for tk in tag_map.keys():
		meta_tags.append(String(tk))
	meta_tags.sort()

	var types_list: Array[String] = []
	types_list.append(category)
	for tg in meta_tags:
		var ts := String(tg)
		if not types_list.has(ts):
			types_list.append(ts)
	var role_types := PackedStringArray()
	for s in types_list:
		role_types.append(s)

	var merchant_feature_on := merchant_preset_enabled and (has_merchant_content or is_primary_shop)
	var can_trade := merchant_feature_on
	var quest_giver := has_quest_content or is_primary_quest or category == "quest"
	var quest_feature_on := quest_giver

	var npc_id := _create_id_edit.text.strip_edges()
	if npc_id == "":
		npc_id = _suggest_new_npc_id_flat(root)
	elif not npc_id.begins_with("npc_"):
		npc_id = "npc_%s" % npc_id
		_set_status("提示：已自动补全ID前缀为 %s" % npc_id)

	var folder_name := _sanitize_folder_name(display_name)
	var target_dir := root.path_join(folder_name)
	var target_dir_abs := ProjectSettings.globalize_path(target_dir)
	if DirAccess.dir_exists_absolute(target_dir_abs):
		_set_status("创建失败：已存在同名角色文件夹：%s" % folder_name)
		return
	DirAccess.make_dir_recursive_absolute(target_dir_abs)

	var sprite_filename := _export_sprite_filename_for_npc(display_name, sprite_src)
	var sprite_dst := target_dir.path_join(sprite_filename)
	var copy_a := DirAccess.copy_absolute(ProjectSettings.globalize_path(sprite_src), ProjectSettings.globalize_path(sprite_dst))
	if copy_a != OK:
		_set_status("创建失败：精灵图复制失败")
		return
	if thumb_src != "":
		var thumb_dst := target_dir.path_join("thumb.png")
		var copy_b := DirAccess.copy_absolute(ProjectSettings.globalize_path(thumb_src), ProjectSettings.globalize_path(thumb_dst))
		if copy_b != OK:
			_set_status("创建失败：立绘复制失败")
			return

	var assets_dict: Dictionary = {
		"spritePath": "./%s" % sprite_filename
	}
	if thumb_src != "":
		assets_dict["thumbPath"] = "./thumb.png"

	var data := {
		"schemaVersion": 1,
		"meta": {
			"id": npc_id,
			"displayName": display_name,
			"style": style,
			"category": category,
			"types": role_types,
			"description": _create_desc_edit.text.strip_edges() if _create_desc_edit != null else "",
			"generator": "manual_create_dialog",
			"createdAt": Time.get_datetime_string_from_system(true, true),
			"updatedAt": Time.get_datetime_string_from_system(true, true),
			"tags": meta_tags
		},
		"assets": assets_dict,
		"spritesheet": {
			"layoutVersion": "yituquan_v1",
			"frameWidth": 128,
			"frameHeight": 128,
			"columns": 8,
			"rows": 12,
			"margin": 0,
			"spacing": 0,
			"defaultFps": 8,
			"animations": {
				"idle_down": {"row": 0, "from": 0, "to": 7, "loop": true},
				"walk_down": {"row": 1, "from": 0, "to": 7, "loop": true},
				"idle_left": {"row": 2, "from": 0, "to": 7, "loop": true},
				"walk_left": {"row": 3, "from": 0, "to": 7, "loop": true},
				"idle_up": {"row": 6, "from": 0, "to": 7, "loop": true},
				"walk_up": {"row": 7, "from": 0, "to": 7, "loop": true}
			}
		},
		"gameplay": {
			"faction": "neutral",
			"role": category,
			"level": int(_create_combat_level_spin.value) if _create_combat_level_spin != null else 1,
			"stats": {
				"hp": int(_create_combat_hp_spin.value) if _create_combat_hp_spin != null else 100,
				"attack": int(_create_combat_attack_spin.value) if _create_combat_attack_spin != null else 5,
				"defense": int(_create_combat_defense_spin.value) if _create_combat_defense_spin != null else 3,
				"moveSpeed": float(_create_combat_speed_spin.value) if _create_combat_speed_spin != null else 2.5
			},
			"interaction": {"canTalk": true, "canTrade": can_trade, "questGiver": quest_giver},
			"merchant": {
				"enabled": merchant_feature_on,
				"shopItems": merchant_items
			},
			"quest": {
				"enabled": quest_feature_on,
				"title": (quest_items[0].get("title", "") if not quest_items.is_empty() else ""),
				"description": (quest_items[0].get("description", "") if not quest_items.is_empty() else ""),
				"objective": (quest_items[0].get("objective", "") if not quest_items.is_empty() else ""),
				"rewards": (quest_items[0].get("rewards", {"gold": 0, "exp": 0, "items": []}) if not quest_items.is_empty() else {"gold": 0, "exp": 0, "items": []}),
				"tasks": quest_items
			}
		},
		"ext": {
			"localization": {
				"appearance": {"zh": "", "ja": "", "en": ""},
				"background": {"zh": "", "ja": "", "en": ""},
				"dialogues": {
					"greeting": {"zh": "", "ja": "", "en": ""},
					"shopOpen": {"zh": "", "ja": "", "en": ""},
					"questHint": {"zh": "", "ja": "", "en": ""}
				}
			},
			"animationParams": "standard_humanoid_4dir",
			"dialogueState": "",
			"timeBehaviorText": _create_time_logic_edit.text.strip_edges() if _create_time_logic_check != null and _create_time_logic_check.button_pressed and _create_time_logic_edit != null else "",
			"factionBehaviorText": _create_faction_logic_edit.text.strip_edges() if _create_faction_logic_check != null and _create_faction_logic_check.button_pressed and _create_faction_logic_edit != null else "",
			"otherPayload": {},
			"projectPrivate": {},
			"shopSystem": {
				"enabled": merchant_feature_on,
				"presetId": "npc_library_tool_default_shop_v1"
			}
		}
	}
	var json_path := target_dir.path_join("npc.json")
	if not _repo.save_npc_json(json_path, data):
		_set_status("创建失败：写入 npc.json 失败")
		return
	_set_status("创建成功：%s" % json_path)
	_create_npc_dialog.hide()
	_refresh_list()


func _suggest_new_npc_id_flat(root: String) -> String:
	var n := 1
	while true:
		var candidate := "npc_normal_%03d" % n
		var full := root.path_join(candidate)
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(full)):
			return candidate
		n += 1
	return "npc_normal_001"


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
	else:
		push_warning("[AI资源库] %s" % text)


## 弹窗限制在屏幕内（首次打开不会因固定像素超出可视区域）
func _popup_dialog_fit_screen(dialog: Window, minsize: Vector2i, fallback_ratio: float) -> void:
	call_deferred("_popup_dialog_fit_screen_impl", dialog, minsize, fallback_ratio)


func _popup_dialog_fit_screen_impl(dialog: Window, minsize: Vector2i, fallback_ratio: float) -> void:
	if dialog == null or not is_instance_valid(dialog):
		return
	if not dialog.is_inside_tree():
		return
	var r := clampf(fallback_ratio, 0.42, 0.9)
	var vp := Vector2(1280.0, 720.0)
	if _editor_interface != null:
		var bc := _editor_interface.get_base_control()
		if is_instance_valid(bc):
			vp = bc.get_viewport().get_visible_rect().size
	if vp.x < 128.0 or vp.y < 128.0:
		vp = Vector2(DisplayServer.screen_get_size())
	var max_w := maxi(320, int(vp.x * r))
	var max_h := maxi(260, int(vp.y * r))
	dialog.min_size = Vector2i.ZERO
	dialog.max_size = Vector2i(max_w, max_h)
	dialog.popup_centered_clamped(minsize, r)


func _open_ui_skin_editor() -> void:
	if _ui_skin_dialog == null:
		_build_ui_skin_editor_dialog()
	_refresh_ui_skin_preview()
	_refresh_ui_skin_layout_list()
	if _ui_skin_advanced_panel != null:
		_ui_skin_advanced_panel.visible = false
	if _ui_skin_advanced_btn != null:
		_ui_skin_advanced_btn.text = "高级选项：布局预设…"
	_popup_dialog_fit_screen(_ui_skin_dialog, Vector2i(560, 380), 0.88)


func _on_ui_skin_advanced_pressed() -> void:
	if _ui_skin_advanced_panel == null:
		return
	var on := not _ui_skin_advanced_panel.visible
	_ui_skin_advanced_panel.visible = on
	if _ui_skin_advanced_btn != null:
		_ui_skin_advanced_btn.text = "收起高级选项" if on else "高级选项：布局预设…"


func _build_ui_skin_editor_dialog() -> void:
	_ui_skin_dialog = AcceptDialog.new()
	_ui_skin_dialog.title = "对话UI框编辑"
	_ui_skin_dialog.dialog_hide_on_ok = true
	_ui_skin_dialog.get_ok_button().text = "关闭"
	_dialog_parent().add_child(_ui_skin_dialog)

	_ui_skin_file_dialog = EditorFileDialog.new()
	_ui_skin_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_ui_skin_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_ui_skin_file_dialog.filters = PackedStringArray(["*.png ; PNG图片", "*.jpg ; JPG图片", "*.jpeg ; JPEG图片", "*.webp ; WEBP图片"])
	# 与已弹出的 AcceptDialog 同属 /root 子窗口时，若二者均为 exclusive 会触发 engine 报错
	_ui_skin_file_dialog.exclusive = false
	_dialog_parent().add_child(_ui_skin_file_dialog)
	_ui_skin_file_dialog.file_selected.connect(_on_ui_skin_file_selected)

	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(520, 300)
	wrap.add_theme_constant_override("separation", 8)
	_ui_skin_dialog.add_child(wrap)

	var tip_brief := Label.new()
	tip_brief.text = "替换下方三张贴图，即可改变对话界面外观。"
	tip_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wrap.add_child(tip_brief)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 8)
	wrap.add_child(left_col)

	_add_ui_skin_row(left_col, "dialog_bg", "对话框底图", DIALOG_ASSET_DIALOG_BG)
	_add_ui_skin_row(left_col, "portrait_frame", "立绘框", DIALOG_ASSET_PORTRAIT_FRAME)
	_add_ui_skin_row(left_col, "name_plate", "名字框", DIALOG_ASSET_NAME_PLATE)

	_ui_skin_advanced_btn = Button.new()
	_ui_skin_advanced_btn.text = "高级选项：布局预设…"
	_ui_skin_advanced_btn.tooltip_text = "展开后可保存/读取控件位置（需在 dialogue_ui_default.tscn 中编辑并 Ctrl+S）"
	_ui_skin_advanced_btn.pressed.connect(_on_ui_skin_advanced_pressed)
	wrap.add_child(_ui_skin_advanced_btn)

	_ui_skin_advanced_panel = VBoxContainer.new()
	_ui_skin_advanced_panel.visible = false
	_ui_skin_advanced_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_skin_advanced_panel.add_theme_constant_override("separation", 6)
	wrap.add_child(_ui_skin_advanced_panel)

	var tip_adv := Label.new()
	tip_adv.text = "在场景 dialogue_ui_default.tscn 里拖好位置后按 Ctrl+S，再在此命名并保存；读取可切换预设；恢复默认还原插件内置布局。"
	tip_adv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui_skin_advanced_panel.add_child(tip_adv)

	_ui_skin_layout_scroll = ScrollContainer.new()
	_ui_skin_layout_scroll.custom_minimum_size = Vector2(0, 180)
	_ui_skin_layout_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_skin_layout_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ui_skin_layout_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ui_skin_layout_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_ui_skin_advanced_panel.add_child(_ui_skin_layout_scroll)

	var right_inner := VBoxContainer.new()
	right_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_inner.add_theme_constant_override("separation", 6)
	_ui_skin_layout_scroll.add_child(right_inner)

	var rh := Label.new()
	rh.text = "布局预设"
	rh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_inner.add_child(rh)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	right_inner.add_child(name_row)

	_ui_skin_layout_name_edit = LineEdit.new()
	_ui_skin_layout_name_edit.placeholder_text = "新布局名称"
	_ui_skin_layout_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_ui_skin_layout_name_edit)

	var save_layout_btn := Button.new()
	save_layout_btn.text = "保存当前布局"
	save_layout_btn.tooltip_text = "从磁盘上的 dialogue_ui_default.tscn 读取当前节点位置（请先在该场景里 Ctrl+S）。保存为 JSON 布局数据，非图片。"
	save_layout_btn.pressed.connect(_on_dialogue_layout_save_current_pressed)
	name_row.add_child(save_layout_btn)

	var restore_btn := Button.new()
	restore_btn.text = "恢复默认布局"
	restore_btn.tooltip_text = "用 dialogue_ui_default_builtin.tscn 覆盖 dialogue_ui_default.tscn（不删除已保存的预设文件）。"
	restore_btn.pressed.connect(_on_dialogue_layout_restore_builtin_pressed)
	right_inner.add_child(restore_btn)

	_ui_skin_layout_rows = VBoxContainer.new()
	_ui_skin_layout_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_skin_layout_rows.add_theme_constant_override("separation", 6)
	right_inner.add_child(_ui_skin_layout_rows)


func _add_ui_skin_row(parent: VBoxContainer, key: String, label_text: String, target_res_path: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var tag := Label.new()
	tag.text = label_text
	tag.custom_minimum_size = Vector2(120, 0)
	row.add_child(tag)

	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(120, 64)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(preview)
	_ui_skin_preview_rects[key] = preview

	var path_edit := LineEdit.new()
	path_edit.placeholder_text = "res:// 路径（支持粘贴或拖入）"
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(path_edit)
	_ui_skin_path_inputs[key] = path_edit

	var apply_btn := Button.new()
	apply_btn.text = "应用路径"
	apply_btn.pressed.connect(func() -> void:
		_replace_ui_skin_asset_from_path(key, target_res_path, path_edit.text.strip_edges())
	)
	row.add_child(apply_btn)

	var pick_btn := Button.new()
	pick_btn.text = "选择文件"
	pick_btn.pressed.connect(func() -> void:
		_ui_skin_file_dialog.set_meta("target_key", key)
		_ui_skin_file_dialog.set_meta("target_path", target_res_path)
		_ui_skin_file_dialog.popup_centered_ratio(0.72)
	)
	row.add_child(pick_btn)


func _on_ui_skin_file_selected(res_path: String) -> void:
	var key := String(_ui_skin_file_dialog.get_meta("target_key", ""))
	var target_res_path := String(_ui_skin_file_dialog.get_meta("target_path", ""))
	if key == "" or target_res_path == "":
		return
	_replace_ui_skin_asset_from_path(key, target_res_path, res_path)


func _replace_ui_skin_asset_from_path(key: String, target_res_path: String, src_res_path: String) -> void:
	if src_res_path == "" or target_res_path == "":
		_set_status("替换失败：路径为空")
		return
	if not src_res_path.begins_with("res://"):
		_set_status("替换失败：仅支持 res:// 资源路径")
		return
	if not FileAccess.file_exists(src_res_path):
		_set_status("替换失败：源文件不存在")
		return
	var src_abs := ProjectSettings.globalize_path(src_res_path)
	var dst_abs := ProjectSettings.globalize_path(target_res_path)
	var err := DirAccess.copy_absolute(src_abs, dst_abs)
	if err != OK:
		_set_status("替换失败：%s" % error_string(err))
		return
	if _ui_skin_path_inputs.has(key):
		var edit: LineEdit = _ui_skin_path_inputs[key]
		edit.text = src_res_path
	ResourceLoader.load(target_res_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	_refresh_ui_skin_preview()
	_set_status("已替换：%s" % target_res_path)


func _refresh_ui_skin_preview() -> void:
	_refresh_ui_skin_preview_item("dialog_bg", DIALOG_ASSET_DIALOG_BG)
	_refresh_ui_skin_preview_item("portrait_frame", DIALOG_ASSET_PORTRAIT_FRAME)
	_refresh_ui_skin_preview_item("name_plate", DIALOG_ASSET_NAME_PLATE)


func _refresh_ui_skin_preview_item(key: String, path: String) -> void:
	if not _ui_skin_preview_rects.has(key):
		return
	var rect: TextureRect = _ui_skin_preview_rects[key]
	if not ResourceLoader.exists(path):
		rect.texture = null
		return
	var tex := load(path)
	rect.texture = tex if tex is Texture2D else null


func _editor_filesystem_scan() -> void:
	if _editor_interface == null:
		return
	var fs := _editor_interface.get_resource_filesystem()
	if fs != null:
		fs.scan()


func _ensure_dialogue_layout_storage() -> void:
	var root := DirAccess.open("res://")
	if root == null:
		return
	var p_data := "addons/npc_library_tool/editor_data"
	var p_presets := "addons/npc_library_tool/editor_data/dialogue_layout_presets"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://" + p_data)):
		root.make_dir_recursive(p_data)
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://" + p_presets)):
		root.make_dir_recursive(p_presets)


func _dialogue_layout_index_load() -> Dictionary:
	if not FileAccess.file_exists(DIALOGUE_LAYOUT_PRESETS_INDEX):
		return {"version": 1, "presets": []}
	var f := FileAccess.open(DIALOGUE_LAYOUT_PRESETS_INDEX, FileAccess.READ)
	if f == null:
		return {"version": 1, "presets": []}
	var txt := f.get_as_text()
	f.close()
	var v: Variant = JSON.parse_string(txt)
	if v is Dictionary:
		var d: Dictionary = v
		if not d.has("presets"):
			d["presets"] = []
		return d
	return {"version": 1, "presets": []}


func _dialogue_layout_index_save(data: Dictionary) -> void:
	_ensure_dialogue_layout_storage()
	var f := FileAccess.open(DIALOGUE_LAYOUT_PRESETS_INDEX, FileAccess.WRITE)
	if f == null:
		_set_status("保存布局索引失败：无法写入 editor_data")
		return
	f.store_string(JSON.stringify(data))
	f.close()


func _dialogue_layout_copy_res_file(src: String, dst: String) -> Error:
	if not FileAccess.file_exists(src):
		return ERR_FILE_NOT_FOUND
	var abs_s := ProjectSettings.globalize_path(src)
	var abs_d := ProjectSettings.globalize_path(dst)
	return DirAccess.copy_absolute(abs_s, abs_d)


func _refresh_ui_skin_layout_list() -> void:
	if _ui_skin_layout_rows == null:
		return
	for c in _ui_skin_layout_rows.get_children():
		c.queue_free()
	var idx := _dialogue_layout_index_load()
	var presets: Array = idx.get("presets", [])
	if presets.is_empty():
		var empty := Label.new()
		empty.text = "暂无保存的布局"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ui_skin_layout_rows.add_child(empty)
		return
	for p in presets:
		if p is not Dictionary:
			continue
		var d: Dictionary = p
		var display := String(d.get("display_name", ""))
		var preset_path := String(d.get("file", ""))
		if preset_path == "":
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl := Label.new()
		lbl.text = display if display != "" else preset_path.get_file()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		lbl.tooltip_text = preset_path
		row.add_child(lbl)
		var load_btn := Button.new()
		load_btn.text = "读取"
		load_btn.pressed.connect(_on_dialogue_layout_load_preset_pressed.bind(preset_path))
		row.add_child(load_btn)
		var del_btn := Button.new()
		del_btn.text = "删除"
		del_btn.pressed.connect(_on_dialogue_layout_delete_preset_pressed.bind(preset_path))
		row.add_child(del_btn)
		_ui_skin_layout_rows.add_child(row)


func _on_dialogue_layout_load_preset_pressed(preset_path: String) -> void:
	if preset_path == "" or not FileAccess.file_exists(preset_path):
		_set_status("读取失败：预设文件不存在")
		return
	var ext := preset_path.get_extension().to_lower()
	if ext == "json":
		var f := FileAccess.open(preset_path, FileAccess.READ)
		if f == null:
			_set_status("读取失败：无法打开预设")
			return
		var txt := f.get_as_text()
		f.close()
		var parsed: Variant = JSON.parse_string(txt)
		if not (parsed is Dictionary):
			_set_status("读取失败：预设不是有效的布局 JSON")
			return
		var layout_data: Dictionary = parsed
		var err := DialogueLayoutPresetIo.save_layout_to_scene_file(layout_data, DIALOGUE_UI_SCENE_PATH)
		if err != OK:
			_set_status("应用布局失败：%s" % error_string(err))
			return
		_editor_filesystem_scan()
		_set_status("已应用布局预设（节点锚点与偏移）到 dialogue_ui_default.tscn")
		return
	# 旧版：整场景 .tscn 副本（兼容早期保存）
	if ext == "tscn":
		var err2 := _dialogue_layout_copy_res_file(preset_path, DIALOGUE_UI_SCENE_PATH)
		if err2 != OK:
			_set_status("应用旧版预设失败：%s" % error_string(err2))
			return
		_editor_filesystem_scan()
		_set_status("已用旧版场景副本覆盖默认对话场景")
		return
	_set_status("不支持的预设类型：%s" % ext)


func _on_dialogue_layout_delete_preset_pressed(preset_path: String) -> void:
	var idx := _dialogue_layout_index_load()
	var presets: Array = idx.get("presets", [])
	var display := ""
	var next: Array = []
	for p in presets:
		if p is Dictionary:
			var fp := String((p as Dictionary).get("file", ""))
			if fp == preset_path:
				display = String((p as Dictionary).get("display_name", ""))
				continue
		next.append(p)
	idx["presets"] = next
	_dialogue_layout_index_save(idx)
	if preset_path != "" and FileAccess.file_exists(preset_path):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(preset_path))
		if err != OK:
			_set_status("删除布局文件失败：%s" % error_string(err))
	_refresh_ui_skin_layout_list()
	_editor_filesystem_scan()
	_set_status("已删除布局：%s" % (display if display != "" else preset_path.get_file()))


func _on_dialogue_layout_save_current_pressed() -> void:
	var raw_name := ""
	if _ui_skin_layout_name_edit != null:
		raw_name = _ui_skin_layout_name_edit.text.strip_edges()
	if raw_name == "":
		_set_status("请先输入布局名称")
		return
	if not FileAccess.file_exists(DIALOGUE_UI_SCENE_PATH):
		_set_status("保存失败：找不到默认对话场景")
		return
	var ps: PackedScene = ResourceLoader.load(DIALOGUE_UI_SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if ps == null:
		_set_status("保存失败：无法加载对话场景（请先在编辑器中打开 dialogue_ui_default.tscn 并按 Ctrl+S 保存）")
		return
	var inst := ps.instantiate()
	if inst == null:
		_set_status("保存失败：无法实例化对话场景")
		return
	var layout_data: Dictionary = DialogueLayoutPresetIo.collect_from_instance(inst)
	inst.queue_free()
	_ensure_dialogue_layout_storage()
	var id_str := "%s_%s" % [str(Time.get_unix_time_from_system()), str(randi() % 100000000)]
	var file_rel := DIALOGUE_LAYOUT_PRESETS_DIR + "preset_%s.json" % id_str
	var wf := FileAccess.open(file_rel, FileAccess.WRITE)
	if wf == null:
		_set_status("保存失败：无法写入布局文件")
		return
	wf.store_string(JSON.stringify(layout_data))
	wf.close()
	var idx := _dialogue_layout_index_load()
	var presets: Array = idx.get("presets", [])
	presets.append({
		"id": id_str,
		"display_name": raw_name,
		"file": file_rel,
	})
	idx["presets"] = presets
	_dialogue_layout_index_save(idx)
	_refresh_ui_skin_layout_list()
	_editor_filesystem_scan()
	_set_status("已保存布局数据（锚点/偏移）：%s" % raw_name)


func _on_dialogue_layout_restore_builtin_pressed() -> void:
	if not FileAccess.file_exists(DIALOGUE_UI_BUILTIN_PATH):
		_set_status("恢复失败：缺少内置模板 dialogue_ui_default_builtin.tscn")
		return
	var err := _dialogue_layout_copy_res_file(DIALOGUE_UI_BUILTIN_PATH, DIALOGUE_UI_SCENE_PATH)
	if err != OK:
		_set_status("恢复默认失败：%s" % error_string(err))
		return
	_editor_filesystem_scan()
	_set_status("已将默认对话场景恢复为插件内置布局")


func _open_npc_portrait_editor() -> void:
	if not _enable_dialogue_check.button_pressed:
		_set_status("请先勾选“创建对话系统”")
		return
	var item := _current_item()
	if item.is_empty():
		_set_status("请先选择一个NPC卡片")
		return
	if _npc_portrait_dialog == null:
		_build_npc_portrait_editor_dialog()
	_refresh_npc_portrait_editor_view()
	_popup_dialog_fit_screen(_npc_portrait_dialog, Vector2i(520, 300), 0.88)


func _build_npc_portrait_editor_dialog() -> void:
	_npc_portrait_dialog = AcceptDialog.new()
	_npc_portrait_dialog.title = "NPC立绘编辑"
	_npc_portrait_dialog.dialog_hide_on_ok = true
	_npc_portrait_dialog.get_ok_button().text = "关闭"
	_dialog_parent().add_child(_npc_portrait_dialog)

	_npc_portrait_file_dialog = EditorFileDialog.new()
	_npc_portrait_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_npc_portrait_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_npc_portrait_file_dialog.filters = PackedStringArray(["*.png ; PNG图片", "*.jpg ; JPG图片", "*.jpeg ; JPEG图片", "*.webp ; WEBP图片"])
	_npc_portrait_file_dialog.file_selected.connect(func(path: String) -> void:
		if _npc_portrait_path_edit != null:
			_npc_portrait_path_edit.text = path
		_apply_npc_portrait_override(path)
	)
	_npc_portrait_file_dialog.exclusive = false
	_dialog_parent().add_child(_npc_portrait_file_dialog)

	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(700, 280)
	wrap.add_theme_constant_override("separation", 8)
	_npc_portrait_dialog.add_child(wrap)

	var tip := Label.new()
	tip.text = "当前NPC默认立绘可在此替换（仅对该NPC生效）。支持粘贴 res:// 路径或选择文件。"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wrap.add_child(tip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	wrap.add_child(row)

	_npc_portrait_preview_rect = TextureRect.new()
	_npc_portrait_preview_rect.custom_minimum_size = Vector2(220, 180)
	_npc_portrait_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_npc_portrait_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_npc_portrait_preview_rect)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)

	_npc_portrait_path_edit = LineEdit.new()
	_npc_portrait_path_edit.placeholder_text = "res:// 立绘路径"
	_npc_portrait_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_npc_portrait_path_edit)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	right.add_child(btn_row)

	var apply_btn := Button.new()
	apply_btn.text = "应用路径"
	apply_btn.pressed.connect(func() -> void:
		_apply_npc_portrait_override(_npc_portrait_path_edit.text.strip_edges())
	)
	btn_row.add_child(apply_btn)

	var choose_btn := Button.new()
	choose_btn.text = "选择文件"
	choose_btn.pressed.connect(func() -> void:
		_npc_portrait_file_dialog.popup_centered_ratio(0.72)
	)
	btn_row.add_child(choose_btn)

	var reset_btn := Button.new()
	reset_btn.text = "恢复默认立绘"
	reset_btn.pressed.connect(_clear_npc_portrait_override)
	btn_row.add_child(reset_btn)


func _refresh_npc_portrait_editor_view() -> void:
	var item := _current_item()
	if item.is_empty() or _npc_portrait_preview_rect == null:
		return
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var assets: Dictionary = data.get("assets", {})
	var npc_id := String(meta.get("id", ""))
	var path := ""
	if npc_id != "" and _npc_portrait_override_by_id.has(npc_id):
		path = String(_npc_portrait_override_by_id[npc_id])
	else:
		var rel := String(assets.get("thumbPath", ""))
		var json_path := String(item.get("path", ""))
		if rel != "" and json_path != "":
			path = json_path.get_base_dir().path_join(rel.trim_prefix("./"))
	if _npc_portrait_path_edit != null:
		_npc_portrait_path_edit.text = path
	var tex: Resource = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path)
	_npc_portrait_preview_rect.texture = tex if tex is Texture2D else null


func _apply_npc_portrait_override(path: String) -> void:
	var item := _current_item()
	if item.is_empty():
		_set_status("未选中NPC，无法设置立绘")
		return
	if path == "":
		_set_status("立绘路径不能为空")
		return
	if not path.begins_with("res://"):
		_set_status("立绘路径必须是 res://")
		return
	if not FileAccess.file_exists(path):
		_set_status("立绘文件不存在")
		return
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var npc_id := String(meta.get("id", ""))
	if npc_id == "":
		_set_status("当前NPC缺少ID，无法绑定立绘")
		return
	_npc_portrait_override_by_id[npc_id] = path
	_refresh_npc_portrait_editor_view()
	_set_status("已设置NPC立绘：%s" % path)


func _clear_npc_portrait_override() -> void:
	var item := _current_item()
	if item.is_empty():
		return
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var npc_id := String(meta.get("id", ""))
	if npc_id != "" and _npc_portrait_override_by_id.has(npc_id):
		_npc_portrait_override_by_id.erase(npc_id)
	_refresh_npc_portrait_editor_view()
	_set_status("已恢复NPC默认立绘")


func _npc_json_dialogues_map(data: Dictionary) -> Dictionary:
	var ext: Dictionary = data.get("ext", {})
	var loc: Dictionary = ext.get("localization", {})
	var d: Variant = loc.get("dialogues", {})
	return d if d is Dictionary else {}


func _preferred_dialogue_key_order() -> PackedStringArray:
	return PackedStringArray(["greeting", "shopOpen", "questHint", "farewell", "default"])


func _ordered_dialogue_keys_from_map(dlog: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	var pref := _preferred_dialogue_key_order()
	for k in pref:
		if dlog.has(k):
			out.append(k)
			seen[k] = true
	var keys := dlog.keys()
	keys.sort()
	for k in keys:
		var ks := String(k)
		if not seen.get(ks, false):
			out.append(ks)
			seen[ks] = true
	return out


func _dialogue_zh_from_entry(entry: Variant) -> String:
	if entry is Dictionary:
		var d: Dictionary = entry
		var zh := String(d.get("zh", d.get("ZH", ""))).strip_edges()
		if zh != "":
			return zh
		return String(d.get("en", d.get("ja", ""))).strip_edges()
	return String(entry).strip_edges()


func _dialogue_lines_zh_ordered_from_json(data: Dictionary) -> PackedStringArray:
	var dlog := _npc_json_dialogues_map(data)
	if dlog.is_empty():
		return PackedStringArray()
	var keys := _ordered_dialogue_keys_from_map(dlog)
	var lines := PackedStringArray()
	for k in keys:
		lines.append(_dialogue_zh_from_entry(dlog[k]))
	return lines


func _get_old_dialogue_entry(data: Dictionary, key: String) -> Dictionary:
	var dlog := _npc_json_dialogues_map(data)
	if dlog.has(key):
		var e: Variant = dlog[key]
		return e if e is Dictionary else {}
	return {}


func _merge_dialogue_entry_preserve_locales(old: Dictionary, zh: String) -> Dictionary:
	return {
		"zh": zh,
		"ja": String(old.get("ja", "")),
		"en": String(old.get("en", "")),
	}


func _next_flat_dialogue_key_for_editor() -> String:
	var max_n := 0
	if _dialogue_editor_list != null:
		for row in _dialogue_editor_list.get_children():
			if row is VBoxContainer:
				var k := String(row.get_meta("dialogue_key", ""))
				if k.begins_with("line_") and k.length() > 5:
					var tail := k.substr(5)
					if tail.is_valid_int():
						var n := int(tail)
						if n > max_n:
							max_n = n
	return "line_%03d" % (max_n + 1)


func _sync_dialogue_editor_tip_for_item(item: Dictionary) -> void:
	if _dialogue_editor_tip_label == null:
		return
	var data: Dictionary = item.get("data", {})
	var dlog := _npc_json_dialogues_map(data)
	var json_path := String(item.get("path", "")).strip_edges()
	var has_file := json_path.begins_with("res://")
	if not dlog.is_empty():
		_dialogue_editor_tip_label.text = "已从 npc.json 的 ext.localization.dialogues 加载台词（按分类编辑中文；保存会写回 JSON，并保留各分类下的 ja/en）。"
	elif has_file:
		_dialogue_editor_tip_label.text = "当前 JSON 未包含 ext.localization.dialogues；可点击下方添加台词，保存后将写入 JSON（按 line_001、line_002… 分类）。"
	else:
		_dialogue_editor_tip_label.text = "当前角色 JSON 不在项目内（无 res:// 路径），台词仅保存在本次编辑器会话中；可导出或放到 res:// 下再保存到文件。"


func _open_dialogue_editor() -> void:
	if not _enable_dialogue_check.button_pressed:
		_set_status("请先勾选“创建对话系统”")
		return
	var item := _current_item()
	if item.is_empty():
		_set_status("请先选择一个NPC卡片")
		return
	if _dialogue_editor_dialog == null:
		_build_dialogue_editor_dialog()
	_refresh_dialogue_editor_view()
	_popup_dialog_fit_screen(_dialogue_editor_dialog, Vector2i(560, 400), 0.88)


func _build_dialogue_editor_dialog() -> void:
	_dialogue_editor_dialog = AcceptDialog.new()
	_dialogue_editor_dialog.title = "对话内容编辑"
	_dialogue_editor_dialog.dialog_hide_on_ok = true
	_dialogue_editor_dialog.get_ok_button().text = "关闭"
	_dialog_parent().add_child(_dialogue_editor_dialog)

	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(720, 480)
	wrap.add_theme_constant_override("separation", 8)
	_dialogue_editor_dialog.add_child(wrap)

	_dialogue_editor_tip_label = Label.new()
	_dialogue_editor_tip_label.text = "加载中…"
	_dialogue_editor_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wrap.add_child(_dialogue_editor_tip_label)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	wrap.add_child(top_row)

	var new_btn := Button.new()
	new_btn.text = "新建对话内容"
	new_btn.pressed.connect(func() -> void:
		_add_dialogue_line_row("", _next_flat_dialogue_key_for_editor())
		_save_dialogue_lines_from_editor()
	)
	top_row.add_child(new_btn)

	var clear_btn := Button.new()
	clear_btn.text = "清空全部"
	clear_btn.pressed.connect(func() -> void:
		if _dialogue_editor_list == null:
			return
		for c in _dialogue_editor_list.get_children():
			c.queue_free()
		_save_dialogue_lines_from_editor()
	)
	top_row.add_child(clear_btn)

	_dialogue_editor_scroll = ScrollContainer.new()
	_dialogue_editor_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_editor_scroll.custom_minimum_size = Vector2(0, 380)
	wrap.add_child(_dialogue_editor_scroll)

	_dialogue_editor_list = VBoxContainer.new()
	_dialogue_editor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_editor_list.add_theme_constant_override("separation", 10)
	_dialogue_editor_scroll.add_child(_dialogue_editor_list)


func _refresh_dialogue_editor_view() -> void:
	if _dialogue_editor_list == null:
		return
	var item := _current_item()
	_sync_dialogue_editor_tip_for_item(item)
	for c in _dialogue_editor_list.get_children():
		c.queue_free()
	var data: Dictionary = item.get("data", {})
	var dlog := _npc_json_dialogues_map(data)
	if not dlog.is_empty():
		var keys := _ordered_dialogue_keys_from_map(dlog)
		for k in keys:
			var zh := _dialogue_zh_from_entry(dlog[k])
			_add_dialogue_line_row(zh, String(k))
	else:
		var lines := _get_dialogue_lines_for_item(item)
		var n := lines.size()
		if n == 0:
			_add_dialogue_line_row("", "line_001")
		else:
			for i in range(n):
				_add_dialogue_line_row(String(lines[i]), "line_%03d" % (i + 1))


func _add_dialogue_line_row(text: String, dialogue_key: String = "") -> void:
	if _dialogue_editor_list == null:
		return
	var row := VBoxContainer.new()
	row.set_meta("dialogue_key", dialogue_key)
	row.add_theme_constant_override("separation", 6)
	_dialogue_editor_list.add_child(row)

	if dialogue_key != "":
		var lk := Label.new()
		lk.text = "分类：%s（zh → ext.localization.dialogues）" % dialogue_key
		lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(lk)

	var edit := TextEdit.new()
	edit.custom_minimum_size = Vector2(0, 90)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text = text
	edit.text_changed.connect(_save_dialogue_lines_from_editor)
	row.add_child(edit)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	row.add_child(actions)

	var next_btn := Button.new()
	next_btn.text = "下一句"
	next_btn.pressed.connect(func() -> void:
		_add_dialogue_line_row("", _next_flat_dialogue_key_for_editor())
		_save_dialogue_lines_from_editor()
	)
	actions.add_child(next_btn)

	var del_btn := Button.new()
	del_btn.text = "删除本句"
	del_btn.pressed.connect(func() -> void:
		row.queue_free()
		call_deferred("_save_dialogue_lines_from_editor")
	)
	actions.add_child(del_btn)


func _save_dialogue_lines_from_editor() -> void:
	var item := _current_item()
	if item.is_empty() or _dialogue_editor_list == null:
		return
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var npc_id := String(meta.get("id", ""))
	if npc_id == "":
		return
	var new_dialogues: Dictionary = {}
	var out_lines := PackedStringArray()
	var row_idx := 0
	for row in _dialogue_editor_list.get_children():
		if not row is VBoxContainer:
			continue
		var r: VBoxContainer = row
		row_idx += 1
		var key := String(r.get_meta("dialogue_key", ""))
		var te: TextEdit = null
		for ch in r.get_children():
			if ch is TextEdit:
				te = ch as TextEdit
				break
		if te == null:
			continue
		var t := te.text.strip_edges()
		if t == "":
			continue
		if key == "":
			key = "line_%03d" % row_idx
		var old_e := _get_old_dialogue_entry(data, key)
		new_dialogues[key] = _merge_dialogue_entry_preserve_locales(old_e, t)
		out_lines.append(t)
	var ext: Dictionary = data.get("ext", {})
	var loc: Dictionary = ext.get("localization", {})
	loc["dialogues"] = new_dialogues
	ext["localization"] = loc
	data["ext"] = ext
	_dialogue_lines_by_id[npc_id] = out_lines
	var json_path := String(item.get("path", "")).strip_edges()
	if json_path.begins_with("res://"):
		if _repo.save_npc_json(json_path, data):
			var si := _selected_source_index
			if si >= 0 and si < _items.size():
				_items[si]["data"] = data
			_set_status("已保存台词到 npc.json：%d 条（ext.localization.dialogues）" % out_lines.size())
		else:
			_set_status("保存失败：无法写入 npc.json")
	else:
		var si2 := _selected_source_index
		if si2 >= 0 and si2 < _items.size():
			_items[si2]["data"] = data
		_set_status("已缓存台词 %d 条（当前无 res:// JSON 路径，未写入磁盘）" % out_lines.size())


func _get_dialogue_lines_for_item(item: Dictionary) -> PackedStringArray:
	if item.is_empty():
		return PackedStringArray(AD_DIALOGUE_LINES)
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var npc_id := String(meta.get("id", ""))
	if npc_id != "" and _dialogue_lines_by_id.has(npc_id):
		return _with_ad_dialogue_lines(PackedStringArray(_dialogue_lines_by_id[npc_id]))
	var from_json := _dialogue_lines_zh_ordered_from_json(data)
	return _with_ad_dialogue_lines(from_json)


func _with_ad_dialogue_lines(lines: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for line in lines:
		var t := String(line).strip_edges()
		if t != "" and out.find(t) < 0:
			out.append(t)
	for ad in AD_DIALOGUE_LINES:
		if out.find(ad) < 0:
			out.append(ad)
	return out


func _get_dialogue_lines_for_current_item() -> PackedStringArray:
	return _get_dialogue_lines_for_item(_current_item())


func _select_option_by_text(ob: OptionButton, value: String) -> void:
	for i in range(ob.item_count):
		if ob.get_item_text(i) == value:
			ob.select(i)
			return
	ob.select(0)


func _select_option_by_metadata(ob: OptionButton, value: String) -> void:
	for i in range(ob.item_count):
		if String(ob.get_item_metadata(i)) == value:
			ob.select(i)
			return
	ob.select(0)


func _try_set_property(node: Node, prop: String, value: Variant) -> void:
	if value == null:
		return
	for p in node.get_property_list():
		if String(p.get("name", "")) == prop:
			node.set(prop, value)
			return


func _set_owner_recursive(root: Node, owner: Node) -> void:
	root.owner = owner
	for c in root.get_children():
		if c is Node:
			_set_owner_recursive(c, owner)


## 打包前设置 owner：遇到子场景实例（scene_file_path 非空）时，
## 仅设实例根的 owner，不递归其内部子节点，否则 PackedScene 会把子场景内联。
func _set_owner_for_packing(pack_root: Node, current: Node) -> void:
	for c in current.get_children():
		if not c is Node:
			continue
		c.owner = pack_root
		if String(c.scene_file_path) != "":
			pass
		else:
			_set_owner_for_packing(pack_root, c)


## 拖入主场景后设置 owner：实例根 owner=主场景根，内部子节点不设（保持子场景实例关系）。
func _set_spawned_scene_instance_ownership(instance_root: Node, edited_scene_root: Node) -> void:
	instance_root.owner = edited_scene_root


func _count_style(style: String) -> int:
	var c := 0
	for it in _items:
		if String(it.get("style", "")) == style:
			c += 1
	return c


func _style_to_cn(style: String) -> String:
	match style:
		"gufeng":
			return "古风"
		"modern":
			return "现代风"
		"medieval":
			return "中世纪风"
		_:
			return style


func _category_to_cn(category: String) -> String:
	match category:
		"shop":
			return "商店类"
		"function":
			return "功能类"
		"quest":
			return "任务类"
		"combat":
			return "战斗类"
		_:
			return category
