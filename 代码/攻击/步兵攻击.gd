extends Node
class_name 攻击组件
@export var 攻击伤害 := 10.0
@export var 攻击间隔 := 1.0
@export var 攻击范围 := 50.0
@onready var 伤害框判定: Area2D = $伤害框判定

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
