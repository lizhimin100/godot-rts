class_name DeathHandler
extends Node

## 死亡处理器 — 监听 HealthComponent.died 信号
##
## 工作流程：
##   1. HealthComponent.died 信号触发
##   2. 禁用碰撞和逻辑
##   3. 在单位位置实例化死亡动画场景（death_effect.tscn）
##   4. 无死亡场景时回退简单淡出
##   5. 动画完成后释放单位节点

signal death_finished

## AnimationPlayer 节点路径（为空则自动查找子节点）
@export var animation_player_path: NodePath = NodePath()
## 死亡动画名称（在 AnimationPlayer 中）
@export var death_animation: String = "死亡"

## 死亡特效场景（实例化在单位位置播放帧动画）
const DEATH_SCENE: PackedScene = preload("res://combat/effects/death_effect.tscn")

var _health: HealthComponent = null
var _anim_player: AnimationPlayer = null
var _playing: bool = false


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
		# 方案B：实例化死亡特效场景
		var played: bool = await _play_death_scene(target)
		if not played:
			# 方案C：回退淡出
			if target is CanvasItem:
				var tween: Tween = create_tween()
				tween.tween_property(target, "modulate:a", 0.0, 0.5)
				await tween.finished

	death_finished.emit()

	if is_instance_valid(target):
		target.queue_free()


## 实例化死亡特效场景在单位位置播放
## 返回 true 表示成功播放
func _play_death_scene(target: Node) -> bool:
	if not target or not is_instance_valid(target):
		return false
	if not DEATH_SCENE:
		return false
	if not target is Node2D:
		return false

	var target2d: Node2D = target as Node2D
	var death: Node2D = DEATH_SCENE.instantiate()
	death.global_position = target2d.global_position
	death.z_index = target2d.z_index + 1
	target2d.get_parent().add_child(death)

	# 等待动画完成（死亡特效自动 queue_free）
	await death.tree_exited
	return true


func _get_target_node() -> Node:
	return get_parent()


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
