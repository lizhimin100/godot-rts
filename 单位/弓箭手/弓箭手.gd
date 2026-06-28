extends UnitBase
class_name 弓箭手

## 弓箭手 — RTS 可控制远程单位
## 3 状态状态机：IDLE / MOVE / ATTACK
## 移动使用流场控制器，远程射击带箭矢弹道

enum State {
	IDLE,
	MOVE,
	ATTACK
}

@export var 攻击力: float = 8.0
@export var 攻击范围: float = 150.0
@export var 攻击间隔: float = 0.8

const 玩家纹理: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Archer/Blue/Archer_Blue.png")
const 敌人纹理: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Archer/Red/Archer_Red.png")

var 当前状态: State = State.IDLE
var _攻击冷却: float = 0.0

const 箭矢场景: PackedScene = preload("res://单位/弓箭手/箭矢.tscn")

@onready var 选中标签: Label = $选中标签
@onready var 角色图像: Sprite2D = $角色图像
@onready var 角色动画: AnimationPlayer = $角色动画


func _ready() -> void:
	super._ready()
	当前状态 = State.IDLE

	var 新材质 = 角色图像.material.duplicate()
	角色图像.material = 新材质

	if _是敌人():
		角色图像.texture = 敌人纹理
		角色图像.material.set_shader_parameter("outline_color", Color(0.9, 0.2, 0.2, 1))
		if is_instance_valid(选中标签):
			选中标签.visible = false
		collision_mask = 32 + 8 + 4
	else:
		角色图像.texture = 玩家纹理
		选中标签.visible = false
		collision_mask = 32 + 16 + 4

	角色动画.play("待机")


func _physics_process(delta: float) -> void:
	if is_instance_valid(选中标签):
		选中标签.visible = 选择状态

	if _攻击冷却 > 0:
		_攻击冷却 -= delta

	_同步命令状态()

	match 当前状态:
		State.IDLE:
			_处理待机状态(delta)
		State.MOVE:
			_处理移动状态(delta)
		State.ATTACK:
			velocity = velocity.move_toward(Vector2.ZERO, 移动速度 * 12.0 * delta)

	# ⭐ 统一 move_and_slide（控制器只设 velocity）
	move_and_slide()

	if velocity.x != 0:
		角色图像.flip_h = velocity.x < 0


func 切换状态(to: State) -> void:
	if 当前状态 == to:
		return
	当前状态 = to
	match to:
		State.IDLE: _切换动画("待机")
		State.MOVE: _切换动画("移动")
		State.ATTACK: _切换动画("攻击")


func _切换动画(动画名: String) -> void:
	if 角色动画 and 角色动画.has_animation(动画名):
		角色动画.play(动画名)


func _同步命令状态() -> void:
	match 当前命令:
		命令类型.移动:
			if 当前状态 != State.MOVE:
				切换状态(State.MOVE)
		命令类型.攻击:
			if 攻击目标 and is_instance_valid(攻击目标):
				if 当前状态 != State.ATTACK and 当前状态 != State.MOVE:
					切换状态(State.MOVE)
				if 当前状态 == State.ATTACK:
					var 距离 = global_position.distance_to(攻击目标.global_position)
					if 距离 > 攻击范围:
						切换状态(State.MOVE)
			else:
				命令停止()
		命令类型.无, 命令类型.驻守, _:
			if 当前状态 != State.IDLE:
				攻击目标 = null
				切换状态(State.IDLE)


func _处理待机状态(delta: float) -> void:
	# 待机时排斥力
	var 排斥力: Vector2 = _计算排斥力()
	if 排斥力.length_squared() > 0.01:
		velocity = velocity.move_toward(排斥力, 移动速度 * 10.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 移动速度 * 10.0 * delta)

	if 当前命令 in [命令类型.移动, 命令类型.攻击, 命令类型.巡逻]:
		if 目标位置 != Vector2.ZERO:
			切换状态(State.MOVE)
		return

	if 当前命令 == 命令类型.驻守:
		return

	if 当前命令 == 命令类型.无:
		if not 攻击目标 or not is_instance_valid(攻击目标):
			var 附近敌 = _寻找最近的敌对目标(索敌范围)
			if 附近敌:
				攻击目标 = 附近敌
				目标位置 = 附近敌.global_position
				当前命令 = 命令类型.攻击
				_是自动索敌攻击 = true
				_追击起始位置 = global_position
				切换状态(State.MOVE)


func _处理移动状态(delta: float) -> void:
	var 所有单位: Array = get_tree().get_nodes_in_group("移动单位")
	# 追击限距检测
	if _是自动索敌攻击 and _追击起始位置 != Vector2.ZERO:
		var 追击距离 = global_position.distance_to(_追击起始位置)
		if 追击距离 > 追击上限距离:
			攻击目标 = null
			_是自动索敌攻击 = false
			_追击起始位置 = Vector2.ZERO
			if _原始目标位置 != Vector2.ZERO:
				目标位置 = _原始目标位置
				当前命令 = 命令类型.移动
				_是攻击移动 = true
				切换状态(State.MOVE)
			else:
				命令停止()
			return

	# 进入攻击范围
	if 攻击目标 and is_instance_valid(攻击目标):
		if global_position.distance_to(攻击目标.global_position) <= 攻击范围:
			执行攻击()
			return

	# 追击中更新目标
	if 攻击目标 and is_instance_valid(攻击目标):
		目标位置 = 攻击目标.global_position

	# ⭐ 使用新移动控制器（流场+避障+卡死检测+速度lerp）
	if 当前命令 == 命令类型.巡逻:
		所有单位 = get_tree().get_nodes_in_group("移动单位")
		FFManager.update_target(目标位置, 所有单位)
		var 到达: bool = unit_controller.move_toward(目标位置, delta, FFManager.get_flow_field(), 所有单位)
		if 到达:
			_下一个巡逻点()
		return

	FFManager.update_target(目标位置, 所有单位)
	var 到达: bool = unit_controller.move_toward(目标位置, delta, FFManager.get_flow_field(), 所有单位)
	if 到达:
		match 当前命令:
			命令类型.攻击:
				if not 攻击目标 or not is_instance_valid(攻击目标):
					if _原始目标位置 != Vector2.ZERO:
						目标位置 = _原始目标位置
						当前命令 = 命令类型.移动
						_是攻击移动 = true
						_是自动索敌攻击 = false
						切换状态(State.MOVE)
						return
					攻击目标 = _寻找最近的敌对目标(攻击范围)
					if 攻击目标:
						目标位置 = 攻击目标.global_position
					return
				命令停止()
			命令类型.巡逻:
				_下一个巡逻点()
			_:
				命令停止()
		return

	# 移动中自动索敌（A-move）
	if 当前命令 == 命令类型.移动 and _是攻击移动 and not 攻击目标:
		var 附近敌 = _寻找最近的敌对目标(索敌范围)
		if 附近敌:
			攻击目标 = 附近敌
			当前命令 = 命令类型.攻击
			_是自动索敌攻击 = true
			_追击起始位置 = global_position


func 执行攻击() -> void:
	if 当前状态 == State.ATTACK or 当前生命值 <= 0:
		return
	if _攻击冷却 > 0:
		return
	if not 攻击目标 or not is_instance_valid(攻击目标):
		攻击目标 = _寻找最近的敌对目标(攻击范围)
		if not 攻击目标:
			return

	目标位置 = global_position
	切换状态(State.ATTACK)

	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self) or 当前状态 != State.ATTACK:
		return

	if 攻击目标 and is_instance_valid(攻击目标):
		角色图像.flip_h = 攻击目标.global_position.x < global_position.x

	if 攻击目标 and is_instance_valid(攻击目标) and 攻击目标.当前生命值 > 0:
		var 箭 = 箭矢场景.instantiate()
		箭.global_position = global_position + Vector2(20 if not 角色图像.flip_h else -20, -10)
		箭.目标 = 攻击目标
		箭.伤害 = 攻击力
		箭.攻击者 = self
		get_parent().add_child(箭)

	_攻击冷却 = 攻击间隔

	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(self) or 当前状态 != State.ATTACK:
		return

	if 攻击目标 and is_instance_valid(攻击目标) and 攻击目标.当前生命值 > 0:
		if global_position.distance_to(攻击目标.global_position) > 攻击范围:
			目标位置 = 攻击目标.global_position
			当前命令 = 命令类型.攻击
			切换状态(State.MOVE)
		else:
			if _原始目标位置 != Vector2.ZERO:
				攻击目标 = null
				_是自动索敌攻击 = false
				目标位置 = _原始目标位置
				当前命令 = 命令类型.移动
				_是攻击移动 = true
				切换状态(State.MOVE)
			else:
				攻击目标 = null
				_是自动索敌攻击 = false
				命令停止()
	else:
		if _原始目标位置 != Vector2.ZERO:
			攻击目标 = null
			_是自动索敌攻击 = false
			目标位置 = _原始目标位置
			当前命令 = 命令类型.移动
			_是攻击移动 = true
			切换状态(State.MOVE)
		else:
			攻击目标 = null
			_是自动索敌攻击 = false
			命令停止()
