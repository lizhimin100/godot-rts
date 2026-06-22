extends Node2D

@onready var canvas_group: 酒馆图像 = $CanvasGroup
@onready var 单位生成组件: UnitSpawner = %单位生成器
@onready var 单位移动组件: UnitMover = %单位移动组件
@onready var 出售入口: SellPortal = %出售入口
@onready var 单位合成组件: UnitCombiner = %单位合成组件

@onready var 商店: Shop = %商店
@onready var 棋子库: 棋子库 = %棋子库



func _ready() -> void:
	单位生成组件.unit_spawned.connect(单位移动组件.setup_unit)
	单位生成组件.unit_spawned.connect(出售入口.setup_unit)
	canvas_group.进入酒馆.connect(_on_进入酒馆)
	商店.unit_bought.connect(单位生成组件.spawn_unit)
	单位生成组件.unit_spawned.connect(单位合成组件.queue_unit_combination_update.unbind(1))


func _on_进入酒馆() -> void :
	商店.show()
