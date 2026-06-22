extends Node2D

@onready var 第一层地面图层: TileMapLayer = $场景/第一层地面图层
@onready var 跟随相机: Camera2D = $环境和角色/角色/操作角色/跟随相机

func _ready() -> void:
	var 地图大小 : = 第一层地面图层.get_used_rect()
	var 图块像素大小 : = 第一层地面图层.tile_set.tile_size
	
	跟随相机.limit_top = 地图大小.position.y * 图块像素大小.y
	print(地图大小.position.y * 图块像素大小.y)
	跟随相机.limit_right = 地图大小.end.x * 图块像素大小.x
	print(地图大小.end.x * 图块像素大小.x)
	跟随相机.limit_bottom = 地图大小.end.y * 图块像素大小.y
	print(地图大小.end.y * 图块像素大小.y)
	跟随相机.limit_left = 地图大小.position.x * 图块像素大小.x
	print(地图大小.position.x * 图块像素大小.x)
