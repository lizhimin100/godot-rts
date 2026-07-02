extends Node2D
## 兼容旧场景里仍挂本脚本的 Shadow 节点：仅在运行时发现贴图缺失再补（不调用工厂，避免与工厂循环 preload）。
## 新建阴影已由 npc_foot_shadow_factory 直接写 Sprite2D，通常不再挂此脚本。

const _TexGen := preload("res://addons/npc_library_tool/runtime/npc_foot_shadow_texture.gd")


func _ready() -> void:
	refresh_foot_shadow_visual()


func refresh_foot_shadow_visual() -> void:
	var sp := get_node_or_null("Sprite2D") as Sprite2D
	if sp == null:
		return
	if sp.texture != null:
		return
	var gen := _TexGen.new()
	sp.texture = gen.build_texture()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.z_index = 0
	sp.position = Vector2(0, 12)
	sp.scale = Vector2(0.8, 0.8)
	sp.centered = true
	sp.visible = true
