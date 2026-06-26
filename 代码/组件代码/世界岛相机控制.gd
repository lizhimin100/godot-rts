class_name 世界岛相机控制 extends Camera2D

## 是否启用镜头控制（营地打开时禁用）
var 控制启用 := true : set = set_控制启用

@export var 边缘滚动边距 : int = 15
@export var 滚动速度 : float = 800.0
@export var 加速度 : float = 12.0
@export var 最小缩放 : float = 0.5
@export var 最大缩放 : float = 2.0
@export var 缩放速度 : float = 0.1

var 目标缩放 : float = 1.0
var 速度向量 := Vector2.ZERO
var 鼠标中键按下 := false
var 中键拖拽起点 := Vector2.ZERO
var 中键相机起点 := Vector2.ZERO

# ========== 屏幕震动 ==========
var 震屏偏移 := Vector2.ZERO
var 震屏强度 := 0.0
var 震屏持续时间 := 0.0
var 震屏计时 := 0.0

func _ready() -> void:
	目标缩放 = zoom.x
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0

func set_控制启用(val: bool) -> void:
	控制启用 = val
	速度向量 = Vector2.ZERO

func _process(delta: float) -> void:
	# ===== 屏幕震动更新 =====
	if 震屏计时 > 0:
		震屏计时 -= delta
		震屏偏移 = Vector2(
			randf_range(-震屏强度, 震屏强度),
			randf_range(-震屏强度, 震屏强度)
		) * (震屏计时 / 震屏持续时间)
		if 震屏计时 <= 0:
			震屏偏移 = Vector2.ZERO
			震屏强度 = 0.0
	else:
		震屏偏移 = Vector2.ZERO

	if not 控制启用:
		return

	# 键盘移动 (WASD / 方向键)
	var 输入向量 := Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		输入向量.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		输入向量.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		输入向量.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		输入向量.x += 1

	# 边缘滚动
	var 鼠标位置 := get_viewport().get_mouse_position()
	var 视口尺寸 := get_viewport_rect().size
	if 鼠标位置.x < 边缘滚动边距:
		输入向量.x -= 1
	elif 鼠标位置.x > 视口尺寸.x - 边缘滚动边距:
		输入向量.x += 1
	if 鼠标位置.y < 边缘滚动边距:
		输入向量.y -= 1
	elif 鼠标位置.y > 视口尺寸.y - 边缘滚动边距:
		输入向量.y += 1

	# 带加速度的平滑移动
	if 输入向量 != Vector2.ZERO:
		速度向量 = 速度向量.move_toward(输入向量.normalized() * 滚动速度, 加速度 * 滚动速度 * delta)
	else:
		速度向量 = 速度向量.move_toward(Vector2.ZERO, 加速度 * 滚动速度 * delta * 2)

	if 速度向量.length() > 1.0:
		position += 速度向量 * delta

	# 鼠标中键拖拽
	if 鼠标中键按下:
		position = 中键相机起点 - (get_viewport().get_mouse_position() - 中键拖拽起点) / zoom.x

	# 平滑缩放
	zoom = zoom.lerp(Vector2(目标缩放, 目标缩放), delta * 10)

	# 保持相机限制
	if limit_left != 0 or limit_top != 0 or limit_right != 0 or limit_bottom != 0:
		position.x = clamp(position.x, limit_left, limit_right)
		position.y = clamp(position.y, limit_top, limit_bottom)

	# 应用震屏偏移（override）
	if 震屏偏移 != Vector2.ZERO:
		offset = 震屏偏移

## 触发屏幕震动
func 震屏(强度: float = 8.0, 持续时间: float = 0.3) -> void:
	震屏强度 = 强度
	震屏持续时间 = 持续时间
	震屏计时 = 持续时间

func _unhandled_input(event: InputEvent) -> void:
	if not 控制启用:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			目标缩放 = clamp(目标缩放 + 缩放速度, 最小缩放, 最大缩放)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			目标缩放 = clamp(目标缩放 - 缩放速度, 最小缩放, 最大缩放)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				鼠标中键按下 = true
				中键拖拽起点 = get_viewport().get_mouse_position()
				中键相机起点 = position
			else:
				鼠标中键按下 = false
