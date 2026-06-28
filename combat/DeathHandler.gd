class_name DeathHandler
extends Node

## 死亡处理器 — 监听 HealthComponent.died 信号
##
## 工作流程：
##   1. HealthComponent.died 信号触发
##   2. 禁用碰撞和逻辑
##   3. 尝试播放 AnimationPlayer 的死亡动画
##   4. 无动画时使用 Dead.png 精灵帧动画（适用于 CharacterBody2D 单位的角色图像）
##   5. 无精灵时回退简单淡出
##   6. 动画完成后释放节点

signal death_finished

## AnimationPlayer 节点路径（为空则自动查找子节点）
@export var animation_player_path: NodePath = NodePath()
## 死亡动画名称（在 AnimationPlayer 中）
@export var death_animation: String = "死亡"

## Dead.png 死亡精灵配置 — 仅在无 AnimationPlayer 动画时使用
const DEAD_TEXTURE: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Dead/Dead.png")
## Dead.png 精灵水平帧数（图片总宽 896，每帧 128px）
const DEAD_HFRAMES: int = 7
## 每帧持续时间（秒）
const FRAME_DURATION: float = 0.1

var _health: HealthComponent = null
var _anim_player: AnimationPlayer = null
var _playing: bool = false
## 用于存储原角色图像状态以便恢复（如果死亡被取消）
var _saved_sprite_state: Dictionary = {}


func _ready() -> void:
	_health = _find_health()
	if _health:
		_health.died.connect(_on_died)

	if animation_player_path.is_empty():
		_anim_player = _find_anim_player()
	else:
		_anim_player = get_node_or_null(animation_player_path) as AnimationPlayer


func _on_died(_attacker) -> void:
	if _playing:
		return
	_playing = true

	var target: Node = _get_target_node()
	if not target or not is_instance_valid(target):
		return

	# 禁用碰撞和逻辑
	target.set_process(false)
	target.set_physics_process(false)
	if target is CollisionObject2D:
		target.collision_layer = 0
		target.collision_mask = 0

	# 播放死亡动画
	if _anim_player and _anim_player.has_animation(death_animation):
		# 方案A：使用 AnimationPlayer 预设动画
		_anim_player.play(death_animation)
		await _anim_player.animation_finished
	else:
		# 方案B：查找角色图像 Sprite2D，尝试播放 Dead.png 精灵动画
		var sprite: Sprite2D = _find_sprite(target)
		var played: bool = false
		if sprite:
			played = await _play_dead_sprite_animation(sprite)
		if not played:
			# 方案C：回退淡出
			if target is CanvasItem:
				var tween: Tween = create_tween()
				tween.tween_property(target, "modulate:a", 0.0, 0.5)
				await tween.finished

	death_finished.emit()

	if is_instance_valid(target):
		target.queue_free()


## 使用 Dead.png 播放帧动画
## 返回 true 表示动画成功播放
func _play_dead_sprite_animation(sprite: Sprite2D) -> bool:
	if not sprite or not is_instance_valid(sprite):
		return false

	# 保存当前状态（以便后续可能的还原）
	_saved_sprite_state = {
		"texture": sprite.texture,
		"hframes": sprite.hframes,
		"vframes": sprite.vframes,
		"region_enabled": sprite.region_enabled,
		"region_rect": sprite.region_rect,
	}

	# 设置 Dead.png 纹理
	sprite.texture = DEAD_TEXTURE
	sprite.region_enabled = true
	# 单帧宽 128，高度用满 256
	sprite.region_rect = Rect2(0, 0, 128, 256)
	sprite.hframes = DEAD_HFRAMES
	sprite.vframes = 1
	sprite.frame = 0
	sprite.centered = true

	# 遍历所有帧
	for i in range(DEAD_HFRAMES):
		if not is_instance_valid(sprite):
			return true
		sprite.frame = i
		await get_tree().create_timer(FRAME_DURATION).timeout

	return true


func _get_target_node() -> Node:
	return get_parent()


## 查找名为"角色图像"的 Sprite2D
func _find_sprite(target: Node) -> Sprite2D:
	# 优先查找名为"角色图像"的 Sprite2D
	for child in target.get_children():
		if child is Sprite2D and child.name == "角色图像":
			return child
	# 查找任意 Sprite2D（排除已摧毁图像等特殊用途的）
	for child in target.get_children():
		if child is Sprite2D and child.name != "已摧毁图像":
			return child
	return null


func _find_health() -> HealthComponent:
	var parent: Node = get_parent()
	if not parent:
		return null
	for child in parent.get_children():
		if child is HealthComponent:
			return child
	return null


func _find_anim_player() -> AnimationPlayer:
	var parent: Node = get_parent()
	if not parent:
		return null
	for child in parent.get_children():
		if child is AnimationPlayer:
			return child
	return null
