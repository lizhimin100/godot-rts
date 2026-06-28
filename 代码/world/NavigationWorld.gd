class_name NavigationWorld
extends Node

## 导航世界 — TileMap → Grid 桥梁
## 维护二进制网格（0=可通行，1=障碍），供 FlowFieldManager 使用
## 自动从场景中查找地面层/树林层，并监听建筑变化
##
## 用法：
##   在场景中添加此节点作为子节点（通常放在 /root/世界/ 下）
##   NavigationWorld 自动查找 TileMapLayer
##   建筑放置后调用 rebuild()

signal grid_changed

# TileMap 引用
var ground_layer: TileMapLayer
var tree_layer: TileMapLayer

# 二进制网格（二维数组）
var grid: Array = []
var grid_width: int = 0
var grid_height: int = 0
var grid_offset: Vector2i = Vector2i.ZERO

# 缓存标记
var _dirty: bool = true
var _ground_path: NodePath = NodePath()
var _tree_path: NodePath = NodePath()


func _ready() -> void:
	# 延迟一帧确保场景加载完成
	await get_tree().process_frame
	_auto_find_layers()


## 自动查找地面层和树林层
func _auto_find_layers() -> void:
	if _ground_path != NodePath():
		ground_layer = get_node_or_null(_ground_path) as TileMapLayer
	if _tree_path != NodePath():
		tree_layer = get_node_or_null(_tree_path) as TileMapLayer

	if not ground_layer:
		# 尝试自动查找：寻找场景中第一个有 used_cells 的 TileMapLayer
		var tile_maps: Array[TileMapLayer] = _find_tilemap_layers()
		for layer in tile_maps:
			if not layer.get_used_cells().is_empty():
				ground_layer = layer
				break

	_dirty = true
	rebuild()


## 递归查找所有 TileMapLayer
func _find_tilemap_layers() -> Array[TileMapLayer]:
	var result: Array[TileMapLayer] = []
	_scan_tilemap_layers(get_tree().root, result)
	return result


func _scan_tilemap_layers(node: Node, result: Array[TileMapLayer]) -> void:
	if node is TileMapLayer:
		result.append(node)
	for child in node.get_children():
		_scan_tilemap_layers(child, result)


## 重建网格（全量）
func rebuild() -> void:
	_dirty = false
	grid = []
	grid_width = 0
	grid_height = 0

	if not ground_layer:
		return

	var cells: Array[Vector2i] = ground_layer.get_used_cells()
	if cells.is_empty():
		return

	# 计算包围盒
	var min_cell: Vector2i = cells[0]
	var max_cell: Vector2i = cells[0]
	for c in cells:
		min_cell.x = min(min_cell.x, c.x)
		min_cell.y = min(min_cell.y, c.y)
		max_cell.x = max(max_cell.x, c.x)
		max_cell.y = max(max_cell.y, c.y)

	grid_offset = min_cell
	grid_width = max_cell.x - min_cell.x + 1
	grid_height = max_cell.y - min_cell.y + 1

	# 初始化全 0 网格
	for y in range(grid_height):
		grid.append([])
		for x in range(grid_width):
			grid[y].append(0)

	# 标记树木为障碍
	if tree_layer:
		for c in tree_layer.get_used_cells():
			var gx: int = c.x - grid_offset.x
			var gy: int = c.y - grid_offset.y
			if gx >= 0 and gx < grid_width and gy >= 0 and gy < grid_height:
				grid[gy][gx] = 1

	# 标记建筑为障碍
	for b in get_tree().get_nodes_in_group("建筑"):
		if not is_instance_valid(b):
			continue
		var c: Vector2i = ground_layer.local_to_map(b.global_position)
		var gx: int = c.x - grid_offset.x
		var gy: int = c.y - grid_offset.y
		if gx >= 0 and gx < grid_width and gy >= 0 and gy < grid_height:
			grid[gy][gx] = 1

	grid_changed.emit()


## 世界坐标 → 网格坐标
func world_to_grid(world_pos: Vector2) -> Vector2i:
	if not ground_layer:
		return Vector2i(-1, -1)
	var cell: Vector2i = ground_layer.local_to_map(world_pos)
	return Vector2i(cell.x - grid_offset.x, cell.y - grid_offset.y)


## 判断世界坐标是否在障碍上
func is_obstacle(world_pos: Vector2) -> bool:
	if _dirty or grid.is_empty():
		rebuild()
	var g: Vector2i = world_to_grid(world_pos)
	if g.x < 0 or g.y < 0 or g.x >= grid_width or g.y >= grid_height:
		return false
	return grid[g.y][g.x] == 1


## 设置地面层路径（用于场景未完全加载时配置）
func set_ground_path(path: NodePath) -> void:
	_ground_path = path


## 设置树木层路径
func set_tree_path(path: NodePath) -> void:
	_tree_path = path
