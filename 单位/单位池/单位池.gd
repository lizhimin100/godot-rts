class_name UnitPool extends Resource

@export var available_units : Array[AcUnitStats]

var unit_pool : Array[AcUnitStats]


func generate_unit_pool() -> void:
	unit_pool = []
	
	for unit :AcUnitStats in available_units:
		for i in unit.pool_count:#根据pool_count的数值，多次添加到unit_pool
			unit_pool.append(unit)

func get_random_unit_by_rarity(rarity : UnitRarity.单位稀有度) ->AcUnitStats:
	var units := unit_pool.filter(
		func(unit : AcUnitStats):
			return unit.稀有度 == rarity
		
	)
	if units.is_empty():
		return null
	
	var picked_unit : AcUnitStats = units.pick_random()
	unit_pool.erase(picked_unit)
	return picked_unit

func add_unit(unit : AcUnitStats)-> void:
	var combined_count := unit.get_combined_unit_count()
	unit = unit.duplicate()
	unit.单位等级 = 1
	
	for i in combined_count:
		unit_pool.append(unit)
