class_name UnitMover extends Node


@export var play_areas : Array[游戏瓦片层组件]

static var initialized = false#静态变量标记初始化状态


func _ready() -> void:
	if not initialized:
		initialized = true
		var units := get_tree().get_nodes_in_group("units")
		for unit :Unit in units:
			setup_unit(unit)

func setup_unit(unit : Unit) -> void:
	unit.拖放组件.开始拖动.connect(_on_unit_drap_started.bind(unit))
	unit.拖放组件.取消拖动.connect(_on_unit_drap_canceled.bind(unit))
	unit.拖放组件.放下目标.connect(_on_unit_dropped.bind(unit))

func _set_highlighters(enabled : bool) -> void:
	for play_area : 游戏瓦片层组件 in play_areas:
		play_area.tile_highlighter.enabled = enabled
	

func _get_play_area_fro_position(global : Vector2) -> int :#接受游戏区域的全局位置，返回整数
	var dropped_area_index := -1 #数组“游戏区域”的索引
	for i in play_areas.size():#知晓数组大小
		var tile := play_areas[i].get_tile_from_global(global)#存储游戏区域的瓦片坐标
		if play_areas[i].is_tile_in_bounds(tile):#检查坐标有没有空闲、被占据
			dropped_area_index = i#设置索引为该区域的索引
	return dropped_area_index#返回索引

func _reset_unit_to_starting_position(starting_position : Vector2 , unit : Unit) -> void:
	var i := _get_play_area_fro_position(starting_position)#存储起始位置所在区域的索引
	var tile := play_areas[i].get_tile_from_global(starting_position)#存储游戏区域的瓦片坐标
	unit.reset_after_dragging(starting_position) #调用单位的重置位置方法
	play_areas[i].unit_grid.add_unit(tile , unit)#将单位重新添加到区域的单位网格中



func _move_unit(unit :Unit , play_area :游戏瓦片层组件 , tile :Vector2i) -> void:
	play_area.unit_grid.add_unit(tile , unit)
	unit.global_position = play_area.get_global_from_tile(tile) - 营地场景.一半单元格
	unit.reparent(play_area.unit_grid)#改变单位的父节点为区域的单位网格

func _on_unit_drap_started(unit : Unit) -> void:
	_set_highlighters(true)

	var i := _get_play_area_fro_position(unit.global_position)
	if i > -1:
		var tile := play_areas[i].get_tile_from_global(unit.global_position)
		play_areas[i].unit_grid.remove_unit(tile)


func _on_unit_drap_canceled(starting_position : Vector2 , unit : Unit) -> void:
	_set_highlighters(false)
	_reset_unit_to_starting_position(starting_position ,unit)

func _on_unit_dropped(starting_position : Vector2 , unit : Unit) -> void:
	_set_highlighters(false)
	
	var old_area_index := _get_play_area_fro_position(starting_position)#起始位置的索引
	var drop_area_index := _get_play_area_fro_position(unit.get_global_mouse_position())#放下位置索引
	
	if drop_area_index == -1 :
		_reset_unit_to_starting_position(starting_position , unit)
		return


	var old_area := play_areas[old_area_index]
	var old_tile := old_area.get_tile_from_global(starting_position)
	var new_area := play_areas[drop_area_index]
	var new_tile := new_area.get_hovered_tile()
	
	#放下位置有没有单位，有就删除并放到原位置
	if new_area.unit_grid.is_tile_occupied(new_tile):
		var old_unit : Unit = new_area.unit_grid.units[new_tile]
		new_area.unit_grid.remove_unit(new_tile)
		_move_unit(old_unit , old_area ,old_tile)
	
	#放下单位
	_move_unit(unit , new_area , new_tile)
	
	
	
