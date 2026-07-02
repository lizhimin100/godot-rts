extends Node2D

var used_tiles: Array = []

func get_tiles(layer: TileMapLayer , 地图坐标 : Vector2i , tile_pos : Vector2i):
	var source_id = layer.get_cell_source_id(tile_pos)
	var 地图集资源 : TileSetAtlasSource
	var 瓦片尺寸
	
	if source_id != -1 :
		地图集资源 = layer.tile_set.get_source(source_id)#从层的tile_set获取地图集资源
	if 地图集资源:
		瓦片尺寸 = 地图集资源.get_tile_size_in_atlas(地图坐标)
		#print(瓦片尺寸)  # DEBUG
	
	for j in range(瓦片尺寸.y):#遍历所有行和列
		for i in range(瓦片尺寸.x):
			var tile = tile_pos + Vector2i(i , j)
			if tile not in used_tiles:
				used_tiles.append(tile)#获取每个瓦片位置，加入到数组中
