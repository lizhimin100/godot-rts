class_name Shop extends Control

signal unit_bought(unit : AcUnitStats)

const UNIT_CARD = preload("res://单位/单位卡/角色卡.tscn")

@export var unit_pool : UnitPool
@export var player_stats : PlayerStats

@onready var 网格容器: GridContainer = %网格容器
@onready var 招募购买: VBoxContainer = %招募购买



func _ready() -> void:
	招募购买.visible = false
	unit_pool.generate_unit_pool()
	
	for child: Node in 网格容器.get_children():
		child.queue_free()
	
	_roll_unit()

func _roll_unit() -> void:
	for i in 6:
		var rarity := player_stats.get_random_rarity_for_level()
		var new_card: UnitCard = UNIT_CARD.instantiate()
		new_card.unit_stats = unit_pool.get_random_unit_by_rarity(rarity)
		new_card.unit_bought.connect(_on_unit_bought)
		网格容器.add_child(new_card)

func _put_back_remaining_to_pool () -> void:#将没有购买的单位添加到单位池
	for unit_card : UnitCard in 网格容器.get_children():#遍历棋子合集容器
		if not unit_card.bought:
			unit_pool.add_unit(unit_card.unit_stats)
		
		unit_card.queue_free()



func _on_unit_bought(unit : AcUnitStats) -> void:
	unit_bought.emit(unit)

func _on_重掷按钮_pressed() -> void:
	_put_back_remaining_to_pool()
	_roll_unit()


func _on_退出按钮_pressed() -> void:
	self.hide()
	招募购买.hide()

func _on_返回按钮_pressed() -> void:
	招募购买.hide()

func _on_招募的按钮_pressed() -> void:
	招募购买.show()
