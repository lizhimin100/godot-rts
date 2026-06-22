class_name UnitCombiner extends Node

@export var buffer_timer : Timer#缓冲计时器

var queued_updates := 0#当前排队的等候更新的数量
var tween : Tween

func _ready() -> void:
	buffer_timer.timeout.connect(_on_buffer_timer_timeout)
	


func queue_unit_combination_update() -> void:#TODO 共同方法
	buffer_timer.start()#重新启动缓冲计时器

func _update_unit_combinations(tier : int) -> void:#把参数中单位等级传入
#按单位名，把同一等级单位归类到一组中
	var groups := _group_units_in_tier_by_name(tier)
#返回一个数组，该数组成员是以三个同名、且同等级的单位的数组
	var triplets : Array[Array] = _get_triplets_for_groups(groups)
#如果该变量数组中一个“三个单位”的成员数组都凑不出，就告诉系统更新完或不用更新 再立刻返回
	if triplets.is_empty() :
		_on_units_combined(tier)
		return
	
	tween = create_tween()#动画延时
	
	for combination in triplets:#遍历变量数组中所有的成员数组
#将成员数组的三个单位作为参数传入
		tween.tween_callback(_combine_units.bind(combination[0] , combination[1] , combination[2]))
#设置补间间隔，确保多个单位合成的动画不会同时进行
		tween.tween_interval(UnitAnimations.COMBINE_ANIM_LENGTH)
#动画播放完代表没有成员数组，连接信号作上面变量数组为空时一样的事情，
		tween.finished.connect(_on_units_combined.bind(tier) , CONNECT_ONE_SHOT)

#组合三个单位，为所有成员数组在中间插值时调用的方法
func _combine_units(unit1 : Unit , unit2 : Unit , unit3 : Unit) -> void:
	unit1.stats.单位等级 += 1#设置单位等级（tier）加一
#在播放动画前，移除单位组中的其他两个单位
	unit2.remove_from_group("units")
	unit3.remove_from_group("units")
	unit2.单位合成动画组件.play_combine_animation(unit1.global_position + 营地场景.四分之一单元格)
	unit3.单位合成动画组件.play_combine_animation(unit1.global_position + 营地场景.四分之一单元格)

#该方法返回一个字典
#键是单位名称
#值是该单位的实例的数组
func _group_units_in_tier_by_name(tier : int ) -> Dictionary:#参数是分组依照的等级
	var units := get_tree().get_nodes_in_group("units")#找出所有单位
	var filtered_units := units.filter(#筛选符合想更新等级的单位
		func(unit : Unit) :
			return unit.stats.单位等级 == tier#筛选出等于想更新的等级的单位
	)
	
	var unit_groups := {}
	
	for unit : Unit in filtered_units: #迭代过滤过的单位数组
		if unit_groups.has(unit.stats.单位名称):#如果单位名称已经是字典的键
			unit_groups[unit.stats.单位名称].append(unit)#把单位添加到字典的值中
		else:unit_groups[unit.stats.单位名称] = [unit]
	
	return unit_groups

#返回从上面_group_units_in_tier_by_name方法中得到字典中找到的所有组合
#这些组合以三个单位实例为一数组
#把这些数组作为成员数组存储在一个返回数组中
func _get_triplets_for_groups(groups: Dictionary) -> Array[Array]:
	var upgrades : Array[Array] = []
	
	for unit_name in groups:#遍历传入的字典所有单位
#将字典中“同一名称”键的值存储在当前单位数组中，无论数量多少
		var current_units : Array = groups[unit_name]
		while current_units.size() >= 3:#检测数组大小是否大于3
#如果是，那创建包含三个单位实例的成员数组，将其添加到返回数组中，并移除当前数组前三的元素
			var combination := [current_units[0] , current_units[1] , current_units[2]]
			upgrades.append(combination)
			current_units =current_units.slice(3)
	
	return upgrades

func _on_buffer_timer_timeout() -> void:
	queued_updates += 1
#如果不存在动画或动画存在却没运行，不仅添加更新到队列中
	if not tween or not tween.is_running():
		_update_unit_combinations(1)
#单位合成后，一个更新周期完成后会发生什么
func _on_units_combined(tier : int) -> void:
	if tier == 1:
		_update_unit_combinations(2)
	else:
		queued_updates -= 1
		if queued_updates >= 1:
			_update_unit_combinations(1)
