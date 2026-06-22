class_name 营地场景 extends Node2D

const 单元格 = Vector2(64 , 64)
const 一半单元格 = Vector2(32 , 32)
const 四分之一单元格 = Vector2(16 , 16)

@onready var 出售入口: SellPortal = %出售入口
@onready var 单位移动组件: UnitMover = %单位移动组件
@onready var 单位生成组件: UnitSpawner = %单位生成组件
@onready var 单位合成组件: UnitCombiner = %单位合成组件

func _ready() -> void:
	单位生成组件.unit_spawned.connect(单位移动组件.setup_unit)
	单位生成组件.unit_spawned.connect(出售入口.setup_unit)
	

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("空格"):
		单位合成组件.queue_unit_combination_update()
