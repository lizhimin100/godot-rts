extends PanelContainer

@export var 单位场景 : PackedScene
@export var 图标 : CompressedTexture2D

@onready var 纹理矩形: TextureRect = $纹理矩形

func _ready() -> void:
	add_to_group("单位")
	纹理矩形.texture = 图标
	custom_minimum_size = Vector2(64, 64)
func 拖放位置 (position) :
	var 全局位置 = get_global_rect()
	return 全局位置.has_point(position)

	
func 拖放预览 ():
	var 预览 = TextureRect.new()
	预览.texture = 图标
	预览.size = Vector2(64, 64)
	预览.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return 预览
