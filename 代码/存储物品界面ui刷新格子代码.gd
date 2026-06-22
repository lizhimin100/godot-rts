extends Control

var 背包 = preload("res://物品系统/背包/背包.tres")

@onready var 背包格子 : GridContainer = $"背包UI/GridContainer"
@onready var 鼠标 : Node2D = $"背包UI/GridContainer/鼠标"


func _ready() -> void:
	#初始化时确定背包总格子数，进行刷新
	for index in 背包格子.get_children().size():
		刷新 (index)
		#跳过索引为0的格子，即跳过鼠标
		if index == 0 :
			continue
		#获取从0开始向下循环索引的背包格子，用bind（index）给每个格子连接的信号加上当前循环索引，
		#而当鼠标点击格子时，触发该格子的信号
		背包格子.get_child(index).gui_input.connect(Callable (self , "鼠标点击").bind(index))
		
	# 监听背包物品变化的信号
	背包.物品发生变化.connect(Callable(self, "刷新"))

	
	

func 刷新 (indexes) :
	for index in indexes :
		背包格子.get_child(index).格子显示(背包.存储物品列表[index])
	

func 鼠标点击 (event , index):
	if event is InputEventMouseButton and event.pressed :
		if event.button_index == 1:
			背包.交换物品 (0 , index)


func _process(_delta: float) -> void: 
	# 将当前节点的位置设置为鼠标的全局位置（实现跟随鼠标效果）
	鼠标.global_position = get_global_mouse_position() 
