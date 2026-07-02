@tool
extends Node2D

const FX_TEX := preload("res://AI资源库/特效库/秋叶飘落/fx.png")
const COLS := 5

@export var spawn_rect_half_extents: Vector2 = Vector2(40, 20):
	set(v):
		spawn_rect_half_extents = v
		queue_redraw()

@export_range(0.0, 120.0, 0.5) var petals_per_second: float = 6.0
@export_range(0.5, 30.0, 0.1) var petal_lifetime: float = 3.0
@export_range(0.0, 500.0, 1.0) var gravity: float = 15.0
@export var horizontal_speed_range: Vector2 = Vector2(-20, 20)
@export var vertical_speed_range: Vector2 = Vector2(0, 5)
@export_range(1.0, 30.0, 0.5) var animation_fps: float = 12.0
@export_range(0.25, 3.0, 0.05) var petal_scale_min: float = 0.3
@export_range(0.25, 3.0, 0.05) var petal_scale_max: float = 0.6
@export var petal_z_index: int = 4
@export_range(8, 400, 1) var max_simultaneous_petals: int = 64
@export var preview_in_editor: bool = true:
	set(v):
		preview_in_editor = v
		if not preview_in_editor:
			_clear_petals()
@export var draw_spawn_gizmo: bool = true:
	set(v):
		draw_spawn_gizmo = v
		queue_redraw()

var _sprite_frames: SpriteFrames
var _accum: float = 0.0


class FallingPetal extends Node2D:
	var _velocity: Vector2
	var _life: float
	var _gravity_p: float
	var _sprite: AnimatedSprite2D

	func configure(frames: SpriteFrames, vel: Vector2, lifetime: float, grav: float, z_idx: int, smin: float, smax: float) -> void:
		_velocity = vel
		_life = lifetime
		_gravity_p = grav
		z_as_relative = false
		z_index = z_idx
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.animation = &"default"
		_sprite.centered = true
		_sprite.speed_scale = randf_range(0.75, 1.2)
		var sc := randf_range(smin, smax)
		_sprite.scale = Vector2(sc, sc)
		rotation = randf_range(-0.55, 0.55)
		_sprite.play()
		add_child(_sprite)

	func _process(delta: float) -> void:
		_velocity.y += _gravity_p * delta
		position += _velocity * delta
		_life -= delta
		if _life <= 0.0:
			queue_free()


func _ready() -> void:
	_sprite_frames = _build_sprite_frames()
	queue_redraw()


func _build_sprite_frames() -> SpriteFrames:
	var tex: Texture2D = FX_TEX
	var fw: int = int(floor(float(tex.get_width()) / float(COLS)))
	var fh: int = tex.get_height()
	var sf := SpriteFrames.new()
	if not sf.has_animation(&"default"):
		sf.add_animation(&"default")
	sf.set_animation_loop(&"default", true)
	sf.set_animation_speed(&"default", animation_fps)
	for i in COLS:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(&"default", at)
	return sf


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	if petals_per_second <= 0.0:
		return
	_accum += petals_per_second * delta
	while _accum >= 1.0:
		_accum -= 1.0
		if get_child_count() >= max_simultaneous_petals:
			break
		_spawn_one()


func _spawn_one() -> void:
	var p := FallingPetal.new()
	p.position = Vector2(
		randf_range(-spawn_rect_half_extents.x, spawn_rect_half_extents.x),
		randf_range(-spawn_rect_half_extents.y, spawn_rect_half_extents.y)
	)
	p.configure(
		_sprite_frames,
		Vector2(
			randf_range(horizontal_speed_range.x, horizontal_speed_range.y),
			randf_range(vertical_speed_range.x, vertical_speed_range.y)
		),
		petal_lifetime,
		gravity,
		petal_z_index,
		petal_scale_min,
		petal_scale_max
	)
	add_child(p)


func _clear_petals() -> void:
	for c in get_children():
		if c is FallingPetal:
			(c as Node).queue_free()


func _draw() -> void:
	if not draw_spawn_gizmo:
		return
	if not Engine.is_editor_hint():
		return
	var r := Rect2(-spawn_rect_half_extents, spawn_rect_half_extents * 2.0)
	draw_rect(r, Color(1.0, 0.72, 0.35, 0.12), false, 1.0)
