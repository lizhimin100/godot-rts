extends 单位基类
class_name 弓箭手

## 弓箭手 — RTS 远程单位
##
## 3 状态状态机：待机 / 移动 / 攻击
## ⚠ 速度由 运动服务 统一管理，本类不写 velocity

enum 状态 {
	待机,
	移动,
	攻击,
}

@export var 攻击力: float = 8.0
@export var 攻击范围: float = 150.0
@export var 攻击间隔: float = 0.8

const 玩家纹理: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Archer/Blue/Archer_Blue.png")
const 敌人纹理: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Archer/Red/Archer_Red.png")
const 箭矢场景: PackedScene = preload("res://单位/弓箭手/箭矢.tscn")

var 当前状态: 状态 = 状态.待机
var _追击上限: float = 400.0

@onready var 角色图像: Sprite2D = $角色图像
@onready var 角色动画: AnimationPlayer = $角色动画


func _ready() -> void:
	stats = UnitStats.create_弓箭手_stats()
	stats.attack = 攻击力
	stats.attack_range = 攻击范围
	stats.attack_cooldown = 攻击间隔
	# 移动速度由场景值决定，stats 不覆盖
	_追击上限 = stats.chase_range

	super._ready()

	战斗组件.attack_damage = stats.attack
	战斗组件.attack_range = stats.attack_range
	战斗组件.attack_cooldown = stats.attack_cooldown
	战斗组件.windup_time = 0.15
	战斗组件.recovery_time = 0.25
	战斗组件.cooldown_timing = CombatComponent.CooldownTiming.AT_STRIKE

	if 战斗组件.attack_strike.is_connected(_on_默认打击):
		战斗组件.attack_strike.disconnect(_on_默认打击)
	战斗组件.attack_started.connect(_on_攻击开始)
	战斗组件.attack_strike.connect(_on_打击)
	战斗组件.attack_finished.connect(_on_攻击结束)

	当前状态 = 状态.待机
	var 新材质 = 角色图像.material.duplicate()
	角色图像.material = 新材质

	if _是敌人():
		角色图像.texture = 敌人纹理
		角色图像.material.set_shader_parameter("outline_color", Color(0.9, 0.2, 0.2, 1))
	else:
		角色图像.texture = 玩家纹理

	角色动画.play("待机")
	角色动画.animation_finished.connect(_on_动画结束)

	# 监听移动结束信号
	移动结束.connect(_on_弓箭手移动结束)


func _physics_process(delta: float) -> void:
	_同步命令状态()

	match 当前状态:
		状态.待机:
			_处理待机(delta)
		状态.移动:
			_处理移动(delta)
		状态.攻击:
			_处理攻击(delta)

	super._physics_process(delta)

	if 当前状态 == 状态.攻击:
		var target = 索敌组件.get_target() if 索敌组件 else null
		if target and is_instance_valid(target):
			角色图像.flip_h = target.global_position.x < global_position.x
	elif velocity.x != 0:
		角色图像.flip_h = velocity.x < 0


func _on_弓箭手移动结束(结果: 移动结果) -> void:
	match 结果.结果:
		移动结果.结果类型.已到达:
			match 当前命令:
				命令管理器.命令类型.攻击:
					var target = 索敌组件.get_target()
					if not target or not is_instance_valid(target):
						当前命令 = 命令管理器.命令类型.无
						切换状态(状态.待机)
				_:
					当前命令 = 命令管理器.命令类型.无
					切换状态(状态.待机)

		移动结果.结果类型.目标丢失:
			当前命令 = 命令管理器.命令类型.无
			切换状态(状态.待机)

		_:
			pass


func 切换状态(to: 状态) -> void:
	if 当前状态 == to:
		return
	当前状态 = to
	match to:
		状态.待机: _切换动画("待机")
		状态.移动: _切换动画("移动")
		状态.攻击: _切换动画("攻击")


func _切换动画(动画名: String) -> void:
	if 角色动画 and 角色动画.has_animation(动画名):
		角色动画.play(动画名)


func _on_动画结束(anim_name: String) -> void:
	if anim_name == "攻击" and 当前状态 == 状态.攻击:
		角色动画.play("待机")
		角色动画.stop()


# ============================================================
# 命令同步
# ============================================================

func _同步命令状态() -> void:
	match 当前命令:
		命令管理器.命令类型.移动:
			if 当前状态 != 状态.移动:
				切换状态(状态.移动)

		命令管理器.命令类型.攻击:
			var target = 索敌组件.get_target() if 索敌组件 else null
			if target and is_instance_valid(target):
				if 当前状态 == 状态.待机:
					切换状态(状态.移动)
				elif 当前状态 == 状态.攻击:
					if global_position.distance_to(target.global_position) > 攻击范围:
						切换状态(状态.移动)

		命令管理器.命令类型.停止, 命令管理器.命令类型.驻守, _:
			if 当前状态 != 状态.待机:
				切换状态(状态.待机)


# ============================================================
# 待机
# ============================================================

func _处理待机(delta: float) -> void:
	if 当前命令 in [命令管理器.命令类型.移动, 命令管理器.命令类型.攻击, 命令管理器.命令类型.巡逻]:
		if 目标位置 != Vector2.ZERO:
			切换状态(状态.移动)
		return

	if 当前命令 == 命令管理器.命令类型.驻守:
		return

	if 当前命令 == 命令管理器.命令类型.无:
		var target = 索敌组件.get_target() if 索敌组件 else null
		if target and is_instance_valid(target):
			目标位置 = target.global_position
			当前命令 = 命令管理器.命令类型.攻击
			切换状态(状态.移动)


# ============================================================
# 移动
# ============================================================

func _处理移动(delta: float) -> void:
	var target = 索敌组件.get_target() if 索敌组件 else null

	if target and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= 攻击范围:
			立即停止()
			切换状态(状态.攻击)
			return
		目标位置 = target.global_position

	# 速度由 运动服务 统一管理


# ============================================================
# 攻击
# ============================================================

func _处理攻击(delta: float) -> void:
	var target = 索敌组件.get_target() if 索敌组件 else null
	if target and is_instance_valid(target):
		if global_position.distance_to(target.global_position) > 攻击范围:
			切换状态(状态.移动)


# ============================================================
# CombatComponent 信号响应
# ============================================================

func _on_攻击开始(_target: Node2D) -> void:
	_切换动画("攻击")

func _on_打击(target: Node2D, packet: DamagePacket) -> void:
	if target and is_instance_valid(target):
		var arrow = 箭矢场景.instantiate()
		arrow.target_position = target.global_position
		arrow.damage_packet = packet
		arrow.attacker = self
		get_parent().add_child(arrow)
		arrow.global_position = global_position + Vector2(20 if not 角色图像.flip_h else -20, -10)

func _on_攻击结束(_target: Node2D) -> void:
	var target = 索敌组件.get_target() if 索敌组件 else null
	if target and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist <= 攻击范围:
			pass
		else:
			切换状态(状态.移动)
	elif 当前命令 == 命令管理器.命令类型.无:
		切换状态(状态.待机)
