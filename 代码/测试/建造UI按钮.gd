extends Control

signal 建造1
signal 建造2
signal 建造3

## 展开/收起状态
var _已展开 := false

@onready var 切换按钮: Button = $切换按钮
@onready var 面板: PanelContainer = $面板


func _ready() -> void:
	add_to_group("建造UI")
	面板.visible = false


func _on_切换按钮_pressed() -> void:
	_已展开 = not _已展开
	面板.visible = _已展开
	if _已展开:
		切换按钮.text = "📋 收起建造 ▼"
	else:
		切换按钮.text = "🏗️ 建造"


func 建造城堡() -> void:
	if not _已展开:
		return
	建造1.emit()
	_收起()


func 建造房子() -> void:
	if not _已展开:
		return
	建造2.emit()
	_收起()


func 建造防御塔() -> void:
	if not _已展开:
		return
	建造3.emit()
	_收起()


## 选择建筑后自动收起面板
func _收起() -> void:
	_已展开 = false
	面板.visible = false
	切换按钮.text = "🏗️ 建造"
