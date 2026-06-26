class_name 农民
extends 移动基类

## 农民 — RTS 基础生产单位
## 可建造建筑、采集资源

enum State {
	IDLE,
	MOVE,
	BUILD  # 建造中
}

@export var 攻击力: float = 5.0
@export var 攻击范围: float = 25.0

const 玩家纹理 := preload("res://小剑资源/兵种/Knights/Troops/Pawn/Blue/Pawn_Blue.png")
const 敌人纹理 := preload("res://小剑资源/兵种/Knights/Troops/Pawn/Red/Pawn_Red.png")

var 当前状态: State = State.IDLE
var _建造目标: Node2D = null

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
		collision_mask = 32 + 8 + 4  # 环境+玩家单位+建筑层
	else:
		角色图像.texture = 玩家纹理
		collision_mask = 32 + 16 + 4  # 环境+敌人单位+建筑层

	选中标签.visible = false
	if 角色动画.has_animation("待机"):
		角色动画.play("待机")


func _physics_process(delta: float) -> void:
	if is_instance_valid(选中标签):
		选中标签.visible = 选择状态

	match 当前状态:
		State.IDLE:
			_处理待机状态(delta)
		State.MOVE:
			_处理移动状态(delta)
		State.BUILD:
			velocity = velocity.move_toward(Vector2.ZERO, 加速度 * 10 * delta)

	move_and_slide()
	if velocity.x != 0:
		角色图像.flip_h = velocity.x < 0


func 切换状态(to: State) -> void:
	if 当前状态 == to: return
	当前状态 = to
	match to:
		State.IDLE: _切换动画("待机")
		State.MOVE: _切换动画("移动")
		State.BUILD: _切换动画("待机")


func _切换动画(动画名: String) -> void:
	if 角色动画 and 角色动画.has_animation(动画名):
		角色动画.play(动画名)


func _处理待机状态(delta: float) -> void:
	# 有移动/攻击/巡逻命令 → 切换到移动
	if 当前命令 in [命令类型.移动, 命令类型.攻击, 命令类型.巡逻]:
		if 目标位置 != Vector2.ZERO:
			切换状态(State.MOVE)
			return

	var 排斥力 := _计算排斥力()
	if 排斥力 != Vector2.ZERO:
		velocity = velocity.move_toward(排斥力, 加速度 * 10 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 加速度 * 10 * delta)


func _处理移动状态(delta: float) -> void:
	# 到达建造目标
	if _建造目标 and is_instance_valid(_建造目标):
		if global_position.distance_to(_建造目标.global_position) < 60:
			切换状态(State.BUILD)
			return

	# 导航移动
	if _导航移动到(目标位置, delta):
		当前命令 = 命令类型.无
		切换状态(State.IDLE)


## 建造建筑
func 命令建造(建筑位置: Vector2) -> void:
	目标位置 = 建筑位置
	当前命令 = 命令类型.移动
	导航代理.target_position = 建筑位置
	切换状态(State.MOVE)


## 简单攻击（防身用）
func 执行攻击() -> void:
	pass
