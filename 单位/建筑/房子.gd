class_name 房子
extends 建筑基类

## 房子 — 提供人口上限
## 尚未实现人口系统，仅为基础建筑占位

func _ready() -> void:
	super._ready()
	建筑名称 = "房子"
	最大生命值 = 300.0
	当前生命值 = 最大生命值
