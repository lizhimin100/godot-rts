class_name UnitStats extends Resource

enum 单位稀有度 {普通 ,罕见,稀有,传说}

const  稀有度颜色 : = {
	单位稀有度.普通 : Color("124a2e"),
	单位稀有度.罕见 : Color("1c527c"),
	单位稀有度.稀有 : Color("ab0979"),
	单位稀有度.传说 : Color("ea940b")
}

@export var 单位名称 : String

@export_category("数据分类")
@export var 稀有度 : 单位稀有度
@export var 金币费用 :=1
@export_range(1 , 5) var 单位等级 := 1 : set = _set_tier
@export var pool_count := 6#在一轮单位池中该单位卡的数量

@export_category("视角图标")
@export var 皮肤坐标 : Vector2i

func _set_tier(value : int) -> void:
	单位等级 = value
	emit_changed()

func get_combined_unit_count() -> int:
	#TODO 实际是3还是2要等后续再修改，看单位等级提升和合成怎么做
	return 3 ** (单位等级 -1) 

func get_gold_value() -> int:
	return 金币费用 * get_combined_unit_count()

func 调试 ():
	return 单位名称
