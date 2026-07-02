extends Node2D
## 脚底阴影：挂到 OcadNpc 下，与 ocad_npc.tscn 中 Shadow 实例用法一致。

const _ShadowTex := preload("res://addons/npc_library_tool/runtime/npc_foot_shadow_texture.gd")

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	var gen := _ShadowTex.new()
	sprite.texture = gen.build_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = -1
	sprite.position.y = 12
	sprite.scale = Vector2(0.8, 0.8)
	sprite.centered = true
