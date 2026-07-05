class_name  玩家
extends 移动基类  # 继承自 CharacterBody2D 节点，适用于2D物理运动

# ███ 配置参数 ███


var 对话中: bool = false  # 标记是否处于对话状态
@onready var 角色动画: AnimationPlayer = %角色动画2
@onready var 角色图像: Sprite2D = $角色图像
@onready var 选中标签: Label = $选中标签



@onready var 交互动画: AnimatedSprite2D = $交互动画
@onready var 交互管理器: Node2D = $交互管理器
@onready var 交互提示界面: CanvasLayer = $交互动画/交互提示界面

var 移动中: bool = false



# ███ 状态变量 ███



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("玩家")
	add_to_group("可选单位")#不能直接用分组，不然会导致框选时，会出现area2d节点也包括在其内报错
	add_to_group("同阵营单位")
	移动速度 = 270
	交互提示界面.visible = false
	交互动画.visible = false






# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta : float) -> void: # ## 物理帧处理器（Godot内置回调函数，固定时间步长），用于处理输入和移动逻辑
	选中标签.visible = 选择状态
	if not 交互管理器.交互对象.is_empty() :
		交互动画.visible = not 交互管理器.交互对象.is_empty()  #存在可交互对象时显示交互按键
		交互提示界面.visible = not 交互管理器.交互对象.is_empty()
	else :
		交互动画.visible = false
		交互提示界面.visible = false
	if Input.is_action_just_pressed("交互") : # 当按下交互键
		if not 交互管理器.交互对象.is_empty() : #交互对象组不为空
			var 最近对象 = 交互管理器.交互对象[0]  
			最近对象.交互逻辑(self) # ✅ 调用目标的交互方法（自定义函数）
			if 最近对象.开始对话 :# 只有当实际触发对话时才锁定移动
				对话中 = true
				#print("当前最近交互对象列表:", 最近对象.name)  # DEBUG
		else: # 没有可交互对象时保持移动
			#print("当前没有可交互对象")  # DEBUG
			对话中 = false
	
	super._physics_process(_delta)
	if 选择状态 :
		var 移动方向 = (目标位置 - global_position).normalized()
		角色图像.flip_h = 移动方向.x < 0 # 设置动画水平翻转（关键优化点）当x分量<0时向左移动，需要翻转精灵



func 开始移动() -> void:
	if not 对话中 and 选择状态 : #判断是不是在对话中、有没有被选中，不是对话且被选中才能移动
		移动中 = true
		角色动画.play("移动动画")  # 切换为移动动画

func 停止移动() -> void:
	super.停止移动()
	velocity = Vector2.ZERO  # ★ LEGACY VELOCITY 清除速度向量
	角色动画.play("待机动画")   # 切换回待机动画

#  自定义信号处理 
func 结束对话() -> void:
	#print("对话结束信号触发成功！")  # DEBUG
	对话中 = false  # ✅ 对话结束时更新状态
	#print("当前对话已结束，对话当前状态为：",  对话中)  # DEBUG



func 注册可交互对象(可交互目标: Node) -> void :
	交互管理器.加可交互对象(可交互目标)


func 移除可交互对象(可交互目标: Node) -> void:
	交互管理器.去可交互对象(可交互目标)
