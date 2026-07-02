extends Node2D

@onready var 第一层地面图层: TileMapLayer = $场景/第一层地面图层
@onready var 跟随相机: 世界岛相机控制 = $跟随相机
@onready var 营地按钮: Button = $布局渲染/按钮面板/营地按钮
@onready var 布局UI: CanvasLayer = $布局渲染
@onready var 小地图 = $布局渲染/显示小地图/小地图
# 战争迷雾已由 迷雾系统 Autoload 管理


func _ready() -> void:
	var 地图大小 := 第一层地面图层.get_used_rect()
	var 图块像素大小 := 第一层地面图层.tile_set.tile_size

	跟随相机.limit_top = 地图大小.position.y * 图块像素大小.y
	跟随相机.limit_right = 地图大小.end.x * 图块像素大小.x
	跟随相机.limit_bottom = 地图大小.end.y * 图块像素大小.y
	跟随相机.limit_left = 地图大小.position.x * 图块像素大小.x

	# 让小地图追踪主相机
	if 小地图 and 小地图.玩家节点 == null:
		小地图.玩家节点 = 跟随相机

	# 连接营地按钮
	营地按钮.pressed.connect(_on_营地按钮_pressed)

	# 从营地返回时恢复位置
	if has_node("/root/全局"):
		var 全局变量 := get_node("/root/全局")
		if 全局变量.get("存储_主角位置"):
			跟随相机.position = 全局变量.存储_相机位置
			跟随相机.zoom = Vector2(全局变量.存储_相机缩放, 全局变量.存储_相机缩放)
			var 主角 := find_child("主角", true, false)
			if 主角:
				主角.global_position = 全局变量.存储_主角位置


func _on_营地按钮_pressed() -> void:
	# 保存主角位置到全局
	var 主角 := find_child("主角", true, false)
	if 主角:
		if has_node("/root/全局"):
			var 全局变量 := get_node("/root/全局")
			全局变量.存储_主角位置 = 主角.global_position
			全局变量.存储_相机位置 = 跟随相机.position
			全局变量.存储_相机缩放 = 跟随相机.zoom.x
	# 切换到营地场景
	get_tree().change_scene_to_file("res://场景/营地场景.tscn")
