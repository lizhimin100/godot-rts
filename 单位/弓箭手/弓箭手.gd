extends 单位基类
class_name 弓箭手

## 弓箭手 — RTS 远程单位
## 状态机由 单元状态机 管理，本类只负责战斗和动画

@export var 攻击力: float = 8.0
@export var 攻击范围: float = 150.0
@export var 攻击间隔: float = 0.8

const 玩家纹理: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Archer/Blue/Archer_Blue.png")
const 敌人纹理: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Archer/Red/Archer_Red.png")
const 箭矢场景: PackedScene = preload("res://单位/弓箭手/箭矢.tscn")

@onready var 角色图像: Sprite2D = $角色图像
@onready var 角色动画: AnimationPlayer = $角色动画


func _ready() -> void:
	stats = UnitStats.create_弓箭手_stats()
	stats.attack = 攻击力
	stats.attack_range = 攻击范围
	stats.attack_cooldown = 攻击间隔
	# 移动速度由场景值决定，stats 不覆盖

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

	# 纹理和材质
	var 新材质 = 角色图像.material.duplicate()
	角色图像.material = 新材质

	if _是敌人():
		角色图像.texture = 敌人纹理
		角色图像.material.set_shader_parameter("outline_color", Color(0.9, 0.2, 0.2, 1))
	else:
		角色图像.texture = 玩家纹理

	角色动画.play("待机")
	角色动画.animation_finished.connect(_on_动画结束)


func _physics_process(delta: float) -> void:
	# ⭐ 单驱动力原则：唯一 move_and_slide 入口 + 朝向
	super._physics_process(delta)

	# 攻击时面向目标，移动时面向速度方向
	if _状态机 and _状态机.当前状态 == 单元状态机.状态.攻击:
		var target = 索敌组件.get_target() if 索敌组件 else null
		if target and is_instance_valid(target):
			角色图像.flip_h = target.global_position.x < global_position.x
	elif velocity.x != 0:
		角色图像.flip_h = velocity.x < 0


func _切换动画(动画名: String) -> void:
	if 角色动画 and 角色动画.has_animation(动画名):
		角色动画.play(动画名)


func _on_动画结束(anim_name: String) -> void:
	if anim_name == "攻击":
		if _状态机 and _状态机.当前状态 == 单元状态机.状态.攻击:
			角色动画.play("待机")
			角色动画.stop()


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
	# 状态机会自动决定下一状态（追击还是待机）
	if _状态机:
		_状态机.立即响应()
