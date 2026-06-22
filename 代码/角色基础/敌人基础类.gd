class_name Enemy
extends CharacterBody2D

enum Direction {
	LEFT = -1 ,
	RIGHT =-2 ,
}

@export var direction : = Direction.LEFT :
	set(v) :
		direction = v
		图形.scale.x = -direction
@export var 最大速度 : float =180
@export var 加速度 : float = 2000


@onready var 图形: Node2D = $图形
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
