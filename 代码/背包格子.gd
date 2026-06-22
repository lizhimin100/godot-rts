extends Control

@export var item : 物品 :
	set(v):
		item = v
		$"物品图像".texture = item.物品图片

@onready var 物品图像: TextureRect = $物品图像
@onready var 显示数量 : Label = $"显示格子物品数量"



func 格子显示 (格子物品 : 物品) :
	if 格子物品 != null :
		物品图像 .texture = 格子物品.物品图片
		if 格子物品.是否可数 :
			显示数量.text = str(格子物品.数量)
		else : 
			显示数量.text = ""
	else :
		物品图像 .texture = null
		显示数量.text = ""


func _on_mouse_entered() -> void:
	if item != null :
		owner.set_JS(item)
