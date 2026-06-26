extends Node2D

## 集结点标记 — 一个简单的绿色小旗子

func _draw() -> void:
	# 底座：小绿点
	draw_circle(Vector2.ZERO, 3.0, Color(0.2, 1.0, 0.2, 0.6))
	# 旗杆：竖线
	draw_line(Vector2(0, 0), Vector2(0, -12), Color(0.2, 1.0, 0.2, 0.8), 1.5)
	# 旗面：小三角
	var 三角 := PackedVector2Array([
		Vector2(0, -12),
		Vector2(10, -9),
		Vector2(0, -6),
	])
	draw_colored_polygon(三角, Color(0.2, 1.0, 0.2, 0.7))
