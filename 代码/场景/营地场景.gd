class_name 营地场景 extends Node2D

const 单元格 = Vector2(64 , 64)
const 一半单元格 = Vector2(32 , 32)
const 四分之一单元格 = Vector2(16 , 16)

@onready var 出售入口: SellPortal = %出售入口
@onready var 单位移动组件: UnitMover = %单位移动组件
@onready var 单位生成组件: UnitSpawner = %单位生成组件
@onready var 单位合成组件: UnitCombiner = %单位合成组件

func _ready() -> void:
	# 移除已售出的预设单位
	var 全局变量 := get_node("/root/全局")
	if 全局变量 and not 全局变量.售出单位列表.is_empty():
		var units := get_tree().get_nodes_in_group("units")
		for unit: Unit in units:
			if unit.name in 全局变量.售出单位列表:
				unit.queue_free()

	单位生成组件.unit_spawned.connect(单位移动组件.setup_unit)
	单位生成组件.unit_spawned.connect(出售入口.setup_unit)

	# 连接返回按钮 - 使用 find_child 查找 UI层的返回世界按钮
	var 返回按钮 := find_child("返回世界", true, false) as Button
	if 返回按钮:
		返回按钮.pressed.connect(_on_返回世界_pressed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("空格"):
		单位合成组件.queue_unit_combination_update()


func _on_返回世界_pressed() -> void:
	get_tree().change_scene_to_file("res://场景/世界岛场景.tscn")
