class_name ui按钮  # 自定义类名方便继承
extends Button

@export var 提示文本 : String = ""    # 按钮功能描述
@export var 快捷键 : String = ""             # 快捷键动作名（如"ui_inventory"）
@export var 悬停缩放 : float = 1.1       # 悬停时的缩放效果
@export var 提示框偏移 : Vector2 = Vector2(4, 4) # 提示框相对于按钮的位置
@export var ui提示框 = preload("res://组件/ui提示框组件.tscn")


# ================= 动态生成节点 =================
						 # 运行时动态创建的提示框
var 原始缩放 : Vector2                       # 存储初始缩放值
var 当前提示框: Control = null
# 新增实例管理变量


func _ready() -> void:
	pass

func _init() -> void:
	原始缩放 = scale  # 初始化缩放记录
	# 连接信号
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)

# ================= 核心逻辑 =================
func 创建提示框() -> void:
	var ui容器 := get_tree().current_scene.find_child("布局渲染").find_child("UI提示框位置")# 获取UI容器
	if is_instance_valid(当前提示框):
		当前提示框.queue_free()
	# 创建并配置新提示框
	var 新提示框 := ui提示框.instantiate() as Control
	ui容器.add_child(新提示框)
	# 设置相对位置
	新提示框.global_position = self.get_global_transform_with_canvas().origin + 提示框偏移
	当前提示框 = 新提示框
	# 初始化内容
	if 新提示框.has_method("显示文字"):
		新提示框.显示文字(提示文本)

func 更新提示框位置() -> void:
	if is_instance_valid(当前提示框):
		var 新位置 := self.get_global_transform_with_canvas().origin + 提示框偏移
		当前提示框.global_position = 新位置




# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if is_instance_valid(当前提示框) and 当前提示框.is_visible_in_tree():
		更新提示框位置()
	if !快捷键.is_empty() and Input.is_action_just_pressed(快捷键):
		_on_pressed()
	


# ================= 信号处理 =================
func _on_mouse_entered() -> void:
	create_tween().tween_property(self, "scale", 原始缩放 * 悬停缩放, 0.2)
	创建提示框()    # 动态创建提示框




func _on_mouse_exited() -> void:
	print("鼠标离开信号连接成功。")
	create_tween().tween_property(self, "scale", 原始缩放, 0.2)
	if is_instance_valid(当前提示框):
		当前提示框.queue_free()
		当前提示框 = null


func _on_pressed() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_BOUNCE)# 点击动画
	tween.tween_property(self, "scale", 原始缩放 * 0.9, 0.1)
	tween.tween_property(self, "scale", 原始缩放, 0.2)
	执行操作()# 执行操作

func 执行操作() -> void:
	print("正在使用ui按钮。")
