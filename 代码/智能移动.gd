extends Sprite2D

@export var 格子 : TileMapLayer 

var 路径 : Array[Vector2i]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("移动") :
		var 鼠标位置 = get_global_mouse_position()
		
		var 起点位置 = 格子.local_to_map(global_position)
		var 终点位置 = 格子.local_to_map(鼠标位置)
		
		路径 = 格子.astar.get_id_path(起点位置 , 终点位置)
		
		#print(路径)  # DEBUG
	
	if 路径  and not 路径.is_empty() : #如果路径存在且不是空集便执行下面代码
		var 路径位置 = 格子.map_to_local(路径[0])#将tilmaplayer坐标转换为世界坐标
		global_position = global_position.move_toward(路径位置 , 200 * delta)
		
		if global_position == 路径位置 :
			路径.remove_at(0)
