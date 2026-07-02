extends TileMapLayer

var astar : = AStarGrid2D.new()
 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	astar.region = get_used_rect()
	astar.cell_size = tile_set.tile_size  # 设置单元格尺寸
	

	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER #寻路不再考虑对角线
	astar.update()
	
	#print(astar.region)  # DEBUG
