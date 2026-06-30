extends Node2D

## 施工场地 — 建造中的建筑
##
## 子节点：Sprite（半透明建筑图）+ StaticBody2D（碰撞阻挡）
## 进度条由单独的 build_countdown_ui.tscn 管理（农民.gd 负责实例化）
## 职责仅限：显示施工纹理、阻挡通行

@onready var sprite: Sprite2D = $Sprite
@onready var blocker: StaticBody2D = $Blocker


func set_building_texture(tex: Texture2D) -> void:
	if not sprite:
		sprite = $Sprite
	if not sprite:
		return
	sprite.texture = tex
	sprite.modulate = Color(1, 1, 1, 0.3)


func set_blocker_size(size: Vector2) -> void:
	if not blocker:
		blocker = $Blocker
	if not blocker:
		return
	var shape: RectangleShape2D = blocker.get_node("CollisionShape2D").shape as RectangleShape2D
	if shape:
		shape.size = size
