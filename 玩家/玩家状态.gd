class_name PlayerStats extends Resource

const XP_REQUIREMENTS := {#经验值需要的字典
	1 : 5,
	2 : 10,
	3 : 20,
	4 : 40,
	5 : 80,
	6 : 160,
	7 : 320,
	8 : 640,
	9 : 1280,
	10 : 2560
}

const ROLL_RARITIES : = {
	1: [UnitStats.单位稀有度.普通],
	2: [UnitStats.单位稀有度.普通],
	3: [UnitStats.单位稀有度.普通 , UnitStats.单位稀有度.罕见],
	4: [UnitStats.单位稀有度.普通 , UnitStats.单位稀有度.罕见 , UnitStats.单位稀有度.稀有],
	5: [UnitStats.单位稀有度.普通 , UnitStats.单位稀有度.罕见 , UnitStats.单位稀有度.稀有],
	6: [UnitStats.单位稀有度.普通 , UnitStats.单位稀有度.罕见 , UnitStats.单位稀有度.稀有],
	7: [UnitStats.单位稀有度.普通 , UnitStats.单位稀有度.罕见 , UnitStats.单位稀有度.稀有 , UnitStats.单位稀有度.传说],
	8: [UnitStats.单位稀有度.普通 , UnitStats.单位稀有度.罕见 , UnitStats.单位稀有度.稀有, UnitStats.单位稀有度.传说],
	9: [UnitStats.单位稀有度.普通 , UnitStats.单位稀有度.罕见 , UnitStats.单位稀有度.稀有, UnitStats.单位稀有度.传说],
	10: [UnitStats.单位稀有度.普通 , UnitStats.单位稀有度.罕见 , UnitStats.单位稀有度.稀有, UnitStats.单位稀有度.传说]
	
}

const ROLL_CHANCES := {
	1: [1],
	2: [1],
	3: [7.5 , 2.5],
	4:[6.5 , 3.0 , 0.5],
	5:[5.0 , 3.5 , 1.5],
	6:[4.0 , 4.0 , 2.0],
	7:[2.75 , 4.0 , 3.24 ,0.1],
	8:[2.5 , 3.75 , 3.45 , 0.3],
	9:[1.75 , 2.75 , 4.5 , 1.0],
	10:[1.0 , 2.0 , 4.5 , 2.5]
	
}


@export_range(0 , 9999) var 金钱 : int : set = _set_gold
@export_range(0 , 999) var 经验 : int: set  = _set_xp
@export_range(1 , 10) var 等级 : int : set = _set_level

func get_random_rarity_for_level() -> UnitStats.单位稀有度:
	var rng = RandomNumberGenerator.new()
	var array : Array = ROLL_RARITIES[等级]
	var weights : PackedFloat32Array = PackedFloat32Array(ROLL_CHANCES[等级])
	
	return array[rng.rand_weighted(weights)]


func get_current_xp_requirement() -> int:#升到下一级所需的经验值
	var next_xp = clampi(等级+1 , 1, 10)
	return XP_REQUIREMENTS[next_xp]

func _set_gold(value : int) -> void:
	金钱 = value
	emit_changed()

func _set_xp(value : int) -> void:
	经验 = value
	emit_changed()
	if 等级 == 10:return
	
	var xp_requirement : int = get_current_xp_requirement()
	
	while 等级 < 10 and 经验 >= xp_requirement:
		等级 += 1
		经验 -= xp_requirement
		xp_requirement = get_current_xp_requirement()
		emit_changed()

func _set_level(value : int) -> void:
	等级 = value
	emit_changed()
