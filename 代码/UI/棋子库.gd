class_name 棋子库 extends Control

@export var 单位悬停介绍 :NinePatchRect
@export var 悬停 : bool = false
@export var 显示 : = false

@onready var 棋子格子: NinePatchRect = $棋子格子
@onready var 动画: AnimationPlayer = $动画
@onready var 长凳区域: 游戏瓦片层组件 = %长凳区域


func _ready() -> void:
	var units := get_tree().get_nodes_in_group("units")
	for unit :Unit in units:#将场景中的单位添加到网格字典中。
		setup_unit(unit)

func setup_unit(unit : Unit) -> void:#获取瓦片坐标，并添加到网格中
	var unit_tile := 长凳区域.get_tile_from_global(unit.global_position)
	长凳区域.unit_grid.add_unit(unit_tile , unit)

func set_JS(unit : Unit):
	单位悬停介绍.find_child("名字").text = unit.stats.单位名称
	单位悬停介绍.find_child("图片").texture = unit.皮肤
	单位悬停介绍.find_child("介绍").text = str(unit.stats.单位稀有度 , unit.stats.单位等级)



func _on_按钮_pressed() -> void:
	if not 显示:
		动画.play("弹出")
		显示 = true
	else :
		动画.play("隐藏")
		显示 = false
