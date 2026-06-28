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

# 营地售出单位跟踪（按节点名称）
var 售出单位列表 := []

# 场景切换用 — 存储世界场景中的主角位置
var 存储_主角位置 := Vector2(1072, 650)
var 存储_相机位置 := Vector2(1072, 650)
var 存储_相机缩放 := 1.3

# ========== 建筑类型数据（供建筑放置管理器 + 农民使用） ==========
enum 建筑类型 { 城堡, 房子, 防御塔 }

const 建筑场景 := {
	建筑类型.城堡: preload("res://单位/建筑/城堡.tscn"),
	建筑类型.房子: preload("res://单位/建筑/房子.tscn"),
	建筑类型.防御塔: preload("res://单位/建筑/防御塔.tscn"),
}

const 建筑碰撞尺寸 := {
	建筑类型.城堡: Vector2(300, 240),
	建筑类型.房子: Vector2(120, 180),
	建筑类型.防御塔: Vector2(120, 240),
}


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# 全局通知弹窗 — 在世界坐标位置显示浮动文字
func 显示通知(消息: String, 位置: Vector2 = Vector2(640, 360)) -> void:
	var label := Label.new()
	label.text = 消息
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 1))
	label.position = 位置 - Vector2(label.get_minimum_size().x / 2, 0)
	label.z_index = 200
	get_tree().current_scene.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(label.queue_free)

func 重置全局变量 ():
	可通过 = PackedVector2Array()
	不可通过 = PackedVector2Array()
	选中工人 = false
	选中建筑 = false

	售出单位列表 = []

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
