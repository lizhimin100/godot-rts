class_name 箭矢
extends Area2D

## 箭矢弹道 — 弓箭手射出的飞行箭矢
## 自动追踪目标，命中后造成伤害并自我销毁

var 速度: float = 600.0
var 目标: Node2D = null
var 伤害: float = 1.0
var 攻击者: Node2D = null
var _已命中 := false

const 箭矢纹理 := preload("res://小剑资源/兵种/Knights/Troops/Archer/Arrow/Arrow.png")

@onready var 碰撞: CollisionShape2D = $碰撞
@onready var 视觉: Sprite2D = $视觉


func _ready() -> void:
	# 设置箭矢视觉（纵向2帧，每帧64x64）
	视觉.texture = 箭矢纹理
	视觉.region_enabled = true
	视觉.region_rect = Rect2(0, 0, 64, 64)
	视觉.vframes = 2
	视觉.frame = 0
	视觉.centered = true
	# 播放帧动画（循环切换上下2帧）
	var 帧计时器 := create_tween().set_loops()
	帧计时器.tween_callback(func(): 视觉.frame = 0).set_delay(0)
	帧计时器.tween_callback(func(): 视觉.frame = 1).set_delay(0.08)

	# 朝向目标起始方向
	if 目标 and is_instance_valid(目标):
		look_at(目标.global_position)

	# 安全超时：3秒后自动删除
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		_销毁()


func _physics_process(delta: float) -> void:
	if _已命中:
		return
	if not 目标 or not is_instance_valid(目标):
		_销毁()
		return
	if 目标.当前生命值 <= 0:
		_销毁()
		return

	var 当前方向 := (目标.global_position - global_position).normalized()
	var 移动距离 := 速度 * delta
	var 到目标距离 := global_position.distance_to(目标.global_position)

	if 移动距离 >= 到目标距离:
		global_position = 目标.global_position
		_命中()
	else:
		global_position += 当前方向 * 移动距离
		rotation = 当前方向.angle()


func _命中() -> void:
	if _已命中:
		return
	_已命中 = true

	if 目标 and is_instance_valid(目标) and 目标.当前生命值 > 0:
		if 目标.has_method("受伤"):
			目标.受伤(伤害, 攻击者)

	# 命中闪白效果
	scale = Vector2(1.5, 1.5)
	modulate = Color(1, 1, 0.5, 1)
	await get_tree().create_timer(0.05).timeout

	_销毁()


func _销毁() -> void:
	if is_instance_valid(self):
		queue_free()
