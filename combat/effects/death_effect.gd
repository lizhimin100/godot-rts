extends Node2D

## 死亡特效 — 结构类似弓箭手（Sprite + AnimationPlayer）
## AnimationPlayer 已在场景中预设好 "death" 动画
## 代码只负责触发动画，播放完毕后自毁

@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	anim.play("死亡")
	await anim.animation_finished
	queue_free()
