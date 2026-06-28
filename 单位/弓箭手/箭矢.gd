class_name 箭矢
extends Area2D

## 箭矢弹道 — 弓箭手射出的飞行箭矢
##
## 自动追踪目标，命中后通过 DamageSystem 造成伤害
## 携带 damage_packet（由 CombatComponent 创建）

var 速度: float = 600.0
## 目标（英文名，供弓箭手.gd 设置）
var target: Node2D:
	get: return 目标
	set(v): 目标 = v
var 目标: Node2D = null
## 伤害数据包（传入 DamageSystem）
var damage_packet: DamagePacket = null
var 攻击者: Node2D = null
var _已命中 := false

const 箭矢纹理 := preload("res://小剑资源/兵种/Knights/Troops/Archer/Arrow/Arrow.png")

@onready var 碰撞: CollisionShape2D = $碰撞
@onready var 视觉: Sprite2D = $视觉


func _ready() -> void:
	视觉.texture = 箭矢纹理
	视觉.region_enabled = true
	视觉.region_rect = Rect2(0, 0, 64, 64)
	视觉.vframes = 2
	视觉.frame = 0
	视觉.centered = true

	var 帧计时器 := create_tween().set_loops()
	帧计时器.tween_callback(func(): 视觉.frame = 0).set_delay(0)
	帧计时器.tween_callback(func(): 视觉.frame = 1).set_delay(0.08)

	if 目标 and is_instance_valid(目标):
		look_at(目标.global_position)

	# 安全超时
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		_销毁()


func _physics_process(delta: float) -> void:
	if _已命中:
		return
	if not 目标 or not is_instance_valid(目标):
		_销毁()
		return

	# 检查目标存活（向后兼容：同时支持组件和旧属性）
	var target_alive := true
	var hc: HealthComponent = _find_health(目标)
	if hc:
		target_alive = not hc.is_dead()
	elif "当前生命值" in 目标:
		target_alive = 目标.当前生命值 > 0

	if not target_alive:
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

	# 通过 DamageSystem 造成伤害
	if damage_packet and is_instance_valid(damage_packet.target):
		DamageSystem.apply_damage(damage_packet)
	elif 目标 and is_instance_valid(目标) and damage_packet:
		# 降级：直接伤害
		var hc := _find_health(目标)
		if hc:
			hc.take_damage(damage_packet.damage, 攻击者)

	# 命中闪白
	scale = Vector2(1.5, 1.5)
	modulate = Color(1, 1, 0.5, 1)
	await get_tree().create_timer(0.05).timeout
	_销毁()


func _销毁() -> void:
	if is_instance_valid(self):
		queue_free()


static func _find_health(node: Node) -> HealthComponent:
	var hc: HealthComponent = node.get_node_or_null("HealthComponent") as HealthComponent
	if hc:
		return hc
	for child in node.get_children():
		if child is HealthComponent:
			return child
	return null
