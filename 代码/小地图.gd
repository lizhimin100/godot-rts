extends SubViewport

@export var 相机节点 : Node2D 
@export var 玩家节点 : Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	world_2d = get_tree().root.world_2d #world_2d是指当前2d世界
	#而用get_tree().root能获取游戏当前运行的主视窗的，加上.world_2d则能获取主视窗的2d世界


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	相机节点.position = 玩家节点.position
