class_name 伤害框判定
extends Area2D

signal 伤害到谁(伤害对象)

func _init() -> void:
	area_entered.connect(伤害判定)

func 伤害判定 (伤害对象 : 受伤框判定 ) -> void :
	#print("[攻击对象]%s -> %s " % [owner.name , 伤害对象.owner.name] )  # DEBUG
	伤害到谁.emit(伤害对象)
	伤害对象.受到伤害.emit(self)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
