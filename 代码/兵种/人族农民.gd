extends UnitBase
class_name 人族农民

## 人族农民 — RTS 基础单位
## 4 状态状态机：IDLE / CHASE / MOVE / ATTACK

enum State {
	IDLE,
	CHASE,
	MOVE,
	ATTACK
}

@export_group("战斗属性")
@export var 警戒范围: float = 300.0
@export var 攻击范围: float = 10.0
@export var 攻击间隔: float = 1.0
@export var 攻击伤害: float = 5.0

var 当前状态: State = State.IDLE
var _攻击冷却: float = 0.0
var _附近敌人: Node2D = null

@onready var 选中标签: Label = $选中标签
@onready var 索敌区域: Area2D = $索敌区域
@onready var 角色图像: Sprite2D = $角色图像
@onready var 角色动画: AnimationPlayer = $角色动画


func _ready() -> void:
	super._ready()
	当前状态 = State.IDLE
	选中标签.visible = false
	var 碰撞形状 = CircleShape2D.new()
	碰撞形状.radius = 警戒范围
	索敌区域.get_node("CollisionShape2D").shape = 碰撞形状
	索敌区域.body_entered.connect(_on_索敌区域_进入)
	索敌区域.body_exited.connect(_on_索敌区域_离开)


func _physics_process(delta: float) -> void:
	选中标签.visible = 选择状态

	if _攻击冷却 > 0:
		_攻击冷却 -= delta

	_同步命令状态()

	match 当前状态:
		State.IDLE:
			_处理待机状态(delta)
		State.CHASE:
			_处理追敌状态(delta)
		State.MOVE:
			_处理移动状态(delta)
		State.ATTACK:
			_处理攻击状态(delta)

	# ⭐ 统一 move_and_slide
	move_and_slide()

	if velocity.x != 0:
		角色图像.flip_h = velocity.x < 0


func _同步命令状态() -> void:
	match 当前命令:
		命令类型.移动:
			if 当前状态 != State.MOVE:
				_附近敌人 = null
				切换状态(当前状态, State.MOVE)
		命令类型.攻击:
			if 攻击目标 and is_instance_valid(攻击目标):
				if 当前状态 != State.CHASE and 当前状态 != State.ATTACK:
					切换状态(当前状态, State.CHASE)
			else:
				命令停止()
		命令类型.无, 命令类型.驻守, _:
			if 当前状态 != State.IDLE:
				_附近敌人 = null
				切换状态(当前状态, State.IDLE)


func 切换状态(from: State, to: State) -> void:
	match from:
		State.CHASE, State.ATTACK:
			pass
	match to:
		State.IDLE: 角色动画.play("待机")
		State.CHASE: 角色动画.play("移动")
		State.MOVE: 角色动画.play("移动")
		State.ATTACK: 角色动画.play("攻击")
	当前状态 = to


func _处理待机状态(delta: float):
	if not _附近敌人 or not is_instance_valid(_附近敌人):
		_附近敌人 = _寻找最近的敌对目标(警戒范围)
	if _附近敌人:
		命令攻击(_附近敌人)
		return
	var 排斥力: Vector2 = _计算排斥力()
	if 排斥力 != Vector2.ZERO:
		velocity = velocity.move_toward(排斥力, 加速度 * 10 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 加速度 * 10 * delta)


func _处理追敌状态(delta: float):
	if not 攻击目标 or not is_instance_valid(攻击目标):
		_附近敌人 = null
		命令停止()
		return

	var 距离 = global_position.distance_to(攻击目标.global_position)
	if 距离 <= 攻击范围:
		velocity = Vector2.ZERO
		切换状态(State.CHASE, State.ATTACK)
		return

	# 直接向敌人移动（农民用简单追敌）
	var 敌人方向 = (攻击目标.global_position - global_position).normalized()
	velocity = 敌人方向 * 移动速度
	var 总避障力: Vector2 = _计算总避障力(敌人方向)
	if 总避障力 != Vector2.ZERO:
		velocity += 总避障力
	velocity = velocity.limit_length(最大速度)


func _处理移动状态(delta: float):
	# ⭐ 使用新移动控制器
	var 所有单位: Array = get_tree().get_nodes_in_group("移动单位")
	FFManager.update_target(目标位置, 所有单位)
	var 到达: bool = unit_controller.move_toward(目标位置, delta, FFManager.get_flow_field(), 所有单位)
	if 到达:
		velocity = Vector2.ZERO
		命令停止()


func _处理攻击状态(delta: float):
	if not 攻击目标 or not is_instance_valid(攻击目标):
		_附近敌人 = null
		命令停止()
		return

	var 距离 = global_position.distance_to(攻击目标.global_position)
	if 距离 > 攻击范围:
		切换状态(State.ATTACK, State.CHASE)
		return

	角色图像.flip_h = 攻击目标.global_position.x < global_position.x

	velocity = Vector2.ZERO
	if _攻击冷却 <= 0:
		角色动画.play("攻击")
		if 攻击目标.has_method("受伤"):
			攻击目标.受伤(攻击伤害, self)
		_攻击冷却 = 攻击间隔


func _切换动画(动画名: String) -> void:
	角色动画.play(动画名)


func _on_索敌区域_进入(body: Node2D):
	if body.is_in_group("敌人") and not _附近敌人:
		_附近敌人 = body


func _on_索敌区域_离开(body: Node2D):
	if body == _附近敌人:
		_附近敌人 = null
