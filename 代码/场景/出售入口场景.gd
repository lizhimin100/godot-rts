class_name SellPortal extends Area2D#节点放在最下面，不然在该节点后面的UNIT会检测不到

@export var player_stats : PlayerStats

@onready var 轮廓高亮组件: 轮廓高亮组件 = $轮廓高亮组件
@onready var 金钱显示: HBoxContainer = %金钱显示
@onready var 金钱标签: Label = %金钱标签

var current_unit : Unit

static var initialized = false#静态变量标记初始化状态

func _ready() -> void:
	if not initialized:#不用静态变量标记初始化状态会导致下面信号重复连接
		initialized = true
		var units := get_tree().get_nodes_in_group("units")
		for unit: Unit in units :
			setup_unit(unit)

func setup_unit(unit : Unit) -> void:
	unit.拖放组件.放下目标.connect(_on_unit_dropped.bind(unit))
	unit.quick_sell_pressed.connect(_sell_unit.bind(unit))

func _sell_unit(unit : Unit) -> void:
	player_stats.金钱 += unit.stats.get_gold_value()
	#TODO 以后出售单位有物品将返回物品
	#TODO 以后出售单位后，该单位要回到单位池
	prints(player_stats.金钱)
	unit.queue_free()

func _on_unit_dropped(_starting_position : Vector2 , unit : Unit) -> void:
	if unit and unit == current_unit :
		_sell_unit(unit)



func _on_area_entered(unit : Unit) -> void:
	current_unit = unit
	轮廓高亮组件.highlight()
	金钱标签.text = str(unit.stats.get_gold_value())
	金钱显示.show()#该方法是如果该UI隐藏，则显示


func _on_area_exited(unit : Unit) -> void:
	if unit and unit == current_unit :
		current_unit = null
	轮廓高亮组件.clear_highlight()
	金钱显示.hide()
