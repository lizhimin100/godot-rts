extends Node
class_name 血量

var _血量 : int = 0

@export var max_health : int = 10
@onready var health : int = max_health :
	set(v):
		v = clampi(v , 0 , max_health)
		if _血量 == v:
			return
		_血量 = v
	get:
		return _血量

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
