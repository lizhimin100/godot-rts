class_name 箭矢
extends Area2D

## 箭矢弹道 — 弓箭手射出的飞行箭矢
##
## 发射时 snapshot 目标位置，飞行轨迹固定不追踪 target node。
## 命中后通过 DamageSystem 造成伤害并自我销毁。
##
## ⭐ 关键设计决策：
##   不追踪 target node（旧版本追踪 node 导致箭"追人"的错误行为）
##   使用 target_position 快照位置，弹道固定

var 速度: float = 600.0
## 目标位置快照（箭矢生成时记录，飞行过程中不更新）
var target_position: Vector2 = Vector2.ZERO
## 伤害数据包（传入 DamageSystem）
var damage_packet: DamagePacket = null
var attacker: Node2D = null
var _已命中 := false

const 箭矢纹理 := preload("res://小剑资源/兵种/Knights/Troops/Archer/Arrow/Arrow.png")

@onready var 碰撞: CollisionShape2D = $碰撞
@onready var 视觉: Sprite2D = $视觉


func _ready() -> void:
	视觉.texture = 箭矢纹理
	视觉.region_enabled = true
	# 纹理 64×128，两帧箭矢动画垂直排列
	视觉.region_rect = Rect2(0, 0, 64, 128)
	视觉.vframes = 2
	视觉.frame = 0
	视觉.centered = true

	var 帧计时器 := create_tween().set_loops()
	帧计时器.tween_callback(func(): 视觉.frame = 0).set_delay(0)
	帧计时器.tween_callback(func(): 视觉.frame = 1).set_delay(0.08)

	# 朝向目标方向
	look_at(target_position)

	# 安全超时
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		_销毁()


func _physics_process(delta: float) -> void:
	if _已命中:
		return

	var 当前方向 := (target_position - global_position).normalized()
	var 移动距离 := 速度 * delta
	var 到目标距离 := global_position.distance_to(target_position)

	if 移动距离 >= 到目标距离:
		global_position = target_position
		_命中()
	else:
		global_position += 当前方向 * 移动距离
		rotation = 当前方向.angle()


func _命中() -> void:
	if _已命中:
		return
	_已命中 = true

	# 通过 DamageSystem 造成伤害
	if damage_packet and is_instance_valid(damage_packet.target):
		DamageSystem.apply_damage(damage_packet)

	# 命中闪白
	scale = Vector2(1.5, 1.5)
	modulate = Color(1, 1, 0.5, 1)
	await get_tree().create_timer(0.05).timeout
	_销毁()


func _销毁() -> void:
	if is_instance_valid(self):
		queue_free()
