extends Control

signal 建造1
signal 建造2
signal 建造3



func 建造城堡() -> void:
	建造1.emit()



func 建造房子() -> void:
	建造2.emit()


func 建造防御塔() -> void:
	建造3.emit()
