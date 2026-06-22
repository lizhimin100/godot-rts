class_name TierIcon extends TextureRect

const TIER_ICONS := {
	1 : preload("res://assets/sprites/level1.png"),
	2 : preload("res://assets/sprites/level2.png"),
	3 : preload("res://assets/sprites/level3.png"),
}

@export var stats : UnitStats : set = _set_stats

func _set_stats(value :  UnitStats) -> void:
	if stats == value :
		return
	
	stats = value
	
	if stats == null:#没有单位信息或单位等级为1级时返回
		texture = null
		return
	
	
	#if not is_node_ready():
		#await ready
	
	stats.changed.connect(_on_stats_changed)
	_on_stats_changed()


func  _on_stats_changed() -> void:
	if stats.单位等级 == 1 or stats.单位等级 == 5 :
		texture = null
	else :texture = TIER_ICONS[stats.单位等级-1]
