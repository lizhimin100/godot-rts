class_name 游戏瓦片层组件 extends TileMapLayer

@export var unit_grid : 单位网格组件
@export var tile_highlighter : 瓦片高亮组件

var bounds : Rect2i

func _ready() -> void:
	bounds = Rect2i(Vector2i.ZERO , unit_grid.size)

func get_tile_from_global(global : Vector2) -> Vector2i :#根据全局坐标返回瓦片地图坐标位置
	return local_to_map(to_local(global))

func get_global_from_tile(tile : Vector2i) -> Vector2 :#根据瓦片坐标返回瓦片的全局位置
	return to_global(map_to_local(tile))

func get_hovered_tile() -> Vector2i:#返回瓦片地图层内的鼠标坐标
	return local_to_map(get_local_mouse_position())

func is_tile_in_bounds(tile : Vector2i) -> bool:#接受一个瓦片坐标，检查还在不在规定的矩形内
	return bounds.has_point(tile)
