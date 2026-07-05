extends CharacterBody2D
class_name 主角控制器

var 选择状态 := false :
	set(val):
		选择状态 = val
		if 选中标签:
			选中标签.visible = val

@export var 移动速度: float = 450.0
var 目标位置 := Vector2.ZERO
var 正在移动 := false

@onready var 角色图像: Sprite2D = $角色图像
@onready var 角色动画: AnimationPlayer = $角色动画
@onready var 选中标签: Label = $选中标签


func _ready() -> void:
	add_to_group("可选单位")
	选中标签.visible = false
	角色动画.play("待机")


func _input(event: InputEvent) -> void:
	if not 选择状态:
		return
	if event.is_action_pressed("移动"):
		var 鼠标位置 := get_global_mouse_position()
		命令移动(鼠标位置)


## 公开方法 - 操作UI调用
func 命令移动(位置: Vector2) -> void:
	目标位置 = 位置
	正在移动 = true
	if 角色动画.current_animation != "移动":
		角色动画.play("移动")


func 命令停止() -> void:
	正在移动 = false
	velocity = Vector2.ZERO  # ★ LEGACY VELOCITY
	目标位置 = global_position
	if 角色动画.current_animation != "待机":
		角色动画.play("待机")


func 命令驻守() -> void:
	命令停止()


func _physics_process(delta: float) -> void:
	选中标签.visible = 选择状态

	if 正在移动:
		var 剩余距离 := global_position.distance_to(目标位置)
		if 剩余距离 <= 16.0:
			命令停止()
			return

		var 方向 := (目标位置 - global_position).normalized()
		velocity = 方向 * 移动速度  # ★ LEGACY VELOCITY
		move_and_slide()

		角色图像.flip_h = velocity.x < 0
	else:
		# 减速停止
		if velocity.length() > 0.5:
			velocity = velocity.move_toward(Vector2.ZERO, 3000.0 * delta)  # ★ LEGACY VELOCITY
			move_and_slide()
