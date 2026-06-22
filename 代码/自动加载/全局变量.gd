class_name 全局 extends Node

var 可通过 := PackedVector2Array()
var 不可通过 := PackedVector2Array()
var 选中工人 :bool = false
var 选中建筑 : bool = false


var 金钱 = 1200
var 木材 = 1200
var 食物 = 1200
var 现有人口 = 0
var 最大人口 = 0

var 新新指令 = null
var 新指令目标类型 = null
var 新指令类似 = null
var 新指令id = null

var 敌方单位 = 0
var 我方单位 = 0




# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func 重置全局变量 ():
	可通过 = PackedVector2Array()
	不可通过 = PackedVector2Array()
	选中工人 = false
	选中建筑 = false


	金钱 = 1200
	木材 = 1200
	食物 = 1200
	现有人口 = 0
	最大人口 = 0

	新新指令 = null
	新指令目标类型 = null
	新指令类似 = null
	新指令id = null

	敌方单位 = 0
	我方单位 = 0
