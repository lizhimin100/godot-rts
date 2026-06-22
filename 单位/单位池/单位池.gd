class_name UnitPool extends Resource

@export var available_units : Array[UnitStats]

var unit_pool : Array[UnitStats]


func generate_unit_pool() -> void:
	unit_pool = []
	
	for unit :UnitStats in available_units:
		for i in unit.pool_count:#根据pool_count的数值，多次添加到unit_pool
			unit_pool.append(unit)

func get_random_unit_by_rarity(rarity : UnitStats.单位稀有度) ->UnitStats:
	var units := unit_pool.filter(
		func(unit : UnitStats):
			return unit.稀有度 == rarity
		
	)
	if units.is_empty():
		return null
	
	var picked_unit : UnitStats = units.pick_random()
	unit_pool.erase(picked_unit)
	return picked_unit

func add_unit(unit : UnitStats)-> void:
	var combined_count := unit.get_combined_unit_count()
	unit = unit.duplicate()
	unit.单位等级 = 1
	
	for i in combined_count:
		unit_pool.append(unit)
