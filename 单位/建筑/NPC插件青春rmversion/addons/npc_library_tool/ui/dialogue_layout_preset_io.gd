extends RefCounted
## 对话 UI 布局预设：只序列化节点位置/锚点/边距等，不包含贴图资源（不是截图、也不是整文件副本）。

const FORMAT_VERSION := 2

## 须为编译期常量：不能用 PackedStringArray(...) 构造函数赋给 const
const NODE_PATHS: Array[String] = [
	"Root",
	"Root/Dim",
	"Root/DialogPanel",
	"Root/DialogPanel/PortraitFrame",
	"Root/DialogPanel/PortraitFrame/Portrait",
	"Root/DialogPanel/NamePlate",
	"Root/DialogPanel/NameLabel",
	"Root/DialogPanel/DialogBg",
	"Root/DialogPanel/DialogBg/BodyVBox",
	"Root/DialogPanel/DialogBg/BodyVBox/SpacerTop",
	"Root/DialogPanel/DialogBg/BodyVBox/BodyMargin",
	"Root/DialogPanel/DialogBg/BodyVBox/BodyMargin/BodyText",
	"Root/DialogPanel/DialogBg/BodyVBox/SpacerBottom",
	"Root/ClickAdvance",
]


static func collect_from_instance(dialogue_root: Node) -> Dictionary:
	var out := {
		"format_version": FORMAT_VERSION,
		"nodes": {},
	}
	out["nodes"]["__root__"] = _collect_dialogue_root(dialogue_root)
	for rel in NODE_PATHS:
		var n := dialogue_root.get_node_or_null(NodePath(rel))
		if n == null:
			continue
		out["nodes"][rel] = _collect_node(n)
	return out


static func apply_to_instance(dialogue_root: Node, data: Dictionary) -> void:
	var nodes: Dictionary = data.get("nodes", {})
	if nodes.has("__root__"):
		_apply_dialogue_root(dialogue_root, nodes["__root__"])
	for rel in NODE_PATHS:
		if not nodes.has(rel):
			continue
		var n := dialogue_root.get_node_or_null(NodePath(rel))
		if n == null:
			continue
		_apply_node(n, nodes[rel])


static func _collect_dialogue_root(n: Node) -> Dictionary:
	var d: Dictionary = {"kind": "dialogue_root"}
	if n is CanvasLayer:
		d["layer"] = (n as CanvasLayer).layer
	for prop in ["design_reference_size", "dialogue_scale_min", "dialogue_scale_max", "use_scene_body_margins"]:
		if n.get(prop) != null:
			var v: Variant = n.get(prop)
			d[prop] = _variant_to_jsonable(v)
	return d


static func _apply_dialogue_root(n: Node, d: Dictionary) -> void:
	if d.get("layer", null) != null and n is CanvasLayer:
		(n as CanvasLayer).layer = int(d["layer"])
	for prop in ["design_reference_size", "dialogue_scale_min", "dialogue_scale_max", "use_scene_body_margins"]:
		if not d.has(prop):
			continue
		var v: Variant = _jsonable_to_variant(d[prop], prop)
		if v != null:
			n.set(prop, v)


static func _collect_node(n: Node) -> Dictionary:
	if n is TextureRect:
		var d := _collect_control(n as Control)
		d["kind"] = "TextureRect"
		var tr := n as TextureRect
		d["expand_mode"] = tr.expand_mode
		d["stretch_mode"] = tr.stretch_mode
		return d
	if n is ColorRect:
		var d := _collect_control(n as Control)
		d["kind"] = "ColorRect"
		var cr := n as ColorRect
		d["color"] = _color_to_arr(cr.color)
		d["mouse_filter"] = cr.mouse_filter
		return d
	if n is Label:
		var d := _collect_control(n as Control)
		d["kind"] = "Label"
		var lb := n as Label
		d["horizontal_alignment"] = lb.horizontal_alignment
		d["vertical_alignment"] = lb.vertical_alignment
		if lb.label_settings != null:
			d["label_font_size"] = lb.label_settings.font_size
			d["label_font_color"] = _color_to_arr(lb.label_settings.font_color)
		return d
	if n is RichTextLabel:
		var d := _collect_control(n as Control)
		d["kind"] = "RichTextLabel"
		var rtl := n as RichTextLabel
		d["bbcode_enabled"] = rtl.bbcode_enabled
		d["fit_content"] = rtl.fit_content
		d["autowrap_mode"] = rtl.autowrap_mode
		d["scroll_active"] = rtl.scroll_active
		d["horizontal_alignment"] = rtl.horizontal_alignment
		d["vertical_alignment"] = rtl.vertical_alignment
		if rtl.has_theme_font_size_override(&"normal_font_size"):
			d["normal_font_size"] = rtl.get_theme_font_size(&"normal_font_size")
		if rtl.has_theme_constant_override(&"line_separation"):
			d["line_separation"] = rtl.get_theme_constant(&"line_separation", &"RichTextLabel")
		return d
	if n is MarginContainer:
		var d := _collect_control(n as Control)
		d["kind"] = "MarginContainer"
		var mc := n as MarginContainer
		for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			if mc.has_theme_constant_override(side):
				d[side] = mc.get_theme_constant(side, "MarginContainer")
		return d
	if n is BoxContainer:
		var d := _collect_control(n as Control)
		d["kind"] = "BoxContainer"
		var bc := n as BoxContainer
		if bc.has_theme_constant_override("separation"):
			d["separation"] = bc.get_theme_constant("separation", "BoxContainer")
		return d
	if n is Control:
		var d := _collect_control(n as Control)
		d["kind"] = "Control"
		return d
	return {}


static func _apply_node(n: Node, d: Dictionary) -> void:
	var kind := String(d.get("kind", ""))
	match kind:
		"TextureRect":
			if n is TextureRect:
				_apply_control(n as Control, d)
				var tr := n as TextureRect
				if d.has("expand_mode"):
					tr.expand_mode = int(d["expand_mode"])
				if d.has("stretch_mode"):
					tr.stretch_mode = int(d["stretch_mode"])
		"ColorRect":
			if n is ColorRect:
				_apply_control(n as Control, d)
				var cr := n as ColorRect
				if d.has("color"):
					cr.color = _arr_to_color(d["color"])
				if d.has("mouse_filter"):
					cr.mouse_filter = int(d["mouse_filter"])
		"Label":
			if n is Label:
				_apply_control(n as Control, d)
				var lb := n as Label
				if d.has("horizontal_alignment"):
					lb.horizontal_alignment = int(d["horizontal_alignment"])
				if d.has("vertical_alignment"):
					lb.vertical_alignment = int(d["vertical_alignment"])
				if d.has("label_font_size"):
					if lb.label_settings == null:
						lb.label_settings = LabelSettings.new()
					lb.label_settings.font_size = int(d["label_font_size"])
				if d.has("label_font_color") and lb.label_settings != null:
					lb.label_settings.font_color = _arr_to_color(d["label_font_color"])
		"RichTextLabel":
			if n is RichTextLabel:
				_apply_control(n as Control, d)
				var rtl := n as RichTextLabel
				if d.has("bbcode_enabled"):
					rtl.bbcode_enabled = bool(d["bbcode_enabled"])
				if d.has("fit_content"):
					rtl.fit_content = bool(d["fit_content"])
				if d.has("autowrap_mode"):
					rtl.autowrap_mode = int(d["autowrap_mode"])
				if d.has("scroll_active"):
					rtl.scroll_active = bool(d["scroll_active"])
				if d.has("horizontal_alignment"):
					rtl.horizontal_alignment = int(d["horizontal_alignment"])
				if d.has("vertical_alignment"):
					rtl.vertical_alignment = int(d["vertical_alignment"])
				if d.has("normal_font_size"):
					rtl.add_theme_font_size_override("normal_font_size", int(d["normal_font_size"]))
				if d.has("line_separation"):
					rtl.add_theme_constant_override("line_separation", int(d["line_separation"]))
		"MarginContainer":
			if n is MarginContainer:
				_apply_control(n as Control, d)
				var mc := n as MarginContainer
				for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
					if d.has(side):
						mc.add_theme_constant_override(side, int(d[side]))
		"BoxContainer":
			if n is BoxContainer:
				_apply_control(n as Control, d)
				var bc := n as BoxContainer
				if d.has("separation"):
					bc.add_theme_constant_override("separation", int(d["separation"]))
		"Control":
			if n is Control:
				_apply_control(n as Control, d)
		_:
			if n is Control:
				_apply_control(n as Control, d)


static func _collect_control(c: Control) -> Dictionary:
	var d := {
		"layout_mode": c.layout_mode,
		"anchors_preset": c.anchors_preset,
		"anchor_left": c.anchor_left,
		"anchor_top": c.anchor_top,
		"anchor_right": c.anchor_right,
		"anchor_bottom": c.anchor_bottom,
		"offset_left": c.offset_left,
		"offset_top": c.offset_top,
		"offset_right": c.offset_right,
		"offset_bottom": c.offset_bottom,
		"grow_horizontal": c.grow_horizontal,
		"grow_vertical": c.grow_vertical,
		"size_flags_horizontal": c.size_flags_horizontal,
		"size_flags_vertical": c.size_flags_vertical,
		"custom_minimum_size": _vec2_to_arr(c.custom_minimum_size),
		"z_index": c.z_index,
		"visible": c.visible,
		"rotation": c.rotation,
		"scale": _vec2_to_arr(c.scale),
		"pivot_offset": _vec2_to_arr(c.pivot_offset),
	}
	return d


static func _apply_control(c: Control, d: Dictionary) -> void:
	if d.has("layout_mode"):
		c.layout_mode = int(d["layout_mode"])
	if d.has("anchors_preset"):
		c.anchors_preset = int(d["anchors_preset"])
	if d.has("anchor_left"):
		c.anchor_left = float(d["anchor_left"])
	if d.has("anchor_top"):
		c.anchor_top = float(d["anchor_top"])
	if d.has("anchor_right"):
		c.anchor_right = float(d["anchor_right"])
	if d.has("anchor_bottom"):
		c.anchor_bottom = float(d["anchor_bottom"])
	if d.has("offset_left"):
		c.offset_left = float(d["offset_left"])
	if d.has("offset_top"):
		c.offset_top = float(d["offset_top"])
	if d.has("offset_right"):
		c.offset_right = float(d["offset_right"])
	if d.has("offset_bottom"):
		c.offset_bottom = float(d["offset_bottom"])
	if d.has("grow_horizontal"):
		c.grow_horizontal = int(d["grow_horizontal"])
	if d.has("grow_vertical"):
		c.grow_vertical = int(d["grow_vertical"])
	if d.has("size_flags_horizontal"):
		c.size_flags_horizontal = int(d["size_flags_horizontal"])
	if d.has("size_flags_vertical"):
		c.size_flags_vertical = int(d["size_flags_vertical"])
	if d.has("custom_minimum_size"):
		c.custom_minimum_size = _arr_to_vec2(d["custom_minimum_size"])
	if d.has("z_index"):
		c.z_index = int(d["z_index"])
	if d.has("visible"):
		c.visible = bool(d["visible"])
	if d.has("rotation"):
		c.rotation = float(d["rotation"])
	if d.has("scale"):
		c.scale = _arr_to_vec2(d["scale"])
	if d.has("pivot_offset"):
		c.pivot_offset = _arr_to_vec2(d["pivot_offset"])


static func _variant_to_jsonable(v: Variant) -> Variant:
	if v is Vector2:
		return [v.x, v.y]
	if v is Color:
		return _color_to_arr(v)
	return v


static func _jsonable_to_variant(j: Variant, prop: String) -> Variant:
	if prop == "design_reference_size" and j is Array:
		return _arr_to_vec2(j)
	return j


static func _vec2_to_arr(v: Vector2) -> Array:
	return [v.x, v.y]


static func _arr_to_vec2(a: Variant) -> Vector2:
	if a is Array and (a as Array).size() >= 2:
		var ar: Array = a
		return Vector2(float(ar[0]), float(ar[1]))
	return Vector2.ZERO


static func _color_to_arr(c: Color) -> Array:
	return [c.r, c.g, c.b, c.a]


static func _arr_to_color(a: Variant) -> Color:
	if a is Array and (a as Array).size() >= 4:
		var ar: Array = a
		return Color(float(ar[0]), float(ar[1]), float(ar[2]), float(ar[3]))
	return Color.WHITE


static func save_layout_to_scene_file(data: Dictionary, scene_path: String) -> Error:
	var ps: PackedScene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if ps == null:
		return ERR_CANT_OPEN
	var inst := ps.instantiate()
	if inst == null:
		return ERR_CANT_CREATE
	apply_to_instance(inst, data)
	var packed := PackedScene.new()
	var err := packed.pack(inst)
	inst.queue_free()
	if err != OK:
		return err
	return ResourceSaver.save(packed, scene_path)
