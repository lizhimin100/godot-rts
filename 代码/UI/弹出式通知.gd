extends CanvasLayer

@export var debug : bool = false
@export var 侧部标签 = preload("res://UI/侧部弹出标签/侧部弹出标签.tscn")

@onready var 顶部: TextureRect = $顶部
@onready var 中部: Panel = $中部
@onready var 侧部: VBoxContainer = $侧部

func _input(event: InputEvent) -> void:
	if event is InputEventKey and debug :
		if event.pressed and event.keycode == KEY_1 :
			show_side()


func show_side(message = "Item") :
	var side_label : Label = 侧部标签.instantiate()
	side_label.text = message
	侧部.add_child(side_label)
	
	var tween : Tween = side_label.create_tween()
	tween.tween_interval(2.5)
	tween.tween_callback(side_label.queue_free)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
