extends CharacterBody2D



@onready var 属性组件: 属性组件 = $属性组件
var 最大血量 : Attribute
var 当前血量 : Attribute

@export_group("属性")
@export var 移动速度 : float = 20.0
@export var 血量 = 10

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


var 当前目标 : Node2D = null
var 正在暂停 : bool = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("敌人")
	最大血量 = 属性组件.获取属性对象("最大血量")
	当前血量 = 属性组件.获取属性对象("当前血量")
	print_health()


func _on_受伤框判定_受到伤害(攻击对象: 伤害框判定) -> void:
	当前血量.apply_modifier(AttributeModifier.subtract(1)) 
	if 当前血量.get_value() == 0 :
		animated_sprite_2d.play("死亡")
		queue_free()



func print_health():
	print("health stat : %.01f/%.01f"% [当前血量.get_value() , 最大血量.get_value()])
