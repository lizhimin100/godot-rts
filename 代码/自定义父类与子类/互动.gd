class_name  互动
extends Area2D
var 开始对话 = false
var 当前交互者 : Node = null # 定义类属性

signal 发生交互


func _init() -> void:
	#不能直接赋能，单独输入5就是输入16，同时开启3和5相当于4+16，会很麻烦
	collision_layer = 0 #碰撞层
	collision_mask = 0 #碰撞遮罩
	set_collision_mask_value( 2 , true)
	
	body_entered.connect(进入)
	body_exited.connect(退出)

func 交互逻辑 (交互者 : Node) -> void :
	if !交互者.is_in_group("玩家") :  # 检查是否是角色类节点
		print("交互者必须是玩家节点！")
		return
	当前交互者 = 交互者 # 将交互者赋值给类属性
	对话交互逻辑(当前交互者)
	print("[交互逻辑]%s" % name)
	发生交互.emit()
	await get_tree().create_timer(0.5).timeout # 0.5秒后执行的代码






func 进入 (操作角色 ) -> void :
	print("npc检测到有物体进入：", 操作角色.name)
	if 操作角色.is_in_group("玩家"):
		print("玩家进入npc交互区域")
		操作角色.注册可交互对象(self)

func 退出 (操作角色 ) -> void :
	if 操作角色.is_in_group("玩家"):
		操作角色.移除可交互对象(self)


func 对话交互逻辑 (交互者: Node) -> void  :
	if !交互者.is_in_group("玩家") :  # 检查是否是角色类节点
		print("对话者必须是玩家节点！")
		return
	if 交互者.对话中:  # 如果已经在对话中则返回
		print("当前对话者正在对话中！")
		return
	print(交互者.name , "现在可以和npc进行对话。")
