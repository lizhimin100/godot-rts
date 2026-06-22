extends Node2D

@onready var 物品图像 : Sprite2D = $Sprite2D
@onready var 显示数量 : Label = $"显示鼠标物品数量"



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
