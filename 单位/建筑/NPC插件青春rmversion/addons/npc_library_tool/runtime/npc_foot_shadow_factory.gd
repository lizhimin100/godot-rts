extends Object
## 在 OcadNpc 下创建脚底阴影（纯 Node2D + Sprite2D，不嵌套 PackedScene，避免打包时子场景 owner 不完整导致阴影丢失）。
## 绘制顺序：阴影 z=0、AnimatedSprite2D 设为 z=1，避免 z=-1 时整块地面 TileMap(z=0) 盖住阴影。
## 贴图必须在工厂内同步写入 Sprite2D，禁止在编辑器里对带脚本节点调用实例方法（会触发 placeholder 报错）。

const _TexGen := preload("res://addons/npc_library_tool/runtime/npc_foot_shadow_texture.gd")


## 同步生成脚底椭圆贴图（编辑器拖入 / pack 前可安全调用，不依赖 @tool 节点脚本）。
static func apply_foot_shadow_to_sprite(sp: Sprite2D) -> void:
	if sp == null:
		return
	var gen := _TexGen.new()
	sp.texture = gen.build_texture()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.z_index = 0
	sp.position = Vector2(0, 12)
	sp.scale = Vector2(0.8, 0.8)
	sp.centered = true
	sp.visible = true


static func ensure_under_ocad(ocad_root: Node2D) -> void:
	if ocad_root == null:
		return
	var existing := ocad_root.get_node_or_null("Shadow") as Node2D
	if existing != null:
		# 旧版 z_index=-1 时会被地面 TileMap(z=0) 整块盖住，这里只改层级不删节点。
		existing.z_index = 0
		for c in existing.get_children():
			if c is Sprite2D:
				(c as Sprite2D).z_index = 0
		var sp_old := existing.get_node_or_null("Sprite2D") as Sprite2D
		if sp_old != null and sp_old.texture == null:
			apply_foot_shadow_to_sprite(sp_old)
		bump_anim_above_shadow(ocad_root)
		return
	var root_nd := Node2D.new()
	root_nd.name = "Shadow"
	root_nd.z_index = 0
	root_nd.position = Vector2(0, 6)
	var sp := Sprite2D.new()
	sp.name = "Sprite2D"
	root_nd.add_child(sp)
	apply_foot_shadow_to_sprite(sp)
	ocad_root.add_child(root_nd)
	ocad_root.move_child(root_nd, 0)
	var asp := ocad_root.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if asp != null:
		asp.z_index = 1


static func bump_anim_above_shadow(ocad_root: Node2D) -> void:
	if ocad_root == null:
		return
	var asp := ocad_root.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if asp != null:
		asp.z_index = 1
