extends Node2D

## 建筑放置管理器 — 处理建造UI按钮→选择位置→放置建筑的完整流程

enum 建筑类型 { 城堡, 房子, 防御塔 }

const 建筑场景 := {
	建筑类型.城堡: preload("res://单位/建筑/城堡.tscn"),
	建筑类型.房子: preload("res://单位/建筑/房子.tscn"),
	建筑类型.防御塔: preload("res://单位/建筑/防御塔.tscn"),
}

const 建筑贴图 := {
	建筑类型.城堡: preload("res://小剑资源/兵种/Knights/Buildings/Castle/Castle_Blue.png"),
	建筑类型.房子: preload("res://小剑资源/兵种/Knights/Buildings/House/House_Blue.png"),
	建筑类型.防御塔: preload("res://小剑资源/兵种/Knights/Buildings/Tower/Tower_Blue.png"),
}

const 建筑碰撞尺寸 := {
	建筑类型.城堡: Vector2(160, 128),
	建筑类型.房子: Vector2(96, 80),
	建筑类型.防御塔: Vector2(80, 96),
}

var 放置进行中 := false
var 当前建筑类型: 建筑类型
var 预览精灵: Sprite2D
var 位置有效 := false

# 放置目标父节点
@onready var 建筑父节点: Node = get_node("/root/平面/单位")


func _ready() -> void:
	# 连接建造UI信号
	var 建造UI = get_node_or_null("/root/平面/UI层/建造UI")
	if 建造UI:
		建造UI.建造1.connect(_on_建造城堡)
		建造UI.建造2.connect(_on_建造房子)
		建造UI.建造3.connect(_on_建造防御塔)
		print("🏗️ 建筑放置管理器已连接建造UI")
	else:
		print("⚠️ 未找到建造UI节点")


func _on_建造城堡() -> void:
	开始放置(建筑类型.城堡)


func _on_建造房子() -> void:
	开始放置(建筑类型.房子)


func _on_建造防御塔() -> void:
	开始放置(建筑类型.防御塔)


func 开始放置(类型: 建筑类型) -> void:
	if 放置进行中:
		取消放置()

	当前建筑类型 = 类型
	放置进行中 = true
	位置有效 = false

	# 创建预览精灵
	预览精灵 = Sprite2D.new()
	预览精灵.texture = 建筑贴图[类型]
	预览精灵.modulate = Color(1, 1, 1, 0.5)
	预览精灵.z_index = 100
	add_child(预览精灵)

	print("🏗️ 开始放置: ", 建筑类型.keys()[类型])


func 取消放置() -> void:
	放置进行中 = false
	位置有效 = false
	if is_instance_valid(预览精灵):
		预览精灵.queue_free()
	预览精灵 = null


func _process(_delta: float) -> void:
	if not 放置进行中 or not is_instance_valid(预览精灵):
		return

	var 鼠标位置 = get_global_mouse_position()
	预览精灵.global_position = 鼠标位置

	# 碰撞检测：检查是否与已有建筑重叠
	var 空间 = get_world_2d().direct_space_state
	var 形状 = PhysicsShapeQueryParameters2D.new()
	var 矩形 = RectangleShape2D.new()
	矩形.size = 建筑碰撞尺寸[当前建筑类型]
	形状.set_shape(矩形)
	形状.transform = Transform2D(0, 鼠标位置)
	形状.collision_mask = 4  # 建筑层

	var 结果 = 空间.intersect_shape(形状)
	位置有效 = 结果.is_empty()

	# 预览变色：红=不可放置，绿=可放置
	if 位置有效:
		预览精灵.modulate = Color(0.5, 1, 0.5, 0.5)
	else:
		预览精灵.modulate = Color(1, 0.3, 0.3, 0.5)


func _input(event: InputEvent) -> void:
	if not 放置进行中:
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if 位置有效:
					放置建筑()
			MOUSE_BUTTON_RIGHT:
				取消放置()


func 放置建筑() -> void:
	if not 放置进行中 or not 位置有效:
		return

	var 场景 = 建筑场景[当前建筑类型]
	if not 场景:
		print("⚠️ 建筑场景未找到: ", 建筑类型.keys()[当前建筑类型])
		取消放置()
		return

	var 建筑 = 场景.instantiate()
	建筑.global_position = 预览精灵.global_position
	if 建筑父节点:
		建筑父节点.add_child(建筑)
	else:
		add_child(建筑)

	print("🏗️ 已放置: ", 建筑类型.keys()[当前建筑类型], " 位置: ", 建筑.global_position)
	取消放置()
