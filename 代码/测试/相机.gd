extends Camera2D

const 滚动边距 : int = 5  # 触发边缘滚动的像素距离
const 滚动速度 : float = 550.0  # 相机移动速度
@export var 移动边距 : int = 50            # 屏幕边缘触发滚动的像素距离
@export var 移动速度 : float = 500.0       # 基础移动速度
@export var 最大范围 : Rect2 = Rect2(0, 0, 4096, 4098)  # 相机移动边界
@export var 最小缩放 : float = 0.75         # 滚轮最小缩放级别
@export var 最大缩放 : float = 3.0         # 滚轮最大缩放级别
@export var 缩放速度 : float = 0.1         # 滚轮缩放灵敏度

var 目标缩放 : float = 1.0                 # 当前缩放目标值
var 允许移动 : bool = true  



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if  not 允许移动:
		return  # 对话期间锁定相机
	var 鼠标位置 = get_viewport().get_mouse_position()# 获取鼠标位置 基础边缘滚动逻辑
	var 视口尺寸 = get_viewport_rect().size  # 获取视口尺寸
	var 移动向量 = Vector2.ZERO
	
	# 边缘滚动检测（使用if-else逻辑链）
	if 鼠标位置.x < 移动边距:
		移动向量.x -= 1
	elif 鼠标位置.x > 视口尺寸.x - 移动边距:
		移动向量.x += 1
	if 鼠标位置.y < 移动边距:
		移动向量.y -= 1
	elif 鼠标位置.y > 视口尺寸.y - 移动边距:
		移动向量.y += 1
	position += 移动向量.normalized() * 移动速度 * delta * zoom.x# 应用移动（考虑缩放对速度的影响）
	
	# 限制移动范围
	position.x = clamp(position.x, 最大范围.position.x, 最大范围.end.x)
	position.y = clamp(position.y, 最大范围.position.y, 最大范围.end.y)
	
	# 平滑缩放过渡
	zoom = zoom.lerp(Vector2(目标缩放, 目标缩放), delta * 10)

func _input(event: InputEvent) -> void:  # 输入处理 
	# 鼠标滚轮缩放控制
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			目标缩放 = clamp(目标缩放 + 缩放速度, 最小缩放, 最大缩放)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			目标缩放 = clamp(目标缩放 - 缩放速度, 最小缩放, 最大缩放)

# 该函数用于将相机聚焦到指定的对话位置，并进行缩放. 目标位置: 相机要聚焦到的位置，类型为 Vector2. 目标缩放级别: 相机要缩放到的级别，默认为 0.8
func 聚焦对话位置(目标位置: Vector2, 目标缩放级别: float = 1.35) -> void: #  对话相关控制，要在其他角色脚本里要在其他角色脚本里传入角色当前位置
	#print("当前相机锁定状态：", 允许移动)  # 因为允许移动+false在下面，所以值为true，此处是表示相机被锁定  # DEBUG
	var 过渡时间 = 0.75
	# 使用Tween实现平滑过渡,Tween 是 Godot 引擎中用于实现平滑过渡效果的工具
	var tween = create_tween().set_parallel(true)# set_parallel(true) 表示让所有的过渡动画并行执行
	# 使用 tween_property 方法将相机的位置从当前位置平滑过渡到目标位置
	# 第一个参数是要过渡的对象，这里是 self 表示当前相机节点
	# 第二个参数是要过渡的属性，这里是 "position" 表示位置属性
	# 第三个参数是目标值，即目标位置
	# 第四个参数是过渡时间
	tween.tween_property(self, "position", 目标位置, 过渡时间)
	tween.tween_property(self, "zoom", Vector2(目标缩放级别, 目标缩放级别), 过渡时间)
	允许移动 = false  # 锁定相机控制

func 重置相机() -> void:#
	#print("当前相机锁定状态：", 允许移动)  #因为在聚焦对话位置设置了允许移动+false，所以值为false，表示相机不再被锁定  # DEBUG
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "zoom", Vector2(目标缩放, 目标缩放), 0.5)
	允许移动 = true   # 恢复相机控制
