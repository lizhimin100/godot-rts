extends Node
## 运行时挂到 NPC 根节点下：W A S D 控制父节点移动，并切换 RPG Maker 四向跑动画（runup / rundown / runleft / runright）。

@export var move_speed: float = 140.0

var _asp: AnimatedSprite2D


func _ready() -> void:
	_asp = _find_animated_sprite(get_parent())


func _find_animated_sprite(root: Node) -> AnimatedSprite2D:
	if root == null:
		return null
	var n := root.find_child("AnimatedSprite2D", true, false)
	return n as AnimatedSprite2D


func _physics_process(delta: float) -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1
	if dir.length_squared() > 0.0001:
		dir = dir.normalized()
		parent.global_position += dir * move_speed * delta
		_play_run_for_direction(dir)
	else:
		if _asp != null:
			_asp.stop()


func _play_run_for_direction(dir: Vector2) -> void:
	if _asp == null or _asp.sprite_frames == null:
		return
	var anim := ""
	if absf(dir.x) >= absf(dir.y):
		anim = "runright" if dir.x > 0.0 else "runleft"
	else:
		anim = "rundown" if dir.y > 0.0 else "runup"
	if not _asp.sprite_frames.has_animation(anim):
		return
	if String(_asp.animation) != anim:
		_asp.animation = anim
	if not _asp.is_playing():
		_asp.play()
