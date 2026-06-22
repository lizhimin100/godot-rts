class_name 单位网格组件 extends Node2D

signal unit_grid_changed

@export var size : Vector2i

var units : Dictionary
var _unit_exit_callables : Dictionary

func _ready() -> void:
	for i in range(size.x) :
		for j in range(size.y) :
			units[Vector2i(i , j) ] = null
	#add_unit(Vector2i(0 ,0) ,$"../../长凳区域/单位")
	#prints("有单位占据：", is_tile_occupied(Vector2i(0,0)))
	#printt(is_grid_full())
	#printt("获取第一个空闲瓦片：" , get_first_empty_tile())
	#printt("有哪些单位：" , get_all_units())




func add_unit(tile : Vector2i , unit : Node) -> void:#在网格中添加单位方法
	if not units.has(tile) or unit == null:
		return
	_disconnect_unit_exit_signal(unit)
	units[tile] = unit
	var exit_callable := _on_unit_tree_exited.bind(unit , tile)
	_unit_exit_callables[unit] = exit_callable
	unit.tree_exited.connect(exit_callable)
	#TODO 这里会有报错，是因为在棋子库中将场景中所有单位都添加到“长凳区域”，使用了add_unit
	#TODO 已经连接过一次信号，所以除了原本就在长凳区域的单位
	#TODO 游戏区域的单位移动到长凳区域，会再次使用add_unit使其信号重复连接
	unit_grid_changed.emit()

func remove_unit(tile : Vector2i) ->void:#移除单位网格中对应的单位值
	if not units.has(tile):
		return
	var unit := units[tile] as Node
	
	if not unit :#坐标上没有单位就返回
		return
	_disconnect_unit_exit_signal(unit)
	units[tile] = null
	unit_grid_changed.emit()

func is_tile_occupied(tile : Vector2i) -> bool:#检查单位网格格子有没有被占据
	return units[tile] != null

func is_grid_full() -> bool:#检查单位网格有没有满
	return units.keys().all(is_tile_occupied)

func get_first_empty_tile() -> Vector2i:#获取单位网格第一个空闲格子
	for tile in units :
		if not is_tile_occupied(tile) :
			return tile
	
	return Vector2i(-1 , -1)

func get_all_units() -> Array[Unit]:#获取单位网格中所有单位
	var unit_array : Array[Unit] = []
	for unit : Unit in units.values():
		if unit :
			unit_array.append(unit)
	return unit_array

func _on_unit_tree_exited(unit : Unit , tile : Vector2i) -> void:
	if unit.is_queued_for_deletion():#单位运用queued_free方法，将网格中的值变为null
		units[tile] = null
		_unit_exit_callables.erase(unit)
		unit_grid_changed.emit()

func _disconnect_unit_exit_signal(unit : Node) -> void:
	if not _unit_exit_callables.has(unit):
		return
	var exit_callable : Callable = _unit_exit_callables[unit]
	if unit.tree_exited.is_connected(exit_callable):
		unit.tree_exited.disconnect(exit_callable)
	_unit_exit_callables.erase(unit)
