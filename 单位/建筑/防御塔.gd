class_name 防御塔
extends 建筑基类

## 防御塔 — 自动攻击范围内敌人
## 尚未实现塔攻击逻辑，仅为基础建筑占位

func _ready() -> void:
	super._ready()
	建筑名称 = "防御塔"
	最大生命值 = 800.0
	当前生命值 = 最大生命值
