extends ui按钮
class_name  ui背包按钮

@onready var 存储物品界面ui: Control = $存储物品界面UI

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	存储物品界面ui.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass



func 执行操作() -> void:
	super.执行操作()
	#print("[调试] 正在打开背包")  # 添加调试输出  # DEBUG
	存储物品界面ui.visible = true  # ✅ 切换显示状态
	#get_tree().paused = 存储物品界面ui.visible  # 可选：暂停游戏
