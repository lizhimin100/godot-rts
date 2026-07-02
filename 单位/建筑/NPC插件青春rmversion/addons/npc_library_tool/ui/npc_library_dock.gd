@tool
extends VBoxContainer

## 已弃用：插件主界面使用 `npc_library_dock_v2.gd`。本文件保留作历史参考，新功能请勿在此修改。
const RepoScript := preload("res://addons/npc_library_tool/core/npc_repository.gd")

var _editor_interface: EditorInterface
var _repo: RefCounted

var _root_path_edit: LineEdit
var _search_edit: LineEdit
var _list: ItemList
var _browse_mode_check: CheckBox
var _cards_scroll: ScrollContainer
var _cards_grid: GridContainer
var _status_label: Label
var _error_label: RichTextLabel
var _id_value: Label
var _name_edit: LineEdit
var _style_option: OptionButton
var _category_option: OptionButton
var _role_edit: LineEdit
var _sprite_edit: LineEdit
var _preview_rect: TextureRect
var _preview_anim_option: OptionButton
var _preview_fps_spin: SpinBox
var _preview_play_btn: Button
var _preview_stop_btn: Button
var _preview_hint_label: Label

var _items: Array[Dictionary] = []
var _filtered_indexes: Array[int] = []
var _selected_index: int = -1
var _preview_frames: Array[AtlasTexture] = []
var _preview_frame_idx := 0
var _preview_time_acc := 0.0
var _preview_fps := 8.0
var _preview_playing := false
var _card_previews: Array[Dictionary] = []
var _card_fps := 8.0


func setup(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface
	_repo = RepoScript.new()
	_build_ui()
	set_process(true)
	_refresh_list()


func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var top_bar := HBoxContainer.new()
	add_child(top_bar)

	_root_path_edit = LineEdit.new()
	_root_path_edit.placeholder_text = "AI资源库根目录（默认 res://AI资源库/一图全动作）"
	_root_path_edit.text = RepoScript.NPC_ROOT_DEFAULT
	_root_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_root_path_edit)

	var refresh_btn := Button.new()
	refresh_btn.text = "扫描"
	refresh_btn.pressed.connect(_refresh_list)
	top_bar.add_child(refresh_btn)

	var search_bar := HBoxContainer.new()
	add_child(search_bar)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索 id / 名称 / 风格 / 类别"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(func(_t: String) -> void:
		_apply_filter()
	)
	search_bar.add_child(_search_edit)

	_browse_mode_check = CheckBox.new()
	_browse_mode_check.text = "淘宝浏览模式"
	_browse_mode_check.button_pressed = true
	_browse_mode_check.toggled.connect(func(_on: bool) -> void:
		_update_browse_mode_visibility()
	)
	search_bar.add_child(_browse_mode_check)

	var body := HSplitContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)

	_list = ItemList.new()
	_list.select_mode = ItemList.SELECT_SINGLE
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_item_selected)
	body.add_child(_list)

	_cards_scroll = ScrollContainer.new()
	_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_cards_scroll)

	_cards_grid = GridContainer.new()
	_cards_grid.columns = 3
	_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_scroll.add_child(_cards_grid)

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail)

	_id_value = Label.new()
	_id_value.text = "id: -"
	detail.add_child(_id_value)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "displayName"
	detail.add_child(_name_edit)

	_style_option = OptionButton.new()
	for v in ["gufeng", "medieval", "modern"]:
		_style_option.add_item(v)
	detail.add_child(_style_option)

	_category_option = OptionButton.new()
	for v in ["shop", "function", "quest", "combat"]:
		_category_option.add_item(v)
	detail.add_child(_category_option)

	_role_edit = LineEdit.new()
	_role_edit.placeholder_text = "gameplay.role"
	detail.add_child(_role_edit)

	_sprite_edit = LineEdit.new()
	_sprite_edit.placeholder_text = "assets.spritePath"
	detail.add_child(_sprite_edit)

	var preview_title := Label.new()
	preview_title.text = "动作预览"
	detail.add_child(preview_title)

	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(160, 160)
	_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(_preview_rect)

	var preview_bar := HBoxContainer.new()
	detail.add_child(preview_bar)

	var quick_bar := HBoxContainer.new()
	detail.add_child(quick_bar)
	for quick_name in ["idle_down", "walk_down", "run_down", "idle_left", "walk_left", "run_left", "idle_up", "walk_up", "run_up"]:
		var btn := Button.new()
		btn.text = quick_name
		btn.pressed.connect(func() -> void:
			_select_preview_animation_quick(quick_name)
		)
		quick_bar.add_child(btn)

	_preview_anim_option = OptionButton.new()
	_preview_anim_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	var preview_action_bar := HBoxContainer.new()
	detail.add_child(preview_action_bar)

	_preview_play_btn = Button.new()
	_preview_play_btn.text = "播放"
	_preview_play_btn.pressed.connect(func() -> void:
		_preview_playing = not _preview_frames.is_empty()
	)
	preview_action_bar.add_child(_preview_play_btn)

	_preview_stop_btn = Button.new()
	_preview_stop_btn.text = "停止"
	_preview_stop_btn.pressed.connect(func() -> void:
		_preview_playing = false
		_preview_frame_idx = 0
		_show_preview_frame()
	)
	preview_action_bar.add_child(_preview_stop_btn)

	_preview_hint_label = Label.new()
	_preview_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_hint_label.text = ""
	detail.add_child(_preview_hint_label)

	var action_bar := HBoxContainer.new()
	detail.add_child(action_bar)

	var save_btn := Button.new()
	save_btn.text = "保存JSON"
	save_btn.pressed.connect(_save_current)
	action_bar.add_child(save_btn)

	var apply_btn := Button.new()
	apply_btn.text = "应用到选中节点"
	apply_btn.pressed.connect(_apply_to_selected_node)
	action_bar.add_child(apply_btn)

	_error_label = RichTextLabel.new()
	_error_label.custom_minimum_size = Vector2(0, 120)
	_error_label.fit_content = true
	_error_label.scroll_active = true
	detail.add_child(_error_label)

	_status_label = Label.new()
	_status_label.text = "就绪"
	add_child(_status_label)
	_update_browse_mode_visibility()


func _refresh_list() -> void:
	var root := _root_path_edit.text.strip_edges()
	if root == "":
		root = RepoScript.NPC_ROOT_DEFAULT
	_root_path_edit.text = root

	_items = _repo.scan_npc_files(root)
	_selected_index = -1
	_apply_filter()
	_set_status("扫描完成：%d 个NPC" % _items.size())


func _apply_filter() -> void:
	_filtered_indexes.clear()
	_list.clear()
	_clear_cards()
	var q := _search_edit.text.strip_edges().to_lower()

	for i in range(_items.size()):
		var it := _items[i]
		var text := "%s | %s | %s | %s" % [
			it.get("id", ""),
			it.get("displayName", ""),
			it.get("style", ""),
			it.get("category", "")
		]
		if q == "" or text.to_lower().find(q) >= 0:
			_filtered_indexes.append(i)
			var error_count := PackedStringArray(it.get("errors", PackedStringArray())).size()
			if error_count > 0:
				text += "  [错误:%d]" % error_count
			_list.add_item(text)
			_add_card_for_item(it, i)

	if _list.item_count > 0:
		_list.select(0)
		_on_item_selected(0)
	else:
		_clear_detail()


func _on_item_selected(display_idx: int) -> void:
	if display_idx < 0 or display_idx >= _filtered_indexes.size():
		return
	_selected_index = _filtered_indexes[display_idx]
	var item := _items[_selected_index]
	_highlight_selected_card(_selected_index)
	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var gameplay: Dictionary = data.get("gameplay", {})
	var assets: Dictionary = data.get("assets", {})

	_id_value.text = "id: %s" % String(meta.get("id", ""))
	_name_edit.text = String(meta.get("displayName", ""))
	_select_option_by_text(_style_option, String(meta.get("style", "")))
	_select_option_by_text(_category_option, String(meta.get("category", "")))
	_role_edit.text = String(gameplay.get("role", ""))
	_sprite_edit.text = String(assets.get("spritePath", ""))
	_refresh_preview_from_item(item)

	var errs := PackedStringArray(item.get("errors", PackedStringArray()))
	if errs.is_empty():
		_error_label.text = "[color=green]校验通过[/color]"
	else:
		var lines := "[color=red]校验错误：[/color]\n"
		for e in errs:
			lines += "- %s\n" % e
		_error_label.text = lines


func _save_current() -> void:
	var item := _current_item()
	if item.is_empty():
		return

	var data: Dictionary = item.get("data", {})
	var meta: Dictionary = data.get("meta", {})
	var gameplay: Dictionary = data.get("gameplay", {})
	var assets: Dictionary = data.get("assets", {})

	meta["displayName"] = _name_edit.text.strip_edges()
	meta["style"] = _style_option.get_item_text(_style_option.selected)
	meta["category"] = _category_option.get_item_text(_category_option.selected)
	data["meta"] = meta

	gameplay["role"] = _role_edit.text.strip_edges()
	data["gameplay"] = gameplay

	assets["spritePath"] = _sprite_edit.text.strip_edges()
	data["assets"] = assets

	var path := String(item.get("path", ""))
	if _repo.save_npc_json(path, data):
		item["data"] = data
		item["errors"] = _repo.validate_npc_data(data, String(meta.get("id", "")))
		_items[_selected_index] = item
		_refresh_preview_from_item(item)
		_apply_filter()
		_set_status("已保存：%s" % path)
	else:
		_set_status("保存失败：%s" % path)


func _apply_to_selected_node() -> void:
	var item := _current_item()
	if item.is_empty():
		return
	if _editor_interface == null:
		_set_status("编辑器接口不可用")
		return

	var sel := _editor_interface.get_selection()
	var nodes: Array[Node] = sel.get_selected_nodes()
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

	var display_name := String(meta.get("displayName", ""))
	if display_name != "":
		node.name = display_name

	_try_set_property(node, "role", gameplay.get("role", ""))
	_try_set_property(node, "level", gameplay.get("level", 1))
	var stats: Dictionary = gameplay.get("stats", {})
	_try_set_property(node, "max_hp", stats.get("hp", null))
	_try_set_property(node, "attack", stats.get("attack", null))
	_try_set_property(node, "defense", stats.get("defense", null))
	_try_set_property(node, "move_speed", stats.get("moveSpeed", null))
	_try_set_property(node, "spritesheet", _load_sprite_texture(item))

	_set_status("已应用到节点：%s" % node.name)


func _load_sprite_texture(item: Dictionary) -> Texture2D:
	var data: Dictionary = item.get("data", {})
	var assets: Dictionary = data.get("assets", {})
	var sprite_rel := String(assets.get("spritePath", ""))
	if sprite_rel == "":
		return null
	var json_path := String(item.get("path", ""))
	var base_dir := json_path.get_base_dir()
	var target_path := base_dir.path_join(sprite_rel.trim_prefix("./"))
	var tex := load(target_path)
	if tex is Texture2D:
		return tex
	return null


func _try_set_property(node: Node, prop: String, value: Variant) -> void:
	if value == null:
		return
	for p in node.get_property_list():
		if String(p.get("name", "")) == prop:
			node.set(prop, value)
			return


func _current_item() -> Dictionary:
	if _selected_index < 0 or _selected_index >= _items.size():
		return {}
	return _items[_selected_index]


func _clear_detail() -> void:
	_id_value.text = "id: -"
	_name_edit.text = ""
	_role_edit.text = ""
	_sprite_edit.text = ""
	_error_label.text = ""
	_preview_anim_option.clear()
	_preview_rect.texture = null
	_preview_frames.clear()
	_preview_playing = false


func _update_browse_mode_visibility() -> void:
	var browse_mode := _browse_mode_check != null and _browse_mode_check.button_pressed
	if _list:
		_list.visible = not browse_mode
	if _cards_scroll:
		_cards_scroll.visible = browse_mode


func _set_status(text: String) -> void:
	_status_label.text = text


func _select_option_by_text(ob: OptionButton, value: String) -> void:
	for i in range(ob.item_count):
		if ob.get_item_text(i) == value:
			ob.select(i)
			return
	ob.select(0)


func _process(delta: float) -> void:
	if not _preview_playing or _preview_frames.is_empty():
		pass
	else:
		var fps := maxf(1.0, _preview_fps)
		_preview_time_acc += delta
		if _preview_time_acc >= 1.0 / fps:
			_preview_time_acc = 0.0
			_preview_frame_idx = (_preview_frame_idx + 1) % _preview_frames.size()
			_show_preview_frame()
	_update_card_previews(delta)


func _refresh_preview_from_item(item: Dictionary) -> void:
	_preview_playing = false
	_preview_frame_idx = 0
	_preview_time_acc = 0.0
	_preview_frames.clear()
	_preview_anim_option.clear()
	_preview_hint_label.text = ""

	var data: Dictionary = item.get("data", {})
	var spritesheet: Dictionary = data.get("spritesheet", {})
	var animations: Dictionary = spritesheet.get("animations", {})
	var keys := animations.keys()
	keys.sort()
	for k in keys:
		_preview_anim_option.add_item(String(k))

	var default_fps := float(spritesheet.get("defaultFps", 8))
	_preview_fps = maxf(1.0, default_fps)
	_preview_fps_spin.value = _preview_fps

	if _preview_anim_option.item_count > 0:
		_preview_anim_option.select(0)
		_build_preview_frames_for_selected_anim()
	else:
		_preview_rect.texture = null


func _build_preview_frames_for_selected_anim() -> void:
	_preview_frames.clear()
	_preview_frame_idx = 0
	_preview_time_acc = 0.0
	_preview_playing = false
	_preview_hint_label.text = ""

	var item := _current_item()
	if item.is_empty():
		_preview_rect.texture = null
		return

	var tex := _load_sprite_texture(item)
	if tex == null:
		_preview_rect.texture = null
		_preview_hint_label.text = "预览失败：spritePath 指向的贴图不存在或不可加载。"
		return

	var data: Dictionary = item.get("data", {})
	var spritesheet: Dictionary = data.get("spritesheet", {})
	var animations: Dictionary = spritesheet.get("animations", {})
	var anim_name := _preview_anim_option.get_item_text(_preview_anim_option.selected)
	var anim_data: Dictionary = animations.get(anim_name, {})
	if anim_data.is_empty():
		_preview_rect.texture = null
		_preview_hint_label.text = "预览失败：未找到动画 %s" % anim_name
		return

	var frame_w := int(spritesheet.get("frameWidth", 0))
	var frame_h := int(spritesheet.get("frameHeight", 0))
	var row := int(anim_data.get("row", 0))
	var from_idx := int(anim_data.get("from", 0))
	var to_idx := int(anim_data.get("to", 0))
	var spacing := int(spritesheet.get("spacing", 0))
	var margin := int(spritesheet.get("margin", 0))

	if frame_w <= 0 or frame_h <= 0:
		_preview_rect.texture = null
		_preview_hint_label.text = "预览失败：frameWidth/frameHeight 必须大于 0"
		return

	for col in range(from_idx, to_idx + 1):
		var x := margin + col * (frame_w + spacing)
		var y := margin + row * (frame_h + spacing)
		if x + frame_w > tex.get_width() or y + frame_h > tex.get_height():
			_preview_hint_label.text = "预览失败：动画 %s 的切帧越界（row/from/to 或帧尺寸不匹配贴图）" % anim_name
			_preview_frames.clear()
			_preview_rect.texture = null
			return
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2i(x, y, frame_w, frame_h)
		_preview_frames.append(atlas)

	_preview_hint_label.text = "动画 %s：%d 帧，%d FPS" % [anim_name, _preview_frames.size(), int(_preview_fps)]
	_show_preview_frame()


func _show_preview_frame() -> void:
	if _preview_frames.is_empty():
		_preview_rect.texture = null
		return
	_preview_frame_idx = clampi(_preview_frame_idx, 0, _preview_frames.size() - 1)
	_preview_rect.texture = _preview_frames[_preview_frame_idx]


func _clear_cards() -> void:
	_card_previews.clear()
	if _cards_grid == null:
		return
	for c in _cards_grid.get_children():
		c.queue_free()


func _add_card_for_item(item: Dictionary, source_index: int) -> void:
	var card_btn := Button.new()
	card_btn.custom_minimum_size = Vector2(180, 220)
	card_btn.clip_contents = true
	card_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_btn.pressed.connect(func() -> void:
		_select_item_by_source_index(source_index)
	)
	_cards_grid.add_child(card_btn)

	var card_v := VBoxContainer.new()
	card_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_btn.add_child(card_v)

	var preview_rect := TextureRect.new()
	preview_rect.custom_minimum_size = Vector2(140, 140)
	preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_v.add_child(preview_rect)

	var title := Label.new()
	title.text = "%s\n%s" % [String(item.get("displayName", "")), String(item.get("id", ""))]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_v.add_child(title)

	var tex := _load_sprite_texture(item)
	var idle_frames := _build_frames_for_named_anim(item, tex, PackedStringArray(["idle_down", "idledown", "idle_left", "idleL"]))
	var walk_frames := _build_frames_for_named_anim(item, tex, PackedStringArray(["walk_down", "walkdown", "walk_left", "walkL"]))
	var merged := idle_frames
	if merged.is_empty():
		merged = walk_frames
	elif not walk_frames.is_empty():
		for fr in walk_frames:
			merged.append(fr)

	if not merged.is_empty():
		preview_rect.texture = merged[0]

	_card_previews.append({
		"source_index": source_index,
		"button": card_btn,
		"rect": preview_rect,
		"frames": merged,
		"frame_idx": 0,
		"time_acc": 0.0
	})


func _build_frames_for_named_anim(item: Dictionary, tex: Texture2D, anim_names: PackedStringArray) -> Array[AtlasTexture]:
	var out: Array[AtlasTexture] = []
	if tex == null:
		return out
	var data: Dictionary = item.get("data", {})
	var spritesheet: Dictionary = data.get("spritesheet", {})
	var animations: Dictionary = spritesheet.get("animations", {})
	for nm in anim_names:
		if animations.has(nm):
			var anim_data: Dictionary = animations.get(nm, {})
			return _build_frames_from_anim_data(tex, spritesheet, anim_data)
	return out


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


func _select_item_by_source_index(source_index: int) -> void:
	for display_idx in range(_filtered_indexes.size()):
		if _filtered_indexes[display_idx] == source_index:
			_list.select(display_idx)
			_on_item_selected(display_idx)
			break


func _highlight_selected_card(source_index: int) -> void:
	for cp in _card_previews:
		var btn: Button = cp.get("button")
		var is_sel := int(cp.get("source_index", -1)) == source_index
		btn.modulate = Color(1, 1, 1, 1) if is_sel else Color(0.92, 0.92, 0.92, 1)


func _update_card_previews(delta: float) -> void:
	if _card_previews.is_empty():
		return
	var fps := maxf(1.0, _card_fps)
	var frame_dt := 1.0 / fps
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


func _select_preview_animation_quick(quick_name: String) -> void:
	var candidates := _quick_anim_candidates(quick_name)
	for name in candidates:
		for i in range(_preview_anim_option.item_count):
			if _preview_anim_option.get_item_text(i) == name:
				_preview_anim_option.select(i)
				_build_preview_frames_for_selected_anim()
				return
	_preview_hint_label.text = "未找到快捷动作：%s" % quick_name


func _quick_anim_candidates(quick_name: String) -> PackedStringArray:
	match quick_name:
		"idle_down":
			return PackedStringArray(["idle_down", "idledown"])
		"walk_down":
			return PackedStringArray(["walk_down", "walkdown"])
		"run_down":
			return PackedStringArray(["run_down", "rundown"])
		"idle_left":
			return PackedStringArray(["idle_left", "idleL"])
		"walk_left":
			return PackedStringArray(["walk_left", "walkL"])
		"run_left":
			return PackedStringArray(["run_left", "runL"])
		"idle_up":
			return PackedStringArray(["idle_up", "idleup"])
		"walk_up":
			return PackedStringArray(["walk_up", "walkup"])
		"run_up":
			return PackedStringArray(["run_up", "runup"])
		_:
			return PackedStringArray([quick_name])
