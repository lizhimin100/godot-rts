class_name 移动基类
extends CharacterBody2D

signal 避开友军

@export var 移动速度: float = 200
@export var 最大速度: float = 350
@export var 加速度 = 50
@export var 停止阈值: float = 10.0
@export var 选择状态 = false

var 目标位置: Vector2 = Vector2.ZERO
var 点击位置: Vector2 = Vector2.ZERO
var 移动方向


func _ready() -> void:
	add_to_group("可选单位")


func 开始移动() -> void:
	velocity = 移动方向 * 移动速度
	move_and_slide()


func 结束移动() -> void:
	velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	开始移动()
	var 剩余距离 = global_position.distance_to(目标位置)
	if 剩余距离 <= 停止阈值: 结束移动()
