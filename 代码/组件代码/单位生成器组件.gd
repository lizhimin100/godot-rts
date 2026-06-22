class_name UnitSpawner extends Node

signal unit_spawned(unit : Unit)

const UNIT = preload("res://单位/单位拖放/单位.tscn")

@export var bench :游戏瓦片层组件 = null #背包区
@export var ganme_area :游戏瓦片层组件 = null#游戏区

#测试代码
#func _ready() -> void:
	#var jianshi := preload("res://单位/单位数据/士兵.tres")
	#var tween := create_tween()
	#
	#for i in 15 :
		#tween.tween_callback(spawn_unit.bind(jianshi))
		#tween.tween_interval(0.5)



func _get_first_available_area() -> 游戏瓦片层组件:#寻找第一个有空位的游戏层
	if not bench.unit_grid.is_grid_full():
		return bench
	elif not ganme_area.unit_grid.is_grid_full():
		return ganme_area
	return null

func spawn_unit (unit: UnitStats) -> void:#生成单位的核心方法
	var area := _get_first_available_area()
	#TODO 有UI系统后再修改此项，不应该直接运行报错，应该UI提醒无法添加单位
	assert(area, "替补区和游戏区都已满，无法添加单位")
	
	var new_unit := UNIT.instantiate()
	var tile := area.unit_grid.get_first_empty_tile()
	area.unit_grid.add_child(new_unit)
	area.unit_grid.add_unit(tile , new_unit)
	new_unit.global_position = area.get_global_from_tile(tile) - 营地场景.一半单元格
	new_unit.stats = unit
	unit_spawned.emit(new_unit)
