extends Sprite2D

## 瞬移残影 — 淡出自毁
## 由 农民 创建，自动播放淡出动画后释放

const FADE_DURATION: float = 0.3


func _ready() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.parallel().tween_property(self, "scale", scale * 1.5, FADE_DURATION)
	tween.tween_callback(queue_free)
