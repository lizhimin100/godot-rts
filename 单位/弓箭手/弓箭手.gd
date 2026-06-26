class_name 弓箭手
extends 移动基类

## 弓箭手 — RTS 可控制远程单位
## 贴图请在场景中 Sprite2D > Texture 设置

enum State {
	IDLE,
	MOVE,
	ATTACK
}

@export var 攻击力: float = 15.0
@export var 攻击范围: float = 150.0

const 玩家纹理 := preload("res://小剑资源/兵种/Knights/Troops/Archer/Blue/Archer_Blue.png")
const 敌人纹理 := preload("res://小剑资源/兵种/Knights/Troops/Archer/Red/Archer_Red.png")

var 当前状态: State = State.IDLE

@onready var 选中标签: Label = $选中标签
@onready var 角色图像: Sprite2D = $角色图像
@onready var 角色动画: AnimationPlayer = $角色动画


func _ready() -> void:
	super._ready()
	当前状态 = State.IDLE

	# duplicate 材质 -> 每个单位独立描边
	var 新材质 = 角色图像.material.duplicate()
	角色图像.material = 新材质

	if _是敌人():
		角色图像.texture = 敌人纹理
		角色图像.material.set_shader_parameter("outline_color", Color(0.9, 0.2, 0.2, 1))
		if is_instance_valid(选中标签):
			选中标签.visible = false
		collision_mask = 32 + 8 + 4  # 环境+玩家单位+建筑层
	else:
		角色图像.texture = 玩家纹理
		选中标签.visible = false
		collision_mask = 32 + 16 + 4  # 环境+敌人单位+建筑层

	角色动画.play("待机")


func _physics_process(delta: float) -> void:
	if is_instance_valid(选中标签):
		选中标签.visible = 选择状态

	# 命令中断检测：当前命令已取消 → 强制回到 IDLE
	if 当前命令 == 命令类型.无 and 当前状态 != State.IDLE:
		velocity = velocity.move_toward(Vector2.ZERO, 加速度 * 10 * delta)
		切换状态(State.IDLE)
		move_and_slide()
		return

	match 当前状态:
		State.IDLE:
			_处理待机状态(delta)
		State.MOVE:
			_处理移动状态(delta)
		State.ATTACK:
			velocity = velocity.move_toward(Vector2.ZERO, 加速度 * 10 * delta)

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


# ============================================================
# 待机
# ============================================================

func _处理待机状态(delta: float) -> void:
	var 排斥力 := _计算排斥力()
	if 排斥力 != Vector2.ZERO:
		velocity = velocity.move_toward(排斥力, 加速度 * 10 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 加速度 * 10 * delta)

	# 有移动/攻击/巡逻命令 → 切换到移动
	if 当前命令 in [命令类型.移动, 命令类型.攻击, 命令类型.巡逻]:
		if 目标位置 != Vector2.ZERO:
			切换状态(State.MOVE)
			return

	# 驻守/待机时自动索敌
	if 当前命令 in [命令类型.驻守, 命令类型.无]:
		if not 攻击目标 or not is_instance_valid(攻击目标):
			var 附近敌 = _寻找最近的敌对目标(攻击范围)
			if 附近敌:
				攻击目标 = 附近敌
				目标位置 = 附近敌.global_position
				当前命令 = 命令类型.攻击
				切换状态(State.MOVE)


# ============================================================
# 移动
# ============================================================

func _处理移动状态(delta: float) -> void:
	if 攻击目标 and is_instance_valid(攻击目标):
		if global_position.distance_to(攻击目标.global_position) <= 攻击范围:
			执行攻击()
			return

	if 攻击目标 and is_instance_valid(攻击目标):
		目标位置 = 攻击目标.global_position

	if 当前命令 == 命令类型.巡逻 and _导航移动到(目标位置, delta):
		_下一个巡逻点()
		return

	if _导航移动到(目标位置, delta):
		match 当前命令:
			命令类型.攻击:
				if not 攻击目标 or not is_instance_valid(攻击目标):
					攻击目标 = _寻找最近的敌对目标(攻击范围)
					if 攻击目标:
						目标位置 = 攻击目标.global_position
						导航代理.target_position = 目标位置
						return
				当前命令 = 命令类型.无
				切换状态(State.IDLE)
			命令类型.巡逻:
				_下一个巡逻点()
			_:
				当前命令 = 命令类型.无
				切换状态(State.IDLE)
		return

	if 当前命令 == 命令类型.移动 and not 攻击目标:
		var 附近敌 = _寻找最近的敌对目标(攻击范围)
		if 附近敌:
			攻击目标 = 附近敌
			当前命令 = 命令类型.攻击


# ============================================================
# 攻击（远程）
# ============================================================

func 执行攻击() -> void:
	if 当前状态 == State.ATTACK or 当前生命值 <= 0:
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
	_进行伤害判定()

	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(self) or 当前状态 != State.ATTACK:
		return

	if 攻击目标 and is_instance_valid(攻击目标) and 攻击目标.当前生命值 > 0:
		if global_position.distance_to(攻击目标.global_position) > 攻击范围:
			# 目标超出范围 → 追击
			目标位置 = 攻击目标.global_position
			导航代理.target_position = 目标位置
			当前命令 = 命令类型.攻击
			切换状态(State.MOVE)
		else:
			# 目标仍在范围内 → 回到 IDLE 让自动索敌重新触发攻击
			# 避免递归调用 执行攻击() 导致状态机卡死在 ATTACK
			攻击目标 = null
			当前命令 = 命令类型.无
			切换状态(State.IDLE)
	else:
		攻击目标 = null
		当前命令 = 命令类型.无
		切换状态(State.IDLE)


func _进行伤害判定() -> void:
	if 攻击目标 and is_instance_valid(攻击目标) \
			and global_position.distance_to(攻击目标.global_position) <= 攻击范围 \
			and 攻击目标.当前生命值 > 0:
		攻击目标.受伤(攻击力, self)
		return

	var 目标 = _寻找最近的敌对目标(攻击范围)
	if 目标:
		目标.受伤(攻击力, self)
