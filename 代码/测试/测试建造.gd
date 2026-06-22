extends Node2D

@onready var 建造: TileMapLayer = $建造
@onready var 建造预览: TileMapLayer = $建造预览

var 瓦片ID : int
var 地图坐标 : Vector2i

var 选择模式 :bool = false
var 预览位置 : Vector2i :
	set(v):
		if 预览位置 == v :
			return
		
		建造预览.erase_cell(预览位置) #擦除之前的瓦片
		预览位置 = v #更新新的瓦片该在的鼠标位置
		建造预览.set_cell(v , 瓦片ID  , 地图坐标) #让建造预览跟随预览位置
		
		var atlas_tile : TileSetAtlasSource
		atlas_tile = 建造预览.tile_set.get_source(瓦片ID)
		var tile_size
		if atlas_tile:
			tile_size = atlas_tile.get_tile_size_in_atlas(地图坐标)
		可放置 = true
		for j in range(tile_size.y):
			for i in range(tile_size.x):
				var tile = 预览位置 + Vector2i(i , j)
				if tile in 防建筑重叠.used_tiles:
					可放置 = false
		

var 可放置 : bool = true :
	set(v):
		可放置 = v
		
		if 可放置 == false:
			建造预览.modulate = Color.RED
		else:建造预览.modulate = Color("ffffff6f")


func 获取吸附位置(gloabal_pos : Vector2):#创建捕捉位置的方法
	var local_pos = 建造.to_local(gloabal_pos)#将全局坐标转换为地面的本地坐标
	var tile_pos = 建造.local_to_map(local_pos)#将本地坐标转换地图坐标
	
	return tile_pos

func _physics_process(delta: float) -> void:
	if 选择模式 :
		预览位置 = 获取吸附位置(get_global_mouse_position())



func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and 选择模式 and 可放置:
			place_tile(预览位置)
			选择模式 = false 

		elif event.button_index == MOUSE_BUTTON_RIGHT :
			建造预览.erase_cell(预览位置)
			选择模式 = false 


	if event is InputEventKey:
		if event.keycode == KEY_1 and event.pressed  :
			选择模式 = true
			瓦片ID = 0
			地图坐标 = Vector2i(81 , 67)
		if event.keycode == KEY_2 and event.pressed  :
			选择模式 = true
			瓦片ID = 0
			地图坐标 = Vector2i(112 , 69)
		if event.keycode == KEY_3 and event.pressed  :
			选择模式 = true
			瓦片ID = 0
			地图坐标 = Vector2i(135 , 67)





func place_tile(tile_pos : Vector2i):
	建造.set_cell(tile_pos , 瓦片ID , 地图坐标)
	建造预览.erase_cell(tile_pos)
	防建筑重叠.get_tiles(建造 , 地图坐标 , 预览位置)#放置建筑获取所有占用瓦片


func _on_建造ui_建造1() -> void:
	选择模式 = true
	瓦片ID = 0
	地图坐标 = Vector2i(81 , 67)


func _on_建造ui_建造2() -> void:
	选择模式 = true
	瓦片ID = 0
	地图坐标 = Vector2i(112 , 69)


func _on_建造ui_建造3() -> void:
	选择模式 = true
	瓦片ID = 0
	地图坐标 = Vector2i(135 , 67)
