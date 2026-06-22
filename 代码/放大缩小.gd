extends Sprite2D

var 缩放倍数 : float = 2.0
var 使用镜片 : bool = false


func _ready() -> void:
	self.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if 使用镜片 :
		position = get_global_mouse_position()
	if Input.is_action_just_pressed("镜片放大"):
		缩放倍数 += 0.4
	elif Input.is_action_just_pressed("镜片缩小"):
		缩放倍数 -= 0.4
	
	缩放倍数 = clamp(缩放倍数 , 0.2 , 2.0)
	material.set_shader_parameter("scale_factor" , 缩放倍数)
	

func 点击按钮 () -> void :
	if not 使用镜片 :
		显示镜片()
		使用镜片 = true
	elif 使用镜片 :
		隐藏镜片()
		使用镜片 = false



func 显示镜片 () -> void :
	self.visible = true
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
	

func 隐藏镜片 () -> void :
	self.visible = false
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
