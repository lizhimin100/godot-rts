extends Control



@export var 物品悬停介绍 :NinePatchRect
@export var 悬停 : bool = false

@onready var ui动画: AnimationPlayer = $UI动画
@onready var 菜单: NinePatchRect = $菜单
@onready var 背包栏: NinePatchRect = $背包栏

func _ready() -> void:
	_player_UI("logo1")
	$"菜单/横向/开始按钮".grab_focus()

#播放动画的接口
func _player_UI(str : String) -> void:
	ui动画.play(str)

#跳过动画
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("走") or event.is_action_pressed("UI确认"):
		if ui动画.is_playing():#是否还有动画播放
			var anim_length = ui动画.current_animation_length
			ui动画.seek(anim_length)



func set_JS(item : 物品):
	物品悬停介绍.find_child("名字").text = item.物品名字
	物品悬停介绍.find_child("图片").texture = item.物品图片
	物品悬停介绍.find_child("介绍").text = item.物品描述
	
func _on_开始按钮_pressed() -> void:
	#创建计时器，等待0.5秒后再跳转场景
	var 等待时间 :float = (0.75)
	var timer = get_tree().create_timer(等待时间)
	await timer.timeout
	get_tree().change_scene_to_file("res://场景/战斗场景.tscn")


func _on_选择按钮_pressed() -> void:
	var 选择按键 = ResourceLoader.load("res://UI/ui界面.tscn")
	var 选择 = 选择按键.instantiate()
	get_tree().current_scene.add_child(选择)


func _on_退出按钮_pressed() -> void:
	get_tree().quit()


func _on_菜单按钮_pressed() -> void:
	if 菜单.visible == true and self.visible == true:
		ui动画.play("隐藏菜单")
	elif 菜单.visible != true:
		ui动画.play("唤出菜单")
	背包栏.visible = false
	self.visible = true


func _on_背包按钮_pressed() -> void:
	菜单.visible = false
	self.visible = true
	if 背包栏.visible == true:
		ui动画.play("隐藏背包")
	elif 背包栏.visible != true:
		ui动画.play("唤出背包")
