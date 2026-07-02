@tool
extends Node2D

const VOICE_FILE_EXTENSIONS := [".mp3", ".ogg", ".wav"]

const FootShadowFactory := preload("res://addons/npc_library_tool/runtime/npc_foot_shadow_factory.gd")
const SHOP_ASSET_BASE := "res://addons/npc_library_tool/runtime/shop_preset/assets/"
const SHOP_ASSET_BG := SHOP_ASSET_BASE + "背包分页40.png"
const SHOP_ASSET_SLOT := SHOP_ASSET_BASE + "空白格子界面.png"

## 运行时商店 / 简易对话框等 UI 按此「设计画布」与当前视口短边比例做统一缩放（与 dialogue_ui_default 默认一致）
const DEFAULT_UI_DESIGN_VIEWPORT := Vector2(1920.0, 1080.0)
## 商店弹层整体（含标题栏、关闭键、商品区）按此设计像素作为缩放前尺寸
const SHOP_DESIGN_POPUP_SIZE := Vector2(760.0, 460.0)
## 无预制对话时的简易台词框设计尺寸
const FALLBACK_DIALOG_DESIGN_SIZE := Vector2(560.0, 240.0)
const INTERACT_PROMPT_TEXT := "press E to active"
const INTERACT_PROMPT_FONT_SIZE := 8
const INTERACT_PROMPT_POS := Vector2(-60, -45)
const INTERACT_PROMPT_SIZE := Vector2(120, 28)
@export var ui_design_reference_size: Vector2 = DEFAULT_UI_DESIGN_VIEWPORT
@export var ui_scale_min: float = 0.38
@export var ui_scale_max: float = 2.6

@export var npc_display_name: String = "商人"
@export var dialogue_line: String = "功能还未实现"
@export var dialogue_lines: PackedStringArray = PackedStringArray()
@export var enable_dialogue_system: bool = true
## 留空则用插件自带预制。可复制 `dialogue_ui_default.tscn` 到项目里改布局后拖到这里；脚本需保留 `start_dialogue` 与 `dialogue_sequence_finished`。全局只实例化一个对话层，多 NPC 请统一填同一 PackedScene，避免先触发的 NPC 用了默认预制。
@export var dialogue_ui_scene: PackedScene
@export var npc_portrait: Texture2D
@export_file("*.png", "*.jpg", "*.webp") var npc_portrait_path: String = ""
@export var preferred_voice_locale: String = "chinese"
@export var enable_proximity_voice: bool = true
@export var enable_dialogue_voice: bool = true
@export var enable_ai_logic: bool = false
@export var ai_mode: String = "idle" # idle / wander / horizontal_move / vertical_move / path / action（旧版 walk/run 仍兼容）
@export var ai_range: float = 120.0
@export var ai_speed: float = 30.0
@export var ai_step_distance: float = 26.0
@export var ai_run_axis: String = "horizontal" # horizontal / vertical（旧版 run 轴向往返）
@export var ai_action: String = "idledown"
@export var ai_rest_seconds: float = 2.0
@export var ai_wander_move: String = "walk" # walk / run — 不规则移动与路径移动共用
@export var ai_path_pingpong: bool = true
@export var ai_path_vanish: bool = false
@export var ai_arcade_mode: bool = false
@export var interact_radius: float = 5.0
@export var prompt_text: String = INTERACT_PROMPT_TEXT
@export var player_group_candidates: PackedStringArray = PackedStringArray(["player", "Player"])
@export var player_name_keywords: PackedStringArray = PackedStringArray(["player", "hero", "main", "character"])
@export var interact_action_candidates: PackedStringArray = PackedStringArray(["interact", "ui_accept"])
@export var interact_key_fallbacks: PackedInt32Array = PackedInt32Array([KEY_E, KEY_F, KEY_ENTER])
@export var use_distance_fallback: bool = true
@export var distance_fallback_scale: float = 1.0
@export var debug_compat_log: bool = false
@export var enable_shop_system: bool = false
@export var shop_title: String = "商店"
@export var shop_items: Array[Dictionary] = []

var _player_in_range := false
var _panel_open := false
var _prompt: Label
var _area: Area2D
var _dialog_layer: CanvasLayer
var _sprite: Sprite2D
var _player_candidates: Array[Node2D] = []
var _warned_no_player := false
var _warned_no_input := false
var _dialogue_ui_template: CanvasLayer
var _origin_pos := Vector2.ZERO
var _move_target := Vector2.ZERO
var _has_move_target := false
var _anim_sprite: AnimatedSprite2D
var _arcade_face_sign := 1
var _ai_rest_timer := 0.0
var _run_dir_sign := 1
var _axis_move_elapsed := 0.0
var _wp_vertices: PackedVector2Array = PackedVector2Array()
var _wp_seg_lens: PackedFloat32Array = PackedFloat32Array()
var _wp_total_len: float = 0.0
var _wp_dist: float = 0.0
var _wp_ready: bool = false
var _wp_vanish_done: bool = false
var _wp_stopped_at_end: bool = false
var _shop_layer: CanvasLayer
## 整块商店 UI（面板 + 内部一切）挂在此节点下统一缩放，避免只缩内容、窗口壳不缩
var _shop_modal_root: Control = null
var _shop_scale_panel: PanelContainer = null
var _shop_title_label: Label = null
var _shop_await_close := false
var _shop_scroll: ScrollContainer
var _shop_items_box: VBoxContainer
var _shop_status_label: Label
var _shop_tab_buy_btn: Button
var _shop_tab_sell_btn: Button
var _shop_prev_btn: Button
var _shop_next_btn: Button
var _shop_page_label: Label
var _shop_mode: String = "buy"
var _shop_page: int = 0
var _shop_items_per_page: int = 6
## 商店正文区（标签、分页、列表），缩放由外层 _shop_scale_panel 统一处理
var _shop_content_root: VBoxContainer = null
var _pending_runtime_ui_scale := 1.0
var _shop_scale_apply_attempts := 0
var _ui_viewport_listener_ready := false
## 无预制对话 UI 时的简易台词框整块面板（与 AcceptDialog 分离，整板缩放）
var _fallback_scale_panel: PanelContainer = null
var _fallback_simple_await := false
var _fallback_scale_apply_attempts := 0
var _did_hard_sprite_resource_refresh := false
var _proximity_voice_player: AudioStreamPlayer2D
var _voice_paths_by_locale: Dictionary = {}
var _last_player_in_range := false
var _range_voice_played := false
var _proximity_voice_cycle_index := 0


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_stabilize_visual_state")


func _is_path_preview_line(node: Node) -> bool:
	return node is Line2D and String(node.name).begins_with("PathPreview")


func _hide_path_preview_lines_in_runtime() -> void:
	_hide_path_preview_lines_recursive(self)


func _hide_path_preview_lines_recursive(node: Node) -> void:
	if _is_path_preview_line(node):
		(node as Line2D).visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
		return
	for c in node.get_children():
		if c is Node:
			_hide_path_preview_lines_recursive(c as Node)


func _ready() -> void:
	# 路径预览折线仅用于编辑器内对齐，运行/试玩时隐藏，避免画面上出现淡蓝路径线。
	if not Engine.is_editor_hint():
		_hide_path_preview_lines_in_runtime()
	if Engine.is_editor_hint():
		return
	enable_shop_system = _resolve_runtime_shop_enabled_default()
	_force_visible_runtime()
	_ensure_visual_node()
	_ensure_interact_nodes()
	_build_ui_layers()
	_build_audio_nodes()
	_scan_voice_files()
	set_process(true)
	set_physics_process(enable_ai_logic)
	_origin_pos = global_position
	_cache_anim_sprite()
	_stabilize_visual_state()
	call_deferred("_stabilize_visual_state")
	call_deferred("_deferred_visual_boot_late")
	_schedule_runtime_sprite_refresh()
	if ai_mode == "path" and enable_ai_logic:
		call_deferred("_runtime_bootstrap_waypoint_path")


func _resolve_runtime_shop_enabled_default() -> bool:
	var data: Dictionary = get_meta("npc_data", {})
	if data.is_empty():
		return enable_shop_system
	var meta: Dictionary = data.get("meta", {})
	var category := String(meta.get("category", "")).to_lower()
	var is_shop_profile := category == "shop" or category == "merchant"
	if not is_shop_profile:
		return false
	var gameplay: Dictionary = data.get("gameplay", {})
	var merchant_cfg: Dictionary = gameplay.get("merchant", {})
	if merchant_cfg.has("enabled"):
		return bool(merchant_cfg.get("enabled", false))
	var ext: Dictionary = data.get("ext", {})
	var shop_sys: Dictionary = ext.get("shopSystem", {})
	if shop_sys.has("enabled"):
		return bool(shop_sys.get("enabled", false))
	return false


func _stabilize_visual_state() -> void:
	_force_visible_runtime()
	_hide_path_preview_lines_in_runtime()
	if _anim_sprite == null:
		_cache_anim_sprite()
	if _anim_sprite != null:
		_anim_sprite.visible = true
		if not _anim_sprite.is_playing():
			_apply_idle_anim()
		if not _anim_sprite.is_playing():
			var sf := _anim_sprite.sprite_frames
			if sf != null and sf.get_animation_names().size() > 0:
				_anim_sprite.animation = sf.get_animation_names()[0]
				_anim_sprite.frame = 0
				_anim_sprite.play()
		_anim_sprite.queue_redraw()


func _force_visible_runtime() -> void:
	visible = true
	modulate.a = 1.0
	_force_visible_recursive(self)


func _force_visible_recursive(node: Node) -> void:
	if _is_path_preview_line(node):
		(node as Line2D).visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	for c in node.get_children():
		if c is Node:
			_force_visible_recursive(c as Node)


func _ensure_visual_node() -> void:
	# 若已存在 OcadNpc（标准裁剪链路），优先使用，不再创建整图 Sprite2D。
	var ocad := get_node_or_null("OcadNpc")
	if ocad != null:
		# 禁用 OcadNpc 自己的 process，避免和插件的行动逻辑抢动画导致“滑步”。
		ocad.set_process(false)
		ocad.set_physics_process(false)
		ocad.set_process_input(false)
		ocad.set_process_unhandled_input(false)
		var tex := _resolve_texture_from_meta()
		if tex != null:
			_set_prop_if_exists(ocad, "spritesheet", tex)
			# OcadNpc._ready 先于父节点执行：当时 spritesheet 仍为空会直接 return，不会生成 SpriteFrames。
			# 父节点赋值后必须在这里补建，否则运行时 AnimatedSprite2D 无帧（看起来像“不可见”）。
			_apply_ocad_sprite_frames_from_texture(ocad, tex)
		_set_prop_if_exists(ocad, "random_idle", false)
		_set_prop_if_exists(ocad, "random_item", false)
		FootShadowFactory.ensure_under_ocad(ocad)
		_cache_anim_sprite()
		return

	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		add_child(_sprite)
		_sprite.owner = get_tree().edited_scene_root if get_tree() else null
	if _sprite.texture == null:
		var tex := _resolve_texture_from_meta()
		if tex != null:
			_sprite.texture = tex
	_cache_anim_sprite()


func _ensure_interact_nodes() -> void:
	_area = get_node_or_null("InteractArea") as Area2D
	if _area == null:
		_area = Area2D.new()
		_area.name = "InteractArea"
		add_child(_area)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = _interaction_collision_radius_local()
		shape.shape = circle
		_area.add_child(shape)
	var shape_node := _area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is CircleShape2D:
		(shape_node.shape as CircleShape2D).radius = _interaction_collision_radius_local()
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_rebuild_player_candidates()

	_prompt = get_node_or_null("InteractPrompt") as Label
	if _prompt == null:
		_prompt = Label.new()
		_prompt.name = "InteractPrompt"
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_prompt)
	_prompt.position = INTERACT_PROMPT_POS
	_prompt.size = INTERACT_PROMPT_SIZE
	_prompt.add_theme_font_size_override("font_size", INTERACT_PROMPT_FONT_SIZE)
	var text := prompt_text.strip_edges()
	if text == "" or text == "按 E 互动" or text == "按E交互":
		text = INTERACT_PROMPT_TEXT
	_prompt.text = text
	_prompt.visible = false


func _interaction_collision_radius_local() -> float:
	var scale_factor := maxf(0.001, absf(global_scale.x))
	return maxf(1.0, interact_radius / scale_factor)


func _build_ui_layers() -> void:
	_dialog_layer = CanvasLayer.new()
	_dialog_layer.layer = 180
	add_child(_dialog_layer)
	_ensure_ui_viewport_listener()


func _ensure_ui_viewport_listener() -> void:
	if _ui_viewport_listener_ready:
		return
	_ui_viewport_listener_ready = true
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_runtime_ui_viewport_resized):
		vp.size_changed.connect(_on_runtime_ui_viewport_resized)


func _on_runtime_ui_viewport_resized() -> void:
	if _shop_layer != null and is_instance_valid(_shop_layer) and _shop_layer.visible and _shop_scale_panel != null and is_instance_valid(_shop_scale_panel):
		_apply_shop_content_scale_to_viewport()
	if _fallback_scale_panel != null and is_instance_valid(_fallback_scale_panel):
		_apply_fallback_dialog_content_scale_to_viewport()


func _runtime_ui_uniform_scale() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	var vsize: Vector2 = vp.get_visible_rect().size
	if vsize.x < 2.0 or vsize.y < 2.0:
		return 1.0
	var ref := ui_design_reference_size
	if ref.x < 1.0 or ref.y < 1.0:
		ref = DEFAULT_UI_DESIGN_VIEWPORT
	var sx := vsize.x / ref.x
	var sy := vsize.y / ref.y
	return clampf(minf(sx, sy), ui_scale_min, ui_scale_max)


func _apply_shop_content_scale_to_viewport() -> void:
	if Engine.is_editor_hint() or _shop_scale_panel == null or not is_instance_valid(_shop_scale_panel):
		return
	_pending_runtime_ui_scale = _runtime_ui_uniform_scale()
	_shop_scale_apply_attempts = 0
	call_deferred("_apply_shop_content_scale_finalize")


func _apply_shop_content_scale_finalize() -> void:
	if Engine.is_editor_hint() or _shop_scale_panel == null or not is_instance_valid(_shop_scale_panel):
		return
	var sz := _shop_scale_panel.size
	if sz.x < 1.0 or sz.y < 1.0:
		_shop_scale_apply_attempts += 1
		if _shop_scale_apply_attempts < 10:
			call_deferred("_apply_shop_content_scale_finalize")
		return
	_shop_scale_panel.pivot_offset = Vector2(sz.x * 0.5, sz.y * 0.5)
	_shop_scale_panel.scale = Vector2(_pending_runtime_ui_scale, _pending_runtime_ui_scale)


func _apply_fallback_dialog_content_scale_to_viewport() -> void:
	if Engine.is_editor_hint() or _fallback_scale_panel == null or not is_instance_valid(_fallback_scale_panel):
		return
	_pending_runtime_ui_scale = _runtime_ui_uniform_scale()
	_fallback_scale_apply_attempts = 0
	call_deferred("_apply_fallback_dialog_content_scale_finalize")


func _apply_fallback_dialog_content_scale_finalize() -> void:
	if Engine.is_editor_hint() or _fallback_scale_panel == null or not is_instance_valid(_fallback_scale_panel):
		return
	var sz := _fallback_scale_panel.size
	if sz.x < 1.0 or sz.y < 1.0:
		_fallback_scale_apply_attempts += 1
		if _fallback_scale_apply_attempts < 10:
			call_deferred("_apply_fallback_dialog_content_scale_finalize")
		return
	_fallback_scale_panel.pivot_offset = Vector2(sz.x * 0.5, sz.y * 0.5)
	_fallback_scale_panel.scale = Vector2(_pending_runtime_ui_scale, _pending_runtime_ui_scale)


func _build_audio_nodes() -> void:
	_proximity_voice_player = get_node_or_null("ProximityVoicePlayer") as AudioStreamPlayer2D
	if _proximity_voice_player == null:
		_proximity_voice_player = AudioStreamPlayer2D.new()
		_proximity_voice_player.name = "ProximityVoicePlayer"
		_proximity_voice_player.max_distance = maxf(96.0, interact_radius * 4.0)
		add_child(_proximity_voice_player)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# 商店 / 简易台词框打开时也要能 Esc 关闭；须先于 _panel_open 判断
	if event.is_action_pressed("ui_cancel"):
		if _shop_await_close:
			_close_shop_ui()
			get_viewport().set_input_as_handled()
			return
		if _fallback_simple_await:
			_close_fallback_simple_dialog()
			get_viewport().set_input_as_handled()
			return
	if not _player_in_range or _panel_open:
		return
	var pressed := _is_interact_event(event)
	if not pressed:
		return
	_panel_open = true
	_start_interaction_flow()
	get_viewport().set_input_as_handled()


func _on_shop_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close_shop_ui()


func _close_shop_ui() -> void:
	_shop_await_close = false
	if _shop_layer != null and is_instance_valid(_shop_layer):
		_shop_layer.visible = false


func _close_fallback_simple_dialog() -> void:
	_fallback_simple_await = false


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if use_distance_fallback:
		_update_player_in_range_by_distance()
	if _player_in_range != _last_player_in_range:
		_on_player_range_state_changed(_player_in_range)
		_last_player_in_range = _player_in_range
	if _prompt:
		_prompt.visible = _player_in_range and not _panel_open


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not enable_ai_logic:
		return
	if _anim_sprite == null:
		_cache_anim_sprite()
	if _panel_open:
		_apply_idle_anim()
		return
	match ai_mode:
		"wander":
			_process_wander_irregular(delta)
		"walk":
			_process_wander_irregular(delta)
		"horizontal_move":
			_process_axis_patrol(delta, Vector2.RIGHT)
		"vertical_move":
			_process_axis_patrol(delta, Vector2.DOWN)
		"run":
			_process_random_run(delta)
		"path":
			_process_path_waypoints(delta)
		"action":
			_process_random_action()
		_:
			_apply_idle_anim()


func _runtime_bootstrap_waypoint_path() -> void:
	if Engine.is_editor_hint():
		return
	if ai_mode != "path" or not enable_ai_logic:
		return
	_rebuild_waypoint_polyline()


func _path_dir_to_vec(d: String) -> Vector2:
	match String(d):
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


func _build_waypoint_vertices_from_meta(origin: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(origin)
	var raw: Variant = get_meta("ai_path_points", [])
	if not raw is Array:
		return out
	var p := origin
	for item in raw as Array:
		if not item is Dictionary:
			continue
		var d := String((item as Dictionary).get("dir", "right"))
		var dist := float((item as Dictionary).get("dist", 0))
		p += _path_dir_to_vec(d) * maxf(1.0, dist)
		out.append(p)
	return out


func _expand_waypoints_pingpong(vs: PackedVector2Array) -> PackedVector2Array:
	if vs.size() < 2:
		return vs
	var out := PackedVector2Array()
	for i in range(vs.size()):
		out.append(vs[i])
	for i in range(vs.size() - 2, -1, -1):
		out.append(vs[i])
	return out


func _rebuild_waypoint_polyline() -> void:
	_wp_ready = false
	_wp_vanish_done = false
	_wp_stopped_at_end = false
	_wp_vertices.clear()
	_wp_seg_lens.clear()
	_wp_total_len = 0.0
	_wp_dist = 0.0
	visible = true
	modulate.a = 1.0
	var fwd := _build_waypoint_vertices_from_meta(global_position)
	if fwd.size() < 2:
		return
	var vs: PackedVector2Array
	if ai_path_pingpong:
		vs = _expand_waypoints_pingpong(fwd)
	else:
		vs = fwd
	for i in range(vs.size() - 1):
		var sl := vs[i].distance_to(vs[i + 1])
		_wp_seg_lens.append(sl)
		_wp_total_len += sl
	if _wp_total_len <= 0.001:
		return
	for i in range(vs.size()):
		_wp_vertices.append(vs[i])
	global_position = _wp_vertices[0]
	_wp_ready = true


func _sample_wp_polyline(dist_along: float) -> Dictionary:
	var out_pos := global_position
	var out_dir := Vector2.RIGHT
	if _wp_vertices.size() < 2 or _wp_seg_lens.is_empty():
		return {"pos": out_pos, "dir": out_dir}
	var dd := clampf(dist_along, 0.0, _wp_total_len)
	var acc := 0.0
	var seg_i := 0
	while seg_i < _wp_seg_lens.size():
		var sl := float(_wp_seg_lens[seg_i])
		if acc + sl >= dd - 0.0001:
			break
		acc += sl
		seg_i += 1
	if seg_i >= _wp_seg_lens.size():
		seg_i = maxi(0, _wp_seg_lens.size() - 1)
	var sl := float(_wp_seg_lens[seg_i])
	var t := 0.0 if sl <= 0.001 else (dd - acc) / sl
	t = clampf(t, 0.0, 1.0)
	var a: Vector2 = _wp_vertices[seg_i]
	var b: Vector2 = _wp_vertices[seg_i + 1]
	out_pos = a.lerp(b, t)
	out_dir = b - a
	return {"pos": out_pos, "dir": out_dir}


func _apply_wp_anim_at_current_dist(use_run: bool) -> void:
	var samp := _sample_wp_polyline(_wp_dist)
	global_position = samp.pos
	var d: Vector2 = samp.dir
	if d.length() > 0.01:
		_apply_move_anim(d.normalized(), use_run)
	else:
		_apply_idle_anim()


func _process_path_waypoints(delta: float) -> void:
	if not _wp_ready or _wp_vanish_done:
		if _wp_stopped_at_end:
			_apply_idle_anim()
		return
	if _wp_total_len <= 0.001:
		_apply_idle_anim()
		return
	var spd := maxf(1.0, ai_speed)
	var use_run := ai_wander_move == "run"
	if ai_path_pingpong:
		_wp_dist = fmod(_wp_dist + spd * delta, _wp_total_len)
		_apply_wp_anim_at_current_dist(use_run)
		return
	var next_d := _wp_dist + spd * delta
	if next_d >= _wp_total_len - 0.05:
		_wp_dist = _wp_total_len
		_apply_wp_anim_at_current_dist(use_run)
		if ai_path_vanish:
			visible = false
			_wp_vanish_done = true
		else:
			_wp_stopped_at_end = true
		return
	_wp_dist = next_d
	_apply_wp_anim_at_current_dist(use_run)


func _process_wander_irregular(delta: float) -> void:
	var use_run := ai_wander_move == "run"
	if _origin_pos == Vector2.ZERO:
		_origin_pos = global_position
	if _ai_rest_timer > 0.0:
		_ai_rest_timer = maxf(0.0, _ai_rest_timer - delta)
		_apply_idle_anim()
		return
	if not _has_move_target:
		_pick_new_walk_target()
	_apply_move_step(delta, use_run)
	if _has_move_target and global_position.distance_to(_move_target) <= maxf(2.0, ai_step_distance * 0.2):
		_has_move_target = false
		_ai_rest_timer = maxf(0.2, ai_rest_seconds)
		_apply_idle_anim()


func _start_interaction_flow() -> void:
	if enable_dialogue_system:
		await _show_dialogue()
	if enable_shop_system:
		await _show_shop_dialog()
	_panel_open = false


func _show_dialogue() -> void:
	_stop_proximity_voice()
	_ensure_dialogue_ui_template()
	if _dialogue_ui_template != null and _dialogue_ui_template.has_method("start_dialogue"):
		var lines: Array[Dictionary] = []
		var source_lines := dialogue_lines
		if source_lines.is_empty():
			var fallback := dialogue_line.strip_edges()
			if fallback == "" or fallback == "功能还未实现":
				fallback = "。。。你还没有填写该角色台词"
			source_lines = PackedStringArray([fallback])
		var voice_paths := _voice_paths_for_dialogue(source_lines.size())
		for i in range(source_lines.size()):
			var t := source_lines[i]
			var line := {
				"speaker": npc_display_name,
				"text": String(t),
				"is_player": false
			}
			if enable_dialogue_voice and i < voice_paths.size():
				line["voice_path"] = String(voice_paths[i])
			if npc_portrait != null:
				line["portrait"] = npc_portrait
			elif npc_portrait_path != "":
				line["portrait_path"] = npc_portrait_path
			lines.append(line)
		_dialogue_ui_template.start_dialogue(lines)
		if _dialogue_ui_template.has_signal("dialogue_sequence_finished"):
			await _dialogue_ui_template.dialogue_sequence_finished
		return

	var text := dialogue_line.strip_edges()
	if text == "" or text == "功能还未实现":
		text = "。。。你还没有填写该角色台词"
	if enable_dialogue_voice:
		var fallback_voice_paths := _voice_paths_for_dialogue(1)
		if not fallback_voice_paths.is_empty():
			var fallback_stream := _load_voice_stream(String(fallback_voice_paths[0]))
			if fallback_stream != null and _proximity_voice_player != null:
				_proximity_voice_player.stream = fallback_stream
				_proximity_voice_player.play()
	var fb_host := Control.new()
	fb_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	fb_host.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_layer.add_child(fb_host)
	var fb_dim := ColorRect.new()
	fb_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	fb_dim.color = Color(0, 0, 0, 0.45)
	fb_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	fb_dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_close_fallback_simple_dialog()
	)
	fb_host.add_child(fb_dim)
	var fb_center := CenterContainer.new()
	fb_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	fb_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fb_host.add_child(fb_center)
	var fb_panel := PanelContainer.new()
	fb_panel.custom_minimum_size = FALLBACK_DIALOG_DESIGN_SIZE
	fb_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_fallback_scale_panel = fb_panel
	fb_center.add_child(fb_panel)
	var fb_outer := VBoxContainer.new()
	fb_outer.add_theme_constant_override("separation", 8)
	fb_panel.add_child(fb_outer)
	var fb_title := Label.new()
	fb_title.text = npc_display_name
	fb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fb_outer.add_child(fb_title)
	var fb_body := Label.new()
	fb_body.text = text
	fb_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fb_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fb_outer.add_child(fb_body)
	var fb_ok := Button.new()
	fb_ok.text = "继续"
	fb_ok.pressed.connect(_close_fallback_simple_dialog)
	fb_outer.add_child(fb_ok)
	_fallback_simple_await = true
	fb_host.tree_exiting.connect(func() -> void:
		_fallback_scale_panel = null
		_fallback_simple_await = false
	)
	call_deferred("_apply_fallback_dialog_content_scale_to_viewport")
	while _fallback_simple_await:
		await get_tree().process_frame
	fb_host.queue_free()


func _scan_voice_files() -> void:
	_voice_paths_by_locale = {
		"chinese": [],
		"japanese": [],
		"english": [],
		"any": []
	}
	var base_dir := _npc_asset_base_dir()
	if base_dir == "":
		return
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		var lower_name := file_name.to_lower()
		if not _is_voice_file_name(lower_name):
			continue
		var file_path := base_dir.path_join(file_name)
		(_voice_paths_by_locale["any"] as Array).append(file_path)
		if lower_name.begins_with("chinese"):
			(_voice_paths_by_locale["chinese"] as Array).append(file_path)
		elif lower_name.begins_with("japanese"):
			(_voice_paths_by_locale["japanese"] as Array).append(file_path)
		elif lower_name.begins_with("english") or lower_name.begins_with("engligh"):
			(_voice_paths_by_locale["english"] as Array).append(file_path)
	dir.list_dir_end()
	for key in _voice_paths_by_locale.keys():
		var paths: Array = _voice_paths_by_locale[key]
		paths.sort()
		_voice_paths_by_locale[key] = paths


func _npc_asset_base_dir() -> String:
	var json_path := String(get_meta("npc_json_path", "")).strip_edges()
	if json_path != "":
		return json_path.get_base_dir()
	var packed := String(scene_file_path).strip_edges()
	if packed != "":
		return packed.get_base_dir()
	return ""


func _is_voice_file_name(file_name_lower: String) -> bool:
	for ext in VOICE_FILE_EXTENSIONS:
		if file_name_lower.ends_with(String(ext)):
			return true
	return false


func _preferred_voice_paths() -> Array:
	var prefer := String(preferred_voice_locale).to_lower().strip_edges()
	var order := [prefer, "chinese", "japanese", "english", "any"]
	var seen := {}
	for key in order:
		var norm_key := String(key)
		if norm_key == "" or seen.get(norm_key, false):
			continue
		seen[norm_key] = true
		var paths: Variant = _voice_paths_by_locale.get(norm_key, [])
		if paths is Array and not (paths as Array).is_empty():
			return paths as Array
	return []


func _voice_paths_for_dialogue(line_count: int) -> Array:
	var out: Array = []
	if line_count <= 0:
		return out
	var paths := _preferred_voice_paths()
	if paths.is_empty():
		return out
	for i in range(line_count):
		out.append(paths[i % paths.size()])
	return out


func _on_player_range_state_changed(in_range: bool) -> void:
	if in_range:
		_try_play_proximity_voice()
		return
	_range_voice_played = false


func _try_play_proximity_voice() -> void:
	if not enable_proximity_voice or _panel_open or _range_voice_played:
		return
	var paths := _preferred_voice_paths()
	if paths.is_empty():
		return
	var path := String(paths[_proximity_voice_cycle_index % paths.size()])
	_proximity_voice_cycle_index += 1
	var stream := _load_voice_stream(path)
	if stream == null or _proximity_voice_player == null:
		return
	_proximity_voice_player.stream = stream
	_proximity_voice_player.play()
	_range_voice_played = true


func _stop_proximity_voice() -> void:
	if _proximity_voice_player != null and _proximity_voice_player.playing:
		_proximity_voice_player.stop()


func _load_voice_stream(path: String) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res := load(path)
	if res is AudioStream:
		return res as AudioStream
	return null


func _on_body_entered(body: Node) -> void:
	if _is_player_like_body(body):
		_player_in_range = true


func _on_body_exited(body: Node) -> void:
	if _is_player_like_body(body):
		_player_in_range = false


func _resolve_texture_from_meta() -> Texture2D:
	var data: Dictionary = get_meta("npc_data", {})
	if data.is_empty():
		return null
	var assets: Dictionary = data.get("assets", {})
	var sprite_rel := String(assets.get("spritePath", ""))
	var json_path := String(get_meta("npc_json_path", ""))
	if sprite_rel == "" or json_path == "":
		return null
	var base_dir := json_path.get_base_dir()
	var target_path := base_dir.path_join(sprite_rel.trim_prefix("./"))
	if not ResourceLoader.exists(target_path):
		return null
	var tex := load(target_path)
	if tex is Texture2D:
		return tex
	return null


func _set_prop_if_exists(target: Object, prop: String, value: Variant) -> void:
	if target == null:
		return
	for p in target.get_property_list():
		if String(p.get("name", "")) == prop:
			target.set(prop, value)
			return


func _load_ocad_generator_script() -> GDScript:
	for p in [
		"res://ocad/ocad_spritesheet_generator.gd",
		"res://addons/npc_library_tool/core/ocad_spritesheet_generator.gd",
	]:
		if ResourceLoader.exists(p):
			var r := load(p)
			if r is GDScript:
				return r as GDScript
	return null


func _deferred_visual_boot_late() -> void:
	if Engine.is_editor_hint():
		return
	_stabilize_visual_state()


func _schedule_runtime_sprite_refresh() -> void:
	# 部分项目在「从插件拖入 / 首帧运行」时 Canvas 未正确提交精灵绘制，表现为必须切一次可见性才刷新。
	# 在运行后数帧内强制重绑 SpriteFrames + 可见性脉冲（仅运行时，编辑器不跑）。
	if Engine.is_editor_hint():
		return
	var tr := get_tree()
	if tr == null:
		return
	for delay in [0.03, 0.08, 0.2]:
		var timer := tr.create_timer(delay)
		timer.timeout.connect(_on_runtime_sprite_refresh_tick, CONNECT_ONE_SHOT)


func _on_runtime_sprite_refresh_tick() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	_refresh_animated_sprite_hard()
	_stabilize_visual_state()


func _refresh_animated_sprite_hard() -> void:
	if _anim_sprite == null:
		_cache_anim_sprite()
	var asp := _anim_sprite
	if asp == null:
		return
	var sf := asp.sprite_frames
	if sf == null or sf.get_animation_names().is_empty():
		return
	if not _did_hard_sprite_resource_refresh:
		_did_hard_sprite_resource_refresh = true
		var prev := asp.animation
		asp.sprite_frames = sf.duplicate(true)
		if String(prev) != "" and asp.sprite_frames.has_animation(prev):
			asp.animation = prev
		else:
			_apply_idle_anim()
	asp.visible = false
	asp.visible = true
	asp.play()
	asp.queue_redraw()


func _apply_ocad_sprite_frames_from_texture(ocad: Node2D, tex: Texture2D) -> void:
	if ocad == null or tex == null:
		return
	var asp := ocad.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if asp == null:
		return
	# 子场景里已打包 SpriteFrames 时勿覆盖，避免重复生成或布局不一致。
	if asp.sprite_frames != null and not asp.sprite_frames.get_animation_names().is_empty():
		return
	var gen_script := _load_ocad_generator_script()
	if gen_script == null:
		return
	var gen := gen_script.new()
	if gen == null or not gen.has_method("build_sprite_frames"):
		return
	var sf: Variant = gen.call("build_sprite_frames", tex)
	if not (sf is SpriteFrames):
		return
	var frames := sf as SpriteFrames
	asp.sprite_frames = frames
	if frames.has_animation("idledown"):
		asp.animation = &"idledown"
	elif frames.get_animation_names().size() > 0:
		asp.animation = frames.get_animation_names()[0]
	asp.flip_h = false
	asp.visible = true
	asp.play()


func _is_interact_event(event: InputEvent) -> bool:
	if event == null:
		return false

	for action_name in interact_action_candidates:
		if action_name == "":
			continue
		# 空项目未配置 InputMap 时，is_action_pressed 会对缺失 action 刷屏报错，需先检查。
		if not InputMap.has_action(action_name):
			continue
		if event.is_action_pressed(action_name):
			return true

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		for code in interact_key_fallbacks:
			if key_event.keycode == int(code):
				return true

	if not _warned_no_input and debug_compat_log:
		_warned_no_input = true
		push_warning("[NpcLibrary] 未命中互动输入：请检查输入映射或按键兜底设置。")
	return false


func _is_player_like_body(body: Node) -> bool:
	if body == null:
		return false
	if body == self:
		return false

	var has_strong_match := false
	for g in player_group_candidates:
		if g != "" and body.is_in_group(g):
			has_strong_match = true
			break

	var body_name := String(body.name).to_lower()
	for kw in player_name_keywords:
		var lowered := String(kw).to_lower()
		if lowered != "" and body_name.find(lowered) >= 0:
			has_strong_match = true
			break

	# 强匹配优先；若未命中强匹配，再回退 CharacterBody2D 兜底。
	if has_strong_match:
		return true
	return body is CharacterBody2D


func _rebuild_player_candidates() -> void:
	_player_candidates.clear()
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	if root == null:
		return
	_collect_player_candidates(root)
	if debug_compat_log:
		print("[NpcLibrary] Player candidates: %d" % _player_candidates.size())


func _collect_player_candidates(node: Node) -> void:
	if node is Node2D and _is_player_like_body(node):
		_player_candidates.append(node as Node2D)
	for c in node.get_children():
		if c is Node:
			_collect_player_candidates(c)


func _update_player_in_range_by_distance() -> void:
	if _player_candidates.is_empty():
		_rebuild_player_candidates()
	if _player_candidates.is_empty():
		if not _warned_no_player and debug_compat_log:
			_warned_no_player = true
			push_warning("[NpcLibrary] 未识别到主角候选，建议配置分组或名称关键词。")
		return

	var nearest := INF
	for n in _player_candidates:
		if not is_instance_valid(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d < nearest:
			nearest = d
	var threshold := maxf(1.0, interact_radius * maxf(1.0, distance_fallback_scale))
	_player_in_range = nearest <= threshold


func _ensure_dialogue_ui_template() -> void:
	if _dialogue_ui_template != null and is_instance_valid(_dialogue_ui_template):
		return
	var existing := get_tree().get_first_node_in_group("dialogue_ui")
	if existing is CanvasLayer:
		_dialogue_ui_template = existing as CanvasLayer
		return
	var scene: Resource = null
	if dialogue_ui_scene != null:
		scene = dialogue_ui_scene
	elif ResourceLoader.exists("res://addons/npc_library_tool/runtime/dialogue/dialogue_ui_default.tscn"):
		scene = load("res://addons/npc_library_tool/runtime/dialogue/dialogue_ui_default.tscn")
	if scene is PackedScene:
		var inst := (scene as PackedScene).instantiate()
		if inst is CanvasLayer:
			_dialogue_ui_template = inst as CanvasLayer
			get_tree().root.add_child(_dialogue_ui_template)


func _cache_anim_sprite() -> void:
	_anim_sprite = get_node_or_null("OcadNpc/AnimatedSprite2D") as AnimatedSprite2D
	if _anim_sprite == null:
		_anim_sprite = find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if _anim_sprite == null:
		_anim_sprite = find_child("AnimatedSprite2D2", true, false) as AnimatedSprite2D


func _process_random_walk(delta: float) -> void:
	if _origin_pos == Vector2.ZERO:
		_origin_pos = global_position
	if _ai_rest_timer > 0.0:
		_ai_rest_timer = maxf(0.0, _ai_rest_timer - delta)
		_apply_idle_anim()
		return
	if not _has_move_target:
		_pick_new_walk_target()
	_apply_move_step(delta, false)
	if _has_move_target and global_position.distance_to(_move_target) <= maxf(2.0, ai_step_distance * 0.2):
		_has_move_target = false
		_ai_rest_timer = maxf(0.2, ai_rest_seconds)
		_apply_idle_anim()


func _process_axis_patrol(delta: float, axis: Vector2) -> void:
	if _origin_pos == Vector2.ZERO:
		_origin_pos = global_position
	if _ai_rest_timer > 0.0:
		_ai_rest_timer = maxf(0.0, _ai_rest_timer - delta)
		_apply_idle_anim()
		return
	_axis_move_elapsed += delta
	if _axis_move_elapsed >= 2.0:
		_axis_move_elapsed = fmod(_axis_move_elapsed, 2.0)
		if randf() <= 0.1:
			_ai_rest_timer = maxf(0.2, ai_rest_seconds)
			_apply_idle_anim()
			return
	var patrol_dist := maxf(8.0, ai_range)
	var target := _origin_pos + axis * patrol_dist * float(_run_dir_sign)
	var to_target := target - global_position
	if to_target.length() <= maxf(2.0, patrol_dist * 0.05):
		_run_dir_sign *= -1
		target = _origin_pos + axis * patrol_dist * float(_run_dir_sign)
		to_target = target - global_position
	var dir := to_target.normalized()
	global_position += dir * maxf(1.0, ai_speed) * delta
	_apply_move_anim(dir, ai_wander_move == "run")


func _pick_new_walk_target() -> void:
	var dirs: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	dirs.shuffle()
	var max_range := maxf(8.0, ai_range)
	var step_dist := clampf(ai_step_distance, 4.0, max_range)
	for d in dirs:
		var dist := randf_range(step_dist * 0.6, step_dist)
		var candidate: Vector2 = global_position + d * dist
		if candidate.distance_to(_origin_pos) <= max_range:
			_move_target = candidate
			_has_move_target = true
			return
	# 如果四向都越界，直接回原点方向短走一步。
	var back_dir := (_origin_pos - global_position).normalized()
	if absf(back_dir.x) > absf(back_dir.y):
		back_dir = Vector2(signf(back_dir.x), 0)
	else:
		back_dir = Vector2(0, signf(back_dir.y))
	_move_target = global_position + back_dir * minf(step_dist, global_position.distance_to(_origin_pos))
	_has_move_target = true


func _apply_move_step(delta: float, running: bool) -> void:
	var speed := maxf(1.0, ai_speed)
	var to_target := _move_target - global_position
	if to_target.length() <= 0.001:
		return
	var dir := to_target.normalized()
	global_position += dir * speed * delta
	_apply_move_anim(dir, running)


func _process_random_run(delta: float) -> void:
	if _origin_pos == Vector2.ZERO:
		_origin_pos = global_position
	var run_dist := maxf(8.0, ai_step_distance)
	var axis := Vector2.RIGHT if ai_run_axis == "horizontal" else Vector2.DOWN
	var target := _origin_pos + axis * run_dist * float(_run_dir_sign)
	var to_target := target - global_position
	if to_target.length() <= maxf(2.0, run_dist * 0.08):
		_run_dir_sign *= -1
		target = _origin_pos + axis * run_dist * float(_run_dir_sign)
		to_target = target - global_position
	var dir := to_target.normalized()
	global_position += dir * maxf(1.0, ai_speed) * delta
	_apply_move_anim(dir, true)


func _process_random_action() -> void:
	if _anim_sprite == null:
		return
	var anim_name := ai_action.strip_edges()
	if anim_name == "":
		anim_name = "idledown"
	if _anim_sprite.sprite_frames != null and _anim_sprite.sprite_frames.has_animation(anim_name):
		if _anim_sprite.animation != StringName(anim_name):
			_anim_sprite.animation = StringName(anim_name)
		if not _anim_sprite.is_playing():
			_anim_sprite.play()
	else:
		_apply_idle_anim()


func _apply_idle_anim() -> void:
	if _anim_sprite == null or _anim_sprite.sprite_frames == null:
		return
	for n in ["idledown", "idle_down", "idleL", "idle_left", "idleup", "idle_up"]:
		if _anim_sprite.sprite_frames.has_animation(n):
			_anim_sprite.animation = StringName(n)
			_anim_sprite.play()
			return


func _apply_move_anim(dir: Vector2, running: bool) -> void:
	if _anim_sprite == null or _anim_sprite.sprite_frames == null:
		return
	var horiz := absf(dir.x) > absf(dir.y)
	if ai_arcade_mode:
		if absf(dir.x) > 0.001:
			_arcade_face_sign = 1 if dir.x > 0.0 else -1
		if not horiz:
			horiz = true
			dir = Vector2(float(_arcade_face_sign), 0.0)
	var candidates := PackedStringArray()
	if horiz:
		candidates = PackedStringArray(["runL", "run_left"] if running else ["walkL", "walk_left"])
		if absf(dir.x) > 0.001:
			_anim_sprite.flip_h = dir.x > 0.0
		else:
			_anim_sprite.flip_h = _arcade_face_sign > 0
	else:
		if dir.y >= 0.0:
			candidates = PackedStringArray(["rundown", "run_down"] if running else ["walkdown", "walk_down"])
		else:
			candidates = PackedStringArray(["runup", "run_up"] if running else ["walkup", "walk_up"])
		_anim_sprite.flip_h = false
	for n in candidates:
		if _anim_sprite.sprite_frames.has_animation(n):
			_anim_sprite.animation = StringName(n)
			_anim_sprite.play()
			return
	# 再兜底一层：跑步动作不存在时回落到走路动作。
	if running:
		var fallback_walk := PackedStringArray(["walkL", "walk_left", "walkdown", "walk_down", "walkup", "walk_up"])
		for n in fallback_walk:
			if _anim_sprite.sprite_frames.has_animation(n):
				_anim_sprite.animation = StringName(n)
				_anim_sprite.play()
				return
	_apply_idle_anim()


func _show_shop_dialog() -> void:
	_ensure_shop_dialog_ui()
	_shop_mode = "buy"
	_shop_page = 0
	_refresh_shop_dialog_items()
	if _shop_status_label != null:
		_shop_status_label.text = ""
	if _shop_scale_panel == null:
		return
	if _shop_title_label != null:
		_shop_title_label.text = shop_title
	_shop_await_close = true
	_shop_layer.visible = true
	call_deferred("_apply_shop_content_scale_to_viewport")
	while _shop_await_close:
		await get_tree().process_frame


func _ensure_shop_dialog_ui() -> void:
	if is_instance_valid(_shop_scale_panel):
		return
	_ensure_ui_viewport_listener()
	_shop_layer = CanvasLayer.new()
	_shop_layer.layer = 220
	_shop_layer.visible = false
	add_child(_shop_layer)
	var modal := Control.new()
	modal.name = "ShopModal"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_modal_root = modal
	_shop_layer.add_child(modal)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_shop_dim_gui_input)
	modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "ShopScaledPanel"
	panel.custom_minimum_size = SHOP_DESIGN_POPUP_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_scale_panel = panel
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_title_label = Label.new()
	_shop_title_label.text = shop_title
	_shop_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_close_shop_ui)
	title_row.add_child(_shop_title_label)
	title_row.add_child(close_btn)
	outer.add_child(title_row)
	var root := VBoxContainer.new()
	_shop_content_root = root
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(720, 400)
	root.add_theme_constant_override("separation", 8)
	outer.add_child(root)
	var tab_row := HBoxContainer.new()
	tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_theme_constant_override("separation", 8)
	root.add_child(tab_row)
	_shop_tab_buy_btn = Button.new()
	_shop_tab_buy_btn.text = "购买"
	_shop_tab_buy_btn.pressed.connect(func() -> void:
		_shop_mode = "buy"
		_shop_page = 0
		_refresh_shop_dialog_items()
	)
	tab_row.add_child(_shop_tab_buy_btn)
	_shop_tab_sell_btn = Button.new()
	_shop_tab_sell_btn.text = "出售"
	_shop_tab_sell_btn.pressed.connect(func() -> void:
		_shop_mode = "sell"
		_shop_page = 0
		_refresh_shop_dialog_items()
	)
	tab_row.add_child(_shop_tab_sell_btn)
	var page_row := HBoxContainer.new()
	page_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_row.add_theme_constant_override("separation", 8)
	root.add_child(page_row)
	_shop_prev_btn = Button.new()
	_shop_prev_btn.text = "上一页"
	_shop_prev_btn.pressed.connect(func() -> void:
		_shop_page = maxi(0, _shop_page - 1)
		_refresh_shop_dialog_items()
	)
	page_row.add_child(_shop_prev_btn)
	_shop_page_label = Label.new()
	_shop_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_row.add_child(_shop_page_label)
	_shop_next_btn = Button.new()
	_shop_next_btn.text = "下一页"
	_shop_next_btn.pressed.connect(func() -> void:
		_shop_page += 1
		_refresh_shop_dialog_items()
	)
	page_row.add_child(_shop_next_btn)
	_shop_scroll = ScrollContainer.new()
	_shop_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(_shop_scroll)
	_shop_items_box = VBoxContainer.new()
	_shop_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_items_box.add_theme_constant_override("separation", 6)
	_shop_scroll.add_child(_shop_items_box)
	_shop_status_label = Label.new()
	_shop_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_shop_status_label)
	call_deferred("_apply_shop_content_scale_to_viewport")


func _runtime_shop_items() -> Array[Dictionary]:
	if not shop_items.is_empty():
		return shop_items
	var data: Dictionary = get_meta("npc_data", {})
	var gameplay: Dictionary = data.get("gameplay", {})
	var merchant_cfg: Dictionary = gameplay.get("merchant", {})
	var items_var: Variant = merchant_cfg.get("shopItems", [])
	var out: Array[Dictionary] = []
	if items_var is Array:
		for it in items_var as Array:
			if it is Dictionary:
				out.append((it as Dictionary).duplicate(true))
	shop_items = out
	return shop_items


func _refresh_shop_dialog_items() -> void:
	if _shop_items_box == null:
		return
	for c in _shop_items_box.get_children():
		c.queue_free()
	var items := _runtime_shop_items()
	if _shop_tab_buy_btn != null:
		_shop_tab_buy_btn.disabled = _shop_mode == "buy"
	if _shop_tab_sell_btn != null:
		_shop_tab_sell_btn.disabled = _shop_mode == "sell"
	if _shop_mode == "sell":
		var todo := Label.new()
		todo.text = "出售模式待接入你的背包系统接口（字段和方法名可定制）。"
		todo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_shop_items_box.add_child(todo)
		_shop_page = 0
		if _shop_page_label != null:
			_shop_page_label.text = "1 / 1"
		if _shop_prev_btn != null:
			_shop_prev_btn.disabled = true
		if _shop_next_btn != null:
			_shop_next_btn.disabled = true
		return
	if items.is_empty():
		var empty := Label.new()
		empty.text = "该商人未配置商品。请在插件商人功能页添加商品。"
		_shop_items_box.add_child(empty)
		if _shop_page_label != null:
			_shop_page_label.text = "1 / 1"
		if _shop_prev_btn != null:
			_shop_prev_btn.disabled = true
		if _shop_next_btn != null:
			_shop_next_btn.disabled = true
		return
	var total_pages := maxi(1, int(ceil(float(items.size()) / float(maxi(1, _shop_items_per_page)))))
	_shop_page = clampi(_shop_page, 0, total_pages - 1)
	if _shop_page_label != null:
		_shop_page_label.text = "%d / %d" % [_shop_page + 1, total_pages]
	if _shop_prev_btn != null:
		_shop_prev_btn.disabled = _shop_page <= 0
	if _shop_next_btn != null:
		_shop_next_btn.disabled = _shop_page >= total_pages - 1
	var from_idx := _shop_page * _shop_items_per_page
	var to_idx := mini(items.size(), from_idx + _shop_items_per_page)
	for i in range(from_idx, to_idx):
		var item: Dictionary = items[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_shop_items_box.add_child(row)
		var slot_bg := TextureRect.new()
		slot_bg.custom_minimum_size = Vector2(48, 48)
		slot_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_bg.texture = _load_shop_ui_texture(SHOP_ASSET_SLOT)
		row.add_child(slot_bg)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = _resolve_shop_item_texture(item)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		slot_bg.add_child(icon)
		var info := Label.new()
		var stock := int(item.get("stock", -1))
		var stock_text := "无限" if stock < 0 else str(stock)
		info.text = "%s  价格:%d  数量:%d  库存:%s" % [
			String(item.get("itemName", "未命名商品")),
			int(item.get("price", 0)),
			maxi(1, int(item.get("count", 1))),
			stock_text
		]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var buy_btn := Button.new()
		buy_btn.text = "购买"
		buy_btn.disabled = stock == 0
		var idx := i
		buy_btn.pressed.connect(func() -> void:
			_on_shop_buy_pressed(idx)
		)
		row.add_child(buy_btn)


func _on_shop_buy_pressed(item_index: int) -> void:
	if item_index < 0 or item_index >= shop_items.size():
		return
	var item: Dictionary = shop_items[item_index]
	var stock := int(item.get("stock", -1))
	if stock == 0:
		if _shop_status_label != null:
			_shop_status_label.text = "库存不足"
		return
	if stock > 0:
		item["stock"] = stock - 1
	shop_items[item_index] = item
	if _shop_status_label != null:
		_shop_status_label.text = "已购买 %s（示例商店逻辑，可按项目接入背包/金币）" % String(item.get("itemName", "商品"))
	_refresh_shop_dialog_items()


func _resolve_shop_item_texture(item: Dictionary) -> Texture2D:
	var p := String(item.get("spritePath", "")).strip_edges()
	if p == "":
		return null
	if p.begins_with("./"):
		var json_path := String(get_meta("npc_json_path", ""))
		if json_path != "":
			p = json_path.get_base_dir().path_join(p.trim_prefix("./"))
	if not p.begins_with("res://"):
		return null
	if not ResourceLoader.exists(p):
		return null
	var tex := load(p)
	if tex is Texture2D:
		return tex
	return null


func _load_shop_ui_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex := load(path)
	if tex is Texture2D:
		return tex
	return null
